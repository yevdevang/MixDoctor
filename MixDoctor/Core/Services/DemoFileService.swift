//
//  DemoFileService.swift
//  MixDoctor
//
//  Service for loading bundled demo audio files on first launch
//

import Foundation
import SwiftData
import AVFoundation
import CoreMedia
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DemoFileService {
    static let shared = DemoFileService()

    private init() {}

    struct DemoFileDefinition {
        let assetName: String       // Name in Assets.xcassets
        let displayName: String     // User-facing name
        let genre: String?
        let mixStage: String        // "mix" or "master_streaming"
    }

    static let demoFiles: [DemoFileDefinition] = [
        DemoFileDefinition(
            assetName: "Song_3_MIX_example",
            displayName: "Song 1 MIX",
            genre: "Pop/Rock",
            mixStage: "mix"
        ),
        DemoFileDefinition(
            assetName: "Song_2_MASTER_example",
            displayName: "Song 2 MASTER",
            genre: "Jazz",
            mixStage: "master_streaming"
        ),
        DemoFileDefinition(
            assetName: "Song_1_MIX_example",
            displayName: "Song 3 MIX",
            genre: "Pop/Rock",
            mixStage: "mix"
        ),
        DemoFileDefinition(
            assetName: "Unmixed_MIX_example",
            displayName: "Song 4 UNMIXED",
            genre: "Electronic",
            mixStage: "mix"
        )
    ]

    private let hasLoadedKey = "hasLoadedDemoFiles"

    /// Load demo files into the app if not already loaded.
    /// Called after onboarding completes or on app update for existing users.
    func loadDemoFilesIfNeeded(modelContext: ModelContext) async {
        // Check if demo files already exist in SwiftData
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { $0.isDemoFile == true }
        )
        let existingDemoFiles = (try? modelContext.fetch(descriptor)) ?? []

        // Get existing demo file display names to avoid duplicates
        let existingNames = Set(existingDemoFiles.map { $0.fileName })

        // If all demo files already exist by name, skip
        let allDemoFilesExist = Self.demoFiles.allSatisfy { existingNames.contains($0.displayName) }
        if allDemoFilesExist {
            UserDefaults.standard.set(true, forKey: hasLoadedKey)
            return
        }

        let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()

        for definition in Self.demoFiles {
            // Skip if already loaded
            if existingNames.contains(definition.displayName) {
                continue
            }

            // Load audio data from asset catalog
            guard let dataAsset = NSDataAsset(name: definition.assetName) else {
                print("⚠️ DemoFileService: Could not find asset '\(definition.assetName)'")
                continue
            }

            // Determine file extension from the asset data
            let fileExtension = detectFileExtension(from: dataAsset.data)
            let fileName = "\(definition.displayName).\(fileExtension)"
            let destinationURL = audioDir.appendingPathComponent(fileName)

            // Skip copy if file already exists on disk
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                do {
                    try dataAsset.data.write(to: destinationURL)
                } catch {
                    print("⚠️ DemoFileService: Failed to write '\(fileName)': \(error.localizedDescription)")
                    continue
                }
            }

            // Extract metadata via AVURLAsset
            let asset = AVURLAsset(url: destinationURL)
            let duration: TimeInterval
            let sampleRate: Double
            let channels: Int

            do {
                duration = try await asset.load(.duration).seconds
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                if let track = tracks.first {
                    let formatDescriptions = try await track.load(.formatDescriptions)
                    if let formatDescription = formatDescriptions.first {
                        let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                        sampleRate = basicDescription?.pointee.mSampleRate ?? 44100.0
                        channels = Int(basicDescription?.pointee.mChannelsPerFrame ?? 2)
                    } else {
                        sampleRate = 44100.0
                        channels = 2
                    }
                } else {
                    sampleRate = 44100.0
                    channels = 2
                }
            } catch {
                print("⚠️ DemoFileService: Failed to load metadata for '\(fileName)': \(error.localizedDescription)")
                continue
            }

            let fileSize: Int64
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                fileSize = attrs[.size] as? Int64 ?? 0
            } catch {
                fileSize = 0
            }

            let audioFile = AudioFile(
                fileName: definition.displayName,
                fileURL: destinationURL,
                duration: duration,
                sampleRate: sampleRate,
                bitDepth: 16,
                numberOfChannels: channels,
                fileSize: fileSize,
                genre: definition.genre,
                mixStage: definition.mixStage,
                isDemoFile: true
            )

            modelContext.insert(audioFile)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: hasLoadedKey)
        } catch {
            print("⚠️ DemoFileService: Failed to save demo files: \(error.localizedDescription)")
        }
    }

    /// Detect file extension from raw audio data
    private func detectFileExtension(from data: Data) -> String {
        guard data.count >= 4 else { return "wav" }

        let header = [UInt8](data.prefix(4))

        // Check for MP3 (ID3 tag or sync word)
        if header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33 { // "ID3"
            return "mp3"
        }
        if header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 { // MP3 sync word
            return "mp3"
        }

        // Default to wav (RIFF header or other)
        return "wav"
    }
}
