//
//  MixDoctorTests.swift
//  MixDoctorTests
//
//  Unit tests for MixDoctor
//

import Testing
import SwiftData
@testable import MixDoctor

@Suite("MixDoctor Core Tests")
struct MixDoctorTests {
    
    @Test("AudioFile creation")
    func audioFileCreation() async throws {
        let audioFile = AudioFile(
            fileName: "test.wav",
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            duration: 120.0,
            sampleRate: 44100,
            bitDepth: 24,
            numberOfChannels: 2,
            fileSize: 10_000_000
        )
        
        #expect(audioFile.fileName == "test.wav")
        #expect(audioFile.duration == 120.0)
        #expect(audioFile.sampleRate == 44100)
        #expect(audioFile.numberOfChannels == 2)
    }
    
    @Test("AnalysisResult initialization")
    func analysisResultInit() async throws {
        let audioFile = AudioFile(
            fileName: "test.wav",
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            duration: 120.0,
            sampleRate: 44100,
            bitDepth: 24,
            numberOfChannels: 2,
            fileSize: 10_000_000
        )
        
        let result = AnalysisResult(audioFile: audioFile)
        
        #expect(result.overallScore == 0)
        #expect(result.recommendations.isEmpty)
        #expect(!result.hasPhaseIssues)
        #expect(!result.hasStereoIssues)
    }
    
    @Test("Score color mapping")
    func scoreColorMapping() async throws {
        #expect(Color.scoreColor(for: 95) == .scoreExcellent)
        #expect(Color.scoreColor(for: 80) == .scoreGood)
        #expect(Color.scoreColor(for: 60) == .scoreFair)
        #expect(Color.scoreColor(for: 30) == .scorePoor)
    }
    
    @Test("AppConstants values")
    func appConstantsValidation() async throws {
        #expect(AppConstants.cornerRadius == 12)
        #expect(AppConstants.supportedAudioFormats.contains("wav"))
        #expect(AppConstants.supportedAudioFormats.contains("mp3"))
        #expect(AppConstants.maxFileSizeMB == 500)
    }
}

@Suite("AudioAnalysisService Tests")
struct AudioAnalysisServiceTests {
    
    @Test("AudioAnalysisService initialization")
    func serviceInit() async throws {
        let service = AudioAnalysisService()
        // Service should initialize without throwing
        #expect(true) // Just verify it doesn't crash
    }
    
    @Test("Analysis error descriptions")
    func analysisErrorDescriptions() async throws {
        let fileNotFoundError = AudioAnalysisService.AnalysisError.fileNotFound
        let unsupportedError = AudioAnalysisService.AnalysisError.unsupportedFormat
        
        #expect(fileNotFoundError.errorDescription?.isEmpty == false)
        #expect(unsupportedError.errorDescription?.isEmpty == false)
    }
}