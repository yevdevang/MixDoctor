//
//  MixDoctorApp.swift
//  MixDoctor
//
//  Created by Yevgeny Levin on 17/10/2025.
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct MixDoctorApp: App {
    @State private var modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService.shared
    @State private var iCloudMonitor = iCloudSyncMonitor.shared
    @State private var showWelcomeMessage = false
    @State private var showLaunchScreen = true
    @StateObject private var ratingService: RatingService
    @Environment(\.requestReview) private var requestReview
    
    init() {
        // Configure Mac Catalyst fonts FIRST, before anything else
        #if targetEnvironment(macCatalyst)
        Self.configureMacCatalystFonts()
        #endif
        
        // Check if user has enabled iCloud sync (default to true for better UX)
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        do {
            let schema = Schema([AudioFile.self])
            
            // Get the application support directory
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
            
            // Schema version tracking for migration
            let currentSchemaVersion = 4  // Incremented - ensure clean schema
            let lastSchemaVersion = UserDefaults.standard.integer(forKey: "lastSchemaVersion")
            
            // If there's a corrupted store or schema changed, delete it
            if FileManager.default.fileExists(atPath: storeURL.path) {
                // Check if we had a migration failure or schema version changed
                if UserDefaults.standard.bool(forKey: "hadMigrationFailure") || lastSchemaVersion < currentSchemaVersion {
                    print("⚠️ Deleting old store - schema version: \(lastSchemaVersion) -> \(currentSchemaVersion)")
                    try? FileManager.default.removeItem(at: storeURL)
                    // Also clean up any -wal or -shm files
                    try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-wal"))
                    try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-shm"))
                    UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
                    UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
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
            
            print("✅ ModelContainer created successfully with CloudKit: \(iCloudEnabled)")
            
            // Save schema version on successful initialization
            UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
            
        } catch {
            // Mark that we had a failure and try to delete and recreate
            UserDefaults.standard.set(true, forKey: "hadMigrationFailure")
            
            // Delete the store and try again
            do {
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
                
                print("🔄 Attempting recovery - deleting corrupted store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-wal"))
                try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-shm"))
                
                let schema = Schema([AudioFile.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none  // Fallback to local only on error
                )
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                
                print("✅ ModelContainer recovered successfully (local only)")
                
                // Clear the failure flag since it worked
                UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
            } catch {
                fatalError("Could not create ModelContainer even after deleting store: \(error)")
            }
        }
        _ratingService = StateObject(wrappedValue: RatingService.shared)
    }
    
    #if targetEnvironment(macCatalyst)
    private static func configureMacCatalystFonts() {
        // Scale all UIKit fonts by 1.4x (40% larger) for Mac Catalyst
        let fontScale: CGFloat = 1.4
        
        // Navigation bar fonts
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34 * fontScale, weight: .bold)
        ]
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17 * fontScale, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Tab bar fonts
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10 * fontScale)
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10 * fontScale)
        ]
        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    #endif
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .modelContainer(modelContainer)
                    .environmentObject(ratingService)
                    .macCatalystFontScaling(1.5) // Scale entire UI by 50% on Mac
                    .onChange(of: ratingService.shouldTriggerRating) { _, shouldTrigger in
                        if shouldTrigger {
                            requestReview()
                        }
                    }
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
                // Hide launch screen after animation (matched to audio length: 3 bars @ 120bpm = 6s + delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
