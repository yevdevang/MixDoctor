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

        do {
            try validateAudioFile(url)
            let metadata = try await extractMetadata(from: url)
            
            // Check for duplicates BEFORE copying to iCloud
            if let modelContext = modelContext {
                let fileName = url.lastPathComponent
                let fileSize = metadata.fileSize
                let duration = metadata.duration
                
                if isDuplicate(fileName: fileName, fileSize: fileSize, duration: duration, modelContext: modelContext) {
                    throw AudioImportError.duplicateFile
                }
            }
            
            let destinationURL = try copyToDocuments(from: url)

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
            throw error
        } catch {
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
    func validateAudioFile(_ url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioImportError.invalidAudioFile
        }

        let fileSize = try getFileSize(url)
        let maxSize = AppConstants.maxFileSizeMB * 1_048_576
        guard fileSize <= maxSize else {
            throw AudioImportError.fileTooLarge
        }

        let fileExtension = url.pathExtension.lowercased()
        guard AppConstants.supportedAudioFormats.contains(fileExtension) else {
            throw AudioImportError.unsupportedFormat
        }

        let asset = AVURLAsset(url: url)
        guard asset.isReadable else {
            throw AudioImportError.invalidAudioFile
        }

        return true
    }

    // MARK: - Metadata

    private func extractMetadata(from url: URL) async throws -> AudioMetadata {
        let asset = AVURLAsset(url: url)

        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw AudioImportError.invalidAudioFile
        }

        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw AudioImportError.invalidAudioFile
        }

        let formatDescriptions = try await track.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw AudioImportError.invalidAudioFile
        }

        let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = asbdPointer?.pointee else {
            throw AudioImportError.invalidAudioFile
        }

        let sampleRate = asbd.mSampleRate
        guard sampleRate >= AppConstants.minSampleRate else {
            throw AudioImportError.sampleRateTooLow
        }

        let channelCount = Int(max(1, asbd.mChannelsPerFrame))
        let bitDepth = asbd.mBitsPerChannel > 0 ? Int(asbd.mBitsPerChannel) : 16
        let fileSize = try getFileSize(url)

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
        // Use iCloud storage service for better sync
        let iCloudService = iCloudStorageService.shared
        let directoryURL = iCloudService.getAudioFilesDirectory()

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Get filename, handling special characters
        let originalFileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        
        
        let destinationURL = directoryURL.appendingPathComponent(originalFileName)
        
        // If file already exists at destination, it means:
        // 1. It's an orphaned file being re-imported, OR
        // 2. Previous import failed after copying but before database insert
        // In both cases, we can reuse the existing file instead of creating duplicates
        if fileManager.fileExists(atPath: destinationURL.path) {
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
    private func isDuplicate(fileName: String, fileSize: Int64, duration: TimeInterval, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return false
        }
        
        
        // Check for exact match on fileName and fileSize
        // Duration check within 1 second tolerance (for encoding variations)
        for existingFile in allFiles {
            let sameFileName = existingFile.fileName == fileName
            let sameFileSize = existingFile.fileSize == fileSize
            let similarDuration = abs(existingFile.duration - duration) < 1.0
            
            if sameFileName {
            }
            
            if sameFileName && sameFileSize && similarDuration {
                return true
            }
        }
        
        return false
    }
}
