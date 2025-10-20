//
//  ContentView.swift
//  MixDoctor
//
//  Created by Yevgeny Levin on 17/10/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
            
            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AudioFile.self, AnalysisResult.self])
}
