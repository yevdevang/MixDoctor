import Observation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImportViewModel?
    @State private var isShowingDocumentPicker = false

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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Browse Files") {
                        isShowingDocumentPicker = true
                    }
                    .disabled(viewModel?.isImporting == true)
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
        .alert("Import Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel?.errorMessage ?? "Unknown error occurred")
        }
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
            if viewModel.importedFiles.isEmpty {
                viewModel.loadImports()
            }
        }
    }

    private var dropZoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.primaryAccent)

            VStack(spacing: 8) {
                Text("Import Audio Files")
                    .font(.title2.weight(.semibold))

                Text("Drag and drop files here or tap Browse Files to begin.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                isShowingDocumentPicker = true
            } label: {
                Label("Browse Files", systemImage: "folder")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            supportedFormatsView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func importedFilesList(viewModel: ImportViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return List {
            Section {
                ForEach(viewModel.importedFiles) { file in
                    ImportedFileRow(audioFile: file)
                }
                .onDelete { indexSet in
                    deleteFiles(at: indexSet, viewModel: viewModel)
                }
            } header: {
                HStack {
                    Text("\(viewModel.importedFiles.count) files imported")
                    Spacer()
                    Button("Import More") {
                        isShowingDocumentPicker = true
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isImporting)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.importedFiles.isEmpty {
                EmptyImportState()
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
            if progress > 0 {
                ProgressView(value: progress, total: 1) {
                    Text("Importing files…")
                        .font(.headline)
                }
                .progressViewStyle(.linear)

                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            } else {
                ProgressView {
                    Text("Importing files…")
                        .font(.headline)
                }
                .progressViewStyle(.linear)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.backgroundSecondary)
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

        switch result {
        case .success(let urls):
            Task {
                await viewModel.importFiles(urls)
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
        }
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
}

// MARK: - Supporting Views

private struct ImportedFileRow: View {
    let audioFile: AudioFile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(audioFile.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 8) {
                Text(secondsText(duration: audioFile.duration))
                Text("•")
                Text(sampleRateText(sampleRate: audioFile.sampleRate))
                Text("•")
                Text("\(audioFile.bitDepth)-bit")
                Text("•")
                Text(channelLabel(for: audioFile.numberOfChannels))
                Text("•")
                Text(FileManager.default.formatFileSize(audioFile.fileSize))
                
                if audioFile.numberOfChannels < 2 {
                    Text("•")
                    Label("Mono", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical, 8)
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
    ImportView()
        .modelContainer(for: [AudioFile.self])
}
