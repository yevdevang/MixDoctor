//
//  iCloudSyncMonitor.swift
//  MixDoctor
//
//  Monitors iCloud file changes and ensures files are downloaded
//

import Foundation
import Combine

@MainActor
final class iCloudSyncMonitor: ObservableObject {
    static let shared = iCloudSyncMonitor()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    
    private var metadataQuery: NSMetadataQuery?
    private let iCloudService = iCloudStorageService.shared
    
    private init() {}
    
    // MARK: - Start/Stop Monitoring
    
    func startMonitoring() {
        guard iCloudService.isICloudAvailable else {
            print("❌ iCloudSyncMonitor: iCloud not available")
            return
        }
        
        #if targetEnvironment(macCatalyst)
        print("🖥️ iCloudSyncMonitor: Starting on MacCatalyst")
        #else
        print("📱 iCloudSyncMonitor: Starting on iOS")
        #endif
        
        let directory = iCloudService.getAudioFilesDirectory()
        print("✅ iCloudSyncMonitor: Monitoring directory: \(directory.path)")
        
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K BEGINSWITH %@", 
                                      NSMetadataItemPathKey, 
                                      directory.path)
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        
        // Listen for ubiquity identity changes (iCloud account changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquityIdentityDidChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
        
        query.start()
        metadataQuery = query
        
        print("✅ iCloudSyncMonitor: Query started")
        
        // On MacCatalyst, immediately trigger a manual check as NSMetadataQuery can be slower
        #if targetEnvironment(macCatalyst)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await checkDirectoryForFiles()
            
            // Also schedule periodic checks for Mac Catalyst since NSMetadataQuery is less reliable
            Task.detached { [weak self] in
                while true {
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // Check every 10 seconds
                    await self?.checkDirectoryForFiles()
                }
            }
        }
        #endif
    }
    
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Query Notifications
    
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        
        query.disableUpdates()
        
        print("📊 NSMetadataQuery finished gathering")
        print("📊 Found \(query.resultCount) items")
        
        // Download any files that aren't downloaded yet
        Task {
            await downloadPendingFiles(from: query)
        }
        
        query.enableUpdates()
    }
    
    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        
        query.disableUpdates()
        
        print("🔔 iCloud files changed - triggering orphan cleanup")
        
        // Post notification that iCloud changed so views can cleanup orphaned records
        NotificationCenter.default.post(name: .iCloudFilesChanged, object: nil)
        
        // Check for new files that need downloading
        Task {
            await downloadPendingFiles(from: query)
        }
        
        query.enableUpdates()
    }
    
    @objc private func ubiquityIdentityDidChange(_ notification: Notification) {
        print("⚠️ iCloud identity changed - may need to re-sync")
        
        // Post notification so views can handle the change
        NotificationCenter.default.post(name: .iCloudFilesChanged, object: nil)
    }
    
    // MARK: - File Download
    
    private func downloadPendingFiles(from query: NSMetadataQuery) async {
        let results = query.results as? [NSMetadataItem] ?? []
        var filesToDownload: [URL] = []
        
        print("📥 downloadPendingFiles: Processing \(results.count) metadata items")
        
        for item in results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }
            
            let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "unknown"
            
            // Check download status
            let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            
            print("📄 File: \(fileName)")
            print("   URL: \(url.path)")
            print("   Download status: \(downloadStatus ?? "unknown")")
            
            if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                print("   ⬇️ Needs download - adding to queue")
                filesToDownload.append(url)
            } else {
                print("   ✅ Already downloaded or downloading")
            }
        }
        
        print("📥 Total files to download: \(filesToDownload.count)")
        
        guard !filesToDownload.isEmpty else {
            isSyncing = false
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        
        for (index, url) in filesToDownload.enumerated() {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                
                // Wait for download to complete
                await waitForDownload(url: url)
                
                syncProgress = Double(index + 1) / Double(filesToDownload.count)
            } catch {
            }
        }
        
        isSyncing = false
        syncProgress = 1.0
        
    }
    
    private func waitForDownload(url: URL, maxAttempts: Int = 30) async {
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, files download much faster, reduce wait time
        let pollInterval: UInt64 = 200_000_000 // 0.2 seconds
        let attempts = 15 // 3 seconds max
        #else
        let pollInterval: UInt64 = 1_000_000_000 // 1 second
        let attempts = maxAttempts
        #endif
        
        for _ in 0..<attempts {
            do {
                let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let status = values.ubiquitousItemDownloadingStatus
                
                if status == .current {
                    return
                }
            } catch {
            }
            
            // Wait before checking again
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }
    
    // MARK: - Manual Sync
    
    func syncNow() async {
        
        // First try direct file check (more reliable in simulator)
        await checkDirectoryForFiles()
        
        // Then use query if available
        if let query = metadataQuery {
            await downloadPendingFiles(from: query)
        } else {
        }
    }
    
    // MARK: - Direct File Check
    
    private func checkDirectoryForFiles() async {
        let directory = iCloudService.getAudioFilesDirectory()
        
        print("🔍 iCloudSyncMonitor: Checking directory for files...")
        print("📂 Directory path: \(directory.path)")
        
        do {
            // List all files in directory
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey, .nameKey, .isUbiquitousItemKey],
                options: [.skipsHiddenFiles]
            )
            
            print("📊 Found \(files.count) files in directory")
            
            guard !files.isEmpty else {
                print("📂 No files to sync")
                return
            }
            
            isSyncing = true
            syncProgress = 0.0
            
            for (index, fileURL) in files.enumerated() {
                let fileName = fileURL.lastPathComponent
                
                // Check if file needs downloading
                if let values = try? fileURL.resourceValues(forKeys: [
                    URLResourceKey.ubiquitousItemDownloadingStatusKey,
                    URLResourceKey.isUbiquitousItemKey
                ]) {
                    let status = values.ubiquitousItemDownloadingStatus
                    let isICloud = values.isUbiquitousItem ?? false
                    let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
                    
                    print("📄 File: \(fileName)")
                    print("   ├─ iCloud file: \(isICloud)")
                    print("   ├─ Exists locally: \(fileExists)")
                    print("   └─ Download status: \(status?.rawValue ?? "unknown")")
                    
                    if status == .notDownloaded || !fileExists {
                        print("⬇️ Downloading: \(fileName)")
                        do {
                            try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                            await waitForDownload(url: fileURL)
                            print("✅ Downloaded: \(fileName)")
                        } catch {
                            print("❌ Failed to download \(fileName): \(error.localizedDescription)")
                        }
                    } else {
                        print("✅ Already available: \(fileName)")
                    }
                }
                
                syncProgress = Double(index + 1) / Double(files.count)
            }
            
            isSyncing = false
            syncProgress = 1.0
            
            print("✅ Directory check complete - posting notifications")
            
            // Notify that sync is complete so views can check for orphaned records AND import new files
            NotificationCenter.default.post(name: .iCloudSyncCompleted, object: nil)
            
            // Also post files changed to trigger immediate import
            NotificationCenter.default.post(name: .iCloudFilesChanged, object: nil)
            
        } catch {
            print("❌ Error checking directory: \(error.localizedDescription)")
            isSyncing = false
        }
    }
}
