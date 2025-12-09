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
    @State private var hasPerformedInitialSync = false // Track if we've done initial sync
    @State private var isScanning = false // Prevent concurrent scans
    #if targetEnvironment(macCatalyst)
    @State private var fileToDelete: AudioFile?
    @State private var showDeleteConfirmation = false
    #endif

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
                            print("🔄 Manual sync triggered")
                            // First cleanup orphaned records
                            await checkAndDownloadMissingFiles()
                            // Then sync and scan
                            await iCloudMonitor.syncNow()
                            await scanAndImportFromiCloud()
                            await loadMissingAnalysisResults()
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
            #if targetEnvironment(macCatalyst)
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = nil
            #else
            appearance.configureWithDefaultBackground()
            #endif
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)]
            appearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            #endif
            
            // ALWAYS run orphan cleanup on appear (not just first time)
            // This ensures deleted files are removed immediately when switching back to Dashboard
            Task(priority: .userInitiated) {
                if !audioFiles.isEmpty {
                    print("🔍 View appeared - checking for orphaned records")
                    await checkAndDownloadMissingFiles()
                }
            }
            
            // Only run heavy operations once on first appear
            guard !hasPerformedInitialSync else { return }
            hasPerformedInitialSync = true
            
            // Perform initial sync in background with lower priority
            Task(priority: .utility) {
                // First, remove any duplicate entries
                await removeDuplicateFiles()
                
                // Only check for missing files if we have files in the database
                if !audioFiles.isEmpty {
                    // On MacCatalyst, aggressively check for orphaned records first
                    #if targetEnvironment(macCatalyst)
                    print("🖥️ MacCatalyst: Running aggressive orphan cleanup on launch")
                    await checkAndDownloadMissingFiles()
                    // Small delay to let iCloud settle
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    #endif
                    
                    await checkAndDownloadMissingFiles()
                }
                
                // Scan for new files in iCloud
                await scanAndImportFromiCloud()
                
                // Load analysis results for files that need them
                await loadMissingAnalysisResults()
            }
        }
        .onChange(of: iCloudMonitor.isSyncing) { oldValue, newValue in
            // When sync finishes (goes from true to false), check for new files and cleanup
            if oldValue == true && newValue == false {
                Task(priority: .utility) {
                    // First clean up any orphaned records from deleted files
                    await checkAndDownloadMissingFiles()
                    
                    // Then scan for new files
                    await scanAndImportFromiCloud()
                    await loadMissingAnalysisResults()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudSyncCompleted)) { _ in
            // When iCloud sync completes, check for orphaned records AND scan for new files
            print("🔔 Received iCloudSyncCompleted notification - scanning for new files")
            Task(priority: .utility) {
                await checkAndDownloadMissingFiles()
                await scanAndImportFromiCloud()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudFilesChanged)) { _ in
            // When iCloud files change, immediately check for orphaned records AND scan for new files
            print("🔔 Received iCloudFilesChanged notification - scanning for new files")
            Task(priority: .userInitiated) {
                await checkAndDownloadMissingFiles()
                await scanAndImportFromiCloud()
            }
        }
        #if targetEnvironment(macCatalyst)
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete,
                   let index = filteredFiles.firstIndex(where: { $0.id == file.id }) {
                    deleteFiles(at: IndexSet(integer: index))
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete '\(file.fileName)'? This will remove it from all your devices.")
            }
        }
        #endif
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
        #if !targetEnvironment(macCatalyst)
        .background(Color.backgroundSecondary)
        #endif
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
                    AudioFileRow(
                        audioFile: file,
                        onDelete: {
                            #if targetEnvironment(macCatalyst)
                            fileToDelete = file
                            showDeleteConfirmation = true
                            #else
                            if let index = filteredFiles.firstIndex(where: { $0.id == file.id }) {
                                deleteFiles(at: IndexSet(integer: index))
                            }
                            #endif
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                #if targetEnvironment(macCatalyst)
                .listRowBackground(Color.clear)
                #endif
            }
            .onDelete(perform: deleteFiles)
        }
        #if targetEnvironment(macCatalyst)
        .scrollContentBackground(.hidden)
        #endif
        .refreshable {
            await iCloudMonitor.syncNow()
            await scanAndImportFromiCloud()
            await loadMissingAnalysisResults()
        }
        .navigationDestination(item: $navigateToFile) { file in
            ResultsView(audioFile: file)
        }
        #if targetEnvironment(macCatalyst)
        .overlay {
            if isAnalyzing, let file = analyzingFile {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Analyzing \(file.fileName)...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
                .allowsHitTesting(true)
            }
        }
        #else
        .fullScreenCover(isPresented: $isAnalyzing) {
            if let file = analyzingFile {
                AnimatedGradientLoader(fileName: file.fileName)
            }
        }
        #endif
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack {
                    Spacer()
                    
                    VStack {
                        Spacer()
                        ContentUnavailableView(
                            "No Audio Files",
                            systemImage: "music.note",
                            description: Text("Import audio files to get started.\n\nPull down to sync from iCloud.")
                        )
                        Spacer()
                    }
                    .frame(maxWidth: 500, minHeight: geometry.size.height)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .refreshable {
                await iCloudMonitor.syncNow()
                await scanAndImportFromiCloud()
                await loadMissingAnalysisResults()
            }
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
            #if targetEnvironment(macCatalyst)
            // On Mac, ensure UI updates on main thread with delay for spinner to show
            await MainActor.run {
                analyzingFile = file
                isAnalyzing = true
            }
            // Small delay to allow UI to update and show the spinner
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            #else
            analyzingFile = file
            isAnalyzing = true
            #endif
            
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
                #if targetEnvironment(macCatalyst)
                await MainActor.run {
                    isAnalyzing = false
                    analyzingFile = nil
                    navigateToFile = file
                }
                #else
                isAnalyzing = false
                analyzingFile = nil
                navigateToFile = file
                #endif
                
            } catch {
                #if targetEnvironment(macCatalyst)
                await MainActor.run {
                    isAnalyzing = false
                    analyzingFile = nil
                    // Still navigate to show error in ResultsView
                    navigateToFile = file
                }
                #else
                isAnalyzing = false
                analyzingFile = nil
                // Still navigate to show error in ResultsView
                navigateToFile = file
                #endif
            }
        }
    }
    
    private func checkAndDownloadMissingFiles() async {
        print("🔍 Checking for missing or orphaned files...")
        
        var missingFiles: [(AudioFile, URL)] = []
        var orphanedRecords: [AudioFile] = []
        
        for file in audioFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            print("📄 Checking: \(file.fileName) - exists locally: \(fileExists)")
            
            if !fileExists {
                // Check if it's in iCloud but not downloaded, or truly deleted
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isUbiquitousItemKey,
                        .ubiquitousItemDownloadingStatusKey,
                        .ubiquitousItemIsUploadedKey
                    ])
                    
                    let isICloud = values.isUbiquitousItem ?? false
                    let downloadStatus = values.ubiquitousItemDownloadingStatus
                    let isUploaded = values.ubiquitousItemIsUploaded ?? false
                    
                    print("   iCloud file: \(isICloud), status: \(downloadStatus?.rawValue ?? "nil"), uploaded: \(isUploaded)")
                    
                    // If file is in iCloud AND has a valid download status AND is uploaded, try to download
                    if isICloud && isUploaded && downloadStatus != nil {
                        print("☁️ File in iCloud, will download: \(file.fileName)")
                        missingFiles.append((file, fileURL))
                    } else {
                        // File doesn't exist in iCloud or is being deleted - orphaned record
                        print("👻 Orphaned record detected (not in iCloud or being deleted): \(file.fileName)")
                        orphanedRecords.append(file)
                    }
                } catch {
                    // If we can't get resource values and file doesn't exist, it's orphaned
                    print("👻 Orphaned record (error checking): \(file.fileName) - \(error.localizedDescription)")
                    orphanedRecords.append(file)
                }
            }
        }
        
        // Clean up orphaned records (files deleted on another device)
        if !orphanedRecords.isEmpty {
            print("🗑️ Cleaning up \(orphanedRecords.count) orphaned record(s)")
            for record in orphanedRecords {
                print("   Removing orphaned record: \(record.fileName)")
                // Also delete the analysis result
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName)
                modelContext.delete(record)
            }
            do {
                try modelContext.save()
                print("✅ Successfully cleaned up orphaned records")
            } catch {
                print("❌ Failed to save after cleanup: \(error.localizedDescription)")
            }
        }
        
        // Download missing files that still exist in iCloud
        if !missingFiles.isEmpty {
            print("⬇️ Downloading \(missingFiles.count) missing file(s)")
            
            // Trigger iCloud sync to download missing files
            await iCloudMonitor.syncNow()
            
            // Additional attempt to explicitly download each missing file
            for (file, fileURL) in missingFiles {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                    print("   Started download: \(file.fileName)")
                } catch {
                    print("   Failed to start download: \(file.fileName)")
                }
            }
        } else if orphanedRecords.isEmpty {
            print("✅ All files are present and accounted for")
        }
    }
    
    /// Remove duplicate entries from the database (keeps oldest import)
    private func removeDuplicateFiles() async {
        print("🔍 Checking for duplicate files in database...")
        
        // Group files by fileName
        var filesByName: [String: [AudioFile]] = [:]
        for file in audioFiles {
            filesByName[file.fileName, default: []].append(file)
        }
        
        var duplicatesRemoved = 0
        
        for (fileName, files) in filesByName where files.count > 1 {
            print("⚠️ Found \(files.count) duplicates of: \(fileName)")
            
            // Sort by import date (oldest first) and keep the first one
            let sorted = files.sorted { $0.dateImported < $1.dateImported }
            let toKeep = sorted.first!
            let toDelete = sorted.dropFirst()
            
            print("   Keeping: imported \(toKeep.dateImported)")
            for duplicate in toDelete {
                print("   Deleting: imported \(duplicate.dateImported)")
                modelContext.delete(duplicate)
                duplicatesRemoved += 1
            }
        }
        
        if duplicatesRemoved > 0 {
            do {
                try modelContext.save()
                print("✅ Removed \(duplicatesRemoved) duplicate entries")
            } catch {
                print("❌ Failed to remove duplicates: \(error.localizedDescription)")
            }
        } else {
            print("✅ No duplicates found")
        }
    }
    
    private func scanAndImportFromiCloud() async {
        // Prevent concurrent scans
        guard !isScanning else {
            print("⏭️ Scan already in progress, skipping")
            return
        }
        
        isScanning = true
        defer { isScanning = false }
        
        print("📂 DashboardView.scanAndImportFromiCloud: Starting scan")
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        print("📂 iCloud audio directory: \(audioDir.path)")
        print("📂 Directory exists: \(FileManager.default.fileExists(atPath: audioDir.path))")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            print("📂 Found \(files.count) total items in iCloud directory")
            
            // Filter audio files - use all supported formats from AppConstants
            let audioFiles = files.filter { fileURL in
                // Skip directories
                if let isDirectory = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory {
                    return false
                }
                return AppConstants.supportedAudioFormats.contains(fileURL.pathExtension.lowercased())
            }
            
            print("📂 Found \(audioFiles.count) audio files:")
            for (index, file) in audioFiles.enumerated() {
                print("   \(index + 1). \(file.lastPathComponent)")
            }
            
            // Early exit if no audio files found
            guard !audioFiles.isEmpty else {
                print("📂 No audio files found - exiting")
                return
            }
            
            var imported = 0
            
            for fileURL in audioFiles {
                // Check if already imported by comparing stored filename
                let fileName = fileURL.lastPathComponent
                
                print("🔍 Checking file: \(fileName)")
                
                let descriptor = FetchDescriptor<AudioFile>(
                    predicate: #Predicate<AudioFile> { $0.fileName == fileName }
                )
                
                // If exact filename match exists, skip this file
                do {
                    let existing = try modelContext.fetch(descriptor)
                    if !existing.isEmpty {
                        print("⏭️ File already in database (\(existing.count) matches): \(fileName)")
                        continue
                    } else {
                        print("✅ File not in database, will import: \(fileName)")
                    }
                } catch {
                    print("⚠️ Error checking for existing file: \(error.localizedDescription)")
                }
                
                // Download if needed (with shorter timeout on Mac Catalyst)
                do {
                    let values = try fileURL.resourceValues(forKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey])
                    if values.ubiquitousItemDownloadingStatus == .notDownloaded {
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        #if targetEnvironment(macCatalyst)
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s on Mac
                        #else
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s on iOS
                        #endif
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
                    
                    let fileName = fileURL.lastPathComponent
                    
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
                    
                    // IMPORTANT: Save immediately to prevent duplicates from concurrent scans
                    try modelContext.save()
                    
                    // Try to load analysis result from iCloud Drive
                    if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: fileName) {
                        analysisResult.audioFile = audioFile
                        audioFile.analysisResult = analysisResult
                        audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                        try? modelContext.save()
                    }
                    
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
        print("🗑️ DashboardView.deleteFiles: Starting deletion of \(offsets.count) file(s)")
        
        for index in offsets {
            let file = filteredFiles[index]
            print("🗑️ Deleting: \(file.fileName)")
            
            // Delete the actual audio file from storage (iCloud or local)
            // Using iCloudStorageService ensures proper eviction and cross-device sync
            let fileURL = file.fileURL
            do {
                try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                print("✅ File deleted from storage: \(file.fileName)")
            } catch {
                print("❌ Failed to delete file \(file.fileName): \(error.localizedDescription)")
            }
        
            // Delete the analysis result JSON from iCloud Drive
            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName)
            print("✅ Analysis result deleted for: \(file.fileName)")
        
            // Delete the SwiftData record (CloudKit will sync this deletion)
            print("🗑️ Deleting database record for: \(file.fileName)")
            modelContext.delete(file)
        }
        
        do {
            try modelContext.save()
            print("✅ Database records deleted and saved for \(offsets.count) file(s)")
        } catch {
            print("❌ CRITICAL: Failed to save database deletions: \(error.localizedDescription)")
        }
        
        // Notify other views that files were deleted
        NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
        print("✅ Deletion complete for \(offsets.count) file(s)")
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
