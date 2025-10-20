//
//  MixDoctorApp.swift
//  MixDoctor
//
//  Main app entry point
//

import SwiftUI
import SwiftData

@main
struct MixDoctorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [AudioFile.self, AnalysisResult.self])
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Dashboard")
            }
            .tag(0)
            
            NavigationStack {
                ImportView()
            }
            .tabItem {
                Image(systemName: "plus.circle")
                Text("Import")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AudioFile.self, AnalysisResult.self], inMemory: true)
}