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
    
    init() {
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        do {
            let schema = Schema([AudioFile.self])
            
            // Get the application support directory
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
            
            // Schema version tracking for migration
            let currentSchemaVersion = 2  // Incremented due to AudioFile fileURL change
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
        } catch {
            print("Initial ModelContainer creation failed: \(error)")
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
                    url: storeURL
                )
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                
                // Clear the failure flag since it worked
                UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
            } catch {
                fatalError("Could not create ModelContainer even after deleting store: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .onReceive(NotificationCenter.default.publisher(for: .iCloudSyncToggled)) { _ in
                    // User needs to restart app for iCloud sync changes to take effect
                }
        }
    }
}
