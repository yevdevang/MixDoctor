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

        print("📁 Starting import of \(urls.count) file(s)")
        for (index, url) in urls.enumerated() {
            print("   [\(index + 1)] \(url.lastPathComponent)")
        }
        
        isImporting = true
        importProgress = 0
        errorMessage = nil
        showError = false
        infoMessage = nil
        showInfo = false
        defer { isImporting = false }

        do {
            // Pass modelContext to importService so it can check for duplicates BEFORE copying to iCloud
            let files = try await importService.importMultipleFiles(urls, modelContext: modelContext)
            
            print("✅ Import service returned \(files.count) file(s)")
            
            // Check for duplicates before inserting
            var duplicateCount = 0
            var insertedCount = 0
            
            for file in files {
                if !isDuplicate(file) {
                    modelContext.insert(file)
                    insertedCount += 1
                    print("   ✅ Inserted: \(file.fileName)")
                } else {
                    duplicateCount += 1
                    print("   ⚠️ Skipping duplicate: \(file.fileName)")
                    
                    // Remove the physical file since it's a duplicate
                    let fileURL = file.fileURL
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                            print("   🗑️ Removed duplicate file from storage")
                        } catch {
                            print("   ❌ Failed to remove duplicate file: \(error.localizedDescription)")
                        }
                    }
                }
            }

            try modelContext.save()
            print("💾 Saved context - inserted: \(insertedCount), duplicates: \(duplicateCount)")
            print("💾 Context has \(modelContext.insertedModelsArray.count) inserted items")
            
            // Force refresh the query
            try? await Task.sleep(for: .milliseconds(100))
            
            loadImports()
            print("📂 Reloaded imports - total files now: \(importedFiles.count)")
            print("📂 Files in memory:")
            for file in importedFiles.prefix(10) {
                print("   - \(file.fileName)")
            }
            
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
        } catch let error as AudioImportError where error == .duplicateFile {
            // All files were duplicates - caught at import service level
            infoMessage = urls.count == 1 
                ? "This file is already imported" 
                : "All \(urls.count) files are already imported"
            showInfo = true
            importProgress = 1.0
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
            print("⚠️ Could not fetch existing files for duplicate check")
            return false
        }
        
        print("🔍 Checking for duplicates: \(file.fileName) (\(file.fileSize) bytes, \(String(format: "%.1f", file.duration))s)")
        print("   Existing files in database: \(allFiles.count)")
        
        // Check for exact match on fileName and fileSize
        // Duration check within 1 second tolerance (for encoding variations)
        for existingFile in allFiles {
            let sameFileName = existingFile.fileName == file.fileName
            let sameFileSize = existingFile.fileSize == file.fileSize
            let similarDuration = abs(existingFile.duration - file.duration) < 1.0
            
            if sameFileName {
                print("   Found file with same name: \(existingFile.fileName)")
                print("     Size match: \(sameFileSize) (\(existingFile.fileSize) vs \(file.fileSize))")
                print("     Duration match: \(similarDuration) (\(String(format: "%.1f", existingFile.duration))s vs \(String(format: "%.1f", file.duration))s)")
            }
            
            if sameFileName && sameFileSize && similarDuration {
                print("   ✅ DUPLICATE DETECTED - skipping")
                return true
            }
        }
        
        print("   ✅ Not a duplicate - will import")
        return false
    }

    func removeImportedFile(_ file: AudioFile) {
        print("🗑️ Deleting file from Import tab: \(file.fileName)")
        
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
        
        // Delete the analysis result JSON from iCloud Drive
        let _ = AnalysisResultPersistence.shared
        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName)
        
        // Delete the SwiftData record
        modelContext.delete(file)
        try? modelContext.save()
        importedFiles.removeAll { $0.id == file.id }
        
        // Notify other views that files were deleted
        print("📢 Posting audioFileDeleted notification from Import tab")
        NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
    }
    
    // MARK: - Orphaned File Recovery
    
    /// Scan iCloud folder for files that exist physically but aren't in the database
    func scanForOrphanedFiles() async {
        print("🔍 Scanning for orphaned files in iCloud...")
        
        let iCloudService = iCloudStorageService.shared
        let audioDirectory = iCloudService.getAudioFilesDirectory()
        
        guard FileManager.default.fileExists(atPath: audioDirectory.path) else {
            print("⚠️ Audio directory doesn't exist")
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
            
            // Get all files currently in database
            let descriptor = FetchDescriptor<AudioFile>()
            let databaseFiles = (try? modelContext.fetch(descriptor)) ?? []
            let databaseFileNames = Set(databaseFiles.map { $0.fileName })
            
            // Find files that exist physically but not in database
            let orphanedURLs = fileURLs.filter { url in
                let fileName = url.lastPathComponent
                let isAudioFile = AppConstants.supportedAudioFormats.contains(url.pathExtension.lowercased())
                return isAudioFile && !databaseFileNames.contains(fileName)
            }
            
            if !orphanedURLs.isEmpty {
                print("📁 Found \(orphanedURLs.count) orphaned file(s):")
                for url in orphanedURLs {
                    print("   - \(url.lastPathComponent)")
                }
                
                // Re-import orphaned files
                await importFiles(orphanedURLs)
            } else {
                print("✅ No orphaned files found")
            }
            
        } catch {
            print("❌ Error scanning for orphaned files: \(error)")
        }
    }
}
