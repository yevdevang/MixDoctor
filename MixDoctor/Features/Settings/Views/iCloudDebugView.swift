//
//  iCloudDebugView.swift
//  MixDoctor
//
//  Debug view to check iCloud status
//

import SwiftUI
import SwiftData
import AVFoundation

struct iCloudDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var audioFiles: [AudioFile]
    
    @State private var iCloudStatus = ""
    @State private var containerPath = ""
    @State private var filesInContainer: [String] = []
    @State private var isRefreshing = false
    @State private var iCloudDriveEnabled = false
    @State private var signedInToiCloud = false
    @State private var showDeleteConfirmation = false
    @State private var deleteMessage = ""
    
    var body: some View {
        List {
            Section("SwiftData Records") {
                HStack {
                    Text("AudioFile records in database:")
                    Spacer()
                    Text("\(audioFiles.count)")
                        .bold()
                }
                
                Button(action: checkDatabase) {
                    Label("Refresh Database Count", systemImage: "arrow.clockwise")
                }
                
                if !audioFiles.isEmpty {
                    ForEach(audioFiles) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.fileName)
                                .font(.caption)
                            Text("Path: \(file.fileURL.path)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // Check if file exists
                            let fileExists = FileManager.default.fileExists(atPath: file.fileURL.path)
                            HStack {
                                Image(systemName: fileExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(fileExists ? .green : .red)
                                Text(fileExists ? "File exists" : "File missing")
                                    .font(.caption2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Device iCloud Status") {
                HStack {
                    Text("Signed into iCloud:")
                    Spacer()
                    Text(signedInToiCloud ? "✅ Yes" : "❌ No")
                        .foregroundColor(signedInToiCloud ? .green : .red)
                }
                
                HStack {
                    Text("iCloud Drive Enabled:")
                    Spacer()
                    Text(iCloudDriveEnabled ? "✅ Yes" : "❌ No")
                        .foregroundColor(iCloudDriveEnabled ? .green : .red)
                }
            }
            
            Section("App iCloud Status") {
                Text(iCloudStatus)
                    .font(.caption)
                    .foregroundColor(iCloudStatus.contains("Available") ? .green : .red)
            }
            
            Section("Files in iCloud") {
                if filesInContainer.isEmpty {
                    Text("No files found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filesInContainer, id: \.self) { file in
                        Text(file)
                            .font(.caption)
                    }
                }
            }
            
            Section("Troubleshooting") {
                if !signedInToiCloud {
                    Text("⚠️ Go to Settings → [Your Name] and sign in to iCloud")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if !iCloudDriveEnabled {
                    Text("⚠️ Go to Settings → [Your Name] → iCloud → iCloud Drive → Turn ON")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if !iCloudStatus.contains("Available") {
                    Text("⚠️ Delete and reinstall the app after enabling iCloud Drive")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section("Actions") {
                Button("Refresh Status") {
                    checkStatus()
                }
                .disabled(isRefreshing)
                
                Button("Scan & Import Files from iCloud") {
                    Task {
                        await scanAndImportFromiCloud()
                    }
                }
                .disabled(isRefreshing)
                
                Button("Force Download All iCloud Files") {
                    Task {
                        await forceDownloadAll()
                    }
                }
                .disabled(isRefreshing)
                
                Button("Comprehensive File Status Check") {
                    checkComprehensiveFileStatus()
                }
                .disabled(isRefreshing)
                
                Button("Download All Using New Service") {
                    Task {
                        await downloadAllWithNewService()
                    }
                }
                .disabled(isRefreshing)
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete All Files from iCloud", systemImage: "trash.fill")
                }
                .disabled(isRefreshing || (audioFiles.isEmpty && filesInContainer.isEmpty))
            }
        }
        .navigationTitle("iCloud Debug")
        .alert("Delete All Files?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                Task {
                    await deleteAllFiles()
                }
            }
        } message: {
            Text("This will permanently delete all audio files from iCloud Drive and remove all AudioFile records from the database. This cannot be undone.")
        }
        .alert("Deletion Complete", isPresented: Binding(
            get: { !deleteMessage.isEmpty },
            set: { if !$0 { deleteMessage = "" } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteMessage)
        }
        .onAppear {
            checkStatus()
        }
    }
    
    private func scanAndImportFromiCloud() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            
            // Filter audio files
            let audioExtensions = ["mp3", "wav"]
            let audioFiles = files.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            
            
            var imported = 0
            var skipped = 0
            var errors = 0
            
            for fileURL in audioFiles {
                // Check if already imported
                let fileName = fileURL.lastPathComponent
                let descriptor = FetchDescriptor<AudioFile>(
                    predicate: #Predicate { $0.fileName == fileName }
                )
                
                if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
                    skipped += 1
                    continue
                }
                
                // Download if needed
                do {
                    let values = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if values.ubiquitousItemDownloadingStatus == .notDownloaded {
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        // Wait for download
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                    }
                } catch {
                }
                
                // Import the file
                do {
                    // Extract metadata using AVFoundation
                    let asset = AVURLAsset(url: fileURL)
                    let duration = try await asset.load(.duration).seconds
                    let tracks = try await asset.loadTracks(withMediaType: .audio)
                    
                    guard let track = tracks.first else {
                        throw NSError(domain: "AudioImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
                    }
                    
                    let formatDescriptions = try await track.load(.formatDescriptions)
                    guard let formatDescription = formatDescriptions.first else {
                        throw NSError(domain: "AudioImport", code: -2, userInfo: [NSLocalizedDescriptionKey: "No format description found"])
                    }
                    
                    let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    let sampleRate = basicDescription?.pointee.mSampleRate ?? 44100.0
                    let channels = Int(basicDescription?.pointee.mChannelsPerFrame ?? 2)
                    
                    // Get file size
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    
                    let audioFile = AudioFile(
                        fileName: fileName,
                        fileURL: fileURL,
                        duration: duration,
                        sampleRate: sampleRate,
                        bitDepth: 16, // Default
                        numberOfChannels: channels,
                        fileSize: fileSize
                    )
                    
                    modelContext.insert(audioFile)
                    
                    // Try to load analysis result from iCloud Drive
                    if let analysisResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: fileName) {
                        analysisResult.audioFile = audioFile
                        audioFile.analysisResult = analysisResult
                        audioFile.dateAnalyzed = analysisResult.dateAnalyzed
                    }
                    
                    try modelContext.save()
                    
                    imported += 1
                } catch {
                    errors += 1
                }
            }
            
            
            // Refresh UI
            checkStatus()
            
            // Show alert
            await MainActor.run {
                deleteMessage = "Scan complete:\n\(imported) file(s) imported\n\(skipped) file(s) already exist\n\(errors) error(s)"
            }
            
        } catch {
            await MainActor.run {
                deleteMessage = "Error scanning iCloud Drive: \(error.localizedDescription)"
            }
        }
    }
    
    private func forceDownloadAll() async {
        isRefreshing = true
        
        
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        do {
            // Get all files (including those not downloaded)
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [URLResourceKey.ubiquitousItemDownloadingStatusKey, URLResourceKey.isUbiquitousItemKey],
                options: []
            )
            
            
            for fileURL in files {
                
                // Check if it's an iCloud item
                if let values = try? fileURL.resourceValues(forKeys: [URLResourceKey.isUbiquitousItemKey, URLResourceKey.ubiquitousItemDownloadingStatusKey]) {
                    
                    // Try to start download
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        
                        // Wait a bit for download
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    } catch {
                    }
                }
            }
            
            
            // Refresh status
            checkStatus()
            
        } catch {
        }
        
        isRefreshing = false
    }
    
    private func checkStatus() {
        isRefreshing = true
        
        // Check if user is signed into iCloud
        if let _ = FileManager.default.ubiquityIdentityToken {
            signedInToiCloud = true
        } else {
            signedInToiCloud = false
        }
        
        // Check if iCloud Drive is enabled (this is a heuristic)
        iCloudDriveEnabled = signedInToiCloud
        
        let service = iCloudStorageService.shared
        
        // Check if iCloud is available
        if service.isICloudAvailable {
            iCloudStatus = "✅ iCloud Available"
            
            // Get container path
            if let containerURL = service.iCloudContainerURL {
                containerPath = containerURL.path
                
                // List files
                let audioDir = service.getAudioFilesDirectory()
                if let files = try? FileManager.default.contentsOfDirectory(atPath: audioDir.path) {
                    filesInContainer = files
                } else {
                    filesInContainer = ["Error reading directory"]
                }
            } else {
                containerPath = "No container URL"
            }
        } else {
            iCloudStatus = "❌ iCloud Not Available"
            containerPath = "N/A"
            filesInContainer = []
        }
        
        isRefreshing = false
        
        // Print detailed debug info to console
    }
    
    private func checkDatabase() {
        // Force a manual check of the database
        let descriptor = FetchDescriptor<AudioFile>()
        if let allFiles = try? modelContext.fetch(descriptor) {
            for (index, file) in allFiles.enumerated() {
            }
        } else {
        }
    }
    
    private func deleteAllFiles() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        
        var deletedFilesCount = 0
        var deletedRecordsCount = 0
        var errors: [String] = []
        
        // Step 1: Delete all physical files from iCloud Drive
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            
            for fileURL in files {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedFilesCount += 1
                } catch {
                    let errorMsg = "Failed to delete \(fileURL.lastPathComponent): \(error.localizedDescription)"
                    errors.append(errorMsg)
                }
            }
        } catch {
            let errorMsg = "Failed to read directory: \(error.localizedDescription)"
            errors.append(errorMsg)
        }
        
        // Step 2: Delete all AudioFile records from SwiftData
        let descriptor = FetchDescriptor<AudioFile>()
        if let allFiles = try? modelContext.fetch(descriptor) {
            
            for file in allFiles {
                modelContext.delete(file)
                deletedRecordsCount += 1
            }
            
            do {
                try modelContext.save()
            } catch {
                let errorMsg = "Failed to save database changes: \(error.localizedDescription)"
                errors.append(errorMsg)
            }
        }
        
        // Step 3: Refresh status
        checkStatus()
        
        // Step 4: Show result message
        if errors.isEmpty {
            deleteMessage = "Successfully deleted \(deletedFilesCount) file\(deletedFilesCount == 1 ? "" : "s") from iCloud Drive and \(deletedRecordsCount) record\(deletedRecordsCount == 1 ? "" : "s") from database."
        } else {
            deleteMessage = "Deleted \(deletedFilesCount) file\(deletedFilesCount == 1 ? "" : "s") and \(deletedRecordsCount) record\(deletedRecordsCount == 1 ? "" : "s"), but encountered \(errors.count) error\(errors.count == 1 ? "" : "s")."
        }
        
    }
    
    // MARK: - New Comprehensive File Status Functions
    
    private func checkComprehensiveFileStatus() {
        
        // Use the new iCloudStorageService functions
        let service = iCloudStorageService.shared
        service.printFileStatus()
        
        // Also check using the new getAllAudioFilesWithStatus function
        do {
            let allFiles = try service.getAllAudioFilesWithStatus()
            
            
            let iCloudFiles = allFiles.filter { $0.isICloudFile }
            let localFiles = allFiles.filter { !$0.isICloudFile }
            let downloadedICloudFiles = iCloudFiles.filter { $0.isDownloaded }
            let notDownloadedICloudFiles = iCloudFiles.filter { !$0.isDownloaded }
            
            
            if !notDownloadedICloudFiles.isEmpty {
                for file in notDownloadedICloudFiles {
                }
            }
            
        } catch {
        }
        
    }
    
    private func downloadAllWithNewService() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        
        let service = iCloudStorageService.shared
        
        do {
            let result = try await service.downloadAllICloudFiles()
            
            
            // Refresh the view
            checkStatus()
            
        } catch {
        }
        
    }
}
