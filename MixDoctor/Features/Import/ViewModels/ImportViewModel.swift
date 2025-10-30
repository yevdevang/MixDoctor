import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ImportViewModel {
    private let importService: AudioImportService
    private let modelContext: ModelContext

    var isImporting = false
    var importProgress: Double = 0
    var importedFiles: [AudioFile] = []
    var errorMessage: String?
    var showError = false
    var infoMessage: String?
    var showInfo = false

    init(modelContext: ModelContext, importService: AudioImportService = AudioImportService()) {
        self.modelContext = modelContext
        self.importService = importService
    }

    func loadImports() {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        if let storedFiles = try? modelContext.fetch(descriptor) {
            importedFiles = storedFiles
        } else {
            importedFiles = []
        }
    }

    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        isImporting = true
        importProgress = 0
        errorMessage = nil
        showError = false
        infoMessage = nil
        showInfo = false
        defer { isImporting = false }

        do {
            let files = try await importService.importMultipleFiles(urls)
            
            // Check for duplicates before inserting
            var duplicateCount = 0
            var insertedCount = 0
            
            for file in files {
                if !isDuplicate(file) {
                    modelContext.insert(file)
                    insertedCount += 1
                } else {
                    duplicateCount += 1
                    print("⚠️ Skipping duplicate file: \(file.fileName)")
                    
                    // Remove the physical file since it's a duplicate
                    let fileURL = file.fileURL
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                            print("🗑️ Removed duplicate file from storage: \(fileURL.lastPathComponent)")
                        } catch {
                            print("❌ Failed to remove duplicate file: \(error.localizedDescription)")
                        }
                    }
                }
            }

            try modelContext.save()
            loadImports()
            importProgress = 1.0
            
            // Show appropriate message based on results
            if duplicateCount > 0 && insertedCount > 0 {
                // Some files imported, some duplicates
                infoMessage = "Imported \(insertedCount) file\(insertedCount == 1 ? "" : "s"). Skipped \(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")."
                showInfo = true
            } else if duplicateCount > 0 && insertedCount == 0 {
                // All files were duplicates
                infoMessage = duplicateCount == 1 
                    ? "This file is already imported" 
                    : "All \(duplicateCount) files are already imported"
                showInfo = true
            }
            // If insertedCount > 0 and duplicateCount == 0, no message needed (success)
        } catch {
            if let importError = error as? AudioImportError {
                errorMessage = importError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
            importProgress = 0
        }
    }
    // MARK: - Duplicate Detection
    
    /// Check if a file is a duplicate based on fileName, fileSize, and duration
    private func isDuplicate(_ file: AudioFile) -> Bool {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return false
        }
        
        // Check for exact match on fileName and fileSize
        // Duration check within 1 second tolerance (for encoding variations)
        for existingFile in allFiles {
            let sameFileName = existingFile.fileName == file.fileName
            let sameFileSize = existingFile.fileSize == file.fileSize
            let similarDuration = abs(existingFile.duration - file.duration) < 1.0
            
            if sameFileName && sameFileSize && similarDuration {
                return true
            }
        }
        
        return false
    }

    func removeImportedFile(_ file: AudioFile) {
        // Delete the actual audio file from storage (iCloud or local)
        let fileURL = file.fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Deleted audio file from storage: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Failed to delete audio file: \(error)")
            }
        }
        
        // Delete the SwiftData record
        modelContext.delete(file)
        try? modelContext.save()
        importedFiles.removeAll { $0.id == file.id }
    }
}
