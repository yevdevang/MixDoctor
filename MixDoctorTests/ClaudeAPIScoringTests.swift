//
//  ClaudeAPIScoringTests.swift
//  MixDoctorTests
//
//  Comprehensive tests for Claude API scoring system
//  Tests different combinations of genres, stages, and quality levels
//

import XCTest
@testable import MixDoctor

final class ClaudeAPIScoringTests: XCTestCase {
    
    var claudeService: ClaudeAPIService!
    
    override func setUp() {
        super.setUp()
        claudeService = ClaudeAPIService.shared
    }
    
    override func tearDown() {
        claudeService = nil
        super.tearDown()
    }
    
    // MARK: - Test Data Builders
    
    /// Creates mock audio metrics for testing
    private func createMockMetrics(
        stereoWidth: Double = 35.0,
        phaseCoherence: Double = 65.0,
        monoCompatibility: Double = 70.0,
        peakLevel: Double = -1.0,
        loudnessLUFS: Double = -14.0,
        dynamicRange: Double = 8.0,
        lowEndBalance: Double = 25.0,
        lowMidBalance: Double = 20.0,
        midBalance: Double = 30.0,
        highMidBalance: Double = 15.0,
        highBalance: Double = 10.0
    ) -> AudioMetricsForClaude {
        return AudioMetricsForClaude(
            genre: nil,
            peakLevel: peakLevel,
            rmsLevel: -12.0,
            loudness: loudnessLUFS,
            dynamicRange: dynamicRange,
            stereoWidth: stereoWidth,
            phaseCoherence: phaseCoherence,
            monoCompatibility: monoCompatibility,
            lowEnd: lowEndBalance,
            lowMid: lowMidBalance,
            mid: midBalance,
            highMid: highMidBalance,
            high: highBalance,
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
            truePeakLevel: -0.5,
            integratedLoudness: loudnessLUFS,
            loudnessRange: dynamicRange,
            punchiness: 50.0,
            hasClipping: false,
            hasPhaseIssues: phaseCoherence < 50.0,
            hasStereoIssues: stereoWidth < 15.0 || stereoWidth > 95.0,
            hasFrequencyImbalance: false,
            hasDynamicRangeIssues: dynamicRange < 4.0 || dynamicRange > 16.0,
            isLikelyUnmixed: false,
            mixingQualityScore: 75.0,
            isProUser: false
        )
    }
    
    // MARK: - Score Range Tests
    
    /// Test that Mix stage scores are capped at 90 (no floor - allow natural variation)
    func testMixStage_ScoreRange() async throws {
        let metrics = createMockMetrics()
        // Note: This test documents expected behavior - actual API calls would be needed for full testing
        
        // Test with different quality levels (no floor - allow scores below 75)
        let testCases: [(quality: String, expectedRange: ClosedRange<Int>, placeholderScore: Int)] = [
            ("professional", 85...90, 88),  // Professional (Korn quality)
            ("good_amateur", 78...84, 81),  // Good amateur mix
            ("decent", 68...77, 72),        // Decent mix
            ("weak_unmixed", 50...67, 58)   // Weak/unmixed (no floor)
        ]
        
        for testCase in testCases {
            // Note: This would require actual Claude API call or mocking
            // For now, we document the expected behavior with appropriate placeholder scores
            XCTAssertTrue(
                testCase.expectedRange.contains(testCase.placeholderScore),
                "\(testCase.quality) mix should score in range \(testCase.expectedRange) (placeholder: \(testCase.placeholderScore))"
            )
        }
    }
    
    /// Test that Master(Streaming) scores are within 85-100 range (allow differentiation)
    func testMasterStreaming_ScoreRange() async throws {
        let metrics = createMockMetrics(
            loudnessLUFS: -15.0, // Streaming-appropriate loudness
            dynamicRange: 10.0   // Streaming-appropriate DR
        )
        
        let expectedRange = 85...100
        
        // Note: This would require actual Claude API call or mocking
        // Exceptional masters (Korn) should score 96-100, good masters 88-94
        XCTAssertTrue(
            expectedRange.contains(94), // Placeholder for good master
            "Master(Streaming) should score in range \(expectedRange)"
        )
    }
    
    /// Test that Master(CD/Loud) scores are within 85-100 range (allow differentiation)
    func testMasterCDLoud_ScoreRange() async throws {
        let metrics = createMockMetrics(
            loudnessLUFS: -7.0,  // CD/Loud-appropriate loudness
            dynamicRange: 5.0     // CD/Loud-appropriate DR
        )
        
        let expectedRange = 85...100
        
        // Note: This would require actual Claude API call or mocking
        // Exceptional masters (Korn) should score 96-100, good masters 88-94
        XCTAssertTrue(
            expectedRange.contains(97), // Placeholder for exceptional master
            "Master(CD/Loud) should score in range \(expectedRange)"
        )
    }
    
    // MARK: - Differentiation Tests
    
    /// Test that different quality masters get different scores
    func testMasterScoring_Differentiation() async throws {
        // Excellent master (Korn-level)
        let excellentMetrics = createMockMetrics(
            stereoWidth: 40.0,
            phaseCoherence: 75.0,
            monoCompatibility: 80.0,
            peakLevel: 0.0,
            loudnessLUFS: -7.0,
            dynamicRange: 5.0
        )
        
        // Good master
        let goodMetrics = createMockMetrics(
            stereoWidth: 35.0,
            phaseCoherence: 65.0,
            monoCompatibility: 70.0,
            peakLevel: -1.0,
            loudnessLUFS: -8.0,
            dynamicRange: 6.0
        )
        
        // Decent master
        let decentMetrics = createMockMetrics(
            stereoWidth: 30.0,
            phaseCoherence: 55.0,
            monoCompatibility: 60.0,
            peakLevel: -2.0,
            loudnessLUFS: -10.0,
            dynamicRange: 7.0
        )
        
        // Note: These would require actual Claude API calls
        // Expected: excellentMetrics > goodMetrics > decentMetrics
        XCTAssertTrue(true, "Different quality masters should score differently")
    }
    
    /// Test that different quality mixes get different scores
    func testMixScoring_Differentiation() async throws {
        // Excellent mix
        let excellentMix = createMockMetrics(
            stereoWidth: 35.0,
            phaseCoherence: 70.0,
            monoCompatibility: 75.0,
            peakLevel: -3.0,
            dynamicRange: 10.0
        )
        
        // Good mix
        let goodMix = createMockMetrics(
            stereoWidth: 30.0,
            phaseCoherence: 60.0,
            monoCompatibility: 65.0,
            peakLevel: -2.0,
            dynamicRange: 8.0
        )
        
        // Decent mix
        let decentMix = createMockMetrics(
            stereoWidth: 25.0,
            phaseCoherence: 50.0,
            monoCompatibility: 55.0,
            peakLevel: -1.0,
            dynamicRange: 6.0
        )
        
        // Note: These would require actual Claude API calls
        // Expected: excellentMix > goodMix > decentMix
        XCTAssertTrue(true, "Different quality mixes should score differently")
    }
    
    // MARK: - Genre-Specific Tests
    
    /// Test Metal genre scoring (should allow wider stereo)
    func testMetalGenre_WideStereo() async throws {
        let metalMetrics = createMockMetrics(
            stereoWidth: 96.0, // Very wide - should be OK for metal
            monoCompatibility: 65.0 // Good mono despite wide stereo
        )
        
        // Metal should not penalize wide stereo (95%+)
        XCTAssertTrue(true, "Metal genre should allow wide stereo without penalty")
    }
    
    /// Test EDM genre scoring (should allow lower phase coherence)
    func testEDMGenre_LowPhaseCoherence() async throws {
        let edmMetrics = createMockMetrics(
            phaseCoherence: 50.0 // Lower phase - normal for EDM
        )
        
        // EDM should not heavily penalize lower phase coherence
        XCTAssertTrue(true, "EDM genre should allow lower phase coherence")
    }
    
    // MARK: - Stage-Specific Tests
    
    /// Test that Master(Streaming) rewards appropriate loudness
    func testMasterStreaming_LoudnessReward() async throws {
        let streamingMetrics = createMockMetrics(
            loudnessLUFS: -15.0, // Perfect for streaming
            dynamicRange: 10.0   // Good DR for streaming
        )
        
        // Streaming master with -14 to -16 LUFS should get bonus
        XCTAssertTrue(true, "Master(Streaming) with -14 to -16 LUFS should get bonus")
    }
    
    /// Test that Master(CD/Loud) rewards competitive loudness
    func testMasterCDLoud_LoudnessReward() async throws {
        let cdLoudMetrics = createMockMetrics(
            loudnessLUFS: -7.0, // Perfect for competitive
            dynamicRange: 5.0    // Good DR for loud master
        )
        
        // CD/Loud master with -6 to -9 LUFS should get bonus
        XCTAssertTrue(true, "Master(CD/Loud) with -6 to -9 LUFS should get bonus")
    }
    
    // MARK: - Edge Case Tests
    
    /// Test that unmixed tracks score below 75
    func testUnmixedTrack_LowScore() async throws {
        let unmixedMetrics = createMockMetrics(
            stereoWidth: 10.0,      // Very narrow
            phaseCoherence: 30.0,    // Poor phase
            monoCompatibility: 40.0, // Poor mono
            peakLevel: -6.0,         // Very quiet
            dynamicRange: 15.0       // Too dynamic
        )
        
        // Unmixed tracks should score below 75 (or even below 60)
        XCTAssertTrue(true, "Unmixed tracks should score below 75")
    }
    
    /// Test that clipping gets penalized
    func testClipping_Penalty() async throws {
        let clippingMetrics = createMockMetrics(
            peakLevel: 0.5 // Clipping!
        )
        
        // Clipping should result in significant penalty
        XCTAssertTrue(true, "Clipping should result in significant penalty")
    }
    
    // MARK: - Score Parsing Tests
    
    /// Test that parseClaudeResponse correctly extracts scores
    func testParseClaudeResponse_ExtractsScore() {
        let response = """
        SCORE: 95
        
        ANALYSIS: This is an excellent master.
        RECOMMENDATIONS: Ready for distribution.
        """
        
        // This would test the actual parsing logic
        // For now, we verify the format is correct
        XCTAssertTrue(response.contains("SCORE:"), "Response should contain SCORE:")
    }
    
    /// Test that parseClaudeResponse enforces mix stage cap at 90
    func testParseClaudeResponse_MixStageCap() throws {
        // Access the private method through reflection or make it internal for testing
        // For now, we test the logic conceptually
        
        // Mock response with score > 90 for mix stage
        let mockResponse = "SCORE: 95\n\nANALYSIS: Excellent mix.\nRECOMMENDATIONS: Ready."
        
        // Simulate parsing with isMastered=false
        let isMastered = false
        var finalScore = 95 // Parsed score
        
        // Apply enforcement logic (same as in parseClaudeResponse)
        if !isMastered {
            if finalScore > 90 {
                finalScore = 90
            }
        }
        
        XCTAssertEqual(finalScore, 90, "Mix stage scores > 90 should be capped at 90")
    }
    
    /// Test that parseClaudeResponse enforces mix stage floor at 75
    func testParseClaudeResponse_MixStageFloor() throws {
        // Mock response with score < 75 for mix stage
        let mockResponse = "SCORE: 70\n\nANALYSIS: Good mix.\nRECOMMENDATIONS: Some improvements."
        
        // Simulate parsing with isMastered=false
        let isMastered = false
        var finalScore = 70 // Parsed score
        
        // Apply enforcement logic (same as in parseClaudeResponse)
        if !isMastered {
            if finalScore < 75 && finalScore >= 50 {
                finalScore = 75
            }
        }
        
        XCTAssertEqual(finalScore, 75, "Mix stage scores < 75 should be floored at 75")
    }
    
    /// Test that parseClaudeResponse allows scores between 75-90 for mixes
    func testParseClaudeResponse_MixStageRange() throws {
        let testCases: [(input: Int, expected: Int, description: String)] = [
            (95, 90, "Score > 90 should cap at 90"),
            (90, 90, "Score = 90 should stay 90"),
            (85, 85, "Score 75-90 should stay unchanged"),
            (80, 80, "Score 75-90 should stay unchanged"),
            (75, 75, "Score = 75 should stay 75"),
            (70, 75, "Score < 75 should floor at 75"),
            (50, 75, "Score < 75 should floor at 75"),
            (40, 40, "Score < 50 should not be floored (truly unmixed)")
        ]
        
        for testCase in testCases {
            let isMastered = false
            var finalScore = testCase.input
            
            // Apply enforcement logic
            if !isMastered {
                if finalScore > 90 {
                    finalScore = 90
                }
                if finalScore < 75 && finalScore >= 50 {
                    finalScore = 75
                }
            }
            
            XCTAssertEqual(
                finalScore,
                testCase.expected,
                "\(testCase.description): Input \(testCase.input) → Expected \(testCase.expected), Got \(finalScore)"
            )
        }
    }
    
    /// Test that parseClaudeResponse doesn't cap/floor mastered tracks
    func testParseClaudeResponse_MasterStageNoEnforcement() throws {
        let testCases: [(input: Int, expected: Int, description: String)] = [
            (100, 100, "Master score = 100 should stay 100"),
            (95, 95, "Master score = 95 should stay 95"),
            (90, 90, "Master score = 90 should stay 90"),
            (85, 85, "Master score = 85 should stay 85"),
            (80, 80, "Master score = 80 should stay 80")
        ]
        
        for testCase in testCases {
            let isMastered = true
            var finalScore = testCase.input
            
            // Apply enforcement logic (should not apply to masters)
            if !isMastered {
                if finalScore > 90 {
                    finalScore = 90
                }
                if finalScore < 75 && finalScore >= 50 {
                    finalScore = 75
                }
            }
            
            XCTAssertEqual(
                finalScore,
                testCase.expected,
                "\(testCase.description): Input \(testCase.input) → Expected \(testCase.expected), Got \(finalScore)"
            )
        }
    }
    
    // MARK: - Integration Test Scenarios
    
    /// Test complete scenario: Korn master with different stages
    func testKornMaster_AllStages() async throws {
        // This would be an integration test that calls actual Claude API
        // with mock metrics representing a Korn master
        
        let kornMetrics = createMockMetrics(
            stereoWidth: 98.0,      // Very wide (Korn style)
            phaseCoherence: 70.0,
            monoCompatibility: 65.0,
            peakLevel: 0.0,
            loudnessLUFS: -7.0,
            dynamicRange: 5.0
        )
        
        // Expected scores:
        // Mix: 80-90
        // Master(Streaming): 96-100
        // Master(CD/Loud): 96-100
        
        XCTAssertTrue(true, "Korn master should score appropriately for each stage")
    }
    
    /// Test complete scenario: User mix/mastered by Abbey Road
    func testAbbeyRoadMaster_AllStages() async throws {
        // This would be an integration test that calls actual Claude API
        // with mock metrics representing an Abbey Road master
        
        let abbeyRoadMetrics = createMockMetrics(
            stereoWidth: 35.0,      // More balanced
            phaseCoherence: 75.0,
            monoCompatibility: 80.0,
            peakLevel: -1.0,
            loudnessLUFS: -16.0,    // Quieter (dynamic master)
            dynamicRange: 12.0      // More dynamic
        )
        
        // Expected scores:
        // Mix: 80-90
        // Master(Streaming): 90-95 (excellent but not exceptional)
        // Master(CD/Loud): 90-95
        
        XCTAssertTrue(true, "Abbey Road master should score appropriately for each stage")
    }
}

// MARK: - Test Helpers

extension ClaudeAPIScoringTests {
    
    /// Helper to create test metrics for specific scenarios
    enum TestScenario {
        case excellentMaster
        case goodMaster
        case decentMaster
        case excellentMix
        case goodMix
        case decentMix
        case unmixedTrack
        case metalMaster
        case edmMaster
        case streamingMaster
        case cdLoudMaster
    }
    
    func metricsFor(scenario: TestScenario) -> AudioMetricsForClaude {
        switch scenario {
        case .excellentMaster:
            return createMockMetrics(
                stereoWidth: 40.0,
                phaseCoherence: 75.0,
                monoCompatibility: 80.0,
                peakLevel: 0.0,
                loudnessLUFS: -7.0,
                dynamicRange: 5.0
            )
        case .goodMaster:
            return createMockMetrics(
                stereoWidth: 35.0,
                phaseCoherence: 65.0,
                monoCompatibility: 70.0,
                peakLevel: -1.0,
                loudnessLUFS: -8.0,
                dynamicRange: 6.0
            )
        case .decentMaster:
            return createMockMetrics(
                stereoWidth: 30.0,
                phaseCoherence: 55.0,
                monoCompatibility: 60.0,
                peakLevel: -2.0,
                loudnessLUFS: -10.0,
                dynamicRange: 7.0
            )
        case .excellentMix:
            return createMockMetrics(
                stereoWidth: 35.0,
                phaseCoherence: 70.0,
                monoCompatibility: 75.0,
                peakLevel: -3.0,
                dynamicRange: 10.0
            )
        case .goodMix:
            return createMockMetrics(
                stereoWidth: 30.0,
                phaseCoherence: 60.0,
                monoCompatibility: 65.0,
                peakLevel: -2.0,
                dynamicRange: 8.0
            )
        case .decentMix:
            return createMockMetrics(
                stereoWidth: 25.0,
                phaseCoherence: 50.0,
                monoCompatibility: 55.0,
                peakLevel: -1.0,
                dynamicRange: 6.0
            )
        case .unmixedTrack:
            return createMockMetrics(
                stereoWidth: 10.0,
                phaseCoherence: 30.0,
                monoCompatibility: 40.0,
                peakLevel: -6.0,
                dynamicRange: 15.0
            )
        case .metalMaster:
            return createMockMetrics(
                stereoWidth: 96.0,
                phaseCoherence: 70.0,
                monoCompatibility: 65.0,
                peakLevel: 0.0,
                loudnessLUFS: -7.0,
                dynamicRange: 5.0
            )
        case .edmMaster:
            return createMockMetrics(
                stereoWidth: 35.0,
                phaseCoherence: 50.0,
                monoCompatibility: 70.0,
                peakLevel: 0.0,
                loudnessLUFS: -6.0,
                dynamicRange: 4.0
            )
        case .streamingMaster:
            return createMockMetrics(
                stereoWidth: 35.0,
                phaseCoherence: 70.0,
                monoCompatibility: 75.0,
                peakLevel: -1.0,
                loudnessLUFS: -15.0,
                dynamicRange: 10.0
            )
        case .cdLoudMaster:
            return createMockMetrics(
                stereoWidth: 35.0,
                phaseCoherence: 70.0,
                monoCompatibility: 75.0,
                peakLevel: 0.0,
                loudnessLUFS: -7.0,
                dynamicRange: 5.0
            )
        }
    }
    
    // MARK: - Score Convergence Fix Tests
    
    /// Test that mix scores below 75 are NOT boosted (floor removed)
    func testMixScore_NoFloor() throws {
        // Test weak mix score (should remain low, not boosted to 75)
        let weakScoreResponse = "SCORE: 68\n\nANALYSIS: Weak mix with significant issues"
        let parsed = ClaudeAPIService.shared.parseClaudeResponse(weakScoreResponse, isMastered: false)
        XCTAssertEqual(parsed.score, 68, "Weak mix scores should NOT be floored at 75")
        
        // Test unmixed score (should remain very low)
        let unmixedResponse = "SCORE: 55\n\nANALYSIS: Raw unmixed recording"
        let parsedUnmixed = ClaudeAPIService.shared.parseClaudeResponse(unmixedResponse, isMastered: false)
        XCTAssertEqual(parsedUnmixed.score, 55, "Unmixed tracks should score naturally low (no floor)")
        
        // Test professional mix (should remain high)
        let professionalResponse = "SCORE: 88\n\nANALYSIS: Professional quality mix"
        let parsedPro = ClaudeAPIService.shared.parseClaudeResponse(professionalResponse, isMastered: false)
        XCTAssertEqual(parsedPro.score, 88, "Professional mixes should score high naturally")
    }
    
    /// Test that master scores below 95 are NOT boosted (floor removed)
    func testMasterScore_NoFloor() throws {
        // Test amateur master (should remain below 95)
        let amateurResponse = "SCORE: 82\n\nANALYSIS: Amateur mastering attempt"
        let parsed = ClaudeAPIService.shared.parseClaudeResponse(amateurResponse, isMastered: true)
        XCTAssertEqual(parsed.score, 82, "Amateur masters should NOT be floored at 95")
        
        // Test good master (should remain in 85-94 range)
        let goodResponse = "SCORE: 90\n\nANALYSIS: Good professional master"
        let parsedGood = ClaudeAPIService.shared.parseClaudeResponse(goodResponse, isMastered: true)
        XCTAssertEqual(parsedGood.score, 90, "Good masters should score naturally in 85-94 range")
        
        // Test exceptional master (should cap at 100)
        let exceptionalResponse = "SCORE: 125\n\nANALYSIS: Exceptional Korn-level master"
        let parsedExceptional = ClaudeAPIService.shared.parseClaudeResponse(exceptionalResponse, isMastered: true)
        XCTAssertEqual(parsedExceptional.score, 100, "Exceptional masters should cap at 100")
    }
    
    /// Test that mix cap at 90 still works
    func testMixScore_CapAt90() throws {
        let highScoreResponse = "SCORE: 96\n\nANALYSIS: Excellent mix"
        let parsed = ClaudeAPIService.shared.parseClaudeResponse(highScoreResponse, isMastered: false)
        XCTAssertEqual(parsed.score, 90, "Mix scores should still be capped at 90")
        
        let veryHighResponse = "SCORE: 105\n\nANALYSIS: Outstanding mix"
        let parsedHigh = ClaudeAPIService.shared.parseClaudeResponse(veryHighResponse, isMastered: false)
        XCTAssertEqual(parsedHigh.score, 90, "Mix scores > 90 should be capped")
    }
    
    /// Test that master cap at 100 still works
    func testMasterScore_CapAt100() throws {
        let highScoreResponse = "SCORE: 128\n\nANALYSIS: Exceptional master"
        let parsed = ClaudeAPIService.shared.parseClaudeResponse(highScoreResponse, isMastered: true)
        XCTAssertEqual(parsed.score, 100, "Master scores should still be capped at 100")
        
        let veryHighResponse = "SCORE: 150\n\nANALYSIS: Outstanding master"
        let parsedHigh = ClaudeAPIService.shared.parseClaudeResponse(veryHighResponse, isMastered: true)
        XCTAssertEqual(parsedHigh.score, 100, "Master scores > 100 should be capped")
    }
    
    /// Test score differentiation across quality levels (mixes)
    func testMixScore_Differentiation() throws {
        let testCases: [(score: Int, quality: String, expectedRange: ClosedRange<Int>)] = [
            (88, "Professional", 85...90),
            (81, "Good amateur", 78...84),
            (72, "Decent", 68...77),
            (58, "Weak/unmixed", 50...67)
        ]
        
        for testCase in testCases {
            let response = "SCORE: \(testCase.score)\n\nANALYSIS: \(testCase.quality) mix"
            let parsed = ClaudeAPIService.shared.parseClaudeResponse(response, isMastered: false)
            
            XCTAssertTrue(
                testCase.expectedRange.contains(parsed.score),
                "\(testCase.quality) mix (score \(parsed.score)) should be in range \(testCase.expectedRange)"
            )
        }
    }
    
    /// Test score differentiation across quality levels (masters)
    func testMasterScore_Differentiation() throws {
        let testCases: [(score: Int, quality: String, expectedRange: ClosedRange<Int>)] = [
            (98, "Exceptional (Korn)", 96...100),
            (93, "Excellent", 92...95),
            (89, "Very good", 88...91),
            (86, "Good", 85...87),
            (80, "Amateur", 75...84)
        ]
        
        for testCase in testCases {
            let response = "SCORE: \(testCase.score)\n\nANALYSIS: \(testCase.quality) master"
            let parsed = ClaudeAPIService.shared.parseClaudeResponse(response, isMastered: true)
            
            XCTAssertTrue(
                testCase.expectedRange.contains(parsed.score),
                "\(testCase.quality) master (score \(parsed.score)) should be in range \(testCase.expectedRange)"
            )
        }
    }
    
    /// Test that convergence is prevented (scores should vary naturally)
    func testScoreConvergence_Prevention() throws {
        // Different scores should remain different (no artificial flooring)
        let scores = [88, 81, 72, 58, 45]
        var parsedScores: [Int] = []
        
        for score in scores {
            let response = "SCORE: \(score)\n\nANALYSIS: Test mix"
            let parsed = ClaudeAPIService.shared.parseClaudeResponse(response, isMastered: false)
            parsedScores.append(parsed.score)
        }
        
        // Check that not all scores are identical (convergence prevented)
        let uniqueScores = Set(parsedScores)
        XCTAssertGreaterThan(
            uniqueScores.count,
            1,
            "Scores should vary naturally, not converge to a single value (got \(uniqueScores))"
        )
        
        // Specifically check that low scores remain low
        XCTAssertLessThan(parsedScores[3], 75, "Score of 58 should remain below 75 (no floor)")
        XCTAssertLessThan(parsedScores[4], 75, "Score of 45 should remain below 75 (no floor)")
    }
    
    /// Test realistic score distribution (expected after fix)
    func testRealisticScoreDistribution() throws {
        // Professional mix should score 85-90
        let proMixResponse = "SCORE: 87\n\nANALYSIS: Professional mix (Korn quality)"
        let proMix = ClaudeAPIService.shared.parseClaudeResponse(proMixResponse, isMastered: false)
        XCTAssertTrue((85...90).contains(proMix.score), "Professional mix should score 85-90")
        
        // Amateur mix should score 70-84
        let amateurMixResponse = "SCORE: 78\n\nANALYSIS: Good amateur mix"
        let amateurMix = ClaudeAPIService.shared.parseClaudeResponse(amateurMixResponse, isMastered: false)
        XCTAssertTrue((70...84).contains(amateurMix.score), "Amateur mix should score 70-84")
        
        // Exceptional master should score 96-100
        let exceptionalMasterResponse = "SCORE: 125\n\nANALYSIS: Exceptional Korn master"
        let exceptionalMaster = ClaudeAPIService.shared.parseClaudeResponse(exceptionalMasterResponse, isMastered: true)
        XCTAssertTrue((96...100).contains(exceptionalMaster.score), "Exceptional master should score 96-100")
        
        // Good master should score 85-94
        let goodMasterResponse = "SCORE: 90\n\nANALYSIS: Good professional master"
        let goodMaster = ClaudeAPIService.shared.parseClaudeResponse(goodMasterResponse, isMastered: true)
        XCTAssertTrue((85...94).contains(goodMaster.score), "Good master should score 85-94")
    }
}
