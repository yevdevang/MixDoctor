import Observation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImportViewModel?
    @State private var isShowingDocumentPicker = false
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
            .navigationTitle("Import Audio")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileImporter(
            isPresented: $isShowingDocumentPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
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
                    deleteFiles(at: IndexSet(integer: index), viewModel: viewModel)
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete '\(file.fileName)'? This will remove it from all your devices.")
            }
        }
        #endif
        .background(Color.backgroundPrimary.ignoresSafeArea())
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
        .task {
            // Always load imports and check for orphans on appear
            viewModel.loadImports()
            
            // Check for orphaned files (files deleted on other devices)
            Task(priority: .userInitiated) {
                print("🔍 Import view appeared - checking for orphaned files")
                await viewModel.scanForOrphanedFiles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
            // Reload files when a file is deleted from Dashboard
            viewModel.loadImports()
            // Also check for orphans
            Task {
                await viewModel.scanForOrphanedFiles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudFilesChanged)) { _ in
            // When iCloud files change, check for orphaned records
            print("🔔 Import view received iCloudFilesChanged notification")
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

                    
                }

                HStack(spacing: 16) {
                    Button {
                        isShowingDocumentPicker = true
                    } label: {
                        Label("Browse Files", systemImage: "folder")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // Sync button to recover orphaned files
//                if let viewModel {
//                    Button {
//                        Task {
//                            await viewModel.scanForOrphanedFiles()
//                        }
//                    } label: {
//                        Image(systemName: "arrow.clockwise.icloud")
//                            .font(.title3)
//                    }
//                    .buttonStyle(.bordered)
//                    .controlSize(.large)
//                    .disabled(viewModel.isImporting)
//                }
                }

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
                
                Button {
                    isShowingDocumentPicker = true
                } label: {
                    Label("Import More", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)
            }
            .padding()
            #endif
            
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
                } header: {
                    #if !targetEnvironment(macCatalyst)
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
                        
                        Button("Import More") {
                            isShowingDocumentPicker = true
                        }
                        .font(.subheadline)
                        .disabled(viewModel.isImporting)
                    }
                    .padding(.vertical, 4)
                    #endif
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

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let viewModel else { return }

        print("\n" + String(repeating: "🔥", count: 40))
        print("🔥 IMPORT VIEW: handleFileImport called")
        print(String(repeating: "🔥", count: 40))
        
        switch result {
        case .success(let urls):
            print("✅ File picker success: \(urls.count) file(s) selected")
            for (index, url) in urls.enumerated() {
                print("   File \(index + 1): \(url.lastPathComponent)")
                print("      Path: \(url.path)")
                print("      Is security scoped: \(url.startAccessingSecurityScopedResource())")
                url.stopAccessingSecurityScopedResource()
            }
            
            Task {
                print("📞 Calling viewModel.importFiles with \(urls.count) URL(s)")
                await viewModel.importFiles(urls)
                print("✅ viewModel.importFiles completed")
                
                // Just select the first file, don't auto-play or switch tabs
                if !viewModel.importedFiles.isEmpty && selectedAudioFile == nil {
                    selectedAudioFile = viewModel.importedFiles.first
                }
            }
        case .failure(let error):
            print("❌ File picker failed: \(error.localizedDescription)")
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
        
        print(String(repeating: "🔥", count: 40) + "\n")
    }

    private func deleteFiles(at offsets: IndexSet, viewModel: ImportViewModel) {
        for index in offsets {
            let file = viewModel.importedFiles[index]
            viewModel.removeImportedFile(file)
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
                    .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
