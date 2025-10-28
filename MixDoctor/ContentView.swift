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
    @AppStorage("theme") private var theme: String = "system"
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AudioFile.self], inMemory: true)
}
