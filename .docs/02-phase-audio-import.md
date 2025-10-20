# Phase 2: Audio Import System

**Duration**: Week 1-2
**Goal**: Implement robust audio file import with validation and metadata extraction

## Objectives

- Implement document picker for audio file selection
- Support multiple audio formats (WAV, AIFF, MP3, M4A, FLAC)
- Extract audio metadata (sample rate, bit depth, duration, etc.)
- Validate audio files before processing
- Handle file permissions and security-scoped resources
- Implement batch import capability
- Create intuitive import UI

## Technical Requirements

### Supported Audio Formats

| Format | Extension | Container | Codec |
|--------|-----------|-----------|-------|
| WAV | .wav | RIFF | PCM |
| AIFF | .aiff, .aif | AIFF | PCM |
| MP3 | .mp3 | MPEG | MPEG Layer 3 |
| M4A | .m4a | MPEG-4 | AAC |
| FLAC | .flac | FLAC | FLAC |

### File Validation Criteria

- Maximum file size: 500 MB
- Minimum sample rate: 44.1 kHz
- Supported bit depths: 16, 24, 32 bit (for PCM)
- Must have at least 1 audio channel
- Must be stereo for full analysis (mono files get warning)

## Implementation

### 1. AudioImportService Implementation

```swift
import Foundation
import AVFoundation
import UniformTypeIdentifiers

enum AudioImportError: LocalizedError {
    case unsupportedFormat
    case fileTooLarge
    case invalidAudioFile
    case sampleRateTooLow
    case accessDenied
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Audio format not supported"
        case .fileTooLarge:
            return "File exceeds maximum size of 500 MB"
        case .invalidAudioFile:
            return "File is not a valid audio file"
        case .sampleRateTooLow:
            return "Sample rate must be at least 44.1 kHz"
        case .accessDenied:
            return "Cannot access file. Please grant permission."
        case .unknownError(let error):
            return "Import failed: \(error.localizedDescription)"
        }
    }
}

@Observable
final class AudioImportService {

    // MARK: - Main Import Function

    func importAudioFile(from url: URL) async throws -> AudioFile {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw AudioImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Validate file
        try validateAudioFile(url)

        // Extract metadata
        let metadata = try await extractMetadata(from: url)

        // Copy to app's documents directory
        let destinationURL = try await copyToDocuments(from: url)

        // Create AudioFile model
        let audioFile = AudioFile(
            fileName: url.lastPathComponent,
            fileURL: destinationURL,
            duration: metadata.duration,
            sampleRate: metadata.sampleRate,
            bitDepth: metadata.bitDepth,
            numberOfChannels: metadata.numberOfChannels,
            fileSize: metadata.fileSize
        )

        return audioFile
    }

    // MARK: - Validation

    func validateAudioFile(_ url: URL) throws -> Bool {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioImportError.invalidAudioFile
        }

        // Check file size
        let fileSize = try getFileSize(url)
        let maxSize = Int64(AppConstants.maxFileSizeMB) * 1024 * 1024
        guard fileSize <= maxSize else {
            throw AudioImportError.fileTooLarge
        }

        // Check format
        let fileExtension = url.pathExtension.lowercased()
        guard AppConstants.supportedAudioFormats.contains(fileExtension) else {
            throw AudioImportError.unsupportedFormat
        }

        // Check if AVFoundation can read it
        let asset = AVURLAsset(url: url)
        guard asset.isReadable else {
            throw AudioImportError.invalidAudioFile
        }

        return true
    }

    // MARK: - Metadata Extraction

    struct AudioMetadata {
        let duration: TimeInterval
        let sampleRate: Double
        let bitDepth: Int
        let numberOfChannels: Int
        let fileSize: Int64
        let format: String
    }

    private func extractMetadata(from url: URL) async throws -> AudioMetadata {
        let asset = AVURLAsset(url: url)

        // Get duration
        let duration = try await asset.load(.duration).seconds

        // Get audio tracks
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = tracks.first else {
            throw AudioImportError.invalidAudioFile
        }

        // Get format descriptions
        let formatDescriptions = try await firstTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw AudioImportError.invalidAudioFile
        }

        // Extract audio format details
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription?.pointee else {
            throw AudioImportError.invalidAudioFile
        }

        let sampleRate = asbd.mSampleRate
        let numberOfChannels = Int(asbd.mChannelsPerFrame)
        let bitDepth = Int(asbd.mBitsPerChannel)

        // Validate sample rate
        guard sampleRate >= AppConstants.minSampleRate else {
            throw AudioImportError.sampleRateTooLow
        }

        // Get file size
        let fileSize = try getFileSize(url)

        return AudioMetadata(
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth > 0 ? bitDepth : 16, // Default to 16 for compressed formats
            numberOfChannels: numberOfChannels,
            fileSize: fileSize,
            format: url.pathExtension.uppercased()
        )
    }

    // MARK: - File Management

    private func copyToDocuments(from sourceURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilesURL = documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: audioFilesURL.path) {
            try fileManager.createDirectory(at: audioFilesURL, withIntermediateDirectories: true)
        }

        // Generate unique filename if file already exists
        var destinationURL = audioFilesURL.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension

        while fileManager.fileExists(atPath: destinationURL.path) {
            let newFileName = "\(fileName)_\(counter).\(fileExtension)"
            destinationURL = audioFilesURL.appendingPathComponent(newFileName)
            counter += 1
        }

        // Copy file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }

    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    // MARK: - Batch Import

    func importMultipleFiles(_ urls: [URL]) async throws -> [AudioFile] {
        var importedFiles: [AudioFile] = []
        var errors: [Error] = []

        for url in urls {
            do {
                let audioFile = try await importAudioFile(from: url)
                importedFiles.append(audioFile)
            } catch {
                errors.append(error)
            }
        }

        // If all imports failed, throw the first error
        if importedFiles.isEmpty && !errors.isEmpty {
            throw errors[0]
        }

        return importedFiles
    }
}
```

### 2. ImportViewModel Implementation

```swift
import SwiftUI
import SwiftData

@Observable
final class ImportViewModel {
    private let importService: AudioImportService
    private let modelContext: ModelContext

    // State
    var isImporting = false
    var importProgress: Double = 0
    var selectedFiles: [URL] = []
    var importedFiles: [AudioFile] = []
    var errorMessage: String?
    var showError = false

    init(importService: AudioImportService = AudioImportService(),
         modelContext: ModelContext) {
        self.importService = importService
        self.modelContext = modelContext
    }

    // MARK: - Import Actions

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        importProgress = 0
        errorMessage = nil
        defer { isImporting = false }

        do {
            let files = try await importService.importMultipleFiles(urls)

            // Save to SwiftData
            for file in files {
                modelContext.insert(file)
            }
            try modelContext.save()

            importedFiles.append(contentsOf: files)
            importProgress = 1.0

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func clearSelection() {
        selectedFiles.removeAll()
    }

    func removeImportedFile(_ file: AudioFile) {
        modelContext.delete(file)
        try? modelContext.save()
        importedFiles.removeAll { $0.id == file.id }
    }
}
```

### 3. ImportView Implementation

```swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImportViewModel

    @State private var isShowingDocumentPicker = false
    @State private var isShowingDropZone = true

    init() {
        // ViewModel will be initialized in task modifier with modelContext
        _viewModel = State(initialValue: ImportViewModel(modelContext: ModelContext(ModelContainer.shared)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isImporting {
                    importProgressView
                } else if viewModel.importedFiles.isEmpty {
                    dropZoneView
                } else {
                    importedFilesListView
                }
            }
            .navigationTitle("Import Audio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Browse Files") {
                        isShowingDocumentPicker = true
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
            .alert("Import Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
        .task {
            viewModel = ImportViewModel(modelContext: modelContext)
        }
    }

    // MARK: - Views

    private var dropZoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 8) {
                Text("Import Audio Files")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Drag and drop files here or tap Browse Files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { isShowingDocumentPicker = true }) {
                Label("Browse Files", systemImage: "folder")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()

            supportedFormatsView
        }
        .padding()
    }

    private var supportedFormatsView: some View {
        VStack(spacing: 12) {
            Text("Supported Formats")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(AppConstants.supportedAudioFormats, id: \.self) { format in
                    Text(format.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    private var importProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: viewModel.importProgress) {
                Text("Importing files...")
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

            Spacer()
        }
        .padding()
    }

    private var importedFilesListView: some View {
        List {
            Section {
                ForEach(viewModel.importedFiles) { file in
                    ImportedFileRow(audioFile: file)
                }
                .onDelete(perform: deleteFiles)
            } header: {
                HStack {
                    Text("\(viewModel.importedFiles.count) files imported")
                    Spacer()
                    Button("Import More") {
                        isShowingDocumentPicker = true
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
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

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = viewModel.importedFiles[index]
            viewModel.removeImportedFile(file)
        }
    }
}

// MARK: - Imported File Row

struct ImportedFileRow: View {
    let audioFile: AudioFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(formatDuration(audioFile.duration), systemImage: "clock")
                    Label(formatSampleRate(audioFile.sampleRate), systemImage: "waveform")
                    Label("\(audioFile.bitDepth) bit", systemImage: "number")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatSampleRate(_ rate: Double) -> String {
        return "\(Int(rate / 1000))kHz"
    }
}

#Preview {
    ImportView()
        .modelContainer(for: [AudioFile.self])
}
```

### 4. File Extensions and Helpers

```swift
import Foundation

extension FileManager {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func audioFilesDirectory() -> URL {
        let documentsURL = documentsDirectory()
        return documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import MixDoctor

final class AudioImportServiceTests: XCTestCase {

    var sut: AudioImportService!

    override func setUp() {
        super.setUp()
        sut = AudioImportService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testValidateAudioFile_ValidWAV_ReturnsTrue() throws {
        // Given: Valid WAV file URL
        let testBundle = Bundle(for: type(of: self))
        guard let url = testBundle.url(forResource: "test_audio", withExtension: "wav") else {
            XCTFail("Test file not found")
            return
        }

        // When: Validating the file
        let isValid = try sut.validateAudioFile(url)

        // Then: Should return true
        XCTAssertTrue(isValid)
    }

    func testValidateAudioFile_UnsupportedFormat_ThrowsError() {
        // Given: Unsupported file format
        let url = URL(fileURLWithPath: "/test/file.ogg")

        // When/Then: Should throw unsupportedFormat error
        XCTAssertThrowsError(try sut.validateAudioFile(url)) { error in
            XCTAssertEqual(error as? AudioImportError, .unsupportedFormat)
        }
    }
}
```

## Deliverables

- [ ] AudioImportService fully implemented
- [ ] File validation working for all supported formats
- [ ] Metadata extraction functional
- [ ] ImportView with document picker
- [ ] Batch import capability
- [ ] Error handling for all edge cases
- [ ] Unit tests for import service
- [ ] UI tests for import flow
- [ ] Files successfully saved to documents directory
- [ ] SwiftData integration working

## Known Limitations

- FLAC support requires iOS 17+
- Some MP3 files may have inaccurate bit depth reporting (reported as 0)
- Large files (>500MB) are rejected
- Mono files can be imported but will have limited analysis

## Next Phase

Proceed to [Phase 3: CoreML Audio Analysis](03-phase-coreml-analysis.md) to implement the audio analysis engine.

## Estimated Time

- AudioImportService: 4 hours
- Metadata extraction: 3 hours
- ImportView UI: 4 hours
- Error handling: 2 hours
- Testing: 3 hours
- Bug fixes: 2 hours

**Total: ~18 hours (2-3 days)**
