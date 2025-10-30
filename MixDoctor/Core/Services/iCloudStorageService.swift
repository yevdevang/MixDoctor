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
        // Try with nil (uses default container)
        if let url = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = url.appendingPathComponent("Documents")
            print("✅ iCloud container (nil): \(url.path)")
            print("✅ Documents path: \(documentsURL.path)")
            return documentsURL
        }
        
        // Try with explicit container identifier
        if let url = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.yevgenylevin.animated.MixDoctor") {
            let documentsURL = url.appendingPathComponent("Documents")
            print("✅ iCloud container (explicit): \(url.path)")
            print("✅ Documents path: \(documentsURL.path)")
            return documentsURL
        }
        
        print("❌ iCloud container not available")
        print("   • Make sure iCloud Drive is enabled in device Settings")
        print("   • Check that app is properly signed")
        print("   • Verify iCloud capability is enabled in Xcode")
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
        if fileManager.fileExists(atPath: url.path) {
            // For iCloud files, use eviction first
            if url.path.contains("Mobile Documents") {
                try? fileManager.evictUbiquitousItem(at: url)
            }
            try fileManager.removeItem(at: url)
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
            print("Error checking download status: \(error)")
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
            print("Error getting download progress: \(error)")
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
                print("✅ Migrated \(fileName) to iCloud")
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
                print("✅ Migrated \(fileName) to local storage")
            }
        }
    }
}
