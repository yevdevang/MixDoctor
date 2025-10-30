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
            print("⚠️ iCloud not available, cannot start monitoring")
            return
        }
        
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K BEGINSWITH %@", 
                                      NSMetadataItemPathKey, 
                                      iCloudService.getAudioFilesDirectory().path)
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
        
        query.start()
        metadataQuery = query
        
        print("✅ Started iCloud monitoring for: \(iCloudService.getAudioFilesDirectory().path)")
    }
    
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        
        NotificationCenter.default.removeObserver(self)
        print("🛑 Stopped iCloud monitoring")
    }
    
    // MARK: - Query Notifications
    
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        
        query.disableUpdates()
        
        print("📊 iCloud query finished gathering: \(query.resultCount) items")
        
        // Download any files that aren't downloaded yet
        Task {
            await downloadPendingFiles(from: query)
        }
        
        query.enableUpdates()
    }
    
    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        
        query.disableUpdates()
        
        print("🔄 iCloud query updated: \(query.resultCount) items")
        
        // Check for new files that need downloading
        Task {
            await downloadPendingFiles(from: query)
        }
        
        query.enableUpdates()
    }
    
    // MARK: - File Download
    
    private func downloadPendingFiles(from query: NSMetadataQuery) async {
        let results = query.results as? [NSMetadataItem] ?? []
        var filesToDownload: [URL] = []
        
        for item in results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }
            
            // Check download status
            let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            
            if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                filesToDownload.append(url)
            }
        }
        
        guard !filesToDownload.isEmpty else {
            isSyncing = false
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        print("⬇️ Downloading \(filesToDownload.count) files from iCloud...")
        
        for (index, url) in filesToDownload.enumerated() {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                
                // Wait for download to complete
                await waitForDownload(url: url)
                
                syncProgress = Double(index + 1) / Double(filesToDownload.count)
            } catch {
                print("❌ Failed to download \(url.lastPathComponent): \(error)")
            }
        }
        
        isSyncing = false
        syncProgress = 1.0
        
        print("✅ Finished downloading files from iCloud")
    }
    
    private func waitForDownload(url: URL, maxAttempts: Int = 30) async {
        for _ in 0..<maxAttempts {
            do {
                let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let status = values.ubiquitousItemDownloadingStatus
                
                if status == .current {
                    return
                }
            } catch {
                print("⚠️ Error checking download status: \(error)")
            }
            
            // Wait 1 second before checking again
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    // MARK: - Manual Sync
    
    func syncNow() async {
        print("🔄 Manual sync triggered")
        
        // First try direct file check (more reliable in simulator)
        await checkDirectoryForFiles()
        
        // Then use query if available
        if let query = metadataQuery {
            await downloadPendingFiles(from: query)
        } else {
            print("⚠️ Query not initialized, trying direct check only")
        }
    }
    
    // MARK: - Direct File Check
    
    private func checkDirectoryForFiles() async {
        let directory = iCloudService.getAudioFilesDirectory()
        
        print("📂 Checking directory: \(directory.path)")
        print("📂 iCloud available: \(iCloudService.isICloudAvailable)")
        
        do {
            // List all files in directory
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
            
            print("📂 Found \(files.count) files in directory")
            
            isSyncing = true
            syncProgress = 0.0
            
            for (index, fileURL) in files.enumerated() {
                let fileName = fileURL.lastPathComponent
                print("📄 Checking file: \(fileName)")
                
                // Check if file needs downloading
                if let values = try? fileURL.resourceValues(forKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey]) {
                    let status = values.ubiquitousItemDownloadingStatus
                    print("   Status: \(status?.rawValue ?? "unknown")")
                    
                    if status == .notDownloaded || !FileManager.default.fileExists(atPath: fileURL.path) {
                        print("   ⬇️ Downloading: \(fileName)")
                        do {
                            try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                            await waitForDownload(url: fileURL)
                            print("   ✅ Downloaded: \(fileName)")
                        } catch {
                            print("   ❌ Failed to download \(fileName): \(error)")
                        }
                    } else {
                        print("   ✅ Already downloaded: \(fileName)")
                    }
                }
                
                syncProgress = Double(index + 1) / Double(files.count)
            }
            
            isSyncing = false
            syncProgress = 1.0
            
            print("✅ Directory check complete: \(files.count) files")
            
        } catch {
            print("❌ Error checking directory: \(error)")
            isSyncing = false
        }
    }
}
