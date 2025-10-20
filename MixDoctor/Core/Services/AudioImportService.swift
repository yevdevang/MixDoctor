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

    func importAudioFile(from url: URL) async throws -> AudioFile {
        guard url.startAccessingSecurityScopedResource() else {
            throw AudioImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            try validateAudioFile(url)
            let metadata = try await extractMetadata(from: url)
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

    func importMultipleFiles(_ urls: [URL]) async throws -> [AudioFile] {
        var importedFiles: [AudioFile] = []
        var capturedError: Error?

        for url in urls {
            do {
                let audioFile = try await importAudioFile(from: url)
                importedFiles.append(audioFile)
            } catch {
                capturedError = capturedError ?? error
            }
        }

        if importedFiles.isEmpty, let capturedError {
            throw capturedError
        }

        return importedFiles
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
        let fileManager = FileManager.default
        let directoryURL = FileManager.audioFilesDirectory()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Get filename, handling special characters
        let originalFileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        
        print("📁 Importing file:")
        print("   Original: \(originalFileName)")
        print("   Base name: \(baseName)")
        print("   Extension: \(fileExtension)")
        
        var destinationURL = directoryURL.appendingPathComponent(originalFileName)
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let candidateName = "\(baseName)_\(counter).\(fileExtension)"
            destinationURL = directoryURL.appendingPathComponent(candidateName)
            counter += 1
            print("   File exists, trying: \(candidateName)")
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Standardize the URL to ensure it can be read back
            let standardizedURL = URL(fileURLWithPath: destinationURL.path)
            
            print("   ✅ Copied to: \(destinationURL.path)")
            print("   Standardized: \(standardizedURL.path)")
            print("   Verify exists: \(fileManager.fileExists(atPath: standardizedURL.path))")
            
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
}
