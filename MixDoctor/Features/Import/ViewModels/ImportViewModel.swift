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
    var selectedGenre: String?
    var selectedMixStage: String? = "mix"  // Default to "mix"
    var isDeleting = false
    var deletingFile: AudioFile?
    var isDeletingAll = false

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
                if let existingFile = findExistingFile(file) {
                    // Same audio file already exists
                    let stageChanged = (existingFile.mixStage ?? "") != (file.mixStage ?? "")
                    let genreChanged = (existingFile.genre ?? "") != (file.genre ?? "")

                    if stageChanged || genreChanged {
                        // Update the existing file's stage/genre and clear old analysis
                        print("🔄 Updating existing file with new settings:")
                        print("   Existing: \(existingFile.fileName), New: \(file.fileName)")
                        if stageChanged { print("   Stage: \(existingFile.mixStage ?? "nil") → \(file.mixStage ?? "nil")") }
                        if genreChanged { print("   Genre: \(existingFile.genre ?? "nil") → \(file.genre ?? "nil")") }
                        existingFile.mixStage = file.mixStage
                        existingFile.genre = file.genre
                        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: existingFile.fileName, isDemo: existingFile.isDemoFile)
                        existingFile.analysisResult = nil
                        insertedCount += 1  // Count as "imported" since settings changed
                        infoMessage = "Updated \(existingFile.fileName) to \(mixStageLabel(file.mixStage)) stage"
                        showInfo = true
                    } else {
                        duplicateCount += 1
                    }

                    // Remove the physical duplicate file — but ONLY if the new file
                    // has a different filename. If same filename, the import overwrote
                    // the existing physical file and we must NOT delete it.
                    if file.fileName != existingFile.fileName {
                        let fileURL = file.fileURL
                        do {
                            try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                        } catch {
                        }
                    }
                } else {
                    print("📝 Inserting file into database:")
                    print("   Filename: \(file.fileName)")
                    print("   Genre: \(file.genre ?? "nil")")
                    print("   MixStage: \(file.mixStage ?? "nil")")
                    modelContext.insert(file)
                    insertedCount += 1
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
                AnalyticsService.log(.fileImported)
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
    
    /// Find an existing file with the same audio content.
    /// Matches by fileSize + duration (within 1s tolerance) — catches the same audio
    /// imported under different filenames (e.g. "Song - Mix.mp3" vs "Song - Master.mp3").
    /// Returns the existing file regardless of name/genre/stage, or nil if no match.
    private func findExistingFile(_ file: AudioFile) -> AudioFile? {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return nil
        }

        for existingFile in allFiles {
            if existingFile.id == file.id { continue }

            let sameFileSize = existingFile.fileSize == file.fileSize
            let similarDuration = abs(existingFile.duration - file.duration) < 1.0

            if sameFileSize && similarDuration {
                let existingFileURL = existingFile.fileURL
                if !FileManager.default.fileExists(atPath: existingFileURL.path) {
                    modelContext.delete(existingFile)
                    try? modelContext.save()
                    return nil
                }
                return existingFile
            }
        }
        return nil
    }

    private func mixStageLabel(_ stage: String?) -> String {
        switch stage {
        case "master_streaming": return "Master (Streaming)"
        case "master_cd": return "Master (CD)"
        default: return "Mix"
        }
    }

    func removeImportedFile(_ file: AudioFile) {
        // Demo files cannot be deleted
        guard !file.isDemoFile else { return }

        // Show loader
        isDeleting = true
        deletingFile = file
        
        // Capture needed values immediately to avoid accessing file on background thread
        let fileURL = file.fileURL
        let fileName = file.fileName
        let fileID = file.id
        let isDemo = file.isDemoFile

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
            await AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName, isDemo: isDemo)
            
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
                
                AnalyticsService.log(.fileDeleted)

                // CRITICAL: Notify other views AFTER deletion is complete
                NotificationCenter.default.post(name: .audioFileDeleted, object: nil)

                // Hide loader
                self.isDeleting = false
                self.deletingFile = nil
            }
        }
    }

    func deleteAllFiles() {
        // Show loader
        isDeletingAll = true
        isDeleting = true

        Task { @MainActor in
            // Capture only user files — demo files are preserved
            let allFiles = Array(importedFiles.filter { !$0.isDemoFile })
            
            // Delete all files
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
            
            // Clear the imported files array
            importedFiles = []
            
            // Clear selected audio file if it was deleted
            // Note: This will be handled by the view observing importedFiles
            
            // CRITICAL: Notify other views AFTER deletion is complete
            NotificationCenter.default.post(name: .audioFileDeleted, object: nil)
            
            // Hide loader
            isDeleting = false
            isDeletingAll = false
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
            // Use fileURL.lastPathComponent (stored filename with extension) for matching against disk files
            let descriptor = FetchDescriptor<AudioFile>()
            let databaseFiles = (try? modelContext.fetch(descriptor)) ?? []
            let databaseFileNames = Set(databaseFiles.flatMap { file in
                // Include both fileName and on-disk filename to handle demo files
                // (demo files store displayName without extension in fileName)
                [file.fileName, file.fileURL.lastPathComponent]
            })

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
                // Use both fileName and on-disk filename to match demo files correctly
                let descriptor = FetchDescriptor<AudioFile>()
                let existingFiles = (try? modelContext.fetch(descriptor)) ?? []
                let existingFileNames = Set(existingFiles.flatMap { file in
                    [file.fileName, file.fileURL.lastPathComponent]
                })

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
                        if findExistingFile(file) == nil {
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
        
        // Never delete demo file records — their physical files are re-created from bundle
        let deletableOrphans = orphanedRecords.filter { !$0.isDemoFile }
        if !deletableOrphans.isEmpty {
            for record in deletableOrphans {
                AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: record.fileName, isDemo: record.isDemoFile)
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
