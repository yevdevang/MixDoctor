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
        phaseCoherence: Float
    ) async throws -> OpenAIAnalysisResponse {
        
        print("🚀🚀🚀 OPENAI ANALYSIS SERVICE CALLED 🚀🚀🚀")
        print("📡 Using OpenAI GPT-4o model")
        
        let prompt = """
        You are an expert audio engineer analyzing a professionally mixed track. Based on the following technical measurements, provide a detailed analysis.
        
        Audio Measurements:
        - Peak Level: \(peakLevel) dBFS
        - RMS Level: \(rmsLevel) dBFS
        - Dynamic Range: \(dynamicRange) dB
        - Stereo Width: \(String(format: "%.1f", stereoWidth * 100))% (0% = mono, 100% = extreme wide stereo)
        - Phase Coherence: \(phaseCoherence) (-1.0 = phase issues, 1.0 = perfect)
        - Low Frequency Energy (20-250Hz): \(lowFrequencyEnergy)
        - Mid Frequency Energy (250-4000Hz): \(midFrequencyEnergy)
        - High Frequency Energy (4000-20000Hz): \(highFrequencyEnergy)
        - Spectral Centroid: \(spectralCentroid) Hz
        - Zero Crossing Rate: \(zeroCrossingRate)
        
        SCORING GUIDELINES (be realistic - this is likely a professionally mixed track):
        - Score 90-100: Exceptional professional mix (Grammy-level, major label quality)
        - Score 75-89: Very good professional mix (commercial release quality, minor improvements possible)
        - Score 60-74: Good mix with some issues (needs work but fundamentally sound)
        - Score 40-59: Fair mix with multiple issues (requires significant improvement)
        - Score 0-39: Poor mix with major problems (fundamental issues need addressing)
        
        PROFESSIONAL MIXING STANDARDS:
        - Peak Level: -6 to -0.3 dBFS is normal (modern mixes often peak near 0 dBFS)
        - RMS Level: -20 to -6 dBFS is typical for modern commercial mixes
        - Stereo Width: 40-55% = balanced/good, 55-70% = wide/excellent, 70%+ = very wide, <35% = narrow
        - Phase Coherence: 0.7-1.0 = excellent, 0.5-0.7 = acceptable, <0.5 = phase issues
        - Dynamic Range: 6-10 dB = modern pop/rock (normal), 10-14 dB = dynamic mix, <6 dB = over-compressed
        - Frequency Balance: No single band should dominate excessively (>50% of total energy)
        
        BE FAIR: If measurements are within professional ranges, score accordingly (75-90). Only score below 60 if there are clear, objective technical problems.
        
        Respond ONLY with valid JSON in this exact format, no markdown formatting:
        {
            "overallQuality": 85,
            "stereoAnalysis": "brief stereo width assessment",
            "frequencyAnalysis": "brief frequency balance assessment",
            "dynamicsAnalysis": "brief dynamics assessment",
            "effectsAnalysis": "brief audio effects assessment",
            "recommendations": [
                "actionable recommendation 1",
                "actionable recommendation 2",
                "actionable recommendation 3",
                "actionable recommendation 4",
                "actionable recommendation 5"
            ],
            "detailedSummary": "2-3 sentence overall assessment"
        }
        """
        
        let query = ChatQuery(
            messages: [
                .user(.init(content: .string(prompt)))
            ],
            model: Model.gpt4_o,
            responseFormat: .jsonObject
        )
        
        print("📤 Sending request to OpenAI API with GPT-4o...")
        
        do {
            let result = try await openAI.chats(query: query)
            print("📥 Received response from OpenAI")
            
            guard let content = result.choices.first?.message.content else {
                throw OpenAIError.noContent
            }
            
            print("📝 OpenAI Analysis Response: \(content)")
            print("✅✅✅ OPENAI ANALYSIS RECEIVED SUCCESSFULLY ✅✅✅")
            
            return try parseAnalysisResponse(content)
        } catch {
            print("❌ OpenAI API Error: \(error.localizedDescription)")
            throw OpenAIError.apiError(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ jsonString: String) throws -> OpenAIAnalysisResponse {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(OpenAIAnalysisResponse.self, from: jsonData)
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
