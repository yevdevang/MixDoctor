# Phase 5: Data Management & Persistence

**Duration**: Week 6-7
**Goal**: Implement robust data persistence, file management, and export capabilities

## Objectives

- Implement SwiftData persistence layer
- Manage audio file storage efficiently
- Create backup and restore functionality
- Implement export features (PDF reports, CSV data)
- Handle data migration and versioning
- Optimize storage and cleanup
- Implement user preferences management

## Data Architecture

### SwiftData Schema

```swift
import Foundation
import SwiftData

// AudioFile Model (already defined in Phase 1, extended here)
@Model
final class AudioFile {
    var id: UUID
    var fileName: String
    var fileURL: URL
    var duration: TimeInterval
    var sampleRate: Double
    var bitDepth: Int
    var numberOfChannels: Int
    var fileSize: Int64
    var dateImported: Date
    var dateAnalyzed: Date?
    var tags: [String]
    var notes: String

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?

    @Relationship(deleteRule: .cascade)
    var analysisHistory: [AnalysisResult]

    init(fileName: String, fileURL: URL, duration: TimeInterval,
         sampleRate: Double, bitDepth: Int, numberOfChannels: Int, fileSize: Int64) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.numberOfChannels = numberOfChannels
        self.fileSize = fileSize
        self.dateImported = Date()
        self.tags = []
        self.notes = ""
        self.analysisHistory = []
    }
}

// AnalysisResult Model (extended from Phase 1)
@Model
final class AnalysisResult {
    var id: UUID
    var audioFile: AudioFile?
    var dateAnalyzed: Date
    var analysisVersion: String  // Track analysis algorithm version
    var overallScore: Double

    // Metrics
    var stereoWidthScore: Double
    var phaseCoherence: Double
    var frequencyBalance: FrequencyBalance
    var dynamicRange: Double
    var loudnessLUFS: Double
    var peakLevel: Double
    var crestFactor: Double
    var spectralCentroid: Double

    // Issue flags
    var hasPhaseIssues: Bool
    var hasStereoIssues: Bool
    var hasFrequencyImbalance: Bool
    var hasDynamicRangeIssues: Bool
    var hasClipping: Bool

    // Recommendations
    var recommendations: [String]

    // Raw data for visualizations (stored as Data)
    var waveformData: Data?
    var spectrumData: Data?

    init(audioFile: AudioFile) {
        self.id = UUID()
        self.audioFile = audioFile
        self.dateAnalyzed = Date()
        self.analysisVersion = AppConstants.analysisVersion
        self.overallScore = 0
        self.stereoWidthScore = 0
        self.phaseCoherence = 0
        self.frequencyBalance = FrequencyBalance()
        self.dynamicRange = 0
        self.loudnessLUFS = 0
        self.peakLevel = 0
        self.crestFactor = 0
        self.spectralCentroid = 0
        self.hasPhaseIssues = false
        self.hasStereoIssues = false
        self.hasFrequencyImbalance = false
        self.hasDynamicRangeIssues = false
        self.hasClipping = false
        self.recommendations = []
    }
}

// User Preferences Model
@Model
final class UserPreferences {
    var id: UUID
    var theme: ThemeOption
    var analysisSensitivity: AnalysisSensitivity
    var autoAnalyzeOnImport: Bool
    var keepAnalysisHistory: Bool
    var maxHistoryEntries: Int
    var exportFormat: ExportFormat
    var notificationsEnabled: Bool

    init() {
        self.id = UUID()
        self.theme = .system
        self.analysisSensitivity = .normal
        self.autoAnalyzeOnImport = false
        self.keepAnalysisHistory = true
        self.maxHistoryEntries = 10
        self.exportFormat = .pdf
        self.notificationsEnabled = true
    }
}

enum ThemeOption: Codable {
    case light, dark, system
}

enum AnalysisSensitivity: Codable {
    case relaxed, normal, strict
}

enum ExportFormat: Codable {
    case pdf, csv, json
}
```

## Implementation

### 1. Data Persistence Service

```swift
import Foundation
import SwiftData

@Observable
final class DataPersistenceService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Audio Files

    func saveAudioFile(_ audioFile: AudioFile) throws {
        modelContext.insert(audioFile)
        try modelContext.save()
    }

    func fetchAllAudioFiles() -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAudioFile(id: UUID) -> AudioFile? {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func deleteAudioFile(_ audioFile: AudioFile) throws {
        // Delete physical file
        try? FileManager.default.removeItem(at: audioFile.fileURL)

        // Delete from database
        modelContext.delete(audioFile)
        try modelContext.save()
    }

    func updateAudioFile(_ audioFile: AudioFile) throws {
        try modelContext.save()
    }

    // MARK: - Analysis Results

    func saveAnalysisResult(_ result: AnalysisResult, for audioFile: AudioFile) throws {
        // Update or create relationship
        audioFile.analysisResult = result
        audioFile.dateAnalyzed = Date()

        // Add to history if enabled
        if let preferences = fetchPreferences(), preferences.keepAnalysisHistory {
            audioFile.analysisHistory.append(result)

            // Trim history if needed
            if audioFile.analysisHistory.count > preferences.maxHistoryEntries {
                let toRemove = audioFile.analysisHistory.count - preferences.maxHistoryEntries
                audioFile.analysisHistory.removeFirst(toRemove)
            }
        }

        try modelContext.save()
    }

    func fetchAnalysisHistory(for audioFile: AudioFile) -> [AnalysisResult] {
        return audioFile.analysisHistory.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
    }

    // MARK: - Preferences

    func fetchPreferences() -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try? modelContext.fetch(descriptor)
        return preferences?.first
    }

    func savePreferences(_ preferences: UserPreferences) throws {
        if fetchPreferences() == nil {
            modelContext.insert(preferences)
        }
        try modelContext.save()
    }

    func updatePreferences(_ update: (UserPreferences) -> Void) throws {
        guard let preferences = fetchPreferences() else {
            let newPreferences = UserPreferences()
            update(newPreferences)
            modelContext.insert(newPreferences)
            try modelContext.save()
            return
        }

        update(preferences)
        try modelContext.save()
    }

    // MARK: - Search & Filter

    func searchAudioFiles(query: String) -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { audioFile in
                audioFile.fileName.localizedStandardContains(query) ||
                audioFile.notes.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAudioFiles(with tags: [String]) -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { audioFile in
                !Set(audioFile.tags).isDisjoint(with: Set(tags))
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Statistics

    func getStatistics() -> AnalysisStatistics {
        let allFiles = fetchAllAudioFiles()
        let analyzedFiles = allFiles.filter { $0.analysisResult != nil }

        let totalDuration = allFiles.reduce(0) { $0 + $1.duration }
        let totalSize = allFiles.reduce(0) { $0 + $1.fileSize }

        let scores = analyzedFiles.compactMap { $0.analysisResult?.overallScore }
        let averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        let issuesCount = analyzedFiles.filter { file in
            guard let result = file.analysisResult else { return false }
            return result.hasPhaseIssues || result.hasStereoIssues ||
                   result.hasFrequencyImbalance || result.hasDynamicRangeIssues
        }.count

        return AnalysisStatistics(
            totalFiles: allFiles.count,
            analyzedFiles: analyzedFiles.count,
            totalDuration: totalDuration,
            totalSize: totalSize,
            averageScore: averageScore,
            filesWithIssues: issuesCount
        )
    }
}

struct AnalysisStatistics {
    let totalFiles: Int
    let analyzedFiles: Int
    let totalDuration: TimeInterval
    let totalSize: Int64
    let averageScore: Double
    let filesWithIssues: Int
}
```

### 2. File Management Service

```swift
import Foundation

final class FileManagementService {

    private let fileManager = FileManager.default

    // MARK: - Directories

    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var audioFilesDirectory: URL {
        documentsDirectory.appendingPathComponent("AudioFiles", isDirectory: true)
    }

    var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    var backupDirectory: URL {
        documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: - Setup

    func setupDirectories() throws {
        let directories = [audioFilesDirectory, backupDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }
    }

    // MARK: - Storage Management

    func calculateStorageUsage() -> StorageInfo {
        let audioFiles = try? fileManager.contentsOfDirectory(
            at: audioFilesDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )

        let totalSize = audioFiles?.reduce(Int64(0)) { total, url in
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return total + Int64(size ?? 0)
        } ?? 0

        let availableSpace = try? fileManager.attributesOfFileSystem(
            forPath: documentsDirectory.path
        )[.systemFreeSize] as? Int64

        return StorageInfo(
            usedSpace: totalSize,
            availableSpace: availableSpace ?? 0,
            fileCount: audioFiles?.count ?? 0
        )
    }

    // MARK: - Cleanup

    func cleanupCache() throws {
        let cacheContents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )

        for url in cacheContents {
            try? fileManager.removeItem(at: url)
        }
    }

    func removeOrphanedFiles(validURLs: [URL]) throws {
        let audioFiles = try fileManager.contentsOfDirectory(
            at: audioFilesDirectory,
            includingPropertiesForKeys: nil
        )

        let validPaths = Set(validURLs.map { $0.path })

        for url in audioFiles {
            if !validPaths.contains(url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Backup & Restore

    func createBackup(audioFiles: [AudioFile]) async throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupName = "MixDoctor_Backup_\(timestamp)"
        let backupURL = backupDirectory.appendingPathComponent(backupName, isDirectory: true)

        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        // Create metadata file
        let metadata = BackupMetadata(
            date: Date(),
            fileCount: audioFiles.count,
            appVersion: AppConstants.appVersion
        )

        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: backupURL.appendingPathComponent("metadata.json"))

        // Copy audio files and analysis data
        for audioFile in audioFiles {
            let fileName = audioFile.fileURL.lastPathComponent
            let destinationURL = backupURL.appendingPathComponent(fileName)

            try fileManager.copyItem(at: audioFile.fileURL, to: destinationURL)

            // Save analysis result as JSON
            if let result = audioFile.analysisResult {
                let resultData = try JSONEncoder().encode(AnalysisResultExport(from: result))
                let resultFileName = fileName.replacingOccurrences(of: ".", with: "_") + "_analysis.json"
                try resultData.write(to: backupURL.appendingPathComponent(resultFileName))
            }
        }

        return backupURL
    }

    func restoreBackup(from backupURL: URL) async throws -> [AudioFile] {
        // Read metadata
        let metadataURL = backupURL.appendingPathComponent("metadata.json")
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(BackupMetadata.self, from: metadataData)

        // Get all audio files in backup
        let backupContents = try fileManager.contentsOfDirectory(
            at: backupURL,
            includingPropertiesForKeys: nil
        )

        let audioFiles = backupContents.filter { url in
            AppConstants.supportedAudioFormats.contains(url.pathExtension.lowercased())
        }

        var restoredFiles: [AudioFile] = []

        for audioURL in audioFiles {
            // Copy file back to audio files directory
            let destinationURL = audioFilesDirectory.appendingPathComponent(audioURL.lastPathComponent)
            try fileManager.copyItem(at: audioURL, to: destinationURL)

            // Create AudioFile model (analysis results will be restored separately)
            let asset = AVURLAsset(url: destinationURL)
            // Extract metadata (similar to import process)
            // ... metadata extraction code ...

            // restoredFiles.append(audioFile)
        }

        return restoredFiles
    }
}

struct StorageInfo {
    let usedSpace: Int64
    let availableSpace: Int64
    let fileCount: Int

    var usedSpaceFormatted: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var availableSpaceFormatted: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }
}

struct BackupMetadata: Codable {
    let date: Date
    let fileCount: Int
    let appVersion: String
}
```

### 3. Export Service

```swift
import Foundation
import PDFKit

final class ExportService {

    // MARK: - PDF Export

    func exportToPDF(audioFile: AudioFile, result: AnalysisResult) async throws -> URL {
        let pdfMetadata = [
            kCGPDFContextTitle: "MixDoctor Analysis Report",
            kCGPDFContextAuthor: "MixDoctor",
            kCGPDFContextCreator: "MixDoctor iOS App"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let pdfData = renderer.pdfData { context in
            context.beginPage()

            // Draw content
            drawPDFHeader(audioFile: audioFile, in: pageRect)
            drawOverallScore(result: result, in: pageRect, yOffset: 100)
            drawMetrics(result: result, in: pageRect, yOffset: 250)
            drawRecommendations(result: result, in: pageRect, yOffset: 500)
        }

        // Save to temporary directory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(audioFile.fileName)_analysis.pdf")

        try pdfData.write(to: tempURL)
        return tempURL
    }

    private func drawPDFHeader(audioFile: AudioFile, in rect: CGRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24)
        ]

        let title = "MixDoctor Analysis Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (rect.width - titleSize.width) / 2,
            y: 40,
            width: titleSize.width,
            height: titleSize.height
        )

        title.draw(in: titleRect, withAttributes: titleAttributes)

        // File info
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]

        let info = """
        File: \(audioFile.fileName)
        Sample Rate: \(Int(audioFile.sampleRate / 1000))kHz
        Duration: \(formatDuration(audioFile.duration))
        Date: \(formatDate(Date()))
        """

        info.draw(in: CGRect(x: 50, y: 80, width: rect.width - 100, height: 80),
                  withAttributes: infoAttributes)
    }

    private func drawOverallScore(result: AnalysisResult, in rect: CGRect, yOffset: CGFloat) {
        // Draw score circle and value
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 48)
        ]

        let scoreText = "\(Int(result.overallScore))"
        let scoreSize = scoreText.size(withAttributes: scoreAttributes)
        let scoreRect = CGRect(
            x: (rect.width - scoreSize.width) / 2,
            y: yOffset,
            width: scoreSize.width,
            height: scoreSize.height
        )

        scoreText.draw(in: scoreRect, withAttributes: scoreAttributes)
    }

    private func drawMetrics(result: AnalysisResult, in rect: CGRect, yOffset: CGFloat) {
        let metricsText = """
        Stereo Width: \(String(format: "%.1f%%", result.stereoWidthScore))
        Phase Coherence: \(String(format: "%.1f%%", result.phaseCoherence * 100))
        Dynamic Range: \(String(format: "%.1f dB", result.dynamicRange))
        Loudness: \(String(format: "%.1f LUFS", result.loudnessLUFS))
        Peak Level: \(String(format: "%.1f dBFS", result.peakLevel))
        """

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]

        metricsText.draw(in: CGRect(x: 50, y: yOffset, width: rect.width - 100, height: 200),
                        withAttributes: attributes)
    }

    private func drawRecommendations(result: AnalysisResult, in rect: CGRect, yOffset: CGFloat) {
        guard !result.recommendations.isEmpty else { return }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18)
        ]

        "Recommendations".draw(in: CGRect(x: 50, y: yOffset, width: rect.width - 100, height: 30),
                              withAttributes: titleAttributes)

        let recommendations = result.recommendations.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n")

        let recAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]

        recommendations.draw(in: CGRect(x: 50, y: yOffset + 40, width: rect.width - 100, height: 200),
                           withAttributes: recAttributes)
    }

    // MARK: - CSV Export

    func exportToCSV(audioFiles: [AudioFile]) async throws -> URL {
        var csvText = "File Name,Sample Rate,Duration,Overall Score,Stereo Width,Phase Coherence,Dynamic Range,Loudness,Peak Level,Has Issues\n"

        for file in audioFiles {
            guard let result = file.analysisResult else { continue }

            let hasIssues = result.hasPhaseIssues || result.hasStereoIssues ||
                           result.hasFrequencyImbalance || result.hasDynamicRangeIssues

            let row = """
            "\(file.fileName)",\
            \(file.sampleRate),\
            \(file.duration),\
            \(result.overallScore),\
            \(result.stereoWidthScore),\
            \(result.phaseCoherence),\
            \(result.dynamicRange),\
            \(result.loudnessLUFS),\
            \(result.peakLevel),\
            \(hasIssues)\n
            """

            csvText.append(row)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mixdoctor_export.csv")

        try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    // MARK: - JSON Export

    func exportToJSON(audioFile: AudioFile, result: AnalysisResult) async throws -> URL {
        let export = AnalysisResultExport(from: result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(export)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(audioFile.fileName)_analysis.json")

        try jsonData.write(to: tempURL)
        return tempURL
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AnalysisResultExport: Codable {
    let id: String
    let dateAnalyzed: Date
    let overallScore: Double
    let metrics: MetricsExport
    let issues: IssuesExport
    let recommendations: [String]

    struct MetricsExport: Codable {
        let stereoWidth: Double
        let phaseCoherence: Double
        let dynamicRange: Double
        let loudness: Double
        let peakLevel: Double
        let frequencyBalance: FrequencyBalanceExport
    }

    struct FrequencyBalanceExport: Codable {
        let lowEnd: Double
        let mids: Double
        let highs: Double
    }

    struct IssuesExport: Codable {
        let hasPhaseIssues: Bool
        let hasStereoIssues: Bool
        let hasFrequencyImbalance: Bool
        let hasDynamicRangeIssues: Bool
        let hasClipping: Bool
    }

    init(from result: AnalysisResult) {
        self.id = result.id.uuidString
        self.dateAnalyzed = result.dateAnalyzed
        self.overallScore = result.overallScore
        self.metrics = MetricsExport(
            stereoWidth: result.stereoWidthScore,
            phaseCoherence: result.phaseCoherence,
            dynamicRange: result.dynamicRange,
            loudness: result.loudnessLUFS,
            peakLevel: result.peakLevel,
            frequencyBalance: FrequencyBalanceExport(
                lowEnd: result.frequencyBalance.lowEnd,
                mids: result.frequencyBalance.mids,
                highs: result.frequencyBalance.highs
            )
        )
        self.issues = IssuesExport(
            hasPhaseIssues: result.hasPhaseIssues,
            hasStereoIssues: result.hasStereoIssues,
            hasFrequencyImbalance: result.hasFrequencyImbalance,
            hasDynamicRangeIssues: result.hasDynamicRangeIssues,
            hasClipping: result.hasClipping
        )
        self.recommendations = result.recommendations
    }
}
```

### 4. Settings View with Data Management

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var storageInfo: StorageInfo?
    @State private var showingClearCacheAlert = false
    @State private var showingBackupAlert = false

    private let fileManager = FileManagementService()
    private let exportService = ExportService()

    var body: some View {
        NavigationStack {
            List {
                // Storage section
                storageSection

                // Data management section
                dataManagementSection

                // Export section
                exportSection

                // About section
                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                storageInfo = fileManager.calculateStorageUsage()
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section("Storage") {
            if let info = storageInfo {
                LabeledContent("Used Space", value: info.usedSpaceFormatted)
                LabeledContent("Available Space", value: info.availableSpaceFormatted)
                LabeledContent("Audio Files", value: "\(info.fileCount)")
            }

            Button("Clear Cache") {
                showingClearCacheAlert = true
            }
            .foregroundColor(.red)
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                try? fileManager.cleanupCache()
                storageInfo = fileManager.calculateStorageUsage()
            }
        } message: {
            Text("This will remove temporary files and free up space.")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section("Data Management") {
            Button("Create Backup") {
                showingBackupAlert = true
            }

            Button("Export All Data") {
                Task {
                    // Export logic
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Export") {
            NavigationLink("Export Format") {
                ExportFormatPicker()
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: AppConstants.appVersion)
            LabeledContent("Analysis Version", value: AppConstants.analysisVersion)
            Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            Link("Support", destination: URL(string: "https://example.com/support")!)
        }
    }
}
```

## Constants Update

```swift
enum AppConstants {
    // ... existing constants ...

    // Versioning
    static let appVersion = "1.0.0"
    static let analysisVersion = "1.0"

    // Storage
    static let maxStorageGB = 10
    static let backupRetentionDays = 30
}
```

## Deliverables

- [ ] SwiftData schema fully implemented
- [ ] Data persistence service
- [ ] File management service
- [ ] Backup and restore functionality
- [ ] Export service (PDF, CSV, JSON)
- [ ] Storage management and cleanup
- [ ] Settings UI with data management
- [ ] Migration handling

## Next Phase

Proceed to [Phase 6: Testing & Optimization](06-phase-testing-optimization.md)

## Estimated Time

- SwiftData implementation: 4 hours
- File management: 4 hours
- Export functionality: 6 hours
- Backup/restore: 4 hours
- Settings UI: 3 hours
- Testing: 3 hours

**Total: ~24 hours (3-4 days)**
