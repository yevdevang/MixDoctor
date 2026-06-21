//
//  DeterministicScoreEngineTests.swift
//  MixDoctorTests
//
//  Ground-truth regression set for the deterministic scorer.
//
//  Each test encodes a *reference track* with known characteristics and an
//  expected score RANGE. Because the engine is pure and deterministic, these
//  run instantly with NO network / NO API key. Change a rubric number, run the
//  suite, and see exactly which references move — this is the safety net the
//  LLM-only system never had.
//

import XCTest
@testable import MixDoctor

final class DeterministicScoreEngineTests: XCTestCase {

    private let engine = DeterministicScoreEngine()

    // MARK: - Metric Builder

    /// Builds metrics with sensible defaults; override only what a case needs.
    /// `loudness`/`integratedLoudness` are kept in sync unless overridden.
    private func metrics(
        genre: String? = nil,
        peakLevel: Double = -1.0,
        truePeakLevel: Double = -1.2,
        rmsLevel: Double = -12.0,
        loudness: Double = -14.0,
        integratedLoudness: Double? = nil,
        dynamicRange: Double = 9.0,
        stereoWidth: Double = 35.0,
        phaseCoherence: Double = 0.6,
        monoCompatibility: Double = 0.7,
        lowEnd: Double = 25, lowMid: Double = 20, mid: Double = 30,
        highMid: Double = 15, high: Double = 10,
        hasClipping: Bool = false,
        isLikelyUnmixed: Bool = false
    ) -> AudioMetricsForClaude {
        AudioMetricsForClaude(
            genre: genre,
            peakLevel: peakLevel, rmsLevel: rmsLevel, loudness: loudness,
            dynamicRange: dynamicRange,
            stereoWidth: stereoWidth, phaseCoherence: phaseCoherence,
            monoCompatibility: monoCompatibility,
            lowEnd: lowEnd, lowMid: lowMid, mid: mid, highMid: highMid, high: high,
            subBassEnergy: 5, bassEnergy: 20, lowMidEnergy: 20, midEnergy: 30,
            highMidEnergy: 15, presenceEnergy: 8, airEnergy: 2,
            balanceScore: 75, spectralTilt: 0,
            correlationCoefficient: phaseCoherence, sideEnergy: 30, centerImage: 70,
            lufsRange: dynamicRange, crestFactor: 12, percentile95: -6, percentile5: -20,
            compressionRatio: 2, headroom: 1,
            peakToRmsRatio: 12, peakToLufsRatio: 13,
            truePeakLevel: truePeakLevel,
            integratedLoudness: integratedLoudness ?? loudness,
            loudnessRange: dynamicRange, punchiness: 50,
            hasClipping: hasClipping, hasPhaseIssues: phaseCoherence < 0.4,
            hasStereoIssues: stereoWidth < 15 || stereoWidth > 95,
            hasFrequencyImbalance: false,
            hasDynamicRangeIssues: dynamicRange < 4 || dynamicRange > 20,
            isLikelyUnmixed: isLikelyUnmixed, mixingQualityScore: 75, isProUser: false
        )
    }

    private func assertScore(_ result: DeterministicScoreResult,
                             in range: ClosedRange<Int>,
                             _ label: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(range.contains(result.score),
                      "\(label): expected \(range), got \(result.score)\n\(result.breakdown)",
                      file: file, line: line)
    }

    // MARK: - Reference Masters (expect 85–100)

    func test_pop_master_streaming() {
        // Daft Punk "Get Lucky"–style: -10 LUFS, DR ~8, clean, mono-safe.
        let m = metrics(genre: "Pop", peakLevel: -1.0, loudness: -9.0,
                        dynamicRange: 8.0, phaseCoherence: 0.55, monoCompatibility: 0.75)
        let r = engine.score(m, trackType: .mastered)
        assertScore(r, in: 88...100, "Pop streaming master")
    }

    func test_metal_loud_master_not_penalized_for_low_DR() {
        // Korn-style: -7 LUFS, DR 5 — INDUSTRY STANDARD, must NOT be punished.
        let m = metrics(genre: "Metal", peakLevel: -1.0, loudness: -7.0,
                        dynamicRange: 5.0, phaseCoherence: 0.5, monoCompatibility: 0.6,
                        lowEnd: 30, lowMid: 25, mid: 25, highMid: 12, high: 8)
        let r = engine.score(m, trackType: .mastered)
        assertScore(r, in: 85...100, "Metal loud master")
    }

    func test_classical_dynamic_master() {
        // Quiet, very dynamic, wide — must score high, NOT be flagged as too quiet.
        let m = metrics(genre: "Classical", peakLevel: -2.0, truePeakLevel: -2.2,
                        loudness: -19.0, dynamicRange: 15.0,
                        stereoWidth: 70, phaseCoherence: 0.3, monoCompatibility: 0.5)
        let r = engine.score(m, trackType: .mastered)
        assertScore(r, in: 85...100, "Classical dynamic master")
    }

    // MARK: - Penalized Masters (technical faults)

    func test_clipping_master_is_penalized() {
        let m = metrics(genre: "Pop", peakLevel: 0.5, loudness: -9.0,
                        dynamicRange: 8.0, hasClipping: true)
        let r = engine.score(m, trackType: .mastered)
        XCTAssertLessThan(r.score, 95, "Clipping master should lose points\n\(r.breakdown)")
    }

    func test_mono_incompatible_master_is_penalized() {
        // Phase/mono collapse — a real fault even on an otherwise loud master.
        let m = metrics(genre: "Pop", peakLevel: -1.0, loudness: -9.0, dynamicRange: 8.0,
                        phaseCoherence: 0.1, monoCompatibility: 0.2)
        let r = engine.score(m, trackType: .mastered)
        XCTAssertLessThan(r.score, 90, "Mono-incompatible master should lose points\n\(r.breakdown)")
    }

    // MARK: - Pre-Master Mixes (expect ≤90)

    func test_good_premaster_never_exceeds_90() {
        let m = metrics(genre: "Rock", peakLevel: -4.0, loudness: -18.0,
                        dynamicRange: 12.0, phaseCoherence: 0.6, monoCompatibility: 0.7)
        let r = engine.score(m, trackType: .preMaster)
        XCTAssertLessThanOrEqual(r.score, 90, "Pre-master must cap at 90\n\(r.breakdown)")
        assertScore(r, in: 78...90, "Good rock pre-master")
    }

    func test_weak_premaster_scores_low_no_floor() {
        // Off-target loudness, narrow, phase problems — should land well below pro.
        let m = metrics(genre: "Pop", peakLevel: -0.5, loudness: -6.0,
                        dynamicRange: 3.0, stereoWidth: 8, phaseCoherence: 0.25,
                        monoCompatibility: 0.35)
        let r = engine.score(m, trackType: .preMaster)
        assertScore(r, in: 50...80, "Weak pre-master")
    }

    // MARK: - Unmixed (expect ≤75)

    func test_clean_raw_recording_caps_at_75() {
        let m = metrics(peakLevel: -4.0, loudness: -20.0, dynamicRange: 18.0,
                        phaseCoherence: 0.5, isLikelyUnmixed: true)
        let r = engine.score(m, trackType: .unmixed)
        XCTAssertLessThanOrEqual(r.score, 75, "Unmixed must cap at 75\n\(r.breakdown)")
        assertScore(r, in: 68...75, "Clean raw recording")
    }

    func test_clipped_raw_recording_scores_poorly() {
        let m = metrics(peakLevel: 1.0, loudness: -18.0, phaseCoherence: 0.15,
                        hasClipping: true, isLikelyUnmixed: true)
        let r = engine.score(m, trackType: .unmixed)
        assertScore(r, in: 0...55, "Clipped raw recording")
    }

    func test_unmixed_high_dynamic_range_not_penalized() {
        // High DR is GOOD for unmixed — must not drag the score down.
        let highDR = engine.score(metrics(peakLevel: -4.0, dynamicRange: 22.0,
                                           phaseCoherence: 0.5, isLikelyUnmixed: true),
                                  trackType: .unmixed)
        let normalDR = engine.score(metrics(peakLevel: -4.0, dynamicRange: 10.0,
                                             phaseCoherence: 0.5, isLikelyUnmixed: true),
                                    trackType: .unmixed)
        XCTAssertEqual(highDR.score, normalDR.score,
                       "High DR must not penalize unmixed tracks\n\(highDR.breakdown)")
    }

    // MARK: - Determinism & Consistency (the whole point)

    func test_same_input_same_score_every_time() {
        let m = metrics(genre: "Pop", loudness: -9.0, dynamicRange: 8.0)
        let scores = (0..<10).map { _ in engine.score(m, trackType: .mastered).score }
        XCTAssertEqual(Set(scores).count, 1, "Engine must be deterministic; got \(Set(scores))")
    }

    func test_genre_toggle_does_not_swing_score_wildly() {
        // The current LLM system BEGS for this in all-caps and can't guarantee it.
        // Here it's a hard test: same metrics, different genre labels, ≤8 pt spread.
        let base = metrics(peakLevel: -1.0, loudness: -9.0, dynamicRange: 8.0,
                           phaseCoherence: 0.55, monoCompatibility: 0.7)
        let genres = ["Pop", "Rock", "Hip-Hop", "Electronic"]
        let scores = genres.map { g in
            engine.score(metricsWithGenre(base, g), trackType: .mastered).score
        }
        let spread = (scores.max() ?? 0) - (scores.min() ?? 0)
        XCTAssertLessThanOrEqual(spread, 8,
            "Genre toggle should not swing score wildly; scores=\(Dictionary(uniqueKeysWithValues: zip(genres, scores)))")
    }

    /// Rebuilds metrics with a different genre (struct is immutable / let-only).
    private func metricsWithGenre(_ m: AudioMetricsForClaude, _ genre: String) -> AudioMetricsForClaude {
        metrics(genre: genre, peakLevel: m.peakLevel, loudness: m.loudness,
                dynamicRange: m.dynamicRange, phaseCoherence: m.phaseCoherence,
                monoCompatibility: m.monoCompatibility)
    }

    // MARK: - Breakdown is populated (auditability)

    func test_breakdown_traces_every_point() {
        let m = metrics(genre: "Pop", peakLevel: 0.5, loudness: -9.0,
                        dynamicRange: 8.0, hasClipping: true)
        let r = engine.score(m, trackType: .mastered)
        XCTAssertFalse(r.adjustments.isEmpty, "Breakdown must explain the score")
        XCTAssertTrue(r.breakdown.contains("Clipping"), "Breakdown should name the clipping penalty")
    }
}
