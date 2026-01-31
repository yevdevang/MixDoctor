//
//  AudioFeatureExtractorTests.swift
//  MixDoctorTests
//
//  Unit tests for audio feature extraction
//

import XCTest
@testable import MixDoctor

final class AudioFeatureExtractorTests: XCTestCase {
    
    var extractor: AudioFeatureExtractor?
    
    override func setUp() {
        super.setUp()
        extractor = AudioFeatureExtractor()
        
        // Verify initialization completed successfully
        XCTAssertNotNil(extractor, "AudioFeatureExtractor should initialize")
    }
    
    override func tearDown() {
        // Clean up extractor instance
        extractor = nil
        super.tearDown()
    }
    
    // MARK: - Stereo Features Tests
    
    func testStereoFeatureExtraction_MonoSignal() {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Identical left and right channels (mono)
        let left = [Float](repeating: 1.0, count: 1000)
        let right = [Float](repeating: 1.0, count: 1000)
        
        // When
        let features = extractor.extractStereoFeatures(left: left, right: right)
        
        // Then
        // Mono signal should have stereo width of 0 (or very close to 0)
        XCTAssertGreaterThanOrEqual(features.stereoWidth, 0, "Mono signal should have 0 stereo width")
        XCTAssertLessThanOrEqual(features.stereoWidth, 0.1, "Mono signal should have near-zero stereo width")
        XCTAssertGreaterThan(features.correlation, 0.9, "Mono signal should have high correlation")
        XCTAssertEqual(features.leftRightBalance, 0, accuracy: 0.01, "Balanced signal should have 0 balance")
    }
    
    func testStereoFeatureExtraction_WideSignal() {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Different left and right channels (wide)
        let left = [Float](repeating: 1.0, count: 1000)
        let right = [Float](repeating: -1.0, count: 1000)
        
        // When
        let features = extractor.extractStereoFeatures(left: left, right: right)
        
        // Then
        XCTAssertGreaterThan(features.stereoWidth, 0)
        XCTAssertLessThanOrEqual(features.stereoWidth, 1)
        XCTAssertLessThan(features.correlation, 0, "Out of phase signal should have negative correlation")
    }
    
    func testStereoFeatureExtraction_ImbalancedSignal() {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Left louder than right
        let left = [Float](repeating: 1.0, count: 1000)
        let right = [Float](repeating: 0.5, count: 1000)
        
        // When
        let features = extractor.extractStereoFeatures(left: left, right: right)
        
        // Then
        XCTAssertLessThan(features.leftRightBalance, 0, "Left-heavy signal should have negative balance")
    }
    
    // MARK: - Loudness Features Tests
    
    func testLoudnessFeatureExtraction() {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Test signal with known properties
        let left = [Float](repeating: 0.5, count: 1000)
        let right = [Float](repeating: 0.5, count: 1000)
        
        // When
        let features = extractor.extractLoudnessFeatures(left: left, right: right)
        
        // Then
        XCTAssertGreaterThan(features.rmsLevel, 0)
        XCTAssertGreaterThan(features.peakLevel, 0)
        XCTAssertGreaterThan(features.crestFactor, 0)
        XCTAssertNotEqual(features.lufs, 0)
    }
    
    func testLoudnessFeatureExtraction_SilentSignal() {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Silent signal
        let left = [Float](repeating: 0, count: 1000)
        let right = [Float](repeating: 0, count: 1000)
        
        // When
        let features = extractor.extractLoudnessFeatures(left: left, right: right)
        
        // Then
        XCTAssertEqual(features.rmsLevel, 0)
        XCTAssertEqual(features.peakLevel, 0)
    }
    
    // MARK: - Frequency Features Tests
    
    func testFrequencyFeatureExtraction() throws {
        guard let extractor = extractor else {
            XCTFail("Extractor not initialized")
            return
        }
        
        // Given: Test signal at 440 Hz (A4)
        let sampleRate: Double = 44100
        let frequency: Float = 440
        let duration: Float = 1.0
        let sampleCount = Int(sampleRate * Double(duration))
        
        var audio = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let time = Float(i) / Float(sampleRate)
            audio[i] = sin(2.0 * .pi * frequency * time)
        }
        
        // When
        let features = try extractor.extractFrequencyFeatures(audio: audio, sampleRate: sampleRate)
        
        // Then
        XCTAssertFalse(features.spectrum.isEmpty)
        XCTAssertFalse(features.frequencyBands.isEmpty)
        XCTAssertGreaterThan(features.spectralCentroid, 0)
        XCTAssertGreaterThanOrEqual(features.spectralFlatness, 0)
        XCTAssertLessThanOrEqual(features.spectralFlatness, 1)
    }
}
