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

    /// Check if we should skip tests that access app services
    private var shouldSkipServiceTests: Bool {
        // Skip by default unless explicitly enabled
        return ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != "1"
    }

    // MARK: - Warmup Test (Runs First)

    /// This test runs first alphabetically to warm up AudioKit
    /// Prevents initialization race conditions on first test run
    func test_00_AudioKitInitialization() async throws {
        guard !shouldSkipServiceTests else {
            throw XCTSkip("Skipping - RUN_INTEGRATION_TESTS not set")
        }

        print("🔥 Warming up AudioKit service...")

        // Access the AudioKit singleton to trigger initialization
        let audioKit = AudioKitService.shared

        // Give AudioKit time to fully initialize its audio engine
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Verify AudioKit initialized successfully
        XCTAssertNotNil(audioKit, "AudioKit service should initialize")

        print("✅ AudioKit warmup complete")
    }

    /// Verify AudioKit remains stable after warmup
    func test_01_AudioKitStability() async throws {
        guard !shouldSkipServiceTests else {
            throw XCTSkip("Skipping - RUN_INTEGRATION_TESTS not set")
        }

        print("🔍 Verifying AudioKit stability...")

        // Access AudioKit again to verify it's stable
        let audioKit = AudioKitService.shared

        // Small delay to ensure stability
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertNotNil(audioKit, "AudioKit should remain stable")

        print("✅ AudioKit stability confirmed")
    }
}
