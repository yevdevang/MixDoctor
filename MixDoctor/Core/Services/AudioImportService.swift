import AVFoundation
import Foundation
import SwiftData

enum AudioImportError: LocalizedError, Equatable {
    case fileNotFound
    case unsupportedFormat
    case fileTooLarge(maxSizeMB: Int64)
    case metadataUnavailable
    case invalidSampleRate(minimum: Double)
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The selected audio file could not be found."
        case .unsupportedFormat:
            return "The selected file format is not supported."
        case let .fileTooLarge(maxSizeMB):
            return "The selected file exceeds the maximum size of \(maxSizeMB) MB."
        case .metadataUnavailable:
            return "Unable to extract metadata from the audio file."
        case let .invalidSampleRate(minimum):
            return "The audio file must have a sample rate of at least \(Int(minimum)) Hz."
        case .copyFailed:
            return "Unable to copy the audio file into the app's storage."
        }
    }
}

protocol AudioImporting {
    func importAudioFile(from url: URL) throws -> AudioFile
}

struct AudioImportService: AudioImporting {
    private let fileManager: FileManager
    private let importsDirectoryName = "ImportedAudio"
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func importAudioFile(from url: URL) throws -> AudioFile {
        guard url.isFileURL else {
            throw AudioImportError.fileNotFound
        }

        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioImportError.fileNotFound
        }

        try validateFileExtension(for: url)
    try validateFileSize(for: url)

    let destinationURL = try copyToPersistentLocation(sourceURL: url)
    let metadata = try extractMetadata(for: destinationURL)

        let audioFile = AudioFile(
            fileName: destinationURL.lastPathComponent,
            fileURL: destinationURL,
            duration: metadata.duration,
            sampleRate: metadata.sampleRate,
            bitDepth: metadata.bitDepth,
            numberOfChannels: metadata.channels,
            fileSize: metadata.fileSize
        )

        return audioFile
    }

    private func validateFileExtension(for url: URL) throws {
        let ext = url.pathExtension.lowercased()
        guard AppConstants.supportedAudioFormats.contains(ext) else {
            throw AudioImportError.unsupportedFormat
        }
    }

    private func validateFileSize(for url: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let maximumBytes = AppConstants.maxFileSizeMB * 1_048_576

        guard fileSize <= maximumBytes else {
            throw AudioImportError.fileTooLarge(maxSizeMB: AppConstants.maxFileSizeMB)
        }
    }

    private func copyToPersistentLocation(sourceURL: URL) throws -> URL {
        let directory = try makeImportsDirectory()
        let targetURL = uniqueTargetURL(for: sourceURL, in: directory)

        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            return targetURL
        } catch {
            throw AudioImportError.copyFailed
        }
    }

    private func makeImportsDirectory() throws -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let baseURL = documentsURL else {
            throw AudioImportError.copyFailed
        }

        let directoryURL = baseURL.appendingPathComponent(importsDirectoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }

    private func uniqueTargetURL(for sourceURL: URL, in directory: URL) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

    let timestamp = Self.timestampFormatter.string(from: Date())
        let uniqueName = "\(fileName)_\(timestamp).\(ext)"
        return directory.appendingPathComponent(uniqueName)
    }

    private func extractMetadata(for url: URL) throws -> (duration: TimeInterval, sampleRate: Double, bitDepth: Int, channels: Int, fileSize: Int64) {
        let audioFile: AVAudioFile

        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioImportError.metadataUnavailable
        }
        let format = audioFile.processingFormat

        let sampleRate = format.sampleRate
        guard sampleRate >= AppConstants.minSampleRate else {
            throw AudioImportError.invalidSampleRate(minimum: AppConstants.minSampleRate)
        }

        let frameLength = Double(audioFile.length)
        let durationSeconds = frameLength > 0 ? frameLength / sampleRate : 0
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw AudioImportError.metadataUnavailable
        }

        let channelCount = max(1, Int(format.channelCount))
        let inferredBitDepth = format.settings[AVLinearPCMBitDepthKey] as? Int ?? Int(format.commonFormat.bitDepth)
        let bitDepth = inferredBitDepth > 0 ? inferredBitDepth : 16
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return (
            duration: durationSeconds,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channelCount,
            fileSize: fileSize
        )
    }
}

private extension AVAudioCommonFormat {
    var bitDepth: Int {
        switch self {
        case .pcmFormatFloat32:
            return 32
        case .pcmFormatFloat64:
            return 64
        case .pcmFormatInt16:
            return 16
        case .pcmFormatInt32:
            return 32
        default:
            return 0
        }
    }
}
