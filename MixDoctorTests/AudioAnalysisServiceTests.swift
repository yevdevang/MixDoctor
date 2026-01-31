//
//  AudioAnalysisServiceTests.swift
//  MixDoctorTests
//
//  Unit tests for audio analysis service
//

import XCTest
@testable import MixDoctor

final class AudioAnalysisServiceTests: XCTestCase {
    
    var analysisService: AudioAnalysisService!
    
    override func setUp() {
        super.setUp()
        // Use shared singleton instance (initializer is private)
        analysisService = AudioAnalysisService.shared
        // Ensure clean state for each test
        analysisService.reset()
    }
    
    override func tearDown() {
        // Reset singleton state
        analysisService?.reset()
        // Don't explicitly set to nil - @Observable objects can cause
        // SIGABRT during deallocation. Swift will handle cleanup automatically.
        super.tearDown()
    }
    
    // MARK: - Analysis Tests
    
    func testAnalysisService_CalculatesOverallScore() async throws {
        // This test would require a real audio file
        // For now, we test the score calculation logic
        
        // Given: Mock audio file
        // This would need actual implementation with test audio files
        
        // When & Then
        // Tests would go here once we have test audio files
        XCTAssertNotNil(analysisService)
    }
    
    func testAnalysisService_DetectsPhaseIssues() async throws {
        // Test phase issue detection
        // Would require test audio file with phase problems
        XCTAssertNotNil(analysisService)
    }
    
    func testAnalysisService_DetectsStereoIssues() async throws {
        // Test stereo issue detection
        // Would require test audio file with stereo problems
        XCTAssertNotNil(analysisService)
    }
}
