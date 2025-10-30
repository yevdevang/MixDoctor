//
//  DashboardView.swift
//  MixDoctor
//
//  Main dashboard view for managing and viewing audio files
//

import SwiftUI
import SwiftData
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioFile.dateImported, order: .reverse) private var audioFiles: [AudioFile]
    
    @StateObject private var iCloudMonitor = iCloudSyncMonitor.shared

    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .date
    @State private var selectedFile: AudioFile?

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case analyzed = "Analyzed"
        case pending = "Pending"
        case issues = "Has Issues"
    }
    
    enum SortOption: String, CaseIterable {
        case date = "Sort by Date"
        case name = "Sort by Name"
        case score = "Sort by Score"
    }

    var filteredFiles: [AudioFile] {
        var files = audioFiles

        // Apply search filter
        if !searchText.isEmpty {
            files = files.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply status filter
        switch filterOption {
        case .all:
            break
        case .analyzed:
            files = files.filter { $0.analysisResult != nil }
        case .pending:
            files = files.filter { $0.analysisResult == nil }
        case .issues:
            files = files.filter {
                guard let result = $0.analysisResult else { return false }
                return result.hasPhaseIssues || result.hasStereoIssues ||
                       result.hasFrequencyImbalance || result.hasDynamicRangeIssues
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .date:
            files.sort { $0.dateImported > $1.dateImported }
        case .name:
            files.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .score:
            files.sort { (file1, file2) in
                let score1 = file1.analysisResult?.overallScore ?? 0
                let score2 = file2.analysisResult?.overallScore ?? 0
                return score1 > score2
            }
        }

        return files
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // iCloud sync status banner
                if iCloudMonitor.isSyncing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing files from iCloud...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color.blue.opacity(0.1))
                }
                
                if audioFiles.isEmpty {
                    emptyStateView
                } else {
                    // Statistics cards
                    statisticsView

                    // Filter picker
                    filterPicker

                    // Files list
                    filesList
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search audio files")
            .toolbar {
                // iCloud sync button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await iCloudMonitor.syncNow()
                        }
                    } label: {
                        Label("Sync iCloud", systemImage: iCloudMonitor.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.down")
                    }
                    .disabled(iCloudMonitor.isSyncing)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { sortOption = .date }) {
                            Label("Sort by Date", systemImage: "calendar")
                            if sortOption == .date {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button(action: { sortOption = .name }) {
                            Label("Sort by Name", systemImage: "textformat")
                            if sortOption == .name {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button(action: { sortOption = .score }) {
                            Label("Sort by Score", systemImage: "star")
                            if sortOption == .score {
                                Image(systemName: "checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .tint(Color(red: 0.435, green: 0.173, blue: 0.871))
        .onAppear {
            #if canImport(UIKit)
            // Set navigation title color to purple
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)]
            appearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            #endif
            
            // Check for missing files and trigger downloads
            Task {
                await checkAndDownloadMissingFiles()
                // Also scan for new files in iCloud that aren't in database yet
                await scanAndImportFromiCloud()
            }
        }
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCard(
                title: "Total Files",
                value: "\(audioFiles.count)",
                icon: "music.note.list",
                color: .blue
            )

            StatCard(
                title: "Analyzed",
                value: "\(analyzedCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            StatCard(
                title: "Issues Found",
                value: "\(issuesCount)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )

            StatCard(
                title: "Avg Score",
                value: String(format: "%.0f", averageScore),
                icon: "star.fill",
                color: .purple
            )
        }
        .padding()
        .background(Color.backgroundSecondary)
    }

    private var analyzedCount: Int {
        audioFiles.filter { $0.analysisResult != nil }.count
    }

    private var issuesCount: Int {
        audioFiles.compactMap { $0.analysisResult }.filter {
            $0.hasPhaseIssues || $0.hasStereoIssues ||
            $0.hasFrequencyImbalance || $0.hasDynamicRangeIssues
        }.count
    }

    private var averageScore: Double {
        let scores = audioFiles.compactMap { $0.analysisResult?.overallScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $filterOption) {
            ForEach(FilterOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onAppear {
            #if canImport(UIKit)
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)], for: .normal)
            #endif
        }
    }

    // MARK: - Files List

    private var filesList: some View {
        List {
            ForEach(filteredFiles) { file in
                NavigationLink(value: file) {
                    AudioFileRow(audioFile: file)
                }
            }
            .onDelete(perform: deleteFiles)
        }
        .refreshable {
            await iCloudMonitor.syncNow()
            await scanAndImportFromiCloud()
        }
        .navigationDestination(for: AudioFile.self) { file in
            ResultsView(audioFile: file)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ScrollView {
            VStack {
                Spacer()
                ContentUnavailableView(
                    "No Audio Files",
                    systemImage: "music.note",
                    description: Text("Import audio files to get started.\n\nPull down to sync from iCloud.")
                )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .refreshable {
            await iCloudMonitor.syncNow()
            await scanAndImportFromiCloud()
        }
    }

    // MARK: - Actions
    
    private func checkAndDownloadMissingFiles() async {
        print("🔍 Checking for missing files in Dashboard...")
        
        var missingFiles: [(AudioFile, URL)] = []
        
        for file in audioFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            print("📄 File: \(file.fileName)")
            print("   Path: \(fileURL.path)")
            print("   Exists locally: \(fileExists)")
            
            if !fileExists {
                missingFiles.append((file, fileURL))
                
                // Check if file exists in iCloud but not downloaded
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isUbiquitousItemKey,
                        .ubiquitousItemDownloadingStatusKey
                    ])
                    
                    if let isICloud = values.isUbiquitousItem, isICloud {
                        print("   ☁️ File exists in iCloud, downloading status: \(values.ubiquitousItemDownloadingStatus?.rawValue ?? "unknown")")
                    }
                } catch {
                    print("   ⚠️ Could not check iCloud status: \(error)")
                }
            }
        }
        
        if !missingFiles.isEmpty {
            print("⬇️ Found \(missingFiles.count) missing file(s), triggering download...")
            
            // Trigger iCloud sync to download missing files
            await iCloudMonitor.syncNow()
            
            // Additional attempt to explicitly download each missing file
            for (file, fileURL) in missingFiles {
                do {
                    print("📥 Attempting to download: \(file.fileName)")
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                } catch {
                    print("❌ Failed to start download for \(file.fileName): \(error)")
                }
            }
        } else {
            print("✅ All files exist locally")
        }
    }
    
    private func scanAndImportFromiCloud() async {
        print("🔍 Auto-scanning iCloud Drive for new audio files...")
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter audio files
            let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "aif", "aiff"]
            let audioFiles = files.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            
            var imported = 0
            
            for fileURL in audioFiles {
                // Check if already imported
                let fileName = fileURL.lastPathComponent
                let descriptor = FetchDescriptor<AudioFile>(
                    predicate: #Predicate<AudioFile> { $0.fileName == fileName }
                )
                
                if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
                    continue // Already imported
                }
                
                // Download if needed
                do {
                    let values = try fileURL.resourceValues(forKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey])
                    if values.ubiquitousItemDownloadingStatus == .notDownloaded {
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                } catch {
                    print("⚠️ Download check error: \(error)")
                }
                
                // Import the file
                do {
                    let asset = AVURLAsset(url: fileURL)
                    let duration = try await asset.load(.duration).seconds
                    let tracks = try await asset.loadTracks(withMediaType: .audio)
                    
                    guard let track = tracks.first else { continue }
                    
                    let formatDescriptions = try await track.load(.formatDescriptions)
                    guard let formatDescription = formatDescriptions.first else { continue }
                    
                    let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    let sampleRate = basicDescription?.pointee.mSampleRate ?? 44100.0
                    let channels = Int(basicDescription?.pointee.mChannelsPerFrame ?? 2)
                    
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    
                    let audioFile = AudioFile(
                        fileName: fileName,
                        fileURL: fileURL,
                        duration: duration,
                        sampleRate: sampleRate,
                        bitDepth: 16,
                        numberOfChannels: channels,
                        fileSize: fileSize
                    )
                    
                    modelContext.insert(audioFile)
                    try modelContext.save()
                    
                    print("✅ Auto-imported: \(fileName)")
                    imported += 1
                } catch {
                    print("❌ Failed to auto-import \(fileName): \(error)")
                }
            }
            
            if imported > 0 {
                print("📊 Auto-import complete: \(imported) new file(s)")
            }
        } catch {
            print("❌ Error scanning directory: \(error)")
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = filteredFiles[index]
            print("🗑️ Deleting file from Dashboard: \(file.fileName)")
            
            // Delete the actual audio file from storage (iCloud or local)
            let fileURL = file.fileURL
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ Deleted audio file: \(fileURL.lastPathComponent)")
                } catch {
                    print("❌ Failed to delete audio file: \(error)")
                }
            }
            
            // Delete the SwiftData record
            modelContext.delete(file)
        }
        try? modelContext.save()
        
        // Notify other views that files were deleted
        print("📢 Posting audioFileDeleted notification")
        NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AudioFile.self, configurations: config)
    let context = container.mainContext
    
    // Create sample data
    for i in 1...5 {
        let audioFile = AudioFile(
            fileName: "Track \(i).wav",
            fileURL: URL(fileURLWithPath: "/tmp/track\(i).wav"),
            duration: Double.random(in: 120...300),
            sampleRate: 44100,
            bitDepth: 24,
            numberOfChannels: 2,
            fileSize: Int64.random(in: 10_000_000...50_000_000)
        )
        context.insert(audioFile)
    }
    
    return DashboardView()
        .modelContainer(container)
}
