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
        print("📡 Using OpenAI GPT-5 Nano model")
        
        let prompt = """
        You are an expert audio engineer analyzing a music mix. Based on the following technical measurements, provide a detailed analysis:
        
        Audio Measurements:
        - Peak Level: \(peakLevel) dBFS
        - RMS Level: \(rmsLevel) dBFS
        - Dynamic Range: \(dynamicRange) dB
        - Stereo Width: \(stereoWidth) (0.0 = mono, 1.0 = wide stereo)
        - Phase Coherence: \(phaseCoherence) (-1.0 = phase issues, 1.0 = perfect)
        - Low Frequency Energy (20-250Hz): \(lowFrequencyEnergy)
        - Mid Frequency Energy (250-4000Hz): \(midFrequencyEnergy)
        - High Frequency Energy (4000-20000Hz): \(highFrequencyEnergy)
        - Spectral Centroid: \(spectralCentroid) Hz
        - Zero Crossing Rate: \(zeroCrossingRate)
        
        Please analyze and respond in the following JSON format:
        {
            "overallQuality": <number 0-100>,
            "stereoAnalysis": "<brief stereo width assessment>",
            "frequencyAnalysis": "<brief frequency balance assessment>",
            "dynamicsAnalysis": "<brief dynamics assessment>",
            "recommendations": [
                "<actionable recommendation 1>",
                "<actionable recommendation 2>",
                "<actionable recommendation 3>"
            ],
            "detailedSummary": "<2-3 sentence overall assessment>"
        }
        
        Consider:
        - Overall loudness and headroom (peak should be around -0.5 to -1.0 dBFS)
        - Frequency balance (should be relatively balanced across spectrum)
        - Stereo image (0.4-0.7 is typically good for most mixes)
        - Phase coherence (below 0.7 indicates potential phase issues)
        - Dynamic range (8-14 dB is typical for modern mixes)
        - Professional mixing standards
        
        Be specific and actionable in your recommendations.
        """
        
        let query = ChatQuery(
            messages: [
                .user(.init(content: .string(prompt)))
            ],
            model: Model.gpt5_nano
        )
        
        print("📤 Sending request to OpenAI API with GPT-5 Nano...")
        
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
