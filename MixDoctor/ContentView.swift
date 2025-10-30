//
//  ContentView.swift
//  MixDoctor
//
//  Created by Yevgeny Levin on 17/10/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedAudioFile: AudioFile?
    @State private var selectedTab = 0
    @State private var isPlaying = false
    @State private var shouldAutoPlay = false
    @State private var theme: String = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
    @Query(sort: \AudioFile.dateImported, order: .reverse) private var allAudioFiles: [AudioFile]
    
    var colorScheme: ColorScheme? {
        switch theme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(0)
            
            ImportView(
                selectedAudioFile: $selectedAudioFile,
                selectedTab: $selectedTab,
                shouldAutoPlay: $shouldAutoPlay
            )
            .tabItem {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .tag(1)
            
            PlayerView(
                audioFile: selectedAudioFile,
                allAudioFiles: allAudioFiles,
                shouldAutoPlay: $shouldAutoPlay,
                onSelectAudioFile: { file in
                    selectedAudioFile = file
                },
                onPlaybackStateChange: { playing in
                    isPlaying = playing
                }
            )
            .tabItem {
                    Label("Player", systemImage: isPlaying ? "pause.circle" : "play.circle")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(Color(red: 0.435, green: 0.173, blue: 0.871))
        .preferredColorScheme(colorScheme)
        .onAppear {
            // Load theme from iCloud
            theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
            
            // Listen for iCloud theme changes from other devices
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default,
                queue: .main
            ) { _ in
                theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
                print("☁️ Theme updated from iCloud (external): \(theme)")
            }
            
            // Listen for local theme changes within this app
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ThemeDidChange"),
                object: nil,
                queue: .main
            ) { _ in
                theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
                print("🎨 Theme updated locally: \(theme)")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AudioFile.self], inMemory: true)
}
