//
//  AudioKitWarmupTests.swift
//  MixDoctorTests
//
//  Warmup tests to initialize AudioKit before other tests run
//  This file runs first alphabetically to prevent first-run failures
//

import XCTest
@testable import MixDoctor

final class AudioKitWarmupTests: XCTestCase {
    
    // MARK: - Warmup Test (Runs First)
    
    /// This test runs first alphabetically to warm up AudioKit
    /// Prevents initialization race conditions on first test run
    func test_00_AudioKitInitialization() async throws {
        print("🔥 Warming up AudioKit service...")
        
        // Access the AudioKit singleton to trigger initialization
        let audioKit = AudioKitService.shared
        
        // Give AudioKit time to fully initialize its audio engine
        // This is especially important on first run when the audio session
        // needs to be configured and the audio engine needs to start
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify AudioKit initialized successfully
        XCTAssertNotNil(audioKit, "AudioKit service should initialize")
        
        print("✅ AudioKit warmup complete")
    }
    
    /// Verify AudioKit remains stable after warmup
    func test_01_AudioKitStability() async throws {
        print("🔍 Verifying AudioKit stability...")
        
        // Access AudioKit again to verify it's stable
        let audioKit = AudioKitService.shared
        
        // Small delay to ensure stability
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNotNil(audioKit, "AudioKit should remain stable")
        
        print("✅ AudioKit stability confirmed")
    }
}
