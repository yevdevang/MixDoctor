//
//  iCloudStorageService.swift
//  MixDoctor
//
//  Service for managing audio files in iCloud Drive
//

import Foundation

final class iCloudStorageService {
    static let shared = iCloudStorageService()
    
    private let fileManager = FileManager.default
    
    // MARK: - iCloud Container
    
    /// Returns the iCloud ubiquity container URL, or nil if iCloud is not available
    var iCloudContainerURL: URL? {
        // Try with explicit container identifier first (matches entitlements)
        // Primary container: iCloud.MixDoctor
        if let url = fileManager.url(forUbiquityContainerIdentifier: "iCloud.MixDoctor") {
            let documentsURL = url.appendingPathComponent("Documents")
            print("✅ iCloud container found: iCloud.MixDoctor")
            return documentsURL
        }
        
        // Fallback to dev container
        if let url = fileManager.url(forUbiquityContainerIdentifier: "iCloud.dev.yevgenylevin.mixdoctor.MixDoctor") {
            let documentsURL = url.appendingPathComponent("Documents")
            print("✅ iCloud container found: iCloud.dev.yevgenylevin.mixdoctor.MixDoctor")
            return documentsURL
        }
        
        // Last resort: try nil (uses default container)
        if let url = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = url.appendingPathComponent("Documents")
            print("✅ iCloud container found: default container")
            return documentsURL
        }
        
        print("❌ No iCloud container available")
        return nil
    }
    
    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        iCloudContainerURL != nil
    }
    
    /// Returns the appropriate storage directory based on iCloud availability and user preference
    func getAudioFilesDirectory() -> URL {
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        if iCloudEnabled, let iCloudURL = iCloudContainerURL {
            let audioDir = iCloudURL.appendingPathComponent("AudioFiles", isDirectory: true)
            createDirectoryIfNeeded(at: audioDir)
            return audioDir
        } else {
            // Fallback to local Documents directory
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDir = documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
            createDirectoryIfNeeded(at: audioDir)
            return audioDir
        }
    }
    
    // MARK: - Directory Setup
    
    private func createDirectoryIfNeeded(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    // MARK: - File Operations
    
    /// Copy audio file to iCloud Drive or local storage
    func copyAudioFile(from sourceURL: URL) throws -> URL {
        let audioDir = getAudioFilesDirectory()
        let fileName = sourceURL.lastPathComponent
        var destinationURL = audioDir.appendingPathComponent(fileName)
        
        // If file exists, append timestamp to make unique
        if fileManager.fileExists(atPath: destinationURL.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let nameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let uniqueName = "\(nameWithoutExtension)_\(timestamp).\(ext)"
            destinationURL = audioDir.appendingPathComponent(uniqueName)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // If stored in iCloud, start uploading
        if destinationURL.path.contains("Mobile Documents") {
            try? fileManager.startDownloadingUbiquitousItem(at: destinationURL)
        }
        
        return destinationURL
    }
    
    /// Delete audio file from storage
    func deleteAudioFile(at url: URL) throws {
        let fileName = url.lastPathComponent
        
        guard fileManager.fileExists(atPath: url.path) else {
            print("⚠️ File doesn't exist, nothing to delete: \(fileName)")
            return
        }
        
        let isICloudFile = url.path.contains("Mobile Documents")
        
        if isICloudFile {
            print("🗑️ Deleting iCloud file: \(fileName)")
            
            // First evict from local storage
            // This marks the file for deletion from iCloud and removes local copy
            do {
                try fileManager.evictUbiquitousItem(at: url)
                print("✅ Evicted from iCloud: \(fileName)")
            } catch {
                print("⚠️ Eviction warning (file may not be in iCloud): \(error.localizedDescription)")
            }
            
            // Then remove the file
            // On iCloud-enabled devices, this will propagate deletion across all devices
            try fileManager.removeItem(at: url)
            print("✅ Deleted iCloud file: \(fileName)")
            
        } else {
            print("🗑️ Deleting local file: \(fileName)")
            try fileManager.removeItem(at: url)
            print("✅ Deleted local file: \(fileName)")
        }
    }
    
    /// Check if file is downloaded and available locally
    func isFileDownloaded(at url: URL) -> Bool {
        guard url.path.contains("Mobile Documents") else {
            // Local file, always available
            return fileManager.fileExists(atPath: url.path)
        }
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                return status == .current
            }
        } catch {
        }
        
        return false
    }
    
    /// Download file from iCloud if needed
    func ensureFileIsDownloaded(at url: URL) async throws {
        guard url.path.contains("Mobile Documents") else {
            // Local file, nothing to download
            return
        }
        
        if !isFileDownloaded(at: url) {
            try fileManager.startDownloadingUbiquitousItem(at: url)
            
            // Wait for download to complete
            var downloaded = false
            var attempts = 0
            while !downloaded && attempts < 30 { // Max 30 seconds
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                downloaded = isFileDownloaded(at: url)
                attempts += 1
            }
            
            if !downloaded {
                throw NSError(domain: "iCloudStorage", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "File download timeout"
                ])
            }
        }
    }
    
    /// Get download progress for iCloud file
    func getDownloadProgress(for url: URL) -> Double? {
        guard url.path.contains("Mobile Documents") else {
            return nil
        }
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemDownloadRequestedKey,
                .ubiquitousItemIsDownloadingKey
            ])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                if status == .current {
                    return 1.0 // Fully downloaded
                } else if status == .notDownloaded {
                    return 0.0
                } else {
                    return 1.0 // Assume downloaded for other states
                }
            }
        } catch {
        }
        
        return nil
    }
    
    // MARK: - Migration
    
    /// Migrate existing local files to iCloud
    func migrateLocalFilesToICloud() async throws {
        guard let iCloudURL = iCloudContainerURL else {
            throw NSError(domain: "iCloudStorage", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "iCloud not available"
            ])
        }
        
        let localDocumentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localAudioDir = localDocumentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
        
        guard fileManager.fileExists(atPath: localAudioDir.path) else {
            // No local files to migrate
            return
        }
        
        let iCloudAudioDir = iCloudURL.appendingPathComponent("AudioFiles", isDirectory: true)
        createDirectoryIfNeeded(at: iCloudAudioDir)
        
        let localFiles = try fileManager.contentsOfDirectory(
            at: localAudioDir,
            includingPropertiesForKeys: nil
        )
        
        for localFile in localFiles {
            let fileName = localFile.lastPathComponent
            let iCloudFile = iCloudAudioDir.appendingPathComponent(fileName)
            
            // Move file to iCloud
            if !fileManager.fileExists(atPath: iCloudFile.path) {
                try fileManager.moveItem(at: localFile, to: iCloudFile)
            }
        }
    }
    
    /// Migrate iCloud files back to local storage
    func migrateICloudFilesToLocal() async throws {
        guard let iCloudURL = iCloudContainerURL else {
            // No iCloud files to migrate
            return
        }
        
        let iCloudAudioDir = iCloudURL.appendingPathComponent("AudioFiles", isDirectory: true)
        
        guard fileManager.fileExists(atPath: iCloudAudioDir.path) else {
            // No iCloud files to migrate
            return
        }
        
        let localDocumentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localAudioDir = localDocumentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
        createDirectoryIfNeeded(at: localAudioDir)
        
        let iCloudFiles = try fileManager.contentsOfDirectory(
            at: iCloudAudioDir,
            includingPropertiesForKeys: nil
        )
        
        for iCloudFile in iCloudFiles {
            let fileName = iCloudFile.lastPathComponent
            let localFile = localAudioDir.appendingPathComponent(fileName)
            
            // Ensure file is downloaded first
            try await ensureFileIsDownloaded(at: iCloudFile)
            
            // Move file to local storage
            if !fileManager.fileExists(atPath: localFile.path) {
                try fileManager.moveItem(at: iCloudFile, to: localFile)
            }
        }
    }
    
    // MARK: - File Listing and Status
    
    /// Get comprehensive list of all audio files with their status
    func getAllAudioFilesWithStatus() throws -> [(url: URL, isDownloaded: Bool, isICloudFile: Bool, size: Int64?)] {
        var allFiles: [(url: URL, isDownloaded: Bool, isICloudFile: Bool, size: Int64?)] = []
        
        // Check iCloud files
        if let iCloudURL = iCloudContainerURL {
            let iCloudAudioDir = iCloudURL.appendingPathComponent("AudioFiles", isDirectory: true)
            
            if fileManager.fileExists(atPath: iCloudAudioDir.path) {
                let iCloudFiles = try fileManager.contentsOfDirectory(
                    at: iCloudAudioDir,
                    includingPropertiesForKeys: [.fileSizeKey, .ubiquitousItemDownloadingStatusKey],
                    options: [.skipsHiddenFiles]
                )
                
                for file in iCloudFiles {
                    let isDownloaded = isFileDownloaded(at: file)
                    let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    allFiles.append((
                        url: file,
                        isDownloaded: isDownloaded,
                        isICloudFile: true,
                        size: size.map { Int64($0) }
                    ))
                }
            }
        }
        
        // Check local files
        let localDocumentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localAudioDir = localDocumentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
        
        if fileManager.fileExists(atPath: localAudioDir.path) {
            let localFiles = try fileManager.contentsOfDirectory(
                at: localAudioDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            for file in localFiles {
                let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
                allFiles.append((
                    url: file,
                    isDownloaded: true,
                    isICloudFile: false,
                    size: size.map { Int64($0) }
                ))
            }
        }
        
        return allFiles
    }
    
    /// Download all iCloud files to ensure they're available locally
    func downloadAllICloudFiles() async throws -> (downloaded: Int, alreadyLocal: Int, failed: Int) {
        var downloaded = 0
        var alreadyLocal = 0
        var failed = 0
        
        let allFiles = try getAllAudioFilesWithStatus()
        let iCloudFiles = allFiles.filter { $0.isICloudFile }
        
        
        for fileInfo in iCloudFiles {
            if fileInfo.isDownloaded {
                alreadyLocal += 1
            } else {
                do {
                    try await ensureFileIsDownloaded(at: fileInfo.url)
                    downloaded += 1
                } catch {
                    failed += 1
                }
            }
        }
        
        return (downloaded: downloaded, alreadyLocal: alreadyLocal, failed: failed)
    }
    
    /// Print comprehensive status of all files
    func printFileStatus() {
        
        // Check iCloud availability
        if let iCloudURL = iCloudContainerURL {
        } else {
        }
        
        // Get all files
        do {
            let allFiles = try getAllAudioFilesWithStatus()
            
            
            let iCloudFiles = allFiles.filter { $0.isICloudFile }
            let localFiles = allFiles.filter { !$0.isICloudFile }
            let downloadedICloudFiles = iCloudFiles.filter { $0.isDownloaded }
            let notDownloadedICloudFiles = iCloudFiles.filter { !$0.isDownloaded }
            
            
            // List all files with details
            
            if !iCloudFiles.isEmpty {
                for (index, file) in iCloudFiles.enumerated() {
                    let status = file.isDownloaded ? "✅ Downloaded" : "⏳ Not Downloaded"
                    let sizeStr = file.size.map { formatFileSize($0) } ?? "Unknown size"
                }
            }
            
            if !localFiles.isEmpty {
                for (index, file) in localFiles.enumerated() {
                    let sizeStr = file.size.map { formatFileSize($0) } ?? "Unknown size"
                }
            }
            
            if allFiles.isEmpty {
            }
            
        } catch {
        }
        
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
