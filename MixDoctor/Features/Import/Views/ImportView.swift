import Observation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImportViewModel?
    @State private var isShowingDocumentPicker = false
    @State private var isDropTargeted = false
    @State private var selectedGenre: String?
    @Binding var selectedAudioFile: AudioFile?
    @Binding var selectedTab: Int
    @Binding var shouldAutoPlay: Bool
    #if targetEnvironment(macCatalyst)
    @State private var fileToDelete: AudioFile?
    @State private var showDeleteConfirmation = false
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    contentView(viewModel: viewModel)
                } else {
                    ProgressView("Preparing import tools…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            await initializeViewModel()
                        }
                }
            }
            .fileImporter(
                isPresented: $isShowingDocumentPicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            #if targetEnvironment(macCatalyst)
            .navigationTitle("")
            #else
            .navigationTitle("Import Audio")
            #endif
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            #if targetEnvironment(macCatalyst)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = nil
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            #endif
        }
        .alert("Import Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel?.errorMessage ?? "Unknown error occurred")
        }
        .alert("Import Info", isPresented: infoBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel?.infoMessage ?? "")
        }
        #if targetEnvironment(macCatalyst)
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let viewModel = viewModel,
                   let file = fileToDelete,
                   let index = viewModel.importedFiles.firstIndex(where: { $0.id == file.id }) {
                    // Delete the file (this handles cleanup and notification)
                    deleteFiles(at: IndexSet(integer: index), viewModel: viewModel)
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete '\(file.fileName)'? This will remove it from all your devices.")
            }
        }
        .background(Color.backgroundPrimary.ignoresSafeArea(edges: [.top, .horizontal]))
        #else
        .background(Color.backgroundPrimary.ignoresSafeArea())
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private func contentView(viewModel: ImportViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            if viewModel.isImporting {
                importProgressView(progress: viewModel.importProgress)
            }

            if viewModel.importedFiles.isEmpty {
                dropZoneView
                    .padding()
            } else {
                importedFilesList(viewModel: viewModel)
            }
        }
        .background(
            ZStack {
                // Invisible full-coverage drop target - only active when dragging and genre selected
                Color.clear
                    .contentShape(Rectangle())
                    .onDrop(of: [.audio], isTargeted: $isDropTargeted) { providers in
                        guard selectedGenre != nil else {
                            return false
                        }
                        handleDrop(providers: providers)
                        return true
                    }
                
                // Visual drop zone overlay when dragging
                if isDropTargeted {
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                Color.primaryAccent,
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    dash: [10, 5]
                                )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.primaryAccent.opacity(0.1))
                            )
                            .padding(8)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        
                        if selectedGenre == nil {
                            Text("Please select a genre first")
                                .font(.headline)
                                .foregroundStyle(Color.primaryAccent)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.backgroundSecondary)
                                )
                                .transition(.opacity)
                        }
                    }
                }
            }
        )
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        .onChange(of: selectedGenre) { oldValue, newValue in
            viewModel.selectedGenre = newValue
        }
        .task {
            // Run loading operations on background thread to avoid blocking UI during tab switch
            await Task.detached(priority: .userInitiated) {
                await MainActor.run {
                    viewModel.loadImports()
                }
                
                // Check for orphaned files (files deleted on other devices)
                await viewModel.scanForOrphanedFiles()
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
            // Don't reload here - removeImportedFile() already updates the array
            // This notification is for OTHER views (ContentView, PlayerView)
            // Only check for orphans if file was deleted from another view (Dashboard)
            Task(priority: .utility) {
                await viewModel.scanForOrphanedFiles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudFilesChanged)) { _ in
            // When iCloud files change, check for orphaned records
            Task(priority: .userInitiated) {
                await viewModel.cleanupOrphanedRecords()
            }
        }
    }

    private var dropZoneView: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.primaryAccent)

                VStack(spacing: 8) {
                    Text("Import Audio Files")
                        .font(.title2.weight(.semibold))
                    
                    Text("Drag & drop or browse files")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }

                VStack(spacing: 16) {
                    // Genre selection dropdown - full width
                    Menu {
                        ForEach(AppConstants.availableGenres, id: \.self) { genre in
                            Button {
                                selectedGenre = genre
                            } label: {
                                HStack {
                                    Text(genre)
                                    if selectedGenre == genre {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.primaryAccent)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Genre:")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(selectedGenre ?? "Select a genre...")
                                .font(.subheadline)
                                .foregroundStyle(selectedGenre == nil ? Color.secondaryText : Color.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.backgroundSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            selectedGenre == nil ? Color.secondary.opacity(0.3) : Color.primaryAccent.opacity(0.5),
                                            lineWidth: selectedGenre == nil ? 1 : 2
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Browse Files button - full width
                    Button {
                        isShowingDocumentPicker = true
                    } label: {
                        Label("Browse Files", systemImage: "folder")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primaryAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedGenre == nil)
                    .opacity(selectedGenre == nil ? 0.5 : 1.0)
                }
                .frame(maxWidth: 500)

                supportedFormatsView
                
                Spacer()
            }
            .frame(maxWidth: 500)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func importedFilesList(viewModel: ImportViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 0) {
            #if targetEnvironment(macCatalyst)
            // Import More button at the top on Mac
            HStack {
                Text("\(viewModel.importedFiles.count) \(viewModel.importedFiles.count == 1 ? "Song" : "Songs")")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.scanForOrphanedFiles()
                    }
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise.icloud")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isImporting)
                
                // Genre selection dropdown
                Menu {
                    ForEach(AppConstants.availableGenres, id: \.self) { genre in
                        Button {
                            selectedGenre = genre
                        } label: {
                            HStack {
                                Text(genre)
                                if selectedGenre == genre {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.primaryAccent)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Genre:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(selectedGenre ?? "Select...")
                            .font(.subheadline)
                            .foregroundStyle(selectedGenre == nil ? Color.secondaryText : Color.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.backgroundSecondary)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    isShowingDocumentPicker = true
                } label: {
                    Label("Import More", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting || selectedGenre == nil)
            }
            .padding()
            #else
            // Fixed header on iOS - not scrollable
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    Text("\(viewModel.importedFiles.count) \(viewModel.importedFiles.count == 1 ? "Song" : "Songs")")
                        .textCase(.none)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    
                    // Scan for orphaned files button
                    Button {
                        Task {
                            await viewModel.scanForOrphanedFiles()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise.icloud")
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isImporting)
                }
                .padding(.vertical, 4)
                
                // Genre selection dropdown - full width on iOS
                Menu {
                    ForEach(AppConstants.availableGenres, id: \.self) { genre in
                        Button {
                            selectedGenre = genre
                        } label: {
                            HStack {
                                Text(genre)
                                if selectedGenre == genre {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.primaryAccent)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Genre:")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(selectedGenre ?? "Select a genre...")
                            .font(.subheadline)
                            .foregroundStyle(selectedGenre == nil ? Color.secondaryText : Color.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.backgroundSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selectedGenre == nil ? Color.secondary.opacity(0.3) : Color.primaryAccent.opacity(0.5),
                                        lineWidth: selectedGenre == nil ? 1 : 2
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
                
                Button("Import More") {
                    isShowingDocumentPicker = true
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primaryAccent)
                )
                .disabled(viewModel.isImporting || selectedGenre == nil)
                .opacity((viewModel.isImporting || selectedGenre == nil) ? 0.5 : 1.0)
            }
            .padding()
            .background(Color.backgroundPrimary)
            #endif
            
            // Scrollable list
            List {
                Section {
                    ForEach(viewModel.importedFiles) { file in
                        ImportedFileRow(
                            audioFile: file,
                            onPlayTapped: {
                                selectedAudioFile = file
                                shouldAutoPlay = true
                                selectedTab = 2 // Navigate to Player tab
                            },
                            onDelete: {
                                #if targetEnvironment(macCatalyst)
                                fileToDelete = file
                                showDeleteConfirmation = true
                                #else
                                if let index = viewModel.importedFiles.firstIndex(where: { $0.id == file.id }) {
                                    deleteFiles(at: IndexSet(integer: index), viewModel: viewModel)
                                }
                                #endif
                            }
                        )
                        #if targetEnvironment(macCatalyst)
                        .listRowBackground(Color.clear)
                        #endif
                    }
                    .onDelete { indexSet in
                        deleteFiles(at: indexSet, viewModel: viewModel)
                    }
                    
                    // Spacer row to make list take full height and accept drops
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            #if targetEnvironment(macCatalyst)
            .scrollContentBackground(.hidden)
            #endif
            .overlay {
                if viewModel.importedFiles.isEmpty {
                    EmptyImportState()
                }
            }
        }
    }

    private var supportedFormatsView: some View {
        VStack(spacing: 12) {
            Text("Supported Formats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            HStack(spacing: 8) {
                ForEach(AppConstants.supportedAudioFormats.sorted(), id: \.self) { format in
                    Text(format.uppercased())
                        .font(.caption2.weight(.medium))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func importProgressView(progress: Double) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Importing files…")
                        .font(.headline)
                    
                    if progress > 0 {
                        Text("\(Int(progress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                
                Spacer()
            }
            
            if progress > 0 {
                ProgressView(value: progress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        #if !targetEnvironment(macCatalyst)
        .background(Color.backgroundSecondary)
        #endif
    }

    // MARK: - Actions

    @MainActor
    private func initializeViewModel() async {
        guard viewModel == nil else { return }
        let newViewModel = ImportViewModel(modelContext: modelContext)
        newViewModel.loadImports()
        viewModel = newViewModel
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let viewModel else { return false }
        
        
        Task {
            var urls: [URL] = []
            
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    do {
                        let url = try await provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) as? URL
                        if let url = url {
                            // CRITICAL: Start accessing security-scoped resource immediately
                            // for drag-and-drop on MacCatalyst
                            _ = url.startAccessingSecurityScopedResource()
                            urls.append(url)
                        }
                    } catch {
                    }
                }
            }
            
            if !urls.isEmpty {
                await viewModel.importFiles(urls, genre: selectedGenre)
                
                // Select the first file if nothing is selected
                if !viewModel.importedFiles.isEmpty && selectedAudioFile == nil {
                    selectedAudioFile = viewModel.importedFiles.first
                }
            }
        }
        
        return true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let viewModel else { return }

        
        switch result {
        case .success(let urls):
            // Start accessing security-scoped resources for file picker
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
            }
            
            Task {
                await viewModel.importFiles(urls, genre: selectedGenre)
                
                // Just select the first file, don't auto-play or switch tabs
                if !viewModel.importedFiles.isEmpty && selectedAudioFile == nil {
                    selectedAudioFile = viewModel.importedFiles.first
                }
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
        
    }

    private func deleteFiles(at offsets: IndexSet, viewModel: ImportViewModel) {
        // Check if the currently selected file is being deleted BEFORE deletion
        let filesToDelete = offsets.map { viewModel.importedFiles[$0] }
        let isSelectedFileBeingDeleted = filesToDelete.contains { $0.id == selectedAudioFile?.id }
        
        // Delete files (removeImportedFile does everything in background with delay)
        for index in offsets {
            let file = viewModel.importedFiles[index]
            viewModel.removeImportedFile(file)
        }
        
        // Clear selection immediately if needed (array will update shortly)
        if isSelectedFileBeingDeleted {
            selectedAudioFile = nil
            
            // After a short delay, select first available file
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if !viewModel.importedFiles.isEmpty {
                    selectedAudioFile = viewModel.importedFiles.first
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showError ?? false },
            set: { newValue in viewModel?.showError = newValue }
        )
    }
    
    private var infoBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showInfo ?? false },
            set: { newValue in viewModel?.showInfo = newValue }
        )
    }
}

// MARK: - Supporting Views

private struct ImportedFileRow: View {
    let audioFile: AudioFile
    let onPlayTapped: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Status icon
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.fileName)
                    .font(.headline)
                    .lineLimit(1)

                // Metadata - allow wrapping to multiple lines if needed
                Text("\(secondsText(duration: audioFile.duration)) • \(sampleRateText(sampleRate: audioFile.sampleRate)) • \(audioFile.bitDepth)-bit • \(channelLabel(for: audioFile.numberOfChannels)) • \(FileManager.default.formatFileSize(audioFile.fileSize))")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            #if targetEnvironment(macCatalyst)
            // Trash button on Mac
            if let onDelete = onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            #endif
            
            Button(action: onPlayTapped) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.primaryAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Status Icon
    
    private var statusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.15))
                .frame(width: 40, height: 40)

            // Mini waveform visualization
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(statusColor)
                        .frame(width: 2.5, height: waveformHeight(for: index))
                }
            }
            
            // Checkmark overlay for analyzed files (matches AudioFileRow exactly)
            if audioFile.analysisResult != nil {
                VStack {
                    HStack {
                        Spacer()
                        // Always show checkmark for analyzed files (matches DashboardView)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 14, height: 14)
                            )
                    }
                    Spacer()
                }
                .frame(width: 40, height: 40)
                .padding(3)
            }
        }
    }
    
    private var statusColor: Color {
        if let result = audioFile.analysisResult {
            // Use scoreColor directly (matches AudioFileRow)
            // This will show red for scores < 60, orange-red for 60-74, orange for 75-84, etc.
            return Color.scoreColor(for: result.overallScore)
        }
        return .gray
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        // Generate waveform heights - same pattern as DashboardView
        let heights: [CGFloat] = [12, 20, 16, 24, 14]
        return heights[index % heights.count]
    }
    
    // Helper function to detect actual issues (same logic as DashboardView)
    private func hasActualIssues(result: AnalysisResult) -> Bool {
        // If score is high (85+), likely no significant issues
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

    private func secondsText(duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func sampleRateText(sampleRate: Double) -> String {
        sampleRate >= 1000 ? "\(Int(sampleRate / 1000)) kHz" : "\(Int(sampleRate)) Hz"
    }

    private func channelLabel(for count: Int) -> String {
        switch count {
        case 1:
            return "Mono"
        case 2:
            return "Stereo"
        default:
            return "\(count) ch"
        }
    }
}

private struct EmptyImportState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Color.secondaryText)
            Text("No imports yet")
                .font(.headline)
            Text("Import a mix to begin phase analysis and keep track of your uploads here.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    @Previewable @State var selectedAudioFile: AudioFile?
    @Previewable @State var selectedTab = 1
    @Previewable @State var shouldAutoPlay = false
    
    ImportView(selectedAudioFile: $selectedAudioFile, selectedTab: $selectedTab, shouldAutoPlay: $shouldAutoPlay)
        .modelContainer(for: [AudioFile.self])
}
