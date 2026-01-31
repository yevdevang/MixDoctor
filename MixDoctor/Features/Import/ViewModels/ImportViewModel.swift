import Foundation
import Observation
import SwiftData
import FirebaseAnalytics

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
    var selectedGenre: String?
    var selectedMixStage: String? = "mix"  // Default to "mix"

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

    func importFiles(_ urls: [URL], genre: String? = nil, mixStage: String? = nil) async {
        guard !urls.isEmpty else { return }

        for (index, url) in urls.enumerated() {
        }
        
        isImporting = true
        importProgress = 0
        errorMessage = nil
        showError = false
        infoMessage = nil
        showInfo = false
        defer { isImporting = false }

        do {
            // Get the final genre and mixStage that will be used
            let finalGenre = genre ?? selectedGenre
            let finalMixStage = mixStage ?? selectedMixStage
            
            print("📋 ImportViewModel.importFiles - Final params:")
            print("   Genre: \(finalGenre ?? "nil")")
            print("   Mix Stage: \(finalMixStage ?? "nil")")
            
            // Pass modelContext, genre, and mixStage to importService
            let files = try await importService.importMultipleFiles(
                urls,
                modelContext: modelContext,
                genre: finalGenre,
                mixStage: finalMixStage
            )
            
            
            // Check for duplicates before inserting
            var duplicateCount = 0
            var insertedCount = 0
            
            for file in files {
                if !isDuplicate(file) {
                    print("📝 Inserting file into database:")
                    print("   Filename: \(file.fileName)")
                    print("   Genre: \(file.genre ?? "nil")")
                    print("   MixStage: \(file.mixStage ?? "nil")")
                    modelContext.insert(file)
                    insertedCount += 1
                } else {
                    duplicateCount += 1
                    
                    // Remove the physical file since it's a duplicate
                    let fileURL = file.fileURL
                    do {
                        try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                    } catch {
                    }
                }
            }

            try modelContext.save()
            print("✅ ModelContext saved successfully")
            
            // Force refresh the query
            try? await Task.sleep(for: .milliseconds(100))
            
            loadImports()
            print("📋 After loadImports(), checking first few files:")
            for file in importedFiles.prefix(10) {
                print("   \(file.fileName): genre=\(file.genre ?? "nil"), stage=\(file.mixStage ?? "nil")")
            }
            
            importProgress = 1.0
            
            // Log file imported event for each successfully imported file
            if insertedCount > 0 {
                Analytics.logEvent("file_imported", parameters: nil)
            }
            
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
        } catch let error as AudioImportError where error == .iCloudDownloadFailed {
            // File not downloaded from iCloud
            errorMessage = error.errorDescription
            showError = true
            importProgress = 0
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
    
    /// Check if a file is a duplicate based on fileName, fileSize, duration, genre, and mixStage
    /// Also verifies that the existing file physically exists before treating as duplicate
    /// Allows same file with different genre/stage combinations
    private func isDuplicate(_ file: AudioFile) -> Bool {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return false
        }
        
        
        // Check for exact match on fileName, fileSize, duration, genre, AND mixStage
        // Duration check within 1 second tolerance (for encoding variations)
        for existingFile in allFiles {
            // Skip comparing the file to itself (same object ID)
            if existingFile.id == file.id {
                continue
            }
            
            let sameFileName = existingFile.fileName == file.fileName
            let sameFileSize = existingFile.fileSize == file.fileSize
            let similarDuration = abs(existingFile.duration - file.duration) < 1.0
            let sameGenre = (existingFile.genre ?? "") == (file.genre ?? "")
            let sameStage = (existingFile.mixStage ?? "") == (file.mixStage ?? "")
            
            // Only consider duplicate if ALL match: file, genre, AND stage
            if sameFileName && sameFileSize && similarDuration && sameGenre && sameStage {
                // Before treating as duplicate, verify the existing file actually exists
                let existingFileURL = existingFile.fileURL
                let fileExists = FileManager.default.fileExists(atPath: existingFileURL.path)
                
                
                if !fileExists {
                    // File record exists but file is missing - remove the stale record
                    modelContext.delete(existingFile)
                    try? modelContext.save()
                    return false // Not a duplicate since existing file is gone
                }
                
                return true // It's a real duplicate (same file, genre, AND stage)
            }
        }
        
        return false
    }

    func removeImportedFile(_ file: AudioFile) {
        // Capture needed values immediately to avoid accessing file on background thread
        let fileURL = file.fileURL
        let fileName = file.fileName
        let fileID = file.id
        
        // Do ALL operations in background to prevent any UI blocking
        Task.detached(priority: .userInitiated) {
            // Small delay to let current UI operation finish
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            // Update UI array on main thread
            await MainActor.run {
                if let index = self.importedFiles.firstIndex(where: { $0.id == fileID }) {
                    self.importedFiles.remove(at: index)
                }
            }
            
            // Delete the actual audio file from storage (iCloud or local)
            do {
                try await iCloudStorageService.shared.deleteAudioFile(at: fileURL)
            } catch {
            }
            
            // Delete the analysis result JSON from iCloud Drive
            await AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName)
            
            // Delete from SwiftData on main thread
            await MainActor.run {
                // Re-fetch the file to ensure we have the right context
                let descriptor = FetchDescriptor<AudioFile>(
                    predicate: #Predicate<AudioFile> { $0.id == fileID }
                )
                
                if let fileToDelete = try? self.modelContext.fetch(descriptor).first {
                    self.modelContext.delete(fileToDelete)
                    
                    do {
                        try self.modelContext.save()
                    } catch {
                    }
                }
                
                // CRITICAL: Notify other views AFTER deletion is complete
                NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
            }
        }
    }
    
    // MARK: - Orphaned File Recovery
    
    /// Scan iCloud folder for files that exist physically but aren't in the database
    /// This runs silently in the background and doesn't show error dialogs
    func scanForOrphanedFiles() async {
        let iCloudService = iCloudStorageService.shared
        let audioDirectory = iCloudService.getAudioFilesDirectory()
        
        guard FileManager.default.fileExists(atPath: audioDirectory.path) else {
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .nameKey,
                    .isUbiquitousItemKey,
                    .ubiquitousItemDownloadingStatusKey
                ],
                options: [.skipsHiddenFiles]
            )
            
            // Get all files currently in database
            let descriptor = FetchDescriptor<AudioFile>()
            let databaseFiles = (try? modelContext.fetch(descriptor)) ?? []
            let databaseFileNames = Set(databaseFiles.map { $0.fileName })
            
            // Find files that exist physically but not in database
            // Filter out files that aren't downloaded from iCloud
            let orphanedURLs = fileURLs.filter { url in
                let fileName = url.lastPathComponent
                let isAudioFile = AppConstants.supportedAudioFormats.contains(url.pathExtension.lowercased())
                
                // Skip if not an audio file or already in database
                guard isAudioFile && !databaseFileNames.contains(fileName) else {
                    return false
                }
                
                // Check if file is downloaded from iCloud (if it's an iCloud file)
                do {
                    let resourceValues = try url.resourceValues(forKeys: [
                        .isUbiquitousItemKey,
                        .ubiquitousItemDownloadingStatusKey
                    ])
                    
                    let isUbiquitousItem = resourceValues.isUbiquitousItem ?? false
                    
                    // If it's an iCloud file, check if it's downloaded
                    if isUbiquitousItem {
                        if let status = resourceValues.ubiquitousItemDownloadingStatus {
                            // Only include files that are fully downloaded
                            return status == .current
                        }
                        // Can't determine status - skip to avoid errors
                        return false
                    }
                    
                    // Not an iCloud file - check if it exists locally
                    return FileManager.default.fileExists(atPath: url.path)
                } catch {
                    // Error checking - skip this file to avoid import errors
                    return false
                }
            }
            
            if !orphanedURLs.isEmpty {
                print("📁 Found \(orphanedURLs.count) orphaned file(s) - checking if they need import")
                
                // Get all existing files from database
                let descriptor = FetchDescriptor<AudioFile>()
                let existingFiles = (try? modelContext.fetch(descriptor)) ?? []
                let existingFileNames = Set(existingFiles.map { $0.fileName })
                
                // Only import files that DON'T already have a database record
                let filesToImport = orphanedURLs.filter { url in
                    let fileName = url.lastPathComponent
                    let alreadyExists = existingFileNames.contains(fileName)
                    if alreadyExists {
                        print("   ⏭️ Skipping \(fileName) - already in database")
                    }
                    return !alreadyExists
                }
                
                if filesToImport.isEmpty {
                    print("   ✅ All orphaned files already have database records")
                    return
                }
                
                print("   📥 Importing \(filesToImport.count) truly orphaned file(s)")
                
                // Re-import orphaned files (silently - don't show errors for background scanning)
                // Use a separate method that doesn't trigger error dialogs
                do {
                    let importedFiles = try await importService.importMultipleFiles(filesToImport, modelContext: modelContext)
                    
                    // Insert imported files into database
                    for file in importedFiles {
                        // Check for duplicates before inserting
                        if !isDuplicate(file) {
                            modelContext.insert(file)
                        } else {
                            // Remove duplicate file
                            try? iCloudStorageService.shared.deleteAudioFile(at: file.fileURL)
                        }
                    }
                    
                    try? modelContext.save()
                    
                    // Refresh the list after importing
                    await MainActor.run {
                        loadImports()
                    }
                } catch let error as AudioImportError where error == .iCloudDownloadFailed {
                    // Silently ignore iCloud download errors during background scanning
                    // These files will be imported when user manually downloads them
                } catch {
                    // Silently ignore other errors during background scanning
                    // Errors will be shown when user manually imports files
                }
            }
            
        } catch {
            // Silently ignore errors during background scanning
        }
    }
    
    /// Extract genre and stage from filename for legacy files
    /// Expected filename patterns:
    /// - "Song Name - Pop - Mix.wav"
    /// - "Song Name - Rock/Indie - Master(Streaming).wav"
    func updateMetadataFromFilename(_ file: AudioFile) -> Bool {
        var updated = false
        let fileNameWithoutExtension = (file.fileName as NSString).deletingPathExtension
        let components = fileNameWithoutExtension.components(separatedBy: " - ")
        
        // Pattern: "Song Name - Genre - Stage"
        if components.count >= 3 {
            let potentialGenre = components[components.count - 2].trimmingCharacters(in: .whitespaces)
            let potentialStage = components[components.count - 1].trimmingCharacters(in: .whitespaces)
            
            // Extract and set genre if missing
            if file.genre == nil, AppConstants.availableGenres.contains(potentialGenre) {
                file.genre = potentialGenre
                print("📝 Updated genre from filename: \(potentialGenre) for \(file.fileName)")
                updated = true
            }
            
            // Extract and set stage if missing
            if file.mixStage == nil {
                let extractedStage = extractMixStageFromString(potentialStage)
                if extractedStage != "mix" || potentialStage.lowercased().contains("mix") {
                    file.mixStage = extractedStage
                    print("📝 Updated stage from filename: \(extractedStage) for \(file.fileName)")
                    updated = true
                }
            }
        }
        // Pattern: "Song Name - Stage" (no genre in filename)
        else if components.count == 2 {
            let potentialStage = components[1].trimmingCharacters(in: .whitespaces)
            
            // Extract and set stage if missing
            if file.mixStage == nil {
                let extractedStage = extractMixStageFromString(potentialStage)
                if extractedStage != "mix" || potentialStage.lowercased().contains("mix") {
                    file.mixStage = extractedStage
                    print("📝 Updated stage from filename: \(extractedStage) for \(file.fileName)")
                    updated = true
                }
            }
        }
        
        return updated
    }
    
    /// Extract mix stage from string (suffix of filename component)
    private func extractMixStageFromString(_ string: String) -> String {
        let lower = string.lowercased()
        
        // Check for exact matches first
        if lower == "mix" {
            return "mix"
        }
        if lower == "master(streaming)" || lower == "master (streaming)" {
            return "master_streaming"
        }
        if lower == "master(cd-loud)" || lower == "master (cd-loud)" || lower == "master(cd)" || lower == "master (cd)" {
            return "master_cd"
        }
        
        // Check for partial matches
        if lower.contains("streaming") {
            return "master_streaming"
        }
        if lower.contains("cd") || lower.contains("loud") {
            return "master_cd"
        }
        if lower.contains("master") {
            return "master_streaming"  // Default master type
        }
        
        // Default to mix
        return "mix"
    }
    
    /// Update metadata from filenames for all files missing genre or stage
    func updateAllFilesMetadataFromFilenames() async {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return
        }
        
        var updatedCount = 0
        for file in allFiles {
            // Only update files that are missing genre or stage
            if file.genre == nil || file.mixStage == nil {
                if updateMetadataFromFilename(file) {
                    updatedCount += 1
                }
            }
        }
        
        if updatedCount > 0 {
            do {
                try modelContext.save()
                print("✅ Updated metadata for \(updatedCount) file(s) from filenames")
                
                // Refresh the list
                await MainActor.run {
                    loadImports()
                }
            } catch {
                print("❌ Failed to save metadata updates: \(error)")
            }
        }
    }
    
    /// Remove database records for files that no longer exist (deleted on other devices)
    func cleanupOrphanedRecords() async {
        
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
                        orphanedRecords.append(file)
                    }
                } catch {
                    // Error checking means file is gone
                    orphanedRecords.append(file)
                }
            }
        }
        
        if !orphanedRecords.isEmpty {
            for record in orphanedRecords {
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName)
                modelContext.delete(record)
                importedFiles.removeAll { $0.id == record.id }
            }
            
            do {
                try modelContext.save()
                loadImports() // Refresh the list
            } catch {
            }
        } else {
        }
    }
}
