//
//  DashboardView.swift
//  MixDoctor
//
//  Main dashboard view for managing and viewing audio files
//

import SwiftUI
import SwiftData
import AVFoundation
import FirebaseAnalytics
#if canImport(UIKit)
import UIKit
#endif

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
#if targetEnvironment(macCatalyst)
    // MacCatalyst: Use manual loading to prevent UI blocking
    @State private var audioFiles: [AudioFile] = []
    @State private var isLoadingFiles = false
#else
    // iOS: Use @Query (works fine on iOS)
    @Query(sort: \AudioFile.dateImported, order: .reverse) private var audioFiles: [AudioFile]
#endif
    
    @StateObject private var iCloudMonitor = iCloudSyncMonitor.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    private let analysisService = AudioKitService.shared
    
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .date
    @State private var selectedFile: AudioFile?
    @State private var isAnalyzing = false
    @State private var analyzingFile: AudioFile?
    @State private var navigateToFile: AudioFile?
    @State private var hasPerformedInitialSync = false // Track if we've done initial sync
    @State private var isScanning = false // Prevent concurrent scans
    @State private var cachedFilteredFiles: [AudioFile] = [] // Cache filtered results
    @State private var lastFilterHash = 0 // Track filter state changes
    @State private var syncDebounceTask: Task<Void, Never>? // Debounce sync operations
    @State private var hasLoggedDashboardView = false // Track if dashboard view event has been logged
    
    // Cached statistics to prevent blocking SwiftData access during rendering
    @State private var cachedAnalyzedCount: Int = 0
    @State private var cachedIssuesCount: Int = 0
    @State private var cachedAverageScore: Double = 0.0
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
        // Calculate hash of current filter state
        var hasher = Hasher()
        hasher.combine(searchText)
        hasher.combine(filterOption)
        hasher.combine(sortOption)
        hasher.combine(audioFiles.count)
        let currentHash = hasher.finalize()

        // Use cached version if filters haven't changed
        if currentHash == lastFilterHash && !cachedFilteredFiles.isEmpty {
            return cachedFilteredFiles
        }

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

        // Cache the result (non-blocking)
        cachedFilteredFiles = files
        lastFilterHash = currentHash

        return files
    }
    
    var body: some View {
        baseView
    }
    
    private var baseView: some View {
        contentStack
            .tint(.primaryAccent)
#if targetEnvironment(macCatalyst)
            .task { await initializeViewMacCatalyst() }
#else
            .onAppear {
                setupAppearance()
                performInitialSync()
                updateStatistics()
                
                // Log Firebase Analytics event
                if !hasLoggedDashboardView {
                    Analytics.logEvent("dashboard_viewed", parameters: nil)
                    hasLoggedDashboardView = true
                }
            }
            .onChange(of: audioFiles.count) { old, new in
                updateStatistics()
            }
#endif
            .onChange(of: iCloudMonitor.isSyncing) { old, new in
                handleSyncStateChange(oldValue: old, newValue: new)
            }
#if !targetEnvironment(macCatalyst)
            .onChange(of: audioFiles.count) { old, new in
                updateStatistics()
            }
            .onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
                // Update statistics when files are deleted
                updateStatistics()
            }
#endif
    }
    
    private var contentStack: some View {
        NavigationStack {
            dashboardContent
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
    }
    
    // MARK: - Helper Methods
    
    /// Update cached statistics from audioFiles (works on both iOS and MacCatalyst)
    private func updateStatistics() {
        // Calculate statistics safely
        let files = audioFiles
        cachedAnalyzedCount = files.filter { $0.analysisResult != nil }.count
        
        let results = files.compactMap { $0.analysisResult }
        cachedIssuesCount = results.filter { hasActualIssues(result: $0) }.count
        
        let scores = results.compactMap { $0.overallScore }
        cachedAverageScore = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)
    }

    /// Debounce sync operations to prevent rapid consecutive calls
    private func debouncedSync(priority: TaskPriority = .utility) {
        // Cancel any pending sync task
        syncDebounceTask?.cancel()

        // Schedule a new sync task with a short delay
        syncDebounceTask = Task(priority: priority) {
            // Wait a short period to debounce rapid notifications
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            // Check if we were cancelled
            guard !Task.isCancelled else { return }

            // Perform the sync operations
            await checkAndDownloadMissingFiles()
            await scanAndImportFromiCloud()
        }
    }

#if targetEnvironment(macCatalyst)
    @MainActor
    private func initializeViewMacCatalyst() async {
        // Small delay to let UI render first and prevent blocking tab switch
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        setupAppearance()
        performInitialSync()
        // Statistics will be updated by loadAudioFiles() in performInitialSync
        
        // Log Firebase Analytics event
        if !hasLoggedDashboardView {
            Analytics.logEvent("dashboard_viewed", parameters: nil)
            hasLoggedDashboardView = true
        }
    }
#endif
    
    private func setupAppearance() {
#if canImport(UIKit)
        let appearance = UINavigationBarAppearance()
#if targetEnvironment(macCatalyst)
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = nil
#else
        appearance.configureWithDefaultBackground()
#endif
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.primaryAccent)]
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.primaryAccent)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
#endif
    }
    
    private func performInitialSync() {
#if targetEnvironment(macCatalyst)
        Task(priority: .userInitiated) {
            await loadAudioFiles()
        }
#endif
        
        Task(priority: .userInitiated) {
            if !audioFiles.isEmpty {
                await checkAndDownloadMissingFiles()
            }
        }
        
        guard !hasPerformedInitialSync else { return }
        hasPerformedInitialSync = true
        
        Task(priority: .utility) {
            await removeDuplicateFiles()
            
            if !audioFiles.isEmpty {
#if targetEnvironment(macCatalyst)
                await checkAndDownloadMissingFiles()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
#endif
                await checkAndDownloadMissingFiles()
            }
            
            await scanAndImportFromiCloud()
            await loadMissingAnalysisResults()
        }
    }
    
    private func handleSyncStateChange(oldValue: Bool, newValue: Bool) {
        if oldValue == true && newValue == false {
            Task(priority: .utility) {
                await checkAndDownloadMissingFiles()
                await scanAndImportFromiCloud()
                await loadMissingAnalysisResults()
#if !targetEnvironment(macCatalyst)
                await MainActor.run {
                    updateStatistics()
                }
#endif
            }
        }
    }
    
    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // iCloud sync status banner
            if iCloudMonitor.isSyncing {
                HStack(spacing: 12) {
                    // Animated sync icon
                    ProgressView()
                        .tint(.primaryAccent)
                    
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
                            Color.primaryAccent.opacity(0.08),
                            Color.primaryAccent.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.primaryAccent.opacity(0.2)),
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
#if targetEnvironment(macCatalyst)
        .navigationTitle("")
#else
        .navigationTitle("Dashboard")
#endif
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search audio files")
        .toolbar {
            // iCloud sync button
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task(priority: .userInitiated) {
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
                            .tint(.primaryAccent)
                    } else {
                        Label("Sync iCloud", systemImage: "icloud.and.arrow.down")
                    }
                }
                .disabled(iCloudMonitor.isSyncing)
                .foregroundStyle(Color.primaryAccent)
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
                value: analyzedDisplayValue,
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
    
    // Use cached values instead of computed properties to prevent blocking SwiftData access
    private var analyzedCount: Int {
        cachedAnalyzedCount
    }
    
    private var issuesCount: Int {
        cachedIssuesCount
    }
    
    private var averageScore: Double {
        cachedAverageScore
    }
    
    // Display value for "Analyzed" card - shows analysis count for free and Pro users
    private var analyzedDisplayValue: String {
        if subscriptionService.isProUser {
            // For Pro users, show remaining analyses (X/50)
            let usedAnalyses = 50 - subscriptionService.remainingProAnalyses
            return "\(usedAnalyses)/50"
        } else {
            // Show analysis count (X/3) for free users
            let usedAnalyses = 3 - subscriptionService.remainingFreeAnalyses
            return "\(usedAnalyses)/3"
        }
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
            // Selected segment: Use dynamic purple (brighter in dark mode)
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.primaryAccent)
            
            // Selected text: Always white for contrast
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            
            // Unselected text: Brighter purple/lavender for better readability in both modes
            UISegmentedControl.appearance().setTitleTextAttributes([
                .foregroundColor: UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        // Dark mode: Much brighter purple/lavender for better readability
                        return UIColor(red: 0.7, green: 0.5, blue: 0.95, alpha: 1.0) // #b380f2 - brighter lavender
                    } else {
                        // Light mode: Also brighter purple for better readability
                        return UIColor(red: 0.6, green: 0.35, blue: 0.9, alpha: 1.0) // #9933e6 - brighter purple
                    }
                }
            ], for: .normal)
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
                        },
                        isAnalyzing: isAnalyzing && analyzingFile?.id == file.id
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAnalyzing && analyzingFile?.id == file.id)
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
        .fullScreenCover(isPresented: $isAnalyzing) {
            if let file = analyzingFile {
#if targetEnvironment(macCatalyst)
                // MacCatalyst: Ensure animations run on main thread
                AnimatedGradientLoader(fileName: file.fileName)
                    .task { @MainActor in
                        // Force main thread for MacCatalyst animations
                    }
#else
                AnimatedGradientLoader(fileName: file.fileName)
#endif
            }
        }
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
    
    // MARK: - Data Loading
    
#if targetEnvironment(macCatalyst)
    /// Load audio files asynchronously to prevent blocking UI (MacCatalyst only)
    private func loadAudioFiles() async {
        await MainActor.run {
            isLoadingFiles = true
        }
        
        // Fetch directly on main thread - SwiftData is already optimized
        await MainActor.run {
            // Create descriptor
            let descriptor = FetchDescriptor<AudioFile>(
                sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
            )
            
            // Fetch on main thread
            let files = (try? modelContext.fetch(descriptor)) ?? []
            
            // Update UI
            audioFiles = files
            cachedFilteredFiles = files
            isLoadingFiles = false
            
            // Update statistics
            updateStatistics()
        }
    }
    
    /// Reload audio files after changes (non-blocking, MacCatalyst only)
    private func reloadAudioFiles() {
        Task.detached(priority: .utility) {
            await self.loadAudioFiles()
        }
    }
#endif
    
    // MARK: - Actions
    
    private func handleAudioFileSelection(_ file: AudioFile) {
        // Capture values that won't block
        let subscriptionSvc = subscriptionService
        let context = modelContext

#if targetEnvironment(macCatalyst)
        // MacCatalyst: Move ALL logic into background task with low priority
        Task(priority: .utility) {
            // Yield immediately to let UI update
            await Task.yield()
            
            // Get file ID in background to avoid potential fault
            let fileID = await MainActor.run { file.id }
            
            // Fetch the file in background to check if it has analysis
            let descriptor = FetchDescriptor<AudioFile>(
                predicate: #Predicate<AudioFile> { $0.id == fileID }
            )
            
            guard let audioFile = try? context.fetch(descriptor).first else {
                return
            }
            
            // Check if already analyzed - navigate directly without showing loader
            if audioFile.analysisResult != nil {
                await MainActor.run {
                    self.navigateToFile = audioFile
                }
                return
            }
            
            // File needs analysis - show loader now
            await MainActor.run {
                self.isAnalyzing = true
                self.analyzingFile = file
                
                // Log analysis started event
                Analytics.logEvent("analysis_started", parameters: nil)
            }
            
            // Check subscription (now safe off main thread)
            guard subscriptionSvc.canPerformAnalysis() else {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.analyzingFile = nil
                    self.navigateToFile = audioFile
                }
                return
            }
            
            // Get filename for analysis
            let fileName = audioFile.fileName

            do {
                // Run analysis on low-priority background thread to keep UI responsive
                let result = try await Task.detached(priority: .utility) {
                    // Construct fileURL inside background task to avoid blocking main thread
                    let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()
                    let fileURL = audioDir.appendingPathComponent(fileName)
                    return try await AudioKitService.analyzeAudioFileIsolated(url: fileURL)
                }.value

                // Save to iCloud Drive (background)
                Task.detached(priority: .background) {
                    try? AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: fileName)
                }

                // Now update UI and SwiftData on main actor
                await MainActor.run {
                    // Increment usage count
                    subscriptionSvc.incrementAnalysisCount()
                    
                    // Log free analysis count event
                    let remainingFree = subscriptionSvc.remainingFreeAnalyses
                    Analytics.logEvent("free_analysis_count", parameters: [
                        "remaining": String(remainingFree)
                    ])

                    // Save to the AudioFile model
                    audioFile.analysisResult = result
                    audioFile.dateAnalyzed = Date()

                    // Save to SwiftData
                    try? context.save()
                    
                    // Log analysis completed event
                    Analytics.logEvent("analysis_completed", parameters: [
                        "overall_score": String(format: "%.1f", result.overallScore)
                    ])

                    // Reload the list and update statistics
                    Task(priority: .utility) {
                        await self.loadAudioFiles()
                        // Statistics will be updated by loadAudioFiles
                    }

                    // Hide loader and navigate
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isAnalyzing = false
                    }
                    self.analyzingFile = nil
                    self.navigateToFile = audioFile
                }

            } catch {
                // Hide loader and navigate to show error (all on main actor)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isAnalyzing = false
                    }
                    self.analyzingFile = nil
                    // Find file again for navigation
                    let descriptor = FetchDescriptor<AudioFile>(
                        predicate: #Predicate<AudioFile> { $0.id == fileID }
                    )
                    self.navigateToFile = try? context.fetch(descriptor).first
                }
            }
        }
#else
        // iOS: Move ALL logic into background task with low priority
        Task.detached(priority: .utility) {
            // Get file ID in background to avoid potential fault
            let fileID = await MainActor.run { file.id }
            
            // Fetch the file in background to check if it has analysis
            let descriptor = FetchDescriptor<AudioFile>(
                predicate: #Predicate<AudioFile> { $0.id == fileID }
            )
            
            guard let audioFile = try? context.fetch(descriptor).first else {
                return
            }
            
            // Check if already analyzed - navigate directly without showing loader
            if audioFile.analysisResult != nil {
                await MainActor.run {
                    self.navigateToFile = audioFile
                }
                return
            }
            
            // File needs analysis - show loader now
            await MainActor.run {
                self.isAnalyzing = true
                self.analyzingFile = file
                
                // Log analysis started event
                Analytics.logEvent("analysis_started", parameters: nil)
            }
            
            // Check subscription (now safe off main thread)
            guard await subscriptionSvc.canPerformAnalysis() else {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.analyzingFile = nil
                    self.navigateToFile = audioFile
                }
                return
            }
            
            // Get filename for analysis
            let fileName = audioFile.fileName
            
            do {
                // Construct fileURL inside background task to avoid blocking main thread
                let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()
                let fileURL = audioDir.appendingPathComponent(fileName)
                
                // This runs completely off main thread
                let result = try await AudioKitService.analyzeAudioFileIsolated(url: fileURL)

                // Save to iCloud Drive (background)
                Task.detached(priority: .background) {
                    try? AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: fileName)
                }

                // Now update UI and SwiftData on main actor
                await MainActor.run {
                    // Increment usage count
                    subscriptionSvc.incrementAnalysisCount()
                    
                    // Log free analysis count event
                    let remainingFree = subscriptionSvc.remainingFreeAnalyses
                    Analytics.logEvent("free_analysis_count", parameters: [
                        "remaining": String(remainingFree)
                    ])

                    // Save to the AudioFile model
                    audioFile.analysisResult = result
                    audioFile.dateAnalyzed = Date()

                    // Save to SwiftData
                    try? context.save()
                    
                    // Log analysis completed event
                    let usedCount = subscriptionSvc.isProUser ? 
                        (50 - subscriptionSvc.remainingProAnalyses) : 
                        (3 - subscriptionSvc.remainingFreeAnalyses)
                    Analytics.logEvent("analysis_completed", parameters: [
                        "score": String(format: "%.1f", result.overallScore),
                        "analysis_count": String(usedCount)
                    ])

                    // Update statistics after analysis
                    self.updateStatistics()

                    // Hide loader and navigate
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isAnalyzing = false
                    }
                    self.analyzingFile = nil
                    self.navigateToFile = audioFile
                }

            } catch {
                // Hide loader and navigate to show error (all on main actor)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isAnalyzing = false
                    }
                    self.analyzingFile = nil
                    // Find file again for navigation
                    let descriptor = FetchDescriptor<AudioFile>(
                        predicate: #Predicate<AudioFile> { $0.id == fileID }
                    )
                    self.navigateToFile = try? context.fetch(descriptor).first
                }
            }
        }
#endif
    }
    
    private func checkAndDownloadMissingFiles() async {
        
        var missingFiles: [(AudioFile, URL)] = []
        var orphanedRecords: [AudioFile] = []
        
        for file in audioFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            
            if !fileExists {
                // Check if it's in iCloud but not downloaded, or truly deleted
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        URLResourceKey.isUbiquitousItemKey,
                        URLResourceKey.ubiquitousItemDownloadingStatusKey,
                        URLResourceKey.ubiquitousItemIsUploadedKey
                    ])
                    
                    let isICloud = values.isUbiquitousItem ?? false
                    let downloadStatus = values.ubiquitousItemDownloadingStatus
                    let isUploaded = values.ubiquitousItemIsUploaded ?? false
                    
                    
                    // If file is in iCloud AND has a valid download status AND is uploaded, try to download
                    if isICloud && isUploaded && downloadStatus != nil {
                        missingFiles.append((file, fileURL))
                    } else {
                        // File doesn't exist in iCloud or is being deleted - orphaned record
                        orphanedRecords.append(file)
                    }
                } catch {
                    // If we can't get resource values and file doesn't exist, it's orphaned
                    orphanedRecords.append(file)
                }
            }
        }
        
        // Clean up orphaned records (files deleted on another device)
        if !orphanedRecords.isEmpty {
            for record in orphanedRecords {
                // Also delete the analysis result
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName)
                modelContext.delete(record)
            }
            do {
                try modelContext.save()
            } catch {
            }
        }
        
        // Download missing files that still exist in iCloud
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
        } else if orphanedRecords.isEmpty {
        }
    }
    
    /// Remove duplicate entries from the database (keeps oldest import)
    /// Also checks for duplicates by file size + duration to catch cases where filenames differ
    private func removeDuplicateFiles() async {
        // Fetch all files to check for duplicates
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return
        }
        
        // Group files by fileName first
        var filesByName: [String: [AudioFile]] = [:]
        for file in allFiles {
            filesByName[file.fileName, default: []].append(file)
        }
        
        var duplicatesToDelete: Set<AudioFile> = []
        
        // First pass: Remove duplicates with same filename (keep oldest)
        for (fileName, files) in filesByName where files.count > 1 {
            // Sort by import date (oldest first) and keep the first one
            let sorted = files.sorted { $0.dateImported < $1.dateImported }
            let toKeep = sorted.first!
            let toDelete = sorted.dropFirst()
            
            // Verify the file to keep actually exists
            let keepFileExists = FileManager.default.fileExists(atPath: toKeep.fileURL.path)
            if !keepFileExists {
                // If the file to keep doesn't exist, keep the first one that does exist
                if let firstExisting = sorted.first(where: { FileManager.default.fileExists(atPath: $0.fileURL.path) }) {
                    // Delete all others including the non-existent "toKeep"
                    for file in sorted where file.id != firstExisting.id {
                        duplicatesToDelete.insert(file)
                    }
                } else {
                    // None exist, delete all but the oldest
                    duplicatesToDelete.formUnion(toDelete)
                }
            } else {
                // File to keep exists, delete the rest
                duplicatesToDelete.formUnion(toDelete)
            }
        }
        
        // Second pass: Check for duplicates with same file size + duration but different names
        // This catches cases where CloudKit sync created duplicates with slightly different metadata
        var checkedFiles: Set<AudioFile> = []
        for file in allFiles {
            if duplicatesToDelete.contains(file) || checkedFiles.contains(file) {
                continue
            }
            
            // Find files with same size and duration (within 1 second tolerance)
            let potentialDuplicates = allFiles.filter { otherFile in
                !duplicatesToDelete.contains(otherFile) &&
                !checkedFiles.contains(otherFile) &&
                otherFile.id != file.id &&
                otherFile.fileSize == file.fileSize &&
                otherFile.fileSize > 0 && // Only check if size is valid
                abs(otherFile.duration - file.duration) < 1.0
            }
            
            if !potentialDuplicates.isEmpty {
                // Check if files point to the same physical file
                let fileURL = file.fileURL
                for duplicate in potentialDuplicates {
                    let duplicateURL = duplicate.fileURL
                    // Compare standardized URLs to see if they point to the same file
                    if fileURL.standardizedFileURL == duplicateURL.standardizedFileURL {
                        // Same physical file - keep the older one
                        if file.dateImported < duplicate.dateImported {
                            duplicatesToDelete.insert(duplicate)
                        } else {
                            duplicatesToDelete.insert(file)
                        }
                    }
                }
            }
            
            checkedFiles.insert(file)
        }
        
        // Delete all identified duplicates
        if !duplicatesToDelete.isEmpty {
            for duplicate in duplicatesToDelete {
                modelContext.delete(duplicate)
            }
            
            do {
                try modelContext.save()
            } catch {
            }
        }
    }
    
    private func scanAndImportFromiCloud() async {
        // Prevent concurrent scans
        guard !isScanning else {
            return
        }
        
        await MainActor.run {
            isScanning = true
        }
        defer {
            Task { @MainActor in
                isScanning = false
            }
        }
        
        // Yield to let UI update before starting heavy work
        await Task.yield()
        
        // Small delay to allow CloudKit to sync records from other devices
        // This helps prevent duplicates when files were imported on another device
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [URLResourceKey.fileSizeKey, URLResourceKey.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            
            // Filter audio files - use all supported formats from AppConstants
            let audioFiles = files.filter { fileURL in
                // Skip directories
                if let isDirectory = try? fileURL.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]).isDirectory, isDirectory {
                    return false
                }
                return AppConstants.supportedAudioFormats.contains(fileURL.pathExtension.lowercased())
            }
            
            for (index, file) in audioFiles.enumerated() {
            }
            
            // Early exit if no audio files found
            guard !audioFiles.isEmpty else {
                return
            }
            
            var imported = 0
            
            for fileURL in audioFiles {
                // Check if already imported by comparing stored filename
                let fileName = fileURL.lastPathComponent
                
                // Download if needed first (with shorter timeout on Mac Catalyst)
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
                
                // Get file metadata BEFORE checking duplicates (needed for better duplicate detection)
                let fileAttributes: [FileAttributeKey: Any]
                let duration: TimeInterval
                let fileSize: Int64
                
                do {
                    fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    fileSize = fileAttributes[.size] as? Int64 ?? 0
                    
                    let asset = AVURLAsset(url: fileURL)
                    duration = try await asset.load(.duration).seconds
                } catch {
                    // Skip file if we can't read metadata
                    continue
                }
                
                // Enhanced duplicate check: Check by filename AND file size + duration
                // This catches duplicates even if CloudKit hasn't synced yet
                let descriptorByName = FetchDescriptor<AudioFile>(
                    predicate: #Predicate<AudioFile> { $0.fileName == fileName }
                )
                
                var isDuplicate = false
                do {
                    let existingByName = try modelContext.fetch(descriptorByName)
                    
                    // Check if any existing file matches by name AND (size + duration)
                    for existingFile in existingByName {
                        let sameFileName = existingFile.fileName == fileName
                        let sameFileSize = existingFile.fileSize == fileSize
                        let similarDuration = abs(existingFile.duration - duration) < 1.0
                        
                        // If name matches, it's definitely a duplicate
                        // Also check if file physically exists to avoid stale records
                        if sameFileName {
                            let fileExists = FileManager.default.fileExists(atPath: existingFile.fileURL.path)
                            if fileExists {
                                isDuplicate = true
                                break
                            } else {
                                // Stale record - file doesn't exist, remove it
                                modelContext.delete(existingFile)
                                try? modelContext.save()
                            }
                        } else if sameFileSize && similarDuration && fileSize > 0 {
                            // Same size and duration but different name - might be a duplicate
                            // Check if the existing file's physical file matches this one
                            let existingFileExists = FileManager.default.fileExists(atPath: existingFile.fileURL.path)
                            if existingFileExists {
                                // Compare file URLs to see if they point to the same file
                                let existingURL = existingFile.fileURL
                                if existingURL.standardizedFileURL == fileURL.standardizedFileURL {
                                    isDuplicate = true
                                    break
                                }
                            }
                        }
                    }
                } catch {
                    // If fetch fails, continue anyway (better to import than skip)
                }
                
                // Skip if duplicate found
                if isDuplicate {
                    continue
                }
                
                // Import the file
                do {
                    let tracks = try await AVURLAsset(url: fileURL).loadTracks(withMediaType: .audio)
                    guard let track = tracks.first else { continue }
                    
                    let formatDescriptions = try await track.load(.formatDescriptions)
                    guard let formatDescription = formatDescriptions.first else { continue }
                    
                    let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    let sampleRate = basicDescription?.pointee.mSampleRate ?? 44100.0
                    let channels = Int(basicDescription?.pointee.mChannelsPerFrame ?? 2)
                    
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
                    
                    // Log file imported event
                    Analytics.logEvent("file_imported", parameters: nil)
                    
                    // Yield to prevent blocking UI during bulk imports
                    await Task.yield()
                    
#if targetEnvironment(macCatalyst)
                    // Reload the list
                    await MainActor.run { reloadAudioFiles() }
#endif
                    
                    // Try to load analysis result from iCloud Drive
                    // IMPORTANT: Verify the analysis result matches this file to prevent loading stale results
                    if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: fileName) {
                        // Verify the analysis result matches the current file by checking file size and duration
                        // This prevents loading analysis from a previously deleted file with the same name
                        if verifyAnalysisResultMatchesFile(analysisResult: analysisResult, audioFile: audioFile) {
                            analysisResult.audioFile = audioFile
                            audioFile.analysisResult = analysisResult
                            audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                            try? modelContext.save()
                        } else {
                            // Analysis result doesn't match - delete the stale JSON file
                            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName)
                        }
                    }
                    
                    imported += 1
                } catch {
                }
            }
            
            if imported > 0 {
                // Clear cached filtered files to force refresh with new imports
                await MainActor.run {
                    cachedFilteredFiles = []
                    lastFilterHash = 0
                }
                
#if !targetEnvironment(macCatalyst)
                // Update statistics after importing new files
                await MainActor.run {
                    updateStatistics()
                }
#endif
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
                    // IMPORTANT: Verify the analysis result matches this file to prevent loading stale results
                    if verifyAnalysisResultMatchesFile(analysisResult: analysisResult, audioFile: audioFile) {
                        analysisResult.audioFile = audioFile
                        audioFile.analysisResult = analysisResult
                        audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                        loadedCount += 1
                    } else {
                        // Analysis result doesn't match - delete the stale JSON file
                        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName)
                        clearedCount += 1
                    }
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
                
                // Update statistics after loading/clearing analysis results
#if !targetEnvironment(macCatalyst)
                await MainActor.run {
                    updateStatistics()
                }
#endif
            } catch {
            }
        } else {
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        
        for index in offsets {
            let file = filteredFiles[index]
            
            // Delete the actual audio file from storage (iCloud or local)
            // Using iCloudStorageService ensures proper eviction and cross-device sync
            let fileURL = file.fileURL
            do {
                try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
            } catch {
            }
            
            // Delete the analysis result JSON from iCloud Drive
            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName)
            
            // Delete the SwiftData record (CloudKit will sync this deletion)
            modelContext.delete(file)
        }
        
        do {
            try modelContext.save()
        } catch {
        }
        
        // Clear cached filtered files to force refresh
        cachedFilteredFiles = []
        lastFilterHash = 0
        
        // Update statistics after deletion
#if targetEnvironment(macCatalyst)
        Task(priority: .utility) {
            await loadAudioFiles()
        }
#else
        updateStatistics()
#endif
        
        // Notify other views that files were deleted
        NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
    }
    
    /// Verifies that an analysis result matches the audio file it claims to analyze
    /// This prevents loading stale analysis results from previously deleted files
    /// - Parameters:
    ///   - analysisResult: The analysis result to verify
    ///   - audioFile: The audio file to check against
    /// - Returns: true if the analysis result matches the file, false otherwise
    private func verifyAnalysisResultMatchesFile(analysisResult: AnalysisResult, audioFile: AudioFile) -> Bool {
        // Verify the audio file actually exists
        let fileURL = audioFile.fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // File doesn't exist - this is definitely a stale result
            return false
        }
        
        // Check if analysis date is after file import date (sanity check)
        // dateAnalyzed is non-optional Date, so we can compare directly
        if analysisResult.dateAnalyzed < audioFile.dateImported {
            // Analysis was done before file was imported - this is a stale result
            return false
        }
        
        // Verify the analysis JSON file's modification date is after the audio file was imported
        // This ensures the analysis was created for this specific file instance
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        let jsonFileName = "\(audioFile.fileName).analysis.json"
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            do {
                let jsonAttributes = try FileManager.default.attributesOfItem(atPath: jsonURL.path)
                if let jsonModificationDate = jsonAttributes[.modificationDate] as? Date {
                    // Analysis JSON should be modified after the file was imported
                    // Allow 1 second tolerance for timing issues
                    if jsonModificationDate < audioFile.dateImported.addingTimeInterval(-1.0) {
                        // Analysis JSON is older than file import - this is a stale result
                        return false
                    }
                }
            } catch {
                // If we can't check modification date, fail safe and reject the analysis
                return false
            }
        }
        
        return true
    }

    
    
//    #Preview {
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try! ModelContainer(for: AudioFile.self, configurations: config)
//        let context = container.mainContext
//        
//        // Create sample data
//        for i in 1...5 {
//            let audioFile = AudioFile(
//                fileName: "Track \(i).wav",
//                fileURL: URL(fileURLWithPath: "/tmp/track\(i).wav"),
//                duration: Double.random(in: 120...300),
//                sampleRate: 44100,
//                bitDepth: 24,
//                numberOfChannels: 2,
//                fileSize: Int64.random(in: 10_000_000...50_000_000)
//            )
//            context.insert(audioFile)
//        }
//        
//        return DashboardView()
//            .modelContainer(container)
//    }
}
