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
    private let analysisService = AudioKitService.shared
    private let subscriptionService = SubscriptionService.shared

    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .date
    @State private var selectedFile: AudioFile?
    @State private var isAnalyzing = false
    @State private var analyzingFile: AudioFile?
    @State private var navigateToFile: AudioFile?

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
                return hasActualIssues(result: result)
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
                    HStack(spacing: 12) {
                        // Animated sync icon
                        ProgressView()
                            .tint(Color(red: 0.435, green: 0.173, blue: 0.871))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Syncing with iCloud")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text("Checking for new files and updates...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.08),
                                Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.2)),
                        alignment: .bottom
                    )
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
                        if iCloudMonitor.isSyncing {
                            ProgressView()
                                .tint(Color(red: 0.435, green: 0.173, blue: 0.871))
                        } else {
                            Label("Sync iCloud", systemImage: "icloud.and.arrow.down")
                        }
                    }
                    .disabled(iCloudMonitor.isSyncing)
                    .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
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
            
            // Debug: Log database state
            for file in audioFiles {
            }
            
            // Check for missing files and trigger downloads
            Task {
                await checkAndDownloadMissingFiles()
                // Also scan for new files in iCloud that aren't in database yet
                await scanAndImportFromiCloud()
                // Load analysis results for existing files that don't have them
                await loadMissingAnalysisResults()
            }
        }
        .onChange(of: iCloudMonitor.isSyncing) { oldValue, newValue in
            // When sync finishes (goes from true to false), automatically scan and load
            if oldValue == true && newValue == false {
                Task {
                    await scanAndImportFromiCloud()
                    await loadMissingAnalysisResults()
                }
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
        audioFiles.compactMap { $0.analysisResult }.filter { hasActualIssues(result: $0) }.count
    }

    private var averageScore: Double {
        let scores = audioFiles.compactMap { $0.analysisResult?.overallScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    // Helper function to detect actual issues based on score and metrics
    private func hasActualIssues(result: AnalysisResult) -> Bool {
        // If score is high (85+), likely no significant issues (matches Professional Commercial threshold)
        if result.overallScore >= 85 {
            return false
        }
        
        // Check for actual metric-based issues
        let hasPhaseIssues = result.phaseCoherence < 0.7
        let hasStereoIssues = result.stereoWidthScore < 30 || result.stereoWidthScore > 90
        let hasFreqIssues = (result.lowEndBalance > 60 || result.lowEndBalance < 15) ||
                           (result.midBalance < 25 || result.midBalance > 55) ||
                           (result.highBalance < 10 || result.highBalance > 45)
        let hasDynamicIssues = result.dynamicRange < 8
        let hasLevelIssues = result.peakLevel > -1 || result.loudnessLUFS > -10 || result.loudnessLUFS < -30
        
        return hasPhaseIssues || hasStereoIssues || hasFreqIssues || hasDynamicIssues || hasLevelIssues || 
               result.hasClipping || result.hasInstrumentBalanceIssues
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
                Button {
                    handleAudioFileSelection(file)
                } label: {
                    AudioFileRow(audioFile: file)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onDelete(perform: deleteFiles)
        }
        .refreshable {
            await iCloudMonitor.syncNow()
            await scanAndImportFromiCloud()
            await loadMissingAnalysisResults()
        }
        .navigationDestination(item: $navigateToFile) { file in
            ResultsView(audioFile: file)
        }
        .fullScreenCover(isPresented: $isAnalyzing) {
            if let file = analyzingFile {
                AnimatedGradientLoader(fileName: file.fileName)
            }
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
            await loadMissingAnalysisResults()
        }
    }

    // MARK: - Actions
    
    private func handleAudioFileSelection(_ file: AudioFile) {
        Task {
            // Check if file already has analysis
            if file.analysisResult != nil {
                // Navigate directly to results
                navigateToFile = file
                return
            }
            
            // Check if user can perform analysis
            guard subscriptionService.canPerformAnalysis() else {
                // Show paywall or error
                // For now, navigate to results view which will handle the paywall
                navigateToFile = file
                return
            }
            
            // Start analysis with loader
            analyzingFile = file
            isAnalyzing = true
            
            do {
                
                // Perform the analysis
                let result = try await analysisService.getDetailedAnalysis(for: file.fileURL)
                
                
                // Increment usage count for free users
                subscriptionService.incrementAnalysisCount()
                
                // Save to the AudioFile model
                file.analysisResult = result
                file.dateAnalyzed = Date()
                
                // Save to SwiftData
                try modelContext.save()
                
                // Save to iCloud Drive as JSON for cross-device sync
                do {
                    try AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: file.fileName)
                } catch {
                }
                
                
                // Hide loader and navigate
                isAnalyzing = false
                analyzingFile = nil
                navigateToFile = file
                
            } catch {
                isAnalyzing = false
                analyzingFile = nil
                // Still navigate to show error in ResultsView
                navigateToFile = file
            }
        }
    }
    
    private func checkAndDownloadMissingFiles() async {
        
        var missingFiles: [(AudioFile, URL)] = []
        
        for file in audioFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            
            if !fileExists {
                missingFiles.append((file, fileURL))
                
                // Check if file exists in iCloud but not downloaded
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isUbiquitousItemKey,
                        .ubiquitousItemDownloadingStatusKey
                    ])
                    
                    if let isICloud = values.isUbiquitousItem, isICloud {
                    }
                } catch {
                }
            }
        }
        
        if !missingFiles.isEmpty {
            
            // Trigger iCloud sync to download missing files
            await iCloudMonitor.syncNow()
            
            // Additional attempt to explicitly download each missing file
            for (file, fileURL) in missingFiles {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                } catch {
                }
            }
        } else {
        }
    }
    
    private func scanAndImportFromiCloud() async {
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter audio files - use all supported formats from AppConstants
            let audioFiles = files.filter { 
                AppConstants.supportedAudioFormats.contains($0.pathExtension.lowercased()) 
            }
            
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
                    
                    // Try to load analysis result from iCloud Drive
                    if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: fileName) {
                        analysisResult.audioFile = audioFile
                        audioFile.analysisResult = analysisResult
                        audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                    } else {
                    }
                    
                    try modelContext.save()
                    
                    imported += 1
                } catch {
                }
            }
            
            if imported > 0 {
            }
        } catch {
        }
    }
    
    private func loadMissingAnalysisResults() async {
        
        let currentVersion = "AudioKit-\(AppConstants.analysisVersion)"
        var loadedCount = 0
        var clearedCount = 0
        
        // Check all files that don't have analysis results in SwiftData
        for audioFile in audioFiles where audioFile.analysisResult == nil {
            // Try to load from iCloud Drive JSON
            if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: audioFile.fileName) {
                // Check version compatibility
                if analysisResult.analysisVersion == currentVersion {
                    analysisResult.audioFile = audioFile
                    audioFile.analysisResult = analysisResult
                    audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                    loadedCount += 1
                } else {
                    AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName)
                    clearedCount += 1
                }
            }
        }
        
        // Also check files that HAVE analysis results but with wrong version
        for audioFile in audioFiles {
            if let analysisResult = audioFile.analysisResult, analysisResult.analysisVersion != currentVersion {
                audioFile.analysisResult = nil
                audioFile.dateAnalyzed = nil
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName)
                clearedCount += 1
            }
        }
        
        if loadedCount > 0 || clearedCount > 0 {
            do {
                try modelContext.save()
                if loadedCount > 0 {
                }
                if clearedCount > 0 {
                }
            } catch {
            }
        } else {
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = filteredFiles[index]
            
            // Delete the actual audio file from storage (iCloud or local)
            let fileURL = file.fileURL
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
            }
        }
        
        // Delete the analysis result JSON from iCloud Drive
        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName)
        
        // Delete the SwiftData record
        modelContext.delete(file)
        }
        try? modelContext.save()
        
        // Notify other views that files were deleted
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
