//
//  StageMismatchDetectionTests.swift
//  MixDoctorTests
//
//  Tests for the stage-mismatch detection flow introduced in
//  commit 74f9a9b ("fix: Improve handling of mislabeled masters and scoring logic").
//
//  These tests cover:
//  1. ClaudeAPIService.detectMasteredTrack() — the gate used by AudioKitService
//     to decide whether a user-selected stage matches the audio metrics.
//     Each of the four professional mastering profiles is exercised
//     (Professional Dynamic, Streaming-Optimized, Competitive Loud,
//     Balanced Commercial) plus negative / boundary cases.
//  2. AnalysisResult.stageMismatch — the new persisted field that records
//     whether a mismatch was detected ("master", "mix", or nil).
//

import XCTest
@testable import MixDoctor

final class StageMismatchDetectionTests: XCTestCase {

    var claudeService: ClaudeAPIService!

    override func setUp() {
        super.setUp()
        claudeService = ClaudeAPIService.shared
        claudeService.reset()
    }

    override func tearDown() {
        claudeService?.reset()
        claudeService = nil
        super.tearDown()
    }

    // MARK: - Test Data Builder

    /// Creates mock audio metrics with only the fields relevant to
    /// `detectMasteredTrack()` exposed as parameters. All other fields
    /// are set to neutral defaults.
    private func makeMetrics(
        loudness: Double,
        peakLevel: Double,
        dynamicRange: Double,
        isLikelyUnmixed: Bool = false
    ) -> AudioMetricsForClaude {
        return AudioMetricsForClaude(
            genre: nil,
            peakLevel: peakLevel,
            rmsLevel: -12.0,
            loudness: loudness,
            dynamicRange: dynamicRange,
            stereoWidth: 35.0,
            phaseCoherence: 65.0,
            monoCompatibility: 0.6,
            lowEnd: 25.0,
            lowMid: 20.0,
            mid: 30.0,
            highMid: 15.0,
            high: 10.0,
            subBassEnergy: 5.0,
            bassEnergy: 20.0,
            lowMidEnergy: 20.0,
            midEnergy: 30.0,
            highMidEnergy: 15.0,
            presenceEnergy: 8.0,
            airEnergy: 2.0,
            balanceScore: 75.0,
            spectralTilt: 0.0,
            correlationCoefficient: 0.7,
            sideEnergy: 30.0,
            centerImage: 70.0,
            lufsRange: 8.0,
            crestFactor: 12.0,
            percentile95: -6.0,
            percentile5: -20.0,
            compressionRatio: 2.0,
            headroom: 1.0,
            peakToRmsRatio: 12.0,
            peakToLufsRatio: 13.0,
            truePeakLevel: peakLevel,
            integratedLoudness: loudness,
            loudnessRange: dynamicRange,
            punchiness: 50.0,
            hasClipping: false,
            hasPhaseIssues: false,
            hasStereoIssues: false,
            hasFrequencyImbalance: false,
            hasDynamicRangeIssues: false,
            isLikelyUnmixed: isLikelyUnmixed,
            mixingQualityScore: 75.0,
            isProUser: false
        )
    }

    // MARK: - detectMasteredTrack — positive profiles

    /// Abbey Road / audiophile style: dynamic, -15 LUFS, DR 15, peaks near 0.
    func testDetectMasteredTrack_ProfessionalDynamic() {
        let metrics = makeMetrics(loudness: -15.0, peakLevel: -0.5, dynamicRange: 15.0)
        XCTAssertTrue(
            claudeService.detectMasteredTrack(metrics),
            "A -15 LUFS / DR 15 / peak -0.5 track should be detected as a Professional Dynamic master"
        )
    }

    /// Streaming sweet spot: -15 LUFS, DR 10, peak -1.0.
    func testDetectMasteredTrack_StreamingOptimized() {
        let metrics = makeMetrics(loudness: -15.0, peakLevel: -1.0, dynamicRange: 10.0)
        XCTAssertTrue(
            claudeService.detectMasteredTrack(metrics),
            "A -15 LUFS / DR 10 / peak -1.0 track should be detected as a Streaming-Optimized master"
        )
    }

    /// Modern pop / EDM: -8 LUFS, DR 6, peak -0.5.
    func testDetectMasteredTrack_CompetitiveLoud() {
        let metrics = makeMetrics(loudness: -8.0, peakLevel: -0.5, dynamicRange: 6.0)
        XCTAssertTrue(
            claudeService.detectMasteredTrack(metrics),
            "A -8 LUFS / DR 6 / peak -0.5 track should be detected as a Competitive Loud master"
        )
    }

    /// Balanced commercial release: -11 LUFS, DR 10, peak -1.0.
    func testDetectMasteredTrack_BalancedCommercial() {
        let metrics = makeMetrics(loudness: -11.0, peakLevel: -1.0, dynamicRange: 10.0)
        XCTAssertTrue(
            claudeService.detectMasteredTrack(metrics),
            "A -11 LUFS / DR 10 / peak -1.0 track should be detected as a Balanced Commercial master"
        )
    }

    // MARK: - detectMasteredTrack — negative / boundary cases

    /// Quiet amateur mix with wide dynamics — matches none of the four profiles.
    func testDetectMasteredTrack_AmateurMix_NotDetected() {
        let metrics = makeMetrics(loudness: -22.0, peakLevel: -6.0, dynamicRange: 18.0)
        XCTAssertFalse(
            claudeService.detectMasteredTrack(metrics),
            "A quiet, wide-DR amateur mix should NOT be detected as mastered"
        )
    }

    /// If the unmixed flag is set, `detectMasteredTrack` must short-circuit to false
    /// regardless of how professional the other metrics look.
    func testDetectMasteredTrack_UnmixedFlag_ReturnsFalse() {
        // Metrics that would otherwise match Balanced Commercial
        let metrics = makeMetrics(
            loudness: -11.0,
            peakLevel: -1.0,
            dynamicRange: 10.0,
            isLikelyUnmixed: true
        )
        XCTAssertFalse(
            claudeService.detectMasteredTrack(metrics),
            "isLikelyUnmixed=true must force detectMasteredTrack to return false"
        )
    }

    /// -20 LUFS is below the loudness floor of every profile (-18 is the lowest).
    func testDetectMasteredTrack_BelowLoudnessFloor() {
        let metrics = makeMetrics(loudness: -20.0, peakLevel: -1.0, dynamicRange: 12.0)
        XCTAssertFalse(
            claudeService.detectMasteredTrack(metrics),
            "-20 LUFS is below every profile's loudness floor and must not be detected as mastered"
        )
    }

    /// Peak level -3.0 dBFS fails both the Professional Dynamic (> -3) and
    /// Streaming (> -2) peak thresholds; loudness -15 disqualifies Balanced/Competitive.
    func testDetectMasteredTrack_LowPeakBoundary() {
        let metrics = makeMetrics(loudness: -15.0, peakLevel: -3.0, dynamicRange: 15.0)
        XCTAssertFalse(
            claudeService.detectMasteredTrack(metrics),
            "Peak -3.0 dBFS with -15 LUFS should not match any mastering profile"
        )
    }

    // MARK: - AnalysisResult.stageMismatch field

    func testAnalysisResult_StageMismatchDefaultsToNil() {
        let result = AnalysisResult(audioFile: nil)
        XCTAssertNil(
            result.stageMismatch,
            "A freshly initialised AnalysisResult must have stageMismatch == nil"
        )
    }

    func testAnalysisResult_StageMismatchCanStoreMaster() {
        let result = AnalysisResult(audioFile: nil)
        result.stageMismatch = "master"
        XCTAssertEqual(result.stageMismatch, "master")
    }

    func testAnalysisResult_StageMismatchCanStoreMix() {
        let result = AnalysisResult(audioFile: nil)
        result.stageMismatch = "mix"
        XCTAssertEqual(result.stageMismatch, "mix")
    }
}
