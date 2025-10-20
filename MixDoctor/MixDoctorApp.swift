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
    
    init() {
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        do {
            let schema = Schema([AudioFile.self, AnalysisResult.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: iCloudEnabled ? .automatic : .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
