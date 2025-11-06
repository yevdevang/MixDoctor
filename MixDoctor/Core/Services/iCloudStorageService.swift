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
        
        print("📥 Starting download of \(iCloudFiles.count) iCloud files...")
        
        for fileInfo in iCloudFiles {
            if fileInfo.isDownloaded {
                alreadyLocal += 1
                print("✅ Already downloaded: \(fileInfo.url.lastPathComponent)")
            } else {
                do {
                    print("⬇️ Downloading: \(fileInfo.url.lastPathComponent)")
                    try await ensureFileIsDownloaded(at: fileInfo.url)
                    downloaded += 1
                    print("✅ Downloaded: \(fileInfo.url.lastPathComponent)")
                } catch {
                    failed += 1
                    print("❌ Failed to download: \(fileInfo.url.lastPathComponent) - \(error)")
                }
            }
        }
        
        print("📥 Download complete: \(downloaded) downloaded, \(alreadyLocal) already local, \(failed) failed")
        return (downloaded: downloaded, alreadyLocal: alreadyLocal, failed: failed)
    }
    
    /// Print comprehensive status of all files
    func printFileStatus() {
        print("\n🔍 COMPREHENSIVE FILE STATUS CHECK")
        print("================================")
        
        // Check iCloud availability
        print("☁️ iCloud Status:")
        if let iCloudURL = iCloudContainerURL {
            print("   ✅ iCloud available at: \(iCloudURL.path)")
        } else {
            print("   ❌ iCloud not available")
        }
        
        // Get all files
        do {
            let allFiles = try getAllAudioFilesWithStatus()
            
            print("\n📊 File Summary:")
            print("   Total files: \(allFiles.count)")
            
            let iCloudFiles = allFiles.filter { $0.isICloudFile }
            let localFiles = allFiles.filter { !$0.isICloudFile }
            let downloadedICloudFiles = iCloudFiles.filter { $0.isDownloaded }
            let notDownloadedICloudFiles = iCloudFiles.filter { !$0.isDownloaded }
            
            print("   iCloud files: \(iCloudFiles.count)")
            print("   - Downloaded: \(downloadedICloudFiles.count)")
            print("   - Not downloaded: \(notDownloadedICloudFiles.count)")
            print("   Local files: \(localFiles.count)")
            
            // List all files with details
            print("\n📁 Detailed File List:")
            
            if !iCloudFiles.isEmpty {
                print("\n☁️ iCloud Files:")
                for (index, file) in iCloudFiles.enumerated() {
                    let status = file.isDownloaded ? "✅ Downloaded" : "⏳ Not Downloaded"
                    let sizeStr = file.size.map { formatFileSize($0) } ?? "Unknown size"
                    print("   \(index + 1). \(file.url.lastPathComponent)")
                    print("      Status: \(status)")
                    print("      Size: \(sizeStr)")
                    print("      Path: \(file.url.path)")
                }
            }
            
            if !localFiles.isEmpty {
                print("\n💾 Local Files:")
                for (index, file) in localFiles.enumerated() {
                    let sizeStr = file.size.map { formatFileSize($0) } ?? "Unknown size"
                    print("   \(index + 1). \(file.url.lastPathComponent)")
                    print("      Size: \(sizeStr)")
                    print("      Path: \(file.url.path)")
                }
            }
            
            if allFiles.isEmpty {
                print("   No audio files found in storage")
            }
            
        } catch {
            print("❌ Error checking files: \(error)")
        }
        
        print("================================\n")
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
