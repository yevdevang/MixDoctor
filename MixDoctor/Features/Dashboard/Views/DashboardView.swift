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
    @State private var showDeleteAllConfirmation = false // Confirmation for delete all
    @State private var isDeleting = false // Track if deletion is in progress
    @State private var deletingFile: AudioFile? // Track which file is being deleted
    @State private var isDeletingAll = false // Track if deleting all files
    
    // Cached statistics to prevent blocking SwiftData access during rendering
    @State private var cachedAnalyzedCount: Int = 0
    @State private var cachedIssuesCount: Int = 0
    @State private var cachedAverageScore: Double = 0.0
    @State private var isInitialLoad = true // Track if we're still loading files initially
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

        // Sort demo files to the bottom
        let userFiles = files.filter { !$0.isDemoFile }
        let demoFiles = files.filter { $0.isDemoFile }
        files = userFiles + demoFiles

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
                
                // Mark initial load complete after a short delay to allow files to load
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await MainActor.run {
                        isInitialLoad = false
                    }
                }
                
                // Load missing analysis results from JSON files on app startup
                Task(priority: .userInitiated) {
                    // Wait for SwiftData to finish loading files
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await loadMissingAnalysisResults()
                }
                
                // Log Firebase Analytics event
                if !hasLoggedDashboardView {
                    Analytics.logEvent("dashboard_viewed", parameters: nil)
                    hasLoggedDashboardView = true
                }
            }
            .onChange(of: audioFiles.count) { old, new in
                updateStatistics()
                // Mark initial load complete once files appear
                if new > 0 && isInitialLoad {
                    isInitialLoad = false
                }
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
        
        // Mark initial load complete after a short delay to allow files to load
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await MainActor.run {
            isInitialLoad = false
        }
        
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
            
            // Wait a moment for SwiftData to finish loading files
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Load missing analysis results from JSON files
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
            if isInitialLoad && (audioFiles.isEmpty || iCloudMonitor.isSyncing) {
                // Show loading state during initial load
                loadingStateView
            } else if audioFiles.isEmpty {
                emptyStateView
            } else {
                // Statistics cards
                statisticsView
                
                // Filter picker
                filterPicker
                
                // Files list or filtered empty state
                if filteredFiles.isEmpty {
                    filteredEmptyStateView
                } else {
                    filesList
                }
            }
        }
#if targetEnvironment(macCatalyst)
        .navigationTitle("")
#else
        .navigationTitle("Dashboard")
#endif
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search audio files")
        .alert("Delete All Files", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllFiles()
            }
        } message: {
            Text("Are you sure you want to delete all \(audioFiles.filter { !$0.isDemoFile }.count) file\(audioFiles.filter { !$0.isDemoFile }.count == 1 ? "" : "s")? Demo files will be kept. This action cannot be undone and will remove files from all your devices.")
        }
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
                        ZStack {
                            // Circular progress indicator (always show background circle when syncing)
                            Circle()
                                .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 2)
                            
                            // Progress ring if progress is available
                            if iCloudMonitor.syncProgress > 0 && iCloudMonitor.syncProgress < 1.0 {
                                Circle()
                                    .trim(from: 0, to: iCloudMonitor.syncProgress)
                                    .stroke(Color.primaryAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear, value: iCloudMonitor.syncProgress)
                            }
                            
                            // Spinning indicator in center (always show when syncing)
                            ProgressView()
                                .tint(.primaryAccent)
                                .scaleEffect(0.7)
                        }
                        .frame(width: 20, height: 20)
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
                    
                    if audioFiles.contains(where: { !$0.isDemoFile }) {
                        Divider()

                        Button(role: .destructive, action: {
                            showDeleteAllConfirmation = true
                        }) {
                            Label("Delete All Files", systemImage: "trash")
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
    
    // MARK: - Filter Counts
    
    private var pendingCount: Int {
        audioFiles.filter { $0.analysisResult == nil }.count
    }
    
    private var filterIssuesCount: Int {
        audioFiles.filter {
            guard let result = $0.analysisResult else { return false }
            return hasActualIssues(result: result)
        }.count
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        Picker("Filter", selection: $filterOption) {
            ForEach(FilterOption.allCases, id: \.self) { option in
                Text(filterOptionTitle(for: option)).tag(option)
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
    
    private func filterOptionTitle(for option: FilterOption) -> String {
        switch option {
        case .all:
            return option.rawValue
        case .analyzed:
            return option.rawValue
        case .pending:
            let count = pendingCount
            return count > 0 ? "\(option.rawValue) (\(count))" : option.rawValue
        case .issues:
            let count = filterIssuesCount
            return count > 0 ? "\(option.rawValue) (\(count))" : option.rawValue
        }
    }
    
    // MARK: - Files List
    
    private var filesList: some View {
        List {
            ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                Button {
                    handleAudioFileSelection(file)
                } label: {
                    AudioFileRow(
                        audioFile: file,
                        index: index + 1,
                        onDelete: file.isDemoFile ? nil : {
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
                .deleteDisabled(file.isDemoFile)
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
        .overlay {
            if isDeleting {
                deletionLoaderOverlay
            }
        }
    }
    
    // MARK: - Empty State
    
    private var loadingStateView: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Spacer()
                        
                        // Show loader when loading files
                        VStack(spacing: 16) {
                            ZStack {
                                // Circular progress indicator
                                if iCloudMonitor.syncProgress > 0 && iCloudMonitor.syncProgress < 1.0 {
                                    Circle()
                                        .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 4)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .trim(from: 0, to: iCloudMonitor.syncProgress)
                                        .stroke(Color.primaryAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear, value: iCloudMonitor.syncProgress)
                                        .frame(width: 60, height: 60)
                                }
                                // Spinning indicator in center
                                ProgressView()
                                    .tint(.primaryAccent)
                                    .scaleEffect(1.2)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Loading files...")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                if iCloudMonitor.syncProgress > 0 && iCloudMonitor.syncProgress < 1.0 {
                                    Text("\(Int(iCloudMonitor.syncProgress * 100))% complete")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Syncing from iCloud")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
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
    
    private var emptyStateView: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Spacer()
                        
                        if iCloudMonitor.isSyncing {
                            // Show loader when syncing/downloading files
                            VStack(spacing: 16) {
                                ZStack {
                                    // Circular progress indicator
                                    if iCloudMonitor.syncProgress > 0 && iCloudMonitor.syncProgress < 1.0 {
                                        Circle()
                                            .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 4)
                                            .frame(width: 60, height: 60)
                                        Circle()
                                            .trim(from: 0, to: iCloudMonitor.syncProgress)
                                            .stroke(Color.primaryAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .animation(.linear, value: iCloudMonitor.syncProgress)
                                            .frame(width: 60, height: 60)
                                    }
                                    // Spinning indicator in center
                                    ProgressView()
                                        .tint(.primaryAccent)
                                        .scaleEffect(1.2)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Downloading files...")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    if iCloudMonitor.syncProgress > 0 && iCloudMonitor.syncProgress < 1.0 {
                                        Text("\(Int(iCloudMonitor.syncProgress * 100))% complete")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Syncing from iCloud")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            // Show normal empty state when not syncing
                            ContentUnavailableView(
                                "No Audio Files",
                                systemImage: "music.note",
                                description: Text("Import audio files to get started.\n\nPull down to sync from iCloud.")
                            )
                        }
                        
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
    
    // MARK: - Filtered Empty State
    
    private var filteredEmptyStateView: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack {
                    Spacer()
                    
                    VStack {
                        Spacer()
                        switch filterOption {
                        case .all:
                            ContentUnavailableView(
                                "No Audio Files",
                                systemImage: "music.note",
                                description: Text("Import audio files to get started.")
                            )
                        case .analyzed:
                            ContentUnavailableView(
                                "No Analyzed Files",
                                systemImage: "checkmark.circle",
                                description: Text("No files have been analyzed yet.\n\nSelect a file to start analysis.")
                            )
                        case .pending:
                            ContentUnavailableView(
                                "No Pending Analysis",
                                systemImage: "clock",
                                description: Text("All files have been analyzed!\n\nGreat job keeping up with your mixes.")
                            )
                        case .issues:
                            ContentUnavailableView(
                                "No Issues Found",
                                systemImage: "checkmark.seal.fill",
                                description: Text("Excellent! All your analyzed files are in good shape.\n\nNo issues detected.")
                            )
                        }
                        Spacer()
                    }
                    .frame(maxWidth: 500, minHeight: geometry.size.height)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
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
            
            // Mark initial load complete once files are loaded
            if !files.isEmpty {
                isInitialLoad = false
            }
            
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
            let genre = audioFile.genre
            let mixStage = audioFile.mixStage
            let isDemo = audioFile.isDemoFile

            do {
                // Run analysis on low-priority background thread to keep UI responsive
                let result = try await Task.detached(priority: .utility) {
                    // Construct fileURL inside background task to avoid blocking main thread
                    let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()
                    let fileURL = audioDir.appendingPathComponent(fileName)
                    return try await AudioKitService.analyzeAudioFileIsolated(url: fileURL, genre: genre, mixStage: mixStage)
                }.value

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

                    // Save to SwiftData first (synchronously)
                    do {
                        try context.save()
                    } catch {
                        print("❌ Failed to save analysis result to SwiftData: \(error.localizedDescription)")
                    }

                    // Save to iCloud Drive as JSON (background, but ensure it happens)
                    Task.detached(priority: .background) {
                        do {
                            try AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: fileName, isDemo: isDemo)
                            print("✅ Successfully saved analysis result to JSON for \(fileName)")
                        } catch {
                            print("❌ Failed to save analysis result to JSON for \(fileName): \(error.localizedDescription)")
                        }
                    }
                    
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
            let genre = audioFile.genre
            let mixStage = audioFile.mixStage
            let isDemo = audioFile.isDemoFile

            do {
                // Construct fileURL inside background task to avoid blocking main thread
                let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()
                let fileURL = audioDir.appendingPathComponent(fileName)

                // This runs completely off main thread
                let result = try await AudioKitService.analyzeAudioFileIsolated(url: fileURL, genre: genre, mixStage: mixStage)

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

                    // Save to SwiftData first (synchronously)
                    do {
                        try context.save()
                    } catch {
                        print("❌ Failed to save analysis result to SwiftData: \(error.localizedDescription)")
                    }

                    // Save to iCloud Drive as JSON (background, but ensure it happens)
                    Task.detached(priority: .background) {
                        do {
                            try AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: fileName, isDemo: isDemo)
                            print("✅ Successfully saved analysis result to JSON for \(fileName)")
                        } catch {
                            print("❌ Failed to save analysis result to JSON for \(fileName): \(error.localizedDescription)")
                        }
                    }
                    
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
        // Never delete demo file records — their physical files are re-created from bundle
        let deletableOrphans = orphanedRecords.filter { !$0.isDemoFile }
        if !deletableOrphans.isEmpty {
            for record in deletableOrphans {
                // Also delete the analysis result
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName, isDemo: record.isDemoFile)
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
        
        // Delete all identified duplicates (never delete demo files)
        duplicatesToDelete = duplicatesToDelete.filter { !$0.isDemoFile }
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
            
            // Check for files that need downloading
            var filesToDownload: [URL] = []
            for fileURL in audioFiles {
                if let values = try? fileURL.resourceValues(forKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey]),
                   values.ubiquitousItemDownloadingStatus == .notDownloaded {
                    filesToDownload.append(fileURL)
                }
            }
            
            // Set syncing state if we have files to download
            if !filesToDownload.isEmpty {
                await MainActor.run {
                    iCloudMonitor.isSyncing = true
                    iCloudMonitor.syncProgress = 0.0
                }
            }
            
            var imported = 0
            
            // Build a set of demo file names on disk to skip during scanning
            let demoFileDescriptor = FetchDescriptor<AudioFile>(
                predicate: #Predicate<AudioFile> { $0.isDemoFile == true }
            )
            let demoFileNames = Set((try? modelContext.fetch(demoFileDescriptor))?.map { $0.fileURL.lastPathComponent } ?? [])

            for (index, fileURL) in audioFiles.enumerated() {
                // Check if already imported by comparing stored filename
                let fileName = fileURL.lastPathComponent

                // Skip demo files — they are managed by DemoFileService
                if demoFileNames.contains(fileName) {
                    continue
                }

                // Download if needed first (with shorter timeout on Mac Catalyst)
                var needsDownload = false
                do {
                    let values = try fileURL.resourceValues(forKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey])
                    if values.ubiquitousItemDownloadingStatus == .notDownloaded {
                        needsDownload = true
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        
                        // Wait for download with progress updates
                        if let downloadIndex = filesToDownload.firstIndex(of: fileURL) {
                            await waitForFileDownload(fileURL: fileURL, totalFiles: filesToDownload.count, currentIndex: downloadIndex)
                        }
                    }
                } catch {
                }
                
                // Update progress
                if !filesToDownload.isEmpty {
                    let progress = Double(index + 1) / Double(audioFiles.count)
                    await MainActor.run {
                        iCloudMonitor.syncProgress = progress
                    }
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
                    
                    // Extract mix stage from filename if present
                    let mixStage = extractMixStageFromFileName(fileName)
                    
                    let audioFile = AudioFile(
                        fileName: fileName,
                        fileURL: fileURL,
                        duration: duration,
                        sampleRate: sampleRate,
                        bitDepth: 16,
                        numberOfChannels: channels,
                        fileSize: fileSize,
                        genre: nil,  // Genre must be set manually by user
                        mixStage: mixStage
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
                    if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: fileName, isDemo: audioFile.isDemoFile) {
                        // Skip results that were cleared by the user (iCloud may re-sync the JSON)
                        if AnalysisResultPersistence.shared.isResultStale(analysisResult) {
                            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName, isDemo: audioFile.isDemoFile)
                        } else if verifyAnalysisResultMatchesFile(analysisResult: analysisResult, audioFile: audioFile) {
                            // Verify the analysis result matches the current file by checking file size and duration
                            // This prevents loading analysis from a previously deleted file with the same name
                            analysisResult.audioFile = audioFile
                            audioFile.analysisResult = analysisResult
                            audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                            try? modelContext.save()
                        } else {
                            // Analysis result doesn't match - delete the stale JSON file
                            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName, isDemo: audioFile.isDemoFile)
                        }
                    }
                    
                    imported += 1
                } catch {
                }
            }
            
            // Clear syncing state
            await MainActor.run {
                iCloudMonitor.isSyncing = false
                iCloudMonitor.syncProgress = filesToDownload.isEmpty ? 0.0 : 1.0
                
                // Mark initial load complete
                if imported > 0 || !audioFiles.isEmpty {
                    isInitialLoad = false
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
            // Clear syncing state on error
            await MainActor.run {
                iCloudMonitor.isSyncing = false
                iCloudMonitor.syncProgress = 0.0
            }
        }
    }
    
    /// Wait for an iCloud file to finish downloading with progress updates
    private func waitForFileDownload(fileURL: URL, totalFiles: Int, currentIndex: Int, maxAttempts: Int = 30) async {
        #if targetEnvironment(macCatalyst)
        let pollInterval: UInt64 = 200_000_000 // 0.2 seconds
        let attempts = 15 // 3 seconds max
        #else
        let pollInterval: UInt64 = 1_000_000_000 // 1 second
        let attempts = maxAttempts
        #endif
        
        for attempt in 0..<attempts {
            do {
                let values = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let status = values.ubiquitousItemDownloadingStatus
                
                if status == .current {
                    // File is downloaded, update progress
                    let progress = Double(currentIndex + 1) / Double(totalFiles)
                    await MainActor.run {
                        iCloudMonitor.syncProgress = progress
                    }
                    return
                }
            } catch {
            }
            
            // Update progress while waiting
            let baseProgress = Double(currentIndex) / Double(totalFiles)
            let attemptProgress = Double(attempt) / Double(attempts) / Double(totalFiles)
            await MainActor.run {
                iCloudMonitor.syncProgress = min(baseProgress + attemptProgress, 1.0)
            }
            
            // Wait before checking again
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }
    
    private func loadMissingAnalysisResults() async {
        print("🔄 Starting loadMissingAnalysisResults() - checking for JSON files to load")
        
        let currentVersion = "AudioKit-\(AppConstants.analysisVersion)"
        var loadedCount = 0
        var clearedCount = 0
        
        // Get all audio files (ensure we have the latest data)
        let allFiles = audioFiles
        print("   📊 Found \(allFiles.count) audio files to check")
        
        // Check all files that don't have analysis results in SwiftData
        for audioFile in allFiles where audioFile.analysisResult == nil {
            print("   🔍 Checking file without analysis: \(audioFile.fileName)")

            // Try to load from iCloud Drive JSON using multiple naming patterns:
            // 1. Primary: audioFile.fileName with isDemo flag (e.g. "MIX-demo-Song 4 UNMIXED.analysis.json")
            // 2. Fallback: audioFile.fileName without isDemo (e.g. "Song 4 UNMIXED.analysis.json")
            // 3. Fallback: fileURL.lastPathComponent without isDemo (e.g. "Song 4 UNMIXED.wav.analysis.json")
            let storedName = audioFile.fileURL.lastPathComponent
            let analysisResult: AnalysisResult? =
                AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: audioFile.fileName, isDemo: audioFile.isDemoFile)
                ?? AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: audioFile.fileName, isDemo: false)
                ?? AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: storedName, isDemo: false)

            if let analysisResult {
                print("   ✅ Found JSON file for: \(audioFile.fileName)")

                // Skip results that were cleared by the user (iCloud may re-sync the JSON)
                if AnalysisResultPersistence.shared.isResultStale(analysisResult) {
                    print("   ⚠️ Stale result (created before last clear) - deleting JSON for: \(audioFile.fileName)")
                    AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName, isDemo: audioFile.isDemoFile)
                    clearedCount += 1
                } else if analysisResult.analysisVersion == currentVersion {
                    // Check version compatibility
                    print("   ✅ Version matches: \(analysisResult.analysisVersion)")

                    // IMPORTANT: Verify the analysis result matches this file to prevent loading stale results
                    // Skip verification for demo files — they're bundled and never change
                    let matches = audioFile.isDemoFile || verifyAnalysisResultMatchesFile(analysisResult: analysisResult, audioFile: audioFile)
                    if matches {
                        print("   ✅ Analysis result matches file - loading into SwiftData")
                        analysisResult.audioFile = audioFile
                        audioFile.analysisResult = analysisResult
                        audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                        loadedCount += 1
                    } else {
                        print("   ⚠️ Analysis result doesn't match file verification")
                        print("      File: \(audioFile.fileName)")
                        print("      File size: \(audioFile.fileSize), Duration: \(audioFile.duration)")
                        print("      Analysis date: \(analysisResult.dateAnalyzed)")
                        print("      File import date: \(audioFile.dateImported)")
                        print("      ⚠️ Skipping load (keeping JSON file for now)")
                    }
                } else {
                    print("   ⚠️ Version mismatch: \(analysisResult.analysisVersion) != \(currentVersion) - deleting old JSON")
                    AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName, isDemo: audioFile.isDemoFile)
                    clearedCount += 1
                }
            } else {
                print("   ❌ No JSON file found for: \(audioFile.fileName)")
            }
        }
        
        // Also check files that HAVE analysis results but with wrong version
        for audioFile in allFiles {
            if let analysisResult = audioFile.analysisResult, analysisResult.analysisVersion != currentVersion {
                print("   ⚠️ File has outdated analysis version - clearing: \(audioFile.fileName)")
                audioFile.analysisResult = nil
                audioFile.dateAnalyzed = nil
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName, isDemo: audioFile.isDemoFile)
                clearedCount += 1
            }
        }
        
        print("   📊 Summary: Loaded \(loadedCount), Cleared \(clearedCount)")
        
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
        // Filter out demo files — they cannot be deleted
        let deletableOffsets = offsets.filter { index in
            guard index < filteredFiles.count else { return false }
            return !filteredFiles[index].isDemoFile
        }
        guard !deletableOffsets.isEmpty else { return }

        // Show loader for first file being deleted
        if let firstIndex = deletableOffsets.first, firstIndex < filteredFiles.count {
            let file = filteredFiles[firstIndex]
            isDeleting = true
            deletingFile = file
        }

        Task { @MainActor in
            // Capture files to delete before deletion starts (works on both iOS and MacCatalyst)
            let filesToDelete = deletableOffsets.compactMap { index -> AudioFile? in
                guard index < filteredFiles.count else { return nil }
                return filteredFiles[index]
            }
            
            // Delete files
            for file in filesToDelete {
                // Delete the actual audio file from storage (iCloud or local)
                // Using iCloudStorageService ensures proper eviction and cross-device sync
                let fileURL = file.fileURL
                do {
                    try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                } catch {
                }
                
                // Delete the analysis result JSON from iCloud Drive
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName, isDemo: file.isDemoFile)
                
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
            
            // CRITICAL: Notify other views AFTER deletion is complete
            NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
            
            // Hide loader
            isDeleting = false
            deletingFile = nil
        }
    }
    
    /// Delete all audio files from the app (preserves demo files)
    private func deleteAllFiles() {
        // Show loader
        isDeletingAll = true
        isDeleting = true

        Task { @MainActor in
            // Capture only user files — demo files are preserved
            let allFiles = Array(audioFiles.filter { !$0.isDemoFile })

            // Delete all user files
            for file in allFiles {
                // Delete the actual audio file from storage
                let fileURL = file.fileURL
                do {
                    try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                } catch {
                    // Continue even if individual file deletion fails
                }
                
                // Delete the analysis result JSON from iCloud Drive
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName, isDemo: file.isDemoFile)
                
                // Delete the SwiftData record
                modelContext.delete(file)
            }
            
            // Save all deletions
            do {
                try modelContext.save()
            } catch {
                // Handle save error if needed
            }
            
            // Clear cached filtered files
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
            
            // CRITICAL: Notify other views AFTER deletion is complete
            NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
            
            // Hide loader
            isDeleting = false
            isDeletingAll = false
        }
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
            print("   ⚠️ Verification failed: Audio file doesn't exist at \(fileURL.path)")
            return false
        }
        
        // More lenient verification: Check file size and duration match
        // This is more reliable than dates, especially after app rebuilds
        // Get actual file size from disk
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSizeOnDisk = fileAttributes[.size] as? Int64 {
                // Allow 1KB tolerance for file size differences (metadata changes, etc.)
                let sizeDifference = abs(fileSizeOnDisk - audioFile.fileSize)
                if sizeDifference > 1024 {
                    print("   ⚠️ Verification failed: File size mismatch")
                    print("      Expected: \(audioFile.fileSize), Actual: \(fileSizeOnDisk), Diff: \(sizeDifference)")
                    return false
                }
            }
        } catch {
            print("   ⚠️ Verification warning: Could not check file size: \(error.localizedDescription)")
            // Continue with other checks
        }
        
        // Check if analysis date is reasonable (not more than 1 year in the future)
        let oneYearFromNow = Date().addingTimeInterval(365 * 24 * 60 * 60)
        if analysisResult.dateAnalyzed > oneYearFromNow {
            print("   ⚠️ Verification failed: Analysis date is in the future")
            return false
        }
        
        // If analysis date is before import date, it might be from a previous import
        // But allow it if the file name matches and file exists (more lenient)
        // Only reject if analysis is WAY before import (more than 1 day)
        let oneDayBeforeImport = audioFile.dateImported.addingTimeInterval(-24 * 60 * 60)
        if analysisResult.dateAnalyzed < oneDayBeforeImport {
            print("   ⚠️ Verification failed: Analysis is more than 1 day before import")
            print("      Analysis: \(analysisResult.dateAnalyzed), Import: \(audioFile.dateImported)")
            return false
        }
        
        print("   ✅ Verification passed: File exists, size matches, dates are reasonable")
        return true
    }
    
    /// Extract mix stage from filename
    /// Examples:
    /// - "filename - Mix.mp3" → "mix"
    /// - "filename - Master(Streaming).mp3" → "master_streaming"
    /// - "filename - Master(CD-Loud).mp3" → "master_cd"
    /// - "filename.mp3" → "mix" (default)
    private func extractMixStageFromFileName(_ fileName: String) -> String {
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // Check for " - Mix" suffix
        if fileNameWithoutExtension.hasSuffix(" - Mix") {
            return "mix"
        }
        
        // Check for " - Master(Streaming)" suffix
        if fileNameWithoutExtension.hasSuffix(" - Master(Streaming)") {
            return "master_streaming"
        }
        
        // Check for " - Master(CD-Loud)" suffix
        if fileNameWithoutExtension.hasSuffix(" - Master(CD-Loud)") {
            return "master_cd"
        }
        
        // Default to "mix" if no stage suffix found
        return "mix"
    }
    
    // MARK: - Deletion Loader
    
    private var deletionLoaderOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.primaryAccent)
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryAccent))
            
            Text(isDeletingAll ? "Deleting all files..." : "Deleting file...")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if let file = deletingFile, !isDeletingAll {
                Text(file.fileName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        }
        .shadow(radius: 10)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isDeleting)
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
