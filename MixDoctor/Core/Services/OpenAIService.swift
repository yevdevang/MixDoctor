//
//  OpenAIService.swift
//  MixDoctor
//
//  Service for AI-powered audio analysis using OpenAI
//

import Foundation
import OpenAI

final class OpenAIService {
    
    // MARK: - Configuration
    private let openAI: OpenAI
    
    static let shared = OpenAIService()
    
    private init() {
        // Load API key from secure configuration
        let apiKey = Config.openAIAPIKey
        self.openAI = OpenAI(apiToken: apiKey)
    }
    
    // MARK: - Audio Analysis
    
    func analyzeAudioFeatures(
        peakLevel: Float,
        rmsLevel: Float,
        dynamicRange: Float,
        stereoWidth: Float,
        lowFrequencyEnergy: Float,
        midFrequencyEnergy: Float,
        highFrequencyEnergy: Float,
        spectralCentroid: Float,
        zeroCrossingRate: Float,
        phaseCoherence: Float,
        hasCompression: Bool,
        hasReverb: Bool,
        hasStereoProcessing: Bool,
        hasEQ: Bool,
        spectralFlatness: Float,
        stereoCorrelation: Float,
        loudnessRange: Float = 0,
        truePeak: Float = 0,
        crestFactorDB: Float = 0,
        isProUser: Bool = false
    ) async throws -> OpenAIAnalysisResponse {
        
        print("🚀🚀🚀 OPENAI ANALYSIS SERVICE CALLED 🚀🚀🚀")
        let modelToUse = isProUser ? Model.gpt4_o : Model.gpt4_o_mini
        print("📡 Using OpenAI model: \(isProUser ? "GPT-4o (Pro)" : "GPT-4o-mini (Free)")")
        
        // Adjust recommendations count based on user tier
        let maxRecommendations = isProUser ? 5 : 3
        
        // ✨ ENHANCED UNMIXED DETECTION ALGORITHM ✨
        // Based on professional audio analysis:
        // Unmixed audio tends to have:
        // 1. LOW spectral flatness (< 0.15) - dominated by specific frequencies/harmonics
        // 2. HIGH stereo correlation (> 0.85) - channels too similar or mono
        // 3. Low stereo width (< 30%) - not properly spread
        // 4. Missing professional processing effects
        
        print("🔍 Unmixed Detection Metrics:")
        print("   Spectral Flatness: \(spectralFlatness) (unmixed if < 0.15)")
        print("   Stereo Correlation: \(stereoCorrelation) (unmixed if > 0.85)")
        print("   Stereo Width: \(stereoWidth * 100)% (unmixed if < 30%)")
        print("   Phase Coherence: \(phaseCoherence) (unmixed if < 0.6)")
        
        // Calculate unmixed confidence score (0 = definitely mixed, 1 = definitely unmixed)
        let spectralFlatnessScore: Float
        if spectralFlatness < 0.15 {
            spectralFlatnessScore = 1.0
        } else {
            let delta = 0.25 - spectralFlatness
            spectralFlatnessScore = max(0.0, delta / 0.10)
        }
        
        let stereoCorrelationScore: Float
        if stereoCorrelation > 0.85 {
            stereoCorrelationScore = 1.0
        } else {
            let delta = stereoCorrelation - 0.75
            stereoCorrelationScore = max(0.0, delta / 0.10)
        }
        
        let stereoWidthScore: Float
        if stereoWidth < 0.30 {
            stereoWidthScore = 1.0
        } else {
            let delta = 0.40 - stereoWidth
            stereoWidthScore = max(0.0, delta / 0.10)
        }
        
        let phaseCoherenceScore: Float = phaseCoherence < 0.6 ? 1.0 : 0.0
        
        // Weighted average (spectral flatness and correlation are most reliable)
        let weight1 = spectralFlatnessScore * 0.35
        let weight2 = stereoCorrelationScore * 0.35
        let weight3 = stereoWidthScore * 0.20
        let weight4 = phaseCoherenceScore * 0.10
        let unmixedConfidence = weight1 + weight2 + weight3 + weight4
        
        print("   Unmixed Confidence Score: \(unmixedConfidence) (0 = mixed, 1 = unmixed)")
        
        // PRE-CALCULATE if unmixed using MULTIPLE INDICATORS (not just one)
        // An unmixed track should have SEVERAL of these issues, not just one
        
        // Count critical unmixed indicators
        var unmixedScore: Float = 0.0
        
        // Spectral analysis (most reliable) - weight: 30 points
        if spectralFlatness < 0.15 { unmixedScore += 30 }
        
        // Stereo correlation too high - weight: 25 points
        if stereoCorrelation > 0.85 { unmixedScore += 25 }
        
        // Stereo width too narrow - weight: 20 points
        if stereoWidth < 0.30 { unmixedScore += 20 }
        
        // Loudness Range (LRA) - unmixed tracks have very high LRA (>15 LU) - weight: 15 points
        if loudnessRange > 15 { unmixedScore += 15 }
        
        // Crest Factor - unmixed tracks have high crest factor (>12 dB) - weight: 10 points
        if crestFactorDB > 12 { unmixedScore += 10 }
        
        // Missing professional processing (each worth 5 points)
        if !hasCompression { unmixedScore += 5 }
        if !hasReverb { unmixedScore += 5 }
        if !hasStereoProcessing { unmixedScore += 5 }
        if !hasEQ { unmixedScore += 5 }
        
        // Additional technical indicators (lower weight)
        if dynamicRange > 20 { unmixedScore += 5 }  // Excessive dynamic range
        if rmsLevel < -30 { unmixedScore += 5 }     // Very quiet
        if phaseCoherence < 0.5 { unmixedScore += 5 }  // Poor phase
        
        print("   🎯 Unmixed Score: \(unmixedScore)/130")
        print("      Spectral Flatness < 0.15: \(spectralFlatness < 0.15 ? "+30" : "0") (current: \(String(format: "%.3f", spectralFlatness)))")
        print("      Stereo Correlation > 0.85: \(stereoCorrelation > 0.85 ? "+25" : "0") (current: \(String(format: "%.3f", stereoCorrelation)))")
        print("      Stereo Width < 30%: \(stereoWidth < 0.30 ? "+20" : "0") (current: \(Int(stereoWidth * 100))%)")
        print("      Loudness Range > 15 LU: \(loudnessRange > 15 ? "+15" : "0") (current: \(String(format: "%.1f", loudnessRange)) LU)")
        print("      Crest Factor > 12 dB: \(crestFactorDB > 12 ? "+10" : "0") (current: \(String(format: "%.1f", crestFactorDB)) dB)")
        print("      Missing Compression: \(!hasCompression ? "+5" : "0")")
        print("      Missing Reverb: \(!hasReverb ? "+5" : "0")")
        print("      Missing Stereo Processing: \(!hasStereoProcessing ? "+5" : "0")")
        print("      Missing EQ: \(!hasEQ ? "+5" : "0")")
        
        // Unmixed if score >= 70 (requires multiple critical indicators)
        // Professional mixed tracks should score < 40
        let isUnmixed = unmixedScore >= 70
        
        // MANDATORY SCORE (AI cannot override this)
        let mandatoryScoreRange = isUnmixed ? "35-50" : "51-100"
        let unmixedStatus = isUnmixed ? "⚠️ UNMIXED DETECTED (score: \(Int(unmixedScore))/100) - MUST SCORE 35-50" : "✓ Mixed (score: \(Int(unmixedScore))/100) - can score 51-100"
        
        let prompt = """
        ⚠️⚠️⚠️ MANDATORY: \(unmixedStatus) ⚠️⚠️⚠️
        
        🎯 ADVANCED UNMIXED DETECTION RESULTS (Spectral Analysis):
        Unmixed Confidence Score: \(String(format: "%.2f", unmixedConfidence)) (0=mixed, 1=unmixed) \(unmixedConfidence > 0.5 ? "⚠️ UNMIXED" : "✓")
        
        KEY INDICATORS:
        • Spectral Flatness: \(String(format: "%.3f", spectralFlatness)) \(spectralFlatness < 0.15 ? "⚠️ Too low (unmixed)" : "✓")
        • Stereo Correlation: \(String(format: "%.3f", stereoCorrelation)) \(stereoCorrelation > 0.85 ? "⚠️ Too high (unmixed)" : "✓")
        • Stereo Width: \(String(format: "%.1f", stereoWidth * 100))% \(stereoWidth * 100 < 30 ? "⚠️ Too narrow" : "✓")
        • Phase Coherence: \(String(format: "%.2f", phaseCoherence)) \(phaseCoherence < 0.6 ? "⚠️ Poor" : "✓")
        
        ADDITIONAL CHECKS:
        • Dynamic Range: \(String(format: "%.1f", dynamicRange)) dB \(dynamicRange > 15 ? "⚠️ Too wide" : "✓")
        • RMS Level: \(String(format: "%.1f", rmsLevel)) dBFS \(rmsLevel < -25 ? "⚠️ Too quiet" : "✓")
        • Spectral Centroid: \(String(format: "%.0f", spectralCentroid)) Hz \(spectralCentroid < 800 ? "⚠️ Too low" : "✓")
        • Max Frequency Energy: \(String(format: "%.1f", max(lowFrequencyEnergy, midFrequencyEnergy, highFrequencyEnergy) * 100))% \(max(lowFrequencyEnergy, midFrequencyEnergy, highFrequencyEnergy) > 0.5 ? "⚠️ Imbalanced" : "✓")
        
        PROCESSING EFFECTS:
        • Compression: \(hasCompression ? "YES ✓" : "NO ⚠️")
        • Reverb/Delay: \(hasReverb ? "YES ✓" : "NO ⚠️")
        • Stereo Processing: \(hasStereoProcessing ? "YES ✓" : "NO ⚠️")
        • EQ: \(hasEQ ? "YES ✓" : "NO ⚠️")
        
        RESULT: \(isUnmixed ? "UNMIXED TRACK - YOU MUST SCORE BETWEEN 35-50 ONLY" : "MIXED TRACK - You can score 51-100 based on quality")
        
        🎚️ MEASURED AUDIO DATA:
        - Peak: \(peakLevel) dBFS
        - RMS: \(rmsLevel) dBFS  
        - Dynamic Range: \(dynamicRange) dB
        - Stereo Width: \(String(format: "%.1f", stereoWidth * 100))%
        - Phase: \(String(format: "%.2f", phaseCoherence))
        - Low Freq: \(String(format: "%.1f", lowFrequencyEnergy * 100))%
        - Mid Freq: \(String(format: "%.1f", midFrequencyEnergy * 100))%
        - High Freq: \(String(format: "%.1f", highFrequencyEnergy * 100))%
        - Spectral Centroid: \(String(format: "%.0f", spectralCentroid)) Hz
        
        MANDATORY SCORING RULES - YOU MUST FOLLOW THESE:
        \(isUnmixed ? "⚠️ THIS IS UNMIXED → SCORE MUST BE 35-50 ONLY ⚠️" : "✓ This is mixed → score based on quality 51-100")
        
        If unmixed (score 35-50):
        - 35-40 = severely unmixed
        - 41-45 = moderately unmixed  
        - 46-50 = slightly unmixed
        
        If mixed (score 51-100):
        - 51-65 = poor mix quality
        - 66-75 = decent home studio
        - 76-85 = semi-professional
        - 86-92 = professional Spotify quality
        - 93-100 = Grammy masterpiece (rare)
        
        YOUR SCORE MUST BE IN RANGE: \(mandatoryScoreRange)
        
        IMPORTANT: Provide EXACTLY \(maxRecommendations) recommendations - no more, no less. Make them actionable and specific.
        
        Respond ONLY with valid JSON in this exact format, no markdown formatting:
        {
            "overallQuality": <MUST BE \(mandatoryScoreRange)>,
            "stereoAnalysis": "brief stereo width assessment",
            "frequencyAnalysis": "brief frequency balance assessment",
            "dynamicsAnalysis": "brief dynamics assessment",
            "effectsAnalysis": "brief audio effects assessment",
            "recommendations": [
                "actionable recommendation 1",
                "actionable recommendation 2",
                "actionable recommendation 3"\(isProUser ? ",\n                \"actionable recommendation 4\",\n                \"actionable recommendation 5\"" : "")
            ],
            "detailedSummary": "2-3 sentence overall assessment"
        }
        """
        
        let query = ChatQuery(
            messages: [
                .user(.init(content: .string(prompt)))
            ],
            model: modelToUse,
            responseFormat: .jsonObject
        )
        
        print("📤 Sending request to OpenAI API with \(isProUser ? "GPT-4o" : "GPT-4o-mini")...")
        
        do {
            let result = try await openAI.chats(query: query)
            print("📥 Received response from OpenAI")
            
            guard let content = result.choices.first?.message.content else {
                throw OpenAIError.noContent
            }
            
            print("📝 OpenAI Analysis Response: \(content)")
            print("✅✅✅ OPENAI ANALYSIS RECEIVED SUCCESSFULLY ✅✅✅")
            
            return try parseAnalysisResponse(content, isUnmixed: isUnmixed)
        } catch {
            print("❌ OpenAI API Error: \(error.localizedDescription)")
            throw OpenAIError.apiError(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ jsonString: String, isUnmixed: Bool) throws -> OpenAIAnalysisResponse {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }
        
        var response = try JSONDecoder().decode(OpenAIAnalysisResponse.self, from: jsonData)
        
        // POST-PROCESSING: FORCE correct score range if AI ignored instructions
        let originalScore = response.overallQuality
        
        if isUnmixed {
            // UNMIXED tracks MUST score 35-50
            if response.overallQuality > 50 {
                print("⚠️ AI gave score \(originalScore) for UNMIXED track - FORCING to 40")
                response = OpenAIAnalysisResponse(
                    overallQuality: 40, // Force to middle of unmixed range
                    stereoAnalysis: response.stereoAnalysis,
                    frequencyAnalysis: response.frequencyAnalysis,
                    dynamicsAnalysis: response.dynamicsAnalysis,
                    effectsAnalysis: response.effectsAnalysis,
                    recommendations: response.recommendations,
                    detailedSummary: "⚠️ UNMIXED TRACK DETECTED. " + response.detailedSummary
                )
            } else if response.overallQuality < 35 {
                print("⚠️ AI gave score \(originalScore) for UNMIXED track - FORCING to 35")
                response = OpenAIAnalysisResponse(
                    overallQuality: 35,
                    stereoAnalysis: response.stereoAnalysis,
                    frequencyAnalysis: response.frequencyAnalysis,
                    dynamicsAnalysis: response.dynamicsAnalysis,
                    effectsAnalysis: response.effectsAnalysis,
                    recommendations: response.recommendations,
                    detailedSummary: "⚠️ UNMIXED TRACK DETECTED. " + response.detailedSummary
                )
            } else {
                print("✓ AI correctly scored UNMIXED track: \(originalScore)")
            }
        } else {
            // Mixed tracks must score 51-100
            if response.overallQuality < 51 {
                print("⚠️ AI gave score \(originalScore) for MIXED track - should be 51+")
            } else {
                print("✓ AI scored mixed track: \(originalScore)")
            }
        }
        
        return response
    }
}

// MARK: - Models

struct OpenAIAnalysisResponse: Codable {
    let overallQuality: Double
    let stereoAnalysis: String
    let frequencyAnalysis: String
    let dynamicsAnalysis: String
    let effectsAnalysis: String
    let recommendations: [String]
    let detailedSummary: String
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case invalidJSON
    case apiKeyNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let message):
            return "OpenAI API Error (\(statusCode)): \(message)"
        case .noContent:
            return "No content in OpenAI response"
        case .invalidJSON:
            return "Invalid JSON in OpenAI response"
        case .apiKeyNotConfigured:
            return "OpenAI API key not configured in OpenAIService"
        }
    }
}
