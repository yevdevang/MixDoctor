import AVFoundation
import CoreMedia
import Foundation
import Observation
import SwiftData

enum AudioImportError: LocalizedError, Equatable {
    static func == (lhs: AudioImportError, rhs: AudioImportError) -> Bool {
        return true
    }
    
    case unsupportedFormat
    case fileTooLarge
    case invalidAudioFile
    case sampleRateTooLow
    case accessDenied
    case duplicateFile
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Audio format not supported"
        case .fileTooLarge:
            return "File exceeds maximum size of 500 MB"
        case .invalidAudioFile:
            return "File is not a valid audio file"
        case .sampleRateTooLow:
            return "Sample rate must be at least 44.1 kHz"
        case .accessDenied:
            return "Cannot access file. Please grant permission."
        case .duplicateFile:
            return "This file has already been imported"
        case let .unknownError(error):
            return "Import failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class AudioImportService {

    struct AudioMetadata: Equatable {
        let duration: TimeInterval
        let sampleRate: Double
        let bitDepth: Int
        let numberOfChannels: Int
        let fileSize: Int64
        let format: String
    }
    
    nonisolated init() {
    }

    // MARK: - Public API

    func importAudioFile(from url: URL, modelContext: ModelContext? = nil) async throws -> AudioFile {
        
        guard url.startAccessingSecurityScopedResource() else {
            throw AudioImportError.accessDenied
        }
        defer { 
            url.stopAccessingSecurityScopedResource() 
        }

        print("🚀 AudioImportService.importAudioFile: Starting import of \(url.lastPathComponent)")
        print("   Source path: \(url.path)")
        
        // Check if file is in iCloud and needs downloading
        let isIniCloud = url.path.contains("Mobile Documents")
        if isIniCloud {
            print("   📥 File is in iCloud - checking download status...")
            do {
                let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey])
                if let status = resourceValues.ubiquitousItemDownloadingStatus {
                    print("   Download status: \(status.rawValue)")
                    if status == .notDownloaded {
                        print("   📥 Starting download...")
                        try FileManager.default.startDownloadingUbiquitousItem(at: url)
                        
                        // Wait for download with timeout
                        print("   ⏳ Waiting for download (max 30s)...")
                        var attempts = 0
                        let maxAttempts = 60 // 30 seconds (500ms * 60)
                        while attempts < maxAttempts {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                            
                            let currentValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                            if let currentStatus = currentValues.ubiquitousItemDownloadingStatus,
                               currentStatus == .current {
                                print("   ✅ Download complete!")
                                break
                            }
                            attempts += 1
                            
                            if attempts % 10 == 0 {
                                print("   ⏳ Still downloading... (\(attempts/2)s)")
                            }
                        }
                        
                        if attempts >= maxAttempts {
                            print("   ❌ Download timed out after 30 seconds")
                            throw AudioImportError.unknownError(NSError(domain: "MixDoctor", code: -1, userInfo: [NSLocalizedDescriptionKey: "File download from iCloud timed out"]))
                        }
                    } else {
                        print("   ✅ File already downloaded")
                    }
                }
            } catch {
                print("   ⚠️ Could not check iCloud status: \(error.localizedDescription)")
                // Continue anyway - maybe file is local
            }
        }
        
        do {
            print("📋 Validating audio file...")
            try await validateAudioFile(url)
            print("✅ Validation passed")
            
            print("📊 Extracting metadata...")
            let metadata: AudioMetadata
            do {
                metadata = try await extractMetadata(from: url)
                print("✅ Metadata extracted: size=\(metadata.fileSize), duration=\(metadata.duration)")
            } catch {
                print("❌ METADATA EXTRACTION FAILED: \(error)")
                throw error
            }
            
            // Check for duplicates BEFORE copying to iCloud
            // TEMPORARILY DISABLED due to CloudKit sync issues
            print("⚠️ Duplicate check temporarily disabled - will check after copy")
            /*
            if let modelContext = modelContext {
                let fileName = url.lastPathComponent
                let fileSize = metadata.fileSize
                let duration = metadata.duration
                
                print("🔍 Checking duplicate for: \(fileName), size: \(fileSize), duration: \(duration)")
                
                if isDuplicate(fileName: fileName, fileSize: fileSize, duration: duration, modelContext: modelContext) {
                    print("❌ Duplicate detected: \(fileName)")
                    throw AudioImportError.duplicateFile
                } else {
                    print("✅ Not a duplicate, proceeding with import: \(fileName)")
                }
            } else {
                print("⚠️ No modelContext provided - skipping duplicate check")
            }
            */
            
            print("📁 Copying file to app's iCloud container...")
            let destinationURL = try copyToDocuments(from: url)
            print("✅ File copied to: \(destinationURL.path)")

            let audioFile = AudioFile(
                fileName: destinationURL.lastPathComponent,
                fileURL: destinationURL,
                duration: metadata.duration,
                sampleRate: metadata.sampleRate,
                bitDepth: metadata.bitDepth,
                numberOfChannels: metadata.numberOfChannels,
                fileSize: metadata.fileSize
            )

            return audioFile
        } catch let error as AudioImportError {
            print("❌ AudioImportError caught: \(error.errorDescription ?? "unknown")")
            throw error
        } catch {
            print("❌ Unknown error caught: \(error)")
            throw AudioImportError.unknownError(error)
        }
    }

    func importMultipleFiles(_ urls: [URL], modelContext: ModelContext? = nil) async throws -> [AudioFile] {
        var importedFiles: [AudioFile] = []
        var duplicateErrors: [Error] = []
        var otherError: Error?

        for url in urls {
            do {
                let audioFile = try await importAudioFile(from: url, modelContext: modelContext)
                importedFiles.append(audioFile)
            } catch let error as AudioImportError where error == .duplicateFile {
                // Track duplicates separately - don't fail the whole operation
                duplicateErrors.append(error)
            } catch {
                // Track first non-duplicate error
                otherError = otherError ?? error
            }
        }

        // If we have imported files, return them (even if some were duplicates)
        if !importedFiles.isEmpty {
            return importedFiles
        }
        
        // If all files were duplicates, throw duplicate error
        if !duplicateErrors.isEmpty {
            throw AudioImportError.duplicateFile
        }
        
        // If there was another error, throw it
        if let otherError {
            throw otherError
        }
        
        // No files to import
        return []
    }

    // MARK: - Validation

    @discardableResult
    func validateAudioFile(_ url: URL) async throws -> Bool {
        print("  🔍 Checking if file exists at path: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("  ❌ File doesn't exist!")
            throw AudioImportError.invalidAudioFile
        }
        print("  ✅ File exists")

        print("  📏 Checking file size...")
        let fileSize = try getFileSize(url)
        let maxSize = AppConstants.maxFileSizeMB * 1_048_576
        print("  File size: \(fileSize) bytes, max: \(maxSize) bytes")
        guard fileSize <= maxSize else {
            print("  ❌ File too large!")
            throw AudioImportError.fileTooLarge
        }
        print("  ✅ File size OK")

        let fileExtension = url.pathExtension.lowercased()
        print("  🎵 Checking format: \(fileExtension)")
        guard AppConstants.supportedAudioFormats.contains(fileExtension) else {
            print("  ❌ Unsupported format!")
            throw AudioImportError.unsupportedFormat
        }
        print("  ✅ Format supported")

        // Skip AVURLAsset readable check for files in iCloud (they may not be downloaded yet)
        // We'll validate after copying to our container
        let isInICloud = url.path.contains("Mobile Documents") || url.path.contains("iCloud")
        
        if isInICloud {
            print("  ⏭️ Source file is in iCloud - skipping AVURLAsset check (will validate after copy)")
        } else {
            print("  📀 Creating AVURLAsset and checking if readable...")
            let asset = AVURLAsset(url: url)
            
            // Check if asset is readable (using new API for Mac Catalyst 16.0+)
            if #available(macCatalyst 16.0, iOS 16.0, *) {
                do {
                    print("  Attempting to load isReadable property...")
                    let isReadable = try await asset.load(.isReadable)
                    print("  Asset readable check result: \(isReadable)")
                    guard isReadable else {
                        print("  ❌ Asset not readable!")
                        throw AudioImportError.invalidAudioFile
                    }
                } catch {
                    print("  ❌ Error loading asset readable property: \(error)")
                    throw AudioImportError.invalidAudioFile
                }
            } else {
                print("  Asset readable (sync check): \(asset.isReadable)")
                guard asset.isReadable else {
                    print("  ❌ Asset not readable!")
                    throw AudioImportError.invalidAudioFile
                }
            }
            print("  ✅ Asset is readable")
        }

        return true
    }

    // MARK: - Metadata

    private func extractMetadata(from url: URL) async throws -> AudioMetadata {
        print("   📊 Creating AVURLAsset...")
        let asset = AVURLAsset(url: url)

        print("   📊 Loading duration...")
        let duration = try await asset.load(.duration).seconds
        print("   Duration: \(duration)s")
        guard duration.isFinite, duration > 0 else {
            print("   ❌ Invalid duration!")
            throw AudioImportError.invalidAudioFile
        }

        print("   📊 Loading audio tracks...")
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        print("   Found \(tracks.count) track(s)")
        guard let track = tracks.first else {
            print("   ❌ No audio track found!")
            throw AudioImportError.invalidAudioFile
        }

        print("   📊 Loading format descriptions...")
        let formatDescriptions = try await track.load(.formatDescriptions)
        print("   Found \(formatDescriptions.count) format description(s)")
        guard let formatDescription = formatDescriptions.first else {
            print("   ❌ No format description found!")
            throw AudioImportError.invalidAudioFile
        }

        print("   📊 Getting stream basic description...")
        let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = asbdPointer?.pointee else {
            print("   ❌ No ASBD found!")
            throw AudioImportError.invalidAudioFile
        }

        let sampleRate = asbd.mSampleRate
        print("   Sample rate: \(sampleRate) Hz")
        guard sampleRate >= AppConstants.minSampleRate else {
            print("   ❌ Sample rate too low! (min: \(AppConstants.minSampleRate) Hz)")
            throw AudioImportError.sampleRateTooLow
        }

        let channelCount = Int(max(1, asbd.mChannelsPerFrame))
        let bitDepth = asbd.mBitsPerChannel > 0 ? Int(asbd.mBitsPerChannel) : 16
        print("   Channels: \(channelCount), Bit depth: \(bitDepth)")
        
        print("   📊 Getting file size...")
        let fileSize = try getFileSize(url)
        print("   File size: \(fileSize) bytes")

        print("   ✅ Metadata extraction complete!")
        return AudioMetadata(
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            numberOfChannels: channelCount,
            fileSize: fileSize,
            format: url.pathExtension.uppercased()
        )
    }

    // MARK: - File Management

    private func copyToDocuments(from sourceURL: URL) throws -> URL {
        print("  📂 copyToDocuments called")
        print("  Source: \(sourceURL.path)")
        
        // Use iCloud storage service for better sync
        let iCloudService = iCloudStorageService.shared
        let directoryURL = iCloudService.getAudioFilesDirectory()
        print("  App's iCloud container: \(directoryURL.path)")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            print("  Creating iCloud directory...")
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Get filename, handling special characters
        let originalFileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        
        
        let destinationURL = directoryURL.appendingPathComponent(originalFileName)
        print("  Destination path: \(destinationURL.path)")
        
        // Check if the source file is already in our app's container
        // This can happen on MacCatalyst when user picks a file from iCloud Drive
        // that was previously imported. We need to resolve both paths to handle symlinks.
        let resolvedSourcePath = (try? fileManager.destinationOfSymbolicLink(atPath: sourceURL.path)) ?? sourceURL.path
        let resolvedDirectoryPath = (try? fileManager.destinationOfSymbolicLink(atPath: directoryURL.path)) ?? directoryURL.path
        
        let sourceIsInAppContainer = resolvedSourcePath.hasPrefix(resolvedDirectoryPath) || 
                                      sourceURL.path.hasPrefix(directoryURL.path) ||
                                      sourceURL.standardizedFileURL == destinationURL.standardizedFileURL
        print("  Source is already in app container: \(sourceIsInAppContainer)")
        print("  Resolved source path: \(resolvedSourcePath)")
        print("  Resolved directory path: \(resolvedDirectoryPath)")
        
        if sourceIsInAppContainer {
            // File is already in the right place, just return the URL
            print("  ✅ File is already in app container, using as-is")
            return sourceURL
        }
        
        // If file already exists at destination, it means:
        // 1. It's an orphaned file being re-imported, OR
        // 2. Previous import failed after copying but before database insert
        // In both cases, we can reuse the existing file instead of creating duplicates
        let fileExistsAtDestination = fileManager.fileExists(atPath: destinationURL.path)
        print("  File already exists at destination: \(fileExistsAtDestination)")
        
        if fileExistsAtDestination {
            print("  ⚠️ File already exists in app container - reusing existing file")
            return destinationURL
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // If using iCloud, trigger upload
            if destinationURL.path.contains("Mobile Documents") {
                try? fileManager.startDownloadingUbiquitousItem(at: destinationURL)
            }
            
            // Standardize the URL to ensure it can be read back
            let standardizedURL = URL(fileURLWithPath: destinationURL.path)
            
            
            return standardizedURL
        } catch {
            throw AudioImportError.unknownError(error)
        }
    }

    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = attributes[.size] as? NSNumber
        return number?.int64Value ?? 0
    }
    
    // MARK: - Duplicate Detection
    
    /// Check if a file is a duplicate based on fileName, fileSize, and duration
    /// Also verifies that the existing file physically exists before treating as duplicate
    private func isDuplicate(fileName: String, fileSize: Int64, duration: TimeInterval, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            print("⚠️ AudioImportService.isDuplicate: Failed to fetch files from database")
            return false
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 DUPLICATE CHECK for: \(fileName)")
        print("   Size: \(fileSize) bytes, Duration: \(String(format: "%.2f", duration))s")
        print("   Database has \(allFiles.count) total records")
        print(String(repeating: "=", count: 80))
        
        // First pass: Clean up ANY stale records (files that don't physically exist)
        var stalesToRemove: [AudioFile] = []
        for (index, file) in allFiles.enumerated() {
            print("\nRecord #\(index + 1): \(file.fileName)")
            print("   Path: \(file.fileURL.path)")
            
            var fileExists = FileManager.default.fileExists(atPath: file.fileURL.path)
            print("   FileExists (basic check): \(fileExists)")
            
            // For iCloud files, do a more thorough check
            if file.fileURL.path.contains("Mobile Documents") {
                print("   This is an iCloud file - doing thorough check...")
                do {
                    let resourceValues = try file.fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey])
                    let isUploaded = resourceValues.ubiquitousItemIsUploaded ?? false
                    let status = resourceValues.ubiquitousItemDownloadingStatus
                    print("   iCloud uploaded: \(isUploaded)")
                    print("   iCloud status: \(String(describing: status))")
                    // Only consider it as existing if it's actually uploaded to iCloud OR exists locally
                    fileExists = fileExists || isUploaded
                } catch {
                    print("   ❌ iCloud resource error: \(error.localizedDescription)")
                    fileExists = false
                }
            }
            
            print("   Final verdict: \(fileExists ? "✅ EXISTS" : "🗑️ STALE - WILL DELETE")")
            
            if !fileExists {
                stalesToRemove.append(file)
            }
        }
        
        if !stalesToRemove.isEmpty {
            print("\n🧹 CLEANING UP \(stalesToRemove.count) STALE RECORD(S):")
            for stale in stalesToRemove {
                print("   🗑️ Deleting: \(stale.fileName) at \(stale.fileURL.path)")
                modelContext.delete(stale)
            }
            do {
                try modelContext.save()
                print("✅ Stale records deleted successfully\n")
            } catch {
                print("❌ Failed to clean up stale records: \(error.localizedDescription)\n")
            }
        } else {
            print("\n✅ No stale records found in first pass\n")
        }
        
        // Re-fetch after cleanup
        guard let currentFiles = try? modelContext.fetch(descriptor) else {
            print("⚠️ Failed to re-fetch after cleanup")
            print(String(repeating: "=", count: 80) + "\n")
            return false
        }
        
        print("🔍 After cleanup: \(currentFiles.count) valid records remaining")
        
        // Check for exact match on fileName and fileSize
        // Duration check within 1 second tolerance (for encoding variations)
        var foundDuplicate = false
        for existingFile in currentFiles {
            let sameFileName = existingFile.fileName == fileName
            let sameFileSize = existingFile.fileSize == fileSize
            let similarDuration = abs(existingFile.duration - duration) < 1.0
            
            if sameFileName || (sameFileSize && similarDuration) {
                print("\n   Comparing with: \(existingFile.fileName)")
                print("      Name match: \(sameFileName ? "✅" : "❌")")
                print("      Size match: \(sameFileSize ? "✅" : "❌") (\(existingFile.fileSize) vs \(fileSize))")
                print("      Duration match: \(similarDuration ? "✅" : "❌") (\(String(format: "%.2f", existingFile.duration))s vs \(String(format: "%.2f", duration))s)")
            }
            
            if sameFileName && sameFileSize && similarDuration {
                print("\n   ⚠️ POTENTIAL DUPLICATE MATCH!")
                print("      Existing file path: \(existingFile.fileURL.path)")
                
                // Before treating as duplicate, verify the existing file actually exists
                let existingFileURL = existingFile.fileURL
                var fileExists = FileManager.default.fileExists(atPath: existingFileURL.path)
                print("      File exists (basic check): \(fileExists)")
                
                // On MacCatalyst, sometimes iCloud files need to be downloaded first
                // Try to check if it's an iCloud file that needs downloading
                #if targetEnvironment(macCatalyst)
                if existingFileURL.path.contains("Mobile Documents") {
                    print("      Checking iCloud status...")
                    do {
                        let resourceValues = try existingFileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey])
                        if let status = resourceValues.ubiquitousItemDownloadingStatus,
                           let isUploaded = resourceValues.ubiquitousItemIsUploaded {
                            print("         Status: \(status.rawValue), uploaded: \(isUploaded)")
                            // Only consider it as existing if it's uploaded to iCloud AND either current or available for download
                            if isUploaded && (status == .current || status == .notDownloaded) {
                                fileExists = true
                            }
                        }
                    } catch {
                        print("         Error checking iCloud status: \(error.localizedDescription)")
                        fileExists = false
                    }
                }
                #endif
                
                print("      Final file exists: \(fileExists)")
                
                if !fileExists {
                    // File record exists but file is missing - remove the stale record
                    print("      🗑️ File doesn't exist - removing stale record")
                    modelContext.delete(existingFile)
                    do {
                        try modelContext.save()
                        print("      ✅ Stale record removed successfully")
                    } catch {
                        print("      ❌ Failed to remove stale record: \(error.localizedDescription)")
                    }
                    continue // Check next file
                }
                
                print("      ❌ DUPLICATE CONFIRMED - file exists!")
                foundDuplicate = true
                break
            }
        }
        
        if !foundDuplicate {
            print("\n✅ NOT A DUPLICATE - import can proceed")
        }
        print(String(repeating: "=", count: 80) + "\n")
        
        return foundDuplicate
    }
}
