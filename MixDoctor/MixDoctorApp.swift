//
//  MixDoctorApp.swift
//  MixDoctor
//
//  Created by Yevgeny Levin on 17/10/2025.
//

import SwiftUI
import SwiftData

@main
struct MixDoctorApp: App {
    @State private var modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService.shared
    @State private var iCloudMonitor = iCloudSyncMonitor.shared
    @State private var showWelcomeMessage = false
    @State private var showLaunchScreen = true
    
    init() {
        // Check if user has enabled iCloud sync (default to true for better UX)
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        do {
            let schema = Schema([AudioFile.self])
            
            // Get the application support directory
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
            
            // Schema version tracking for migration
            let currentSchemaVersion = 3  // Incremented for CloudKit integration
            let lastSchemaVersion = UserDefaults.standard.integer(forKey: "lastSchemaVersion")
            
            // If there's a corrupted store or schema changed, delete it
            if FileManager.default.fileExists(atPath: storeURL.path) {
                // Check if we had a migration failure or schema version changed
                if UserDefaults.standard.bool(forKey: "hadMigrationFailure") || lastSchemaVersion < currentSchemaVersion {
                    try? FileManager.default.removeItem(at: storeURL)
                    UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
                    UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
                    print("🔄 Removed old database (schema v\(lastSchemaVersion) -> v\(currentSchemaVersion))")
                }
            }
            
            // Configure CloudKit integration
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: iCloudEnabled ? .automatic : .none
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Save schema version on successful initialization
            UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
            
            print("✅ SwiftData initialized with CloudKit: \(iCloudEnabled ? "ENABLED" : "DISABLED")")
        } catch {
            print("❌ Initial ModelContainer creation failed: \(error)")
            // Mark that we had a failure and try to delete and recreate
            UserDefaults.standard.set(true, forKey: "hadMigrationFailure")
            
            // Delete the store and try again
            do {
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
                try? FileManager.default.removeItem(at: storeURL)
                
                let schema = Schema([AudioFile.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none  // Fallback to local only on error
                )
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                
                // Clear the failure flag since it worked
                UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
                print("⚠️ ModelContainer created in fallback mode (local only)")
            } catch {
                fatalError("Could not create ModelContainer even after deleting store: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .modelContainer(modelContainer)
                    .alert("Welcome to Mix Doctor! 🎵", isPresented: $showWelcomeMessage) {
                        Button("Got It!") {
                            showWelcomeMessage = false
                        }
                    } message: {
                        Text("You have 3 free analyses to get started. Upgrade to Pro for unlimited analyses and advanced features!")
                    }
                    .task {
                        // Check subscription status on launch
                        await subscriptionService.updateCustomerInfo()
                        
                        // Start iCloud file monitoring
                        iCloudMonitor.startMonitoring()
                        
                        // Show welcome message only for first-time free users
                        if !subscriptionService.isProUser {
                            let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcomeMessage")
                            if !hasSeenWelcome {
                                // Small delay to ensure UI is ready
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                showWelcomeMessage = true
                                UserDefaults.standard.set(true, forKey: "hasSeenWelcomeMessage")
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .iCloudSyncToggled)) { _ in
                        // User needs to restart app for iCloud sync changes to take effect
                    }
                    .opacity(showLaunchScreen ? 0 : 1)
                
                // Launch Screen
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Hide launch screen after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
