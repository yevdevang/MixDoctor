//
//  FileManagementService.swift
//  MixDoctor
//
//  Service for managing audio files on disk
//

import Foundation

final class FileManagementService {
    static let shared = FileManagementService()
    
    private let fileManager = FileManager.default
    
    // MARK: - Directory URLs
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var audioFilesDirectory: URL {
        documentsDirectory.appendingPathComponent("AudioFiles", isDirectory: true)
    }
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    
    private var backupDirectory: URL {
        documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
    }
    
    private init() {
        setupDirectories()
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        let directories = [audioFilesDirectory, backupDirectory]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }
    }
    
    // MARK: - File Operations
    
    func copyAudioFile(from sourceURL: URL) throws -> URL {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = audioFilesDirectory.appendingPathComponent(fileName)
        
        // If file exists, append timestamp to make unique
        var finalURL = destinationURL
        if fileManager.fileExists(atPath: destinationURL.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let nameWithoutExtension = fileName.deletingPathExtension
            let ext = fileName.pathExtension
            let uniqueName = "\(nameWithoutExtension)_\(timestamp).\(ext)"
            finalURL = audioFilesDirectory.appendingPathComponent(uniqueName)
        }
        
        try fileManager.copyItem(at: sourceURL, to: finalURL)
        return finalURL
    }
    
    func deleteAudioFile(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func deleteAudioFiles(at urls: [URL]) throws {
        for url in urls {
            try deleteAudioFile(at: url)
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    // MARK: - Storage Management
    
    func calculateStorageUsage() throws -> StorageInfo {
        let audioFiles = try fileManager.contentsOfDirectory(
            at: audioFilesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        )
        
        var totalSize: Int64 = 0
        var oldestFileDate: Date?
        var newestFileDate: Date?
        
        for fileURL in audioFiles {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? Int64 {
                totalSize += size
            }
            
            if let creationDate = attributes[.creationDate] as? Date {
                if oldestFileDate == nil || creationDate < oldestFileDate! {
                    oldestFileDate = creationDate
                }
                if newestFileDate == nil || creationDate > newestFileDate! {
                    newestFileDate = creationDate
                }
            }
        }
        
        let cacheSize = try calculateCacheSize()
        let availableSpace = try getAvailableSpace()
        
        return StorageInfo(
            audioFilesSize: totalSize,
            cacheSize: cacheSize,
            totalUsed: totalSize + cacheSize,
            availableSpace: availableSpace,
            numberOfFiles: audioFiles.count,
            oldestFileDate: oldestFileDate,
            newestFileDate: newestFileDate
        )
    }
    
    private func calculateCacheSize() throws -> Int64 {
        let cacheContents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        
        var totalSize: Int64 = 0
        for fileURL in cacheContents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    private func getAvailableSpace() throws -> Int64 {
        let systemAttributes = try fileManager.attributesOfFileSystem(
            forPath: documentsDirectory.path
        )
        return systemAttributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    // MARK: - Cleanup
    
    func clearCache() throws {
        let cacheContents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )
        
        for fileURL in cacheContents {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    func deleteOldFiles(olderThan days: Int) throws -> Int {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        )!
        
        let audioFiles = try fileManager.contentsOfDirectory(
            at: audioFilesDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        )
        
        var deletedCount = 0
        
        for fileURL in audioFiles {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try fileManager.removeItem(at: fileURL)
                deletedCount += 1
            }
        }
        
        return deletedCount
    }
    
    func deleteFilesExceedingQuota(maxSizeGB: Int64) throws -> Int {
        let maxSizeBytes = maxSizeGB * 1024 * 1024 * 1024
        let currentSize = try calculateStorageUsage().audioFilesSize
        
        guard currentSize > maxSizeBytes else { return 0 }
        
        // Get files sorted by creation date (oldest first)
        let audioFiles = try fileManager.contentsOfDirectory(
            at: audioFilesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ).sorted { url1, url2 in
            let date1 = try? fileManager.attributesOfItem(atPath: url1.path)[.creationDate] as? Date
            let date2 = try? fileManager.attributesOfItem(atPath: url2.path)[.creationDate] as? Date
            return (date1 ?? Date.distantPast) < (date2 ?? Date.distantPast)
        }
        
        var totalSize = currentSize
        var deletedCount = 0
        
        for fileURL in audioFiles {
            guard totalSize > maxSizeBytes else { break }
            
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            try fileManager.removeItem(at: fileURL)
            totalSize -= fileSize
            deletedCount += 1
        }
        
        return deletedCount
    }
    
    // MARK: - Backup & Restore
    
    func createBackup() throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupName = "Backup_\(timestamp)"
        let backupURL = backupDirectory.appendingPathComponent(backupName, isDirectory: true)
        
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        
        // Copy audio files
        let audioBackupURL = backupURL.appendingPathComponent("AudioFiles", isDirectory: true)
        try fileManager.copyItem(at: audioFilesDirectory, to: audioBackupURL)
        
        // Copy SwiftData database
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if let dbURL = try? fileManager.contentsOfDirectory(
            at: appSupportURL,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension == "sqlite" }) {
            let dbBackupURL = backupURL.appendingPathComponent(dbURL.lastPathComponent)
            try fileManager.copyItem(at: dbURL, to: dbBackupURL)
        }
        
        return backupURL
    }
    
    func listBackups() throws -> [BackupInfo] {
        let backupURLs = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        )
        
        return try backupURLs.compactMap { url in
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let creationDate = attributes[.creationDate] as? Date else {
                return nil
            }
            
            let size = try calculateDirectorySize(at: url)
            
            return BackupInfo(
                name: url.lastPathComponent,
                url: url,
                creationDate: creationDate,
                size: size
            )
        }.sorted { $0.creationDate > $1.creationDate }
    }
    
    func deleteBackup(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    func deleteOldBackups(keepingLast count: Int) throws {
        let backups = try listBackups()
        let backupsToDelete = Array(backups.dropFirst(count))
        
        for backup in backupsToDelete {
            try deleteBackup(at: backup.url)
        }
    }
    
    private func calculateDirectorySize(at url: URL) throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )
        
        var totalSize: Int64 = 0
        for fileURL in contents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
}

// MARK: - Supporting Types

struct StorageInfo {
    let audioFilesSize: Int64
    let cacheSize: Int64
    let totalUsed: Int64
    let availableSpace: Int64
    let numberOfFiles: Int
    let oldestFileDate: Date?
    let newestFileDate: Date?
    
    var formattedAudioFilesSize: String {
        ByteCountFormatter.string(fromByteCount: audioFilesSize, countStyle: .file)
    }
    
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
    
    var formattedTotalUsed: String {
        ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file)
    }
    
    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }
    
    var usagePercentage: Double {
        guard availableSpace > 0 else { return 0 }
        let total = Double(totalUsed + availableSpace)
        return (Double(totalUsed) / total) * 100
    }
}

struct BackupInfo {
    let name: String
    let url: URL
    let creationDate: Date
    let size: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}

// MARK: - String Extension

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
    
    var pathExtension: String {
        (self as NSString).pathExtension
    }
}
