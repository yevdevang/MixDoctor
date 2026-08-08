//
//  LocalVsClaudeComparisonTests.swift
//  MixDoctorTests
//
//  Ad-hoc comparison of ClaudeAPIService vs. LocalModelAnalysisService on the same
//  synthetic metrics, timing both and printing results side by side.
//  Requires RUN_CLAUDE_API_TESTS=1 (live network call to Claude) and, for the local
//  half, Apple Intelligence available on the host running the Simulator.
//

import XCTest
@testable import MixDoctor

final class LocalVsClaudeComparisonTests: XCTestCase {

    private var shouldSkip: Bool {
        ProcessInfo.processInfo.environment["RUN_CLAUDE_API_TESTS"] != "1"
    }

    func testCompareOnMasteredMetalTrack() async throws {
        try await compare(metrics: kornLikeMetrics(), userGenre: "Metal", mixStage: "Master(CD/Loud)", label: "Mastered Metal")
    }

    func testCompareOnDecentMix() async throws {
        try await compare(metrics: decentMixMetrics(), userGenre: "Rock", mixStage: "Mix", label: "Decent Rock Mix")
    }

    // MARK: - Comparison

    private func log(_ line: String) {
        print(line)
    }

    private func compare(metrics: AudioMetricsForClaude, userGenre: String, mixStage: String, label: String) async throws {
        guard !shouldSkip else { throw XCTSkip("Skipping - RUN_CLAUDE_API_TESTS not set") }

        log("\n══════════════════════════════════════════════")
        log("COMPARISON: \(label)")
        log("══════════════════════════════════════════════")

        let claudeStart = Date()
        do {
            let claudeResponse = try await ClaudeAPIService.shared.analyzeAudioMetrics(metrics, userGenre: userGenre, mixStage: mixStage)
            let claudeElapsed = Date().timeIntervalSince(claudeStart)
            log("CLAUDE — \(String(format: "%.2f", claudeElapsed))s")
            log("   Score: \(claudeResponse.score)")
            log("   Summary: \(claudeResponse.summary)")
            log("   Recommendations: \(claudeResponse.recommendations)")
            XCTAssertTrue((0...100).contains(claudeResponse.score))
        } catch {
            log("CLAUDE — FAILED: \(error.localizedDescription)")
        }

        if #available(iOS 26.0, *), LocalModelAnalysisService.isAvailable {
            let localStart = Date()
            do {
                let localResponse = try await LocalModelAnalysisService.shared.analyzeAudioMetrics(metrics, userGenre: userGenre, mixStage: mixStage)
                let localElapsed = Date().timeIntervalSince(localStart)
                log("LOCAL  — \(String(format: "%.2f", localElapsed))s")
                log("   Score: \(localResponse.score)")
                log("   Summary: \(localResponse.summary)")
                log("   Recommendations: \(localResponse.recommendations)")
                XCTAssertTrue((0...100).contains(localResponse.score))
            } catch {
                log("LOCAL  — FAILED: \(error.localizedDescription)")
            }
        } else {
            let reason: String
            if #available(iOS 26.0, *) {
                reason = LocalModelAnalysisService.unavailableReason ?? "unavailable"
            } else {
                reason = "requires iOS 26+"
            }
            log("LOCAL  — SKIPPED: \(reason)")
        }
        log("══════════════════════════════════════════════\n")
    }

    // MARK: - Fixtures (mirrors ClaudeAPIScoringIntegrationTests' presets)

    private func makeMetrics(
        genre: String?,
        stereoWidth: Double,
        phaseCoherence: Double,
        monoCompatibility: Double,
        peakLevel: Double,
        loudness: Double,
        dynamicRange: Double,
        lowEnd: Double,
        lowMid: Double,
        mid: Double,
        highMid: Double,
        high: Double,
        rmsLevel: Double,
        hasClipping: Bool = false
    ) -> AudioMetricsForClaude {
        AudioMetricsForClaude(
            genre: genre,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            loudness: loudness,
            dynamicRange: dynamicRange,
            stereoWidth: stereoWidth,
            phaseCoherence: phaseCoherence,
            monoCompatibility: monoCompatibility,
            lowEnd: lowEnd,
            lowMid: lowMid,
            mid: mid,
            highMid: highMid,
            high: high,
            subBassEnergy: lowEnd * 0.2,
            bassEnergy: lowEnd * 0.8,
            lowMidEnergy: lowMid,
            midEnergy: mid,
            highMidEnergy: highMid,
            presenceEnergy: high * 0.6,
            airEnergy: high * 0.4,
            balanceScore: 75.0,
            spectralTilt: 0.0,
            correlationCoefficient: 0.7,
            sideEnergy: 30.0,
            centerImage: 70.0,
            lufsRange: dynamicRange,
            crestFactor: 12.0,
            percentile95: loudness + 5.0,
            percentile5: loudness - 10.0,
            compressionRatio: 2.0,
            headroom: 1.0,
            peakToRmsRatio: 12.0,
            peakToLufsRatio: 13.0,
            truePeakLevel: peakLevel + 0.5,
            integratedLoudness: loudness,
            loudnessRange: dynamicRange,
            punchiness: 50.0,
            hasClipping: hasClipping,
            hasPhaseIssues: phaseCoherence < 0.50,
            hasStereoIssues: stereoWidth < 15.0 || stereoWidth > 95.0,
            hasFrequencyImbalance: false,
            hasDynamicRangeIssues: dynamicRange < 4.0 || dynamicRange > 16.0,
            isLikelyUnmixed: false,
            mixingQualityScore: 75.0,
            isProUser: false
        )
    }

    private func kornLikeMetrics() -> AudioMetricsForClaude {
        makeMetrics(
            genre: "Metal", stereoWidth: 98.0, phaseCoherence: 0.72, monoCompatibility: 0.65,
            peakLevel: 0.0, loudness: -7.0, dynamicRange: 5.0,
            lowEnd: 35.0, lowMid: 25.0, mid: 25.0, highMid: 10.0, high: 5.0, rmsLevel: -10.0
        )
    }

    private func decentMixMetrics() -> AudioMetricsForClaude {
        makeMetrics(
            genre: "Rock", stereoWidth: 25.0, phaseCoherence: 0.55, monoCompatibility: 0.60,
            peakLevel: -2.0, loudness: -10.0, dynamicRange: 7.0,
            lowEnd: 30.0, lowMid: 25.0, mid: 28.0, highMid: 12.0, high: 5.0, rmsLevel: -12.0
        )
    }
}
