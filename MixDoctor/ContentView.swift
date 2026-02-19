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
        #if targetEnvironment(macCatalyst)
        macOSView
        #else
        iOSView
        #endif
    }
    
    // MARK: - macOS/Catalyst View
    
    #if targetEnvironment(macCatalyst)
    private var macOSView: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar
            List {
                sidebarButton(title: "Dashboard", icon: "square.grid.2x2", tag: 0)
                sidebarButton(title: "Import", icon: "square.and.arrow.down", tag: 1)
                sidebarButton(title: "Player", icon: isPlaying ? "pause.circle.fill" : "play.circle", tag: 2)
                sidebarButton(title: "Settings", icon: "gear", tag: 3)
            }
            .listStyle(.sidebar)
            .navigationTitle("Mix Doctor")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Main content area - use id to preserve view identity and add animation
            Group {
                switch selectedTab {
                case 0:
                    DashboardView()
                        .id("dashboard")
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                case 1:
                    ImportView(
                        selectedAudioFile: $selectedAudioFile,
                        selectedTab: $selectedTab,
                        shouldAutoPlay: $shouldAutoPlay
                    )
                    .id("import")
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                case 2:
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
                    .id("player")
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                case 3:
                    SettingsView()
                        .id("settings")
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                default:
                    DashboardView()
                        .id("dashboard")
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
            .navigationTitle(navigationTitle)
        }
        .tint(.primaryAccent)
        .preferredColorScheme(colorScheme)
        .onAppear(perform: setupThemeObservers)
        .onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
            // Just clear selection - @Query will auto-update when SwiftData changes
            // Don't access allAudioFiles here - it triggers blocking SwiftData fetch!
            selectedAudioFile = nil
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "Dashboard"
        case 1: return "Import"
        case 2: return "Player"
        case 3: return "Settings"
        default: return "Mix Doctor"
        }
    }
    
    @ViewBuilder
    private func sidebarButton(title: String, icon: String, tag: Int) -> some View {
        Button(action: {
            // Debounce tab selection to prevent rapid switching
            guard selectedTab != tag else { return }
            selectedTab = tag
        }) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(colorScheme == .dark ? .white : Color.primaryAccent)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            selectedTab == tag 
                ? RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primaryAccent.opacity(colorScheme == .dark ? 0.3 : 0.15))
                : nil
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
    }
    #endif
    
    // MARK: - iOS/iPadOS View
    
    private var iOSView: some View {
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
        .tint(.primaryAccent)
        .preferredColorScheme(colorScheme)
        .onAppear(perform: setupThemeObservers)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OnboardingCompleted"))) { _ in
            // Only navigate to Import tab immediately after onboarding completes
            // Wait a moment for SwiftData to finish loading files
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second (allow demo files to load)
                await MainActor.run {
                    // Only navigate if there are truly no files
                    if allAudioFiles.isEmpty {
                        selectedTab = 1 // Import tab
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
            // Just clear selection - @Query will auto-update when SwiftData changes
            // Don't access allAudioFiles here - it triggers blocking SwiftData fetch!
            selectedAudioFile = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupThemeObservers() {
        // Load theme from iCloud
        theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
        
        // Listen for iCloud theme changes from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
        }
        
        // Listen for local theme changes within this app
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ThemeDidChange"),
            object: nil,
            queue: .main
        ) { _ in
            theme = NSUbiquitousKeyValueStore.default.string(forKey: "theme") ?? "system"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AudioFile.self], inMemory: true)
}
