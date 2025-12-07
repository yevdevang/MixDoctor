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

        print("🎯 ImportViewModel.importFiles: Starting import of \(urls.count) files")
        for (index, url) in urls.enumerated() {
            print("   File \(index + 1): \(url.lastPathComponent)")
        }
        
        isImporting = true
        importProgress = 0
        errorMessage = nil
        showError = false
        infoMessage = nil
        showInfo = false
        defer { isImporting = false }

        do {
            print("📞 ImportViewModel: Calling importService.importMultipleFiles")
            // Pass modelContext to importService so it can check for duplicates BEFORE copying to iCloud
            let files = try await importService.importMultipleFiles(urls, modelContext: modelContext)
            print("📦 ImportViewModel: Received \(files.count) files from importService")
            
            
            // Check for duplicates before inserting
            var duplicateCount = 0
            var insertedCount = 0
            
            print("🔄 ImportViewModel: Checking \(files.count) files for duplicates before insertion")
            for file in files {
                print("   Checking file: \(file.fileName)")
                if !isDuplicate(file) {
                    print("   ✅ Not duplicate, inserting: \(file.fileName)")
                    modelContext.insert(file)
                    insertedCount += 1
                } else {
                    print("   ❌ DUPLICATE detected in ViewModel: \(file.fileName)")
                    duplicateCount += 1
                    
                    // Remove the physical file since it's a duplicate
                    let fileURL = file.fileURL
                    do {
                        try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                    } catch {
                        print("⚠️ Failed to delete duplicate file: \(error.localizedDescription)")
                    }
                }
            }

            try modelContext.save()
            
            // Force refresh the query
            try? await Task.sleep(for: .milliseconds(100))
            
            loadImports()
            for file in importedFiles.prefix(10) {
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
    /// Also verifies that the existing file physically exists before treating as duplicate
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
            
            if sameFileName {
            }
            
            if sameFileName && sameFileSize && similarDuration {
                // Before treating as duplicate, verify the existing file actually exists
                let existingFileURL = existingFile.fileURL
                let fileExists = FileManager.default.fileExists(atPath: existingFileURL.path)
                
                if !fileExists {
                    // File record exists but file is missing - remove the stale record
                    modelContext.delete(existingFile)
                    try? modelContext.save()
                    return false // Not a duplicate since existing file is gone
                }
                
                return true // It's a real duplicate
            }
        }
        
        return false
    }

    func removeImportedFile(_ file: AudioFile) {
        
        // Delete the actual audio file from storage (iCloud or local)
        // Using iCloudStorageService ensures proper eviction and cross-device sync
        let fileURL = file.fileURL
        do {
            try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
            print("🗑️ Deleted file: \(file.fileName)")
        } catch {
            print("❌ Failed to delete file \(file.fileName): \(error.localizedDescription)")
        }
        
        // Delete the analysis result JSON from iCloud Drive
        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName)
        
        // Delete the SwiftData record (CloudKit will sync this deletion)
        modelContext.delete(file)
        try? modelContext.save()
        importedFiles.removeAll { $0.id == file.id }
        
        // Notify other views that files were deleted
        NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
    }
    
    // MARK: - Orphaned File Recovery
    
    /// Scan iCloud folder for files that exist physically but aren't in the database
    func scanForOrphanedFiles() async {
        
        let iCloudService = iCloudStorageService.shared
        let audioDirectory = iCloudService.getAudioFilesDirectory()
        
        guard FileManager.default.fileExists(atPath: audioDirectory.path) else {
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
                for url in orphanedURLs {
                }
                
                // Re-import orphaned files
                await importFiles(orphanedURLs)
            } else {
            }
            
        } catch {
        }
    }
    
    /// Remove database records for files that no longer exist (deleted on other devices)
    func cleanupOrphanedRecords() async {
        print("🗑️ ImportViewModel: Cleaning up orphaned records")
        
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return
        }
        
        var orphanedRecords: [AudioFile] = []
        
        for file in allFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            if !fileExists {
                // Check if file is truly gone or just not downloaded from iCloud
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isUbiquitousItemKey,
                        .ubiquitousItemIsUploadedKey
                    ])
                    
                    let isICloud = values.isUbiquitousItem ?? false
                    let isUploaded = values.ubiquitousItemIsUploaded ?? false
                    
                    // If not in iCloud or not uploaded, it's orphaned
                    if !isICloud || !isUploaded {
                        print("   👻 Orphaned: \(file.fileName)")
                        orphanedRecords.append(file)
                    }
                } catch {
                    // Error checking means file is gone
                    print("   👻 Orphaned (error): \(file.fileName)")
                    orphanedRecords.append(file)
                }
            }
        }
        
        if !orphanedRecords.isEmpty {
            print("   Removing \(orphanedRecords.count) orphaned record(s)")
            for record in orphanedRecords {
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName)
                modelContext.delete(record)
                importedFiles.removeAll { $0.id == record.id }
            }
            
            do {
                try modelContext.save()
                print("   ✅ Cleanup complete")
                loadImports() // Refresh the list
            } catch {
                print("   ❌ Failed to save: \(error.localizedDescription)")
            }
        } else {
            print("   ✅ No orphaned records found")
        }
    }
}
