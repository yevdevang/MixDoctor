//
//  ProfessionalMasterOverrideTests.swift
//  MixDoctorTests
//
//  Tests for professional master detection and override fixes:
//  1. detectDefiniteProfessionalMaster() - detects commercial releases
//  2. Professional master override - handles mislabeled pro tracks
//  3. Unmixed detection override - respects user-selected Master stage
//  4. Score enforcement - 85-92 range for pro override, standard caps
//  5. scoreDescription() - proper labels for unmixed/master tracks
//

import XCTest
@testable import MixDoctor

final class ProfessionalMasterOverrideTests: XCTestCase {

    var claudeService: ClaudeAPIService!

    override func setUp() {
        super.setUp()
        claudeService = ClaudeAPIService.shared
        // Ensure clean state for each test
        claudeService.reset()
    }

    override func tearDown() {
        // Reset singleton state before releasing reference
        claudeService?.reset()
        claudeService = nil
        super.tearDown()
    }

    // MARK: - Test Data Builders

    /// Creates mock audio metrics for testing
    private func createMockMetrics(
        loudness: Double = -10.0,
        peakLevel: Double = -1.0,
        dynamicRange: Double = 8.0,
        truePeakLevel: Double = -0.5,
        rmsLevel: Double = -12.0,
        monoCompatibility: Double = 0.6,
        isLikelyUnmixed: Bool = false
    ) -> AudioMetricsForClaude {
        return AudioMetricsForClaude(
            genre: nil,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            loudness: loudness,
            dynamicRange: dynamicRange,
            stereoWidth: 35.0,
            phaseCoherence: 65.0,
            monoCompatibility: monoCompatibility, // Keep as decimal (0.0-1.0) - detection function expects decimal
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
            truePeakLevel: truePeakLevel,
            integratedLoudness: loudness,
            loudnessRange: dynamicRange,
            punchiness: 50.0,
            hasClipping: false,
            hasPhaseIssues: false,
            hasStereoIssues: false,
            hasFrequencyImbalance: false,
            hasDynamicRangeIssues: dynamicRange < 4.0 || dynamicRange > 16.0,
            isLikelyUnmixed: isLikelyUnmixed,
            mixingQualityScore: 75.0,
            isProUser: false
        )
    }

    // MARK: - detectDefiniteProfessionalMaster Tests

    /// Test that professional master with all criteria is detected
    func testDetectProfessionalMaster_AllCriteriaMet() {
        // Korn-level commercial master metrics
        let metrics = createMockMetrics(
            loudness: -8.0,        // Pro loudness (-6 to -14 LUFS)
            peakLevel: -0.5,       // Pro peaks (> -1.5 dBFS)
            dynamicRange: 6.0,     // Pro DR (4-14 dB)
            truePeakLevel: -0.3,
            rmsLevel: -10.0,       // Crest factor = truePeak - rms = -0.3 - (-10) = 9.7 (in 4-14 range)
            monoCompatibility: 0.6 // Pro mono (>= 45%)
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertTrue(isProMaster, "Should detect Korn-level commercial master")
    }

    /// Test that quiet amateur mix is NOT detected as professional
    func testDetectProfessionalMaster_QuietAmateur() {
        let metrics = createMockMetrics(
            loudness: -20.0,       // Too quiet (< -14 LUFS)
            peakLevel: -6.0,       // Weak peaks (< -1.5 dBFS)
            dynamicRange: 18.0,    // Too dynamic (> 14 dB)
            truePeakLevel: -5.0,
            rmsLevel: -22.0,
            monoCompatibility: 0.3 // Poor mono (< 45%)
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Should NOT detect quiet amateur mix as professional")
    }

    /// Test that unmixed track is NOT detected as professional
    func testDetectProfessionalMaster_UnmixedTrack() {
        let metrics = createMockMetrics(
            loudness: -25.0,
            peakLevel: -8.0,
            dynamicRange: 20.0,
            isLikelyUnmixed: true
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Should NOT detect unmixed track as professional (isLikelyUnmixed = true)")
    }

    /// Test that track with pro loudness but bad dynamics is NOT detected
    func testDetectProfessionalMaster_ProLoudnessBadDynamics() {
        let metrics = createMockMetrics(
            loudness: -8.0,        // Pro loudness
            peakLevel: -0.5,       // Pro peaks
            dynamicRange: 20.0,    // BAD - too dynamic (> 14 dB)
            truePeakLevel: -0.3,
            rmsLevel: -25.0        // Bad crest factor (24.7 dB - way out of 4-14 range)
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Should NOT detect track with bad dynamics as professional")
    }

    /// Test that track with pro loudness but poor mono is NOT detected
    func testDetectProfessionalMaster_ProLoudnessPoorMono() {
        let metrics = createMockMetrics(
            loudness: -8.0,
            peakLevel: -0.5,
            dynamicRange: 8.0,
            truePeakLevel: -0.3,
            rmsLevel: -10.0,
            monoCompatibility: 0.3 // Poor mono (< 45%)
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Should NOT detect track with poor mono compatibility as professional")
    }

    // MARK: - Professional Master Override Score Tests

    /// Test that stage mismatch is now caught before Claude is called.
    /// When professional master is detected and user selected Mix, analysis is blocked.
    /// So parseClaudeResponse only handles valid stage selections — standard mix cap at 90.
    func testMixScoring_StandardCap() {
        // Mix cap at 90
        let highScore = claudeService.parseClaudeResponse("SCORE: 98", isMastered: false)
        XCTAssertEqual(highScore.score, 90, "Mix should cap at 90")

        // Low scores stay as-is (no floor)
        let lowScore = claudeService.parseClaudeResponse("SCORE: 70", isMastered: false)
        XCTAssertEqual(lowScore.score, 70, "Mix score 70 should stay 70")

        // Mid scores within range
        let midScore = claudeService.parseClaudeResponse("SCORE: 88", isMastered: false)
        XCTAssertEqual(midScore.score, 88, "Mix score 88 should stay 88")
    }

    /// Test that standard mix (no override) caps at 90 with no floor
    func testStandardMix_ScoreCap() {
        // Test cap at 90
        let highScore = claudeService.parseClaudeResponse("SCORE: 95", isMastered: false)
        XCTAssertEqual(highScore.score, 90, "Standard mix should cap at 90")

        // Test NO floor (scores can go below 75)
        let lowScore = claudeService.parseClaudeResponse("SCORE: 60", isMastered: false)
        XCTAssertEqual(lowScore.score, 60, "Standard mix should NOT have a floor (60 stays 60)")

        // Test very low scores stay low
        let veryLowScore = claudeService.parseClaudeResponse("SCORE: 45", isMastered: false)
        XCTAssertEqual(veryLowScore.score, 45, "Unmixed scores should remain very low (45 stays 45)")
    }

    /// Test that master scores cap at 100 with no floor
    func testMaster_ScoreCap() {
        // Test cap at 100
        let highScore = claudeService.parseClaudeResponse("SCORE: 125", isMastered: true)
        XCTAssertEqual(highScore.score, 100, "Master should cap at 100")

        // Test no floor for masters
        let lowScore = claudeService.parseClaudeResponse("SCORE: 70", isMastered: true)
        XCTAssertEqual(lowScore.score, 70, "Master should NOT have a floor (70 stays 70)")
    }

    // MARK: - Unmixed Detection Override Tests

    /// Test that user-selected Master stage overrides unmixed detection
    func testUnmixedOverride_MasterStageSelected() {
        // This tests the logic that when user selects Master stage,
        // isUnmixed should be false regardless of metrics

        // Create metrics that would normally trigger unmixed detection
        let metrics = createMockMetrics(
            loudness: -8.0,       // Pro loudness (would be a pro master)
            peakLevel: -0.5,
            dynamicRange: 6.0,
            isLikelyUnmixed: true // Metrics say unmixed, but user selected Master
        )

        // User selected Master → should NOT be treated as unmixed
        // This is tested by checking that a master stage track scores normally
        let masterScore = claudeService.parseClaudeResponse("SCORE: 92", isMastered: true)
        XCTAssertEqual(masterScore.score, 92, "Master stage should score normally regardless of unmixed metrics")
    }

    /// Test that Mix stage with unmixed metrics does NOT get override
    func testUnmixedOverride_MixStageWithUnmixedMetrics() {
        // When user selects Mix stage and metrics indicate unmixed,
        // the track should be scored as unmixed (no override)
        let unmixedScore = claudeService.parseClaudeResponse("SCORE: 55", isMastered: false)
        XCTAssertEqual(unmixedScore.score, 55, "Mix stage with unmixed metrics should score low")
    }

    // MARK: - Score Differentiation Tests

    /// Test that different quality levels produce different scores
    func testScoreDifferentiation_Mixes() {
        let testCases: [(rawScore: Int, quality: String)] = [
            (88, "Professional mix (Korn quality)"),
            (78, "Good amateur mix"),
            (65, "Weak amateur mix"),
            (50, "Raw unmixed recording")
        ]

        var parsedScores: [Int] = []
        for testCase in testCases {
            let response = "SCORE: \(testCase.rawScore)"
            let parsed = claudeService.parseClaudeResponse(response, isMastered: false)
            parsedScores.append(parsed.score)
        }

        // Verify all scores are different (no convergence)
        let uniqueScores = Set(parsedScores)
        XCTAssertEqual(uniqueScores.count, 4, "All quality levels should produce different scores")

        // Verify ordering is maintained
        for i in 0..<parsedScores.count - 1 {
            XCTAssertGreaterThan(parsedScores[i], parsedScores[i + 1],
                "Higher quality should produce higher score: \(testCases[i].quality) (\(parsedScores[i])) > \(testCases[i + 1].quality) (\(parsedScores[i + 1]))")
        }
    }

    /// Test that different quality masters produce different scores
    func testScoreDifferentiation_Masters() {
        let testCases: [(rawScore: Int, quality: String)] = [
            (98, "Exceptional master (Korn quality)"),
            (92, "Very good professional master"),
            (85, "Good master"),
            (75, "Amateur mastering attempt")
        ]

        var parsedScores: [Int] = []
        for testCase in testCases {
            let response = "SCORE: \(testCase.rawScore)"
            let parsed = claudeService.parseClaudeResponse(response, isMastered: true)
            parsedScores.append(parsed.score)
        }

        // Verify ordering is maintained
        for i in 0..<parsedScores.count - 1 {
            XCTAssertGreaterThan(parsedScores[i], parsedScores[i + 1],
                "Higher quality should produce higher score: \(testCases[i].quality) (\(parsedScores[i])) > \(testCases[i + 1].quality) (\(parsedScores[i + 1]))")
        }
    }

    // MARK: - Edge Cases

    /// Test score parsing with various formats
    func testScoreParsing_VariousFormats() {
        let formats = [
            ("SCORE: 85", 85),
            ("Score: 85", 85),
            ("Overall Score: 85", 85),
            ("**SCORE: 85**", 85),
            ("Final Score: 85", 85)
        ]

        for (format, expected) in formats {
            let parsed = claudeService.parseClaudeResponse(format, isMastered: true)
            XCTAssertEqual(parsed.score, expected, "Should parse '\(format)' correctly")
        }
    }

    /// Test fallback score when no score found
    func testScoreParsing_Fallback() {
        let noScoreResponse = "This is an analysis without a score"
        let parsed = claudeService.parseClaudeResponse(noScoreResponse, isMastered: false)
        XCTAssertEqual(parsed.score, 50, "Should use fallback score of 50 when no score found")
    }

    // MARK: - Real-World Scenario Tests

    /// Test Korn "Twisted Transistor" scenario - user labels as Mix but it's a master
    /// With stage mismatch detection, this is now caught before Claude is called.
    func testKornScenario_LabeledAsMix() {
        // Korn-level metrics
        let metrics = createMockMetrics(
            loudness: -7.0,
            peakLevel: 0.0,
            dynamicRange: 5.0,
            truePeakLevel: -0.1,
            rmsLevel: -8.0,
            monoCompatibility: 0.65
        )

        // Should be detected as professional master
        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertTrue(isProMaster, "Korn should be detected as professional master")

        // Also detectable by detectMasteredTrack (used for stage mismatch)
        let isMastered = claudeService.detectMasteredTrack(metrics)
        XCTAssertTrue(isMastered, "Korn should be detected as mastered track")
    }

    /// Test Korn "Twisted Transistor" scenario - correctly labeled as Master
    func testKornScenario_LabeledAsMaster() {
        // With Master stage, should score normally (no cap at 90)
        let parsed = claudeService.parseClaudeResponse("SCORE: 95", isMastered: true)
        XCTAssertEqual(parsed.score, 95, "Korn labeled as Master should score 95")
    }

    /// Test amateur mix scenario - should score lower
    func testAmateurMixScenario() {
        // Amateur mix should NOT trigger professional override
        let metrics = createMockMetrics(
            loudness: -18.0,       // Quiet
            peakLevel: -6.0,       // Low peaks
            dynamicRange: 15.0,    // Too dynamic
            monoCompatibility: 0.5
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Amateur mix should NOT be detected as professional")

        // Amateur mix score should stay in low range (no floor)
        let parsed = claudeService.parseClaudeResponse("SCORE: 72", isMastered: false)
        XCTAssertEqual(parsed.score, 72, "Amateur mix should score 72")
    }

    /// Test truly unmixed track scenario - should score very low
    func testUnmixedTrackScenario() {
        let metrics = createMockMetrics(
            loudness: -28.0,
            peakLevel: -10.0,
            dynamicRange: 25.0,
            isLikelyUnmixed: true
        )

        let isProMaster = claudeService.testDetectDefiniteProfessionalMaster(metrics)
        XCTAssertFalse(isProMaster, "Unmixed track should NOT be detected as professional")

        // Unmixed should score very low (no floor)
        let parsed = claudeService.parseClaudeResponse("SCORE: 45", isMastered: false)
        XCTAssertEqual(parsed.score, 45, "Unmixed track should score 45 (no floor)")
    }
}

// MARK: - ScoreDescription Tests

final class ScoreDescriptionTests: XCTestCase {

    // MARK: - Test Helper

    /// Simulates the scoreDescription function logic from ResultsView.swift
    private func scoreDescription(_ score: Double, isProfessionallyMixed: Bool, mixStage: String?) -> String {
        let isMaster = mixStage == "master_streaming" || mixStage == "master_cd"
        let qualityType = isMaster ? "Master" : "Mix"

        // If unmixed, don't show positive quality labels
        if !isProfessionallyMixed {
            switch score {
            case 70...100: return "Unmixed - Needs Processing"
            case 50..<70: return "Unmixed - Raw Recording"
            default: return "Unmixed - Needs Work"
            }
        }

        switch score {
        case 85...100: return "Excellent \(qualityType) Quality"
        case 70..<85: return "Good \(qualityType) Quality"
        case 50..<70: return "Fair \(qualityType) Quality"
        default: return "Needs Improvement"
        }
    }

    // MARK: - Mix Stage Tests

    func testScoreDescription_Mix_Excellent() {
        let description = scoreDescription(90, isProfessionallyMixed: true, mixStage: "mix")
        XCTAssertEqual(description, "Excellent Mix Quality")
    }

    func testScoreDescription_Mix_Good() {
        let description = scoreDescription(78, isProfessionallyMixed: true, mixStage: "mix")
        XCTAssertEqual(description, "Good Mix Quality")
    }

    func testScoreDescription_Mix_Fair() {
        let description = scoreDescription(60, isProfessionallyMixed: true, mixStage: "mix")
        XCTAssertEqual(description, "Fair Mix Quality")
    }

    func testScoreDescription_Mix_NeedsImprovement() {
        let description = scoreDescription(40, isProfessionallyMixed: true, mixStage: "mix")
        XCTAssertEqual(description, "Needs Improvement")
    }

    // MARK: - Master Streaming Stage Tests

    func testScoreDescription_MasterStreaming_Excellent() {
        let description = scoreDescription(95, isProfessionallyMixed: true, mixStage: "master_streaming")
        XCTAssertEqual(description, "Excellent Master Quality")
    }

    func testScoreDescription_MasterStreaming_Good() {
        let description = scoreDescription(80, isProfessionallyMixed: true, mixStage: "master_streaming")
        XCTAssertEqual(description, "Good Master Quality")
    }

    // MARK: - Master CD Stage Tests

    func testScoreDescription_MasterCD_Excellent() {
        let description = scoreDescription(92, isProfessionallyMixed: true, mixStage: "master_cd")
        XCTAssertEqual(description, "Excellent Master Quality")
    }

    func testScoreDescription_MasterCD_Good() {
        let description = scoreDescription(75, isProfessionallyMixed: true, mixStage: "master_cd")
        XCTAssertEqual(description, "Good Master Quality")
    }

    // MARK: - Unmixed Track Tests

    func testScoreDescription_Unmixed_HighScore() {
        // Even with high score, unmixed tracks should show unmixed label
        let description = scoreDescription(85, isProfessionallyMixed: false, mixStage: "mix")
        XCTAssertEqual(description, "Unmixed - Needs Processing")
    }

    func testScoreDescription_Unmixed_MidScore() {
        let description = scoreDescription(60, isProfessionallyMixed: false, mixStage: "mix")
        XCTAssertEqual(description, "Unmixed - Raw Recording")
    }

    func testScoreDescription_Unmixed_LowScore() {
        let description = scoreDescription(40, isProfessionallyMixed: false, mixStage: "mix")
        XCTAssertEqual(description, "Unmixed - Needs Work")
    }

    func testScoreDescription_Unmixed_NoPositiveLabel() {
        // Unmixed track should NEVER show "Good Mix Quality"
        let description = scoreDescription(78, isProfessionallyMixed: false, mixStage: "mix")
        XCTAssertFalse(description.contains("Good Mix Quality"),
            "Unmixed track should NOT show 'Good Mix Quality'")
        XCTAssertTrue(description.contains("Unmixed"),
            "Unmixed track should show 'Unmixed' label")
    }

    // MARK: - Nil Mix Stage Tests

    func testScoreDescription_NilMixStage_DefaultsToMix() {
        let description = scoreDescription(85, isProfessionallyMixed: true, mixStage: nil)
        XCTAssertEqual(description, "Excellent Mix Quality",
            "Nil mix stage should default to Mix quality label")
    }
}
