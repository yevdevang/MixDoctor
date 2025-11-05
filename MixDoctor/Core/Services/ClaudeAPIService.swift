//
//  ClaudeAPIService.swift
//  MixDoctor
//
//  Claude API service for AI-powered audio analysis
//

import Foundation

/// Service for sending audio analysis data to Claude API and getting AI insights
class ClaudeAPIService {
    static let shared = ClaudeAPIService()
    
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    
    private init() {}
    
    private func getClaudeAPIKey() -> String {
        print("🔑 Checking Claude API Key configuration...")
        if let key = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_CLAUDE_API_KEY_HERE",
           key != "$(CLAUDE_API_KEY)" {
            print("🔑 Claude API Key found: \(String(key.prefix(10)))...")
            return key
        } else {
            print("""
            ⚠️ Claude API Key not configured!
            
            Instructions:
            1. Open Config.xcconfig file
            2. Add your Claude API key to Config.xcconfig
            3. CLAUDE_API_KEY = your_actual_api_key_here
            """)
            return "missing-api-key"
        }
    }
    
    /// Send audio analysis metrics to Claude and get AI insights
    func analyzeAudioMetrics(_ metrics: AudioMetricsForClaude) async throws -> ClaudeAnalysisResponse {
        print("🤖 ClaudeAPIService: Starting analysis...")
        print("🤖 Is Pro User: \(metrics.isProUser)")
        print("🤖 Model: \(determineModel(isProUser: metrics.isProUser))")
        
        // DEBUG: Print actual values being sent to Claude
        print("\n🔍 ACTUAL VALUES BEING ANALYZED:")
        print("   Peak Level: \(metrics.peakLevel) dB (should be -0.2 based on meters)")
        print("   RMS Level: \(metrics.rmsLevel) dB")
        print("   Loudness: \(metrics.loudness) LUFS") 
        print("   Dynamic Range: \(metrics.dynamicRange) dB")
        print("   True Peak: \(metrics.truePeakLevel) dBFS")
        print("   Stereo Width: \(metrics.stereoWidth) (raw)")
        print("   Phase Coherence: \(metrics.phaseCoherence) (raw)")
        print("   Mono Compatibility: \(metrics.monoCompatibility) (raw)")
        print("   Low End: \(metrics.lowEnd) (raw)")
        print("   Low Mid: \(metrics.lowMid) (raw)")
        print("   Mid: \(metrics.mid) (raw)")
        print("   High Mid: \(metrics.highMid) (raw)")
        print("   High: \(metrics.high) (raw)")
        print("   Has Clipping: \(metrics.hasClipping)")
        print("   Has Phase Issues: \(metrics.hasPhaseIssues)")
        print("   Has Stereo Issues: \(metrics.hasStereoIssues)")
        print("   Has Frequency Imbalance: \(metrics.hasFrequencyImbalance)")
        print("   Has Dynamic Range Issues: \(metrics.hasDynamicRangeIssues)")
        print("🔍 END VALUES\n")
        
        let prompt = createAnalysisPrompt(from: metrics)
        print("🤖 Prompt length: \(prompt.count) characters")
        
        let requestBody: [String: Any] = [
            "model": determineModel(isProUser: metrics.isProUser),
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        print("🤖 Request size: \(jsonData.count) bytes")
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(getClaudeAPIKey(), forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        
        print("🤖 Making API request to: \(apiURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("🤖 Received response: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw ClaudeAPIError.invalidResponse
        }
        
        print("🤖 HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Claude API Error (\(httpResponse.statusCode)): \(errorMessage)")
            
            // Specific error messages for common issues
            switch httpResponse.statusCode {
            case 401:
                print("❌ AUTHENTICATION ERROR: Invalid API key or unauthorized")
            case 429:
                print("❌ RATE LIMIT ERROR: Too many requests or insufficient credits")
                print("💡 Check your Anthropic billing dashboard for credit balance")
            case 400:
                print("❌ BAD REQUEST: Invalid request format")
            case 500, 502, 503:
                print("❌ ANTHROPIC SERVER ERROR: Try again later")
            default:
                break
            }
            
            throw ClaudeAPIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        print("✅ Claude API request successful, parsing response...")
        return try parseClaudeResponse(data)
    }
    
    private func determineModel(isProUser: Bool) -> String {
        return isProUser ? "claude-sonnet-4-5" : "claude-haiku-4-5"
    }
    
    private func createAnalysisPrompt(from metrics: AudioMetricsForClaude) -> String {
        // Detect if this is likely a mastered track
        let isMasteredTrack = detectMasteredTrack(metrics)
        
        // Detect likely genre based on frequency characteristics
        let detectedGenre = detectGenre(metrics)
        
        // Debug logging
        print("🔍 MASTERED TRACK DETECTION:")
        print("   Peak Level: \(String(format: "%.1f", metrics.peakLevel))dB (>-3.0: \(metrics.peakLevel > -3.0))")
        print("   Dynamic Range: \(String(format: "%.1f", metrics.dynamicRange))dB (<15.0: \(metrics.dynamicRange < 15.0))")
        print("   Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS (-25 to -6: \(metrics.loudness > -25.0 && metrics.loudness < -6.0))")
        print("   RMS Level: \(String(format: "%.1f", metrics.rmsLevel))dB (>-16.0: \(metrics.rmsLevel > -16.0))")
        print("   🎯 DETECTED AS: \(isMasteredTrack ? "MASTERED TRACK" : "PRE-MASTER MIX")")
        print("   🎸 DETECTED GENRE: \(detectedGenre)")
        
        if isMasteredTrack {
            return createMasteredTrackPrompt(metrics: metrics, genre: detectedGenre)
        } else {
            return createPreMasterPrompt(from: metrics, genre: detectedGenre)
        }
    }
    
    private func detectMasteredTrack(_ metrics: AudioMetricsForClaude) -> Bool {
        // Mastered tracks typically have:
        // 1. High peak levels (>-3dB) - most mastered tracks are close to 0dB
        // 2. Moderate dynamic range (4-15dB) - adjusted to be more inclusive
        // 3. Optimized loudness (-6 to -23 LUFS) - expanded range for all mastered tracks
        // 4. High RMS levels (>-16dB) - more realistic threshold
        
        let hasHighPeaks = metrics.peakLevel > -3.0
        let hasModerateToLowDynamicRange = metrics.dynamicRange < 15.0  // More realistic for mastered tracks
        let hasOptimizedLoudness = metrics.loudness > -25.0 && metrics.loudness < -6.0  // Fixed range to include -17.7 LUFS
        let hasHighRMS = metrics.rmsLevel > -16.0  // Adjusted threshold to include -15.09
        
        // Consider it mastered if 3 out of 4 criteria are met
        let criteriaCount = [hasHighPeaks, hasModerateToLowDynamicRange, hasOptimizedLoudness, hasHighRMS].filter { $0 }.count
        return criteriaCount >= 3
    }
    
    private func detectGenre(_ metrics: AudioMetricsForClaude) -> String {
        // Genre detection based on frequency characteristics and dynamics
        
        // Electronic/EDM: Very high bass (>40%), moderate dynamics (<10dB), high loudness
        if metrics.lowEnd > 40.0 && metrics.dynamicRange < 10.0 && metrics.loudness > -12.0 {
            return "Electronic/EDM"
        }
        
        // Hip-Hop: High bass (>35%), low high frequencies (<3%), moderate dynamics
        if metrics.lowEnd > 35.0 && metrics.high < 3.0 && metrics.dynamicRange < 12.0 {
            return "Hip-Hop"
        }
        
        // Rock/Metal: Balanced low-mid presence (>20%), good high-mid (>10%), good dynamics (>8dB)
        if metrics.lowMid > 20.0 && metrics.highMid > 10.0 && metrics.dynamicRange > 8.0 && metrics.high > 5.0 {
            return "Rock/Metal"
        }
        
        // Pop: Balanced overall, strong mid presence (>25%), good high frequencies (>5%)
        if metrics.mid > 25.0 && metrics.high > 5.0 && metrics.lowEnd < 35.0 {
            return "Pop"
        }
        
        // Acoustic/Folk: Good dynamics (>12dB), balanced frequencies, not bass-heavy
        if metrics.dynamicRange > 12.0 && metrics.lowEnd < 30.0 && metrics.mid > 20.0 {
            return "Acoustic/Folk"
        }
        
        // Classical: High dynamics (>15dB), balanced spectrum
        if metrics.dynamicRange > 15.0 && metrics.lowEnd < 25.0 {
            return "Classical"
        }
        
        // Jazz: Good dynamics (>10dB), balanced with some high frequency content
        if metrics.dynamicRange > 10.0 && metrics.high > 8.0 && metrics.lowEnd < 35.0 {
            return "Jazz"
        }
        
        // Alternative/Dark Pop: Bass-heavy but with creative intent (Abbey Road style)
        if metrics.lowEnd > 40.0 && metrics.high < 5.0 && metrics.dynamicRange > 10.0 {
            return "Alternative/Dark Pop"
        }
        
        // Default to Alternative/Indie if no clear match
        return "Alternative/Indie"
    }
    
    private func getGenreFrequencyGuidelines(genre: String, metrics: AudioMetricsForClaude) -> String {
        let lowEnd = String(format: "%.1f", metrics.lowEnd)
        let lowMid = String(format: "%.1f", metrics.lowMid)
        let mid = String(format: "%.1f", metrics.mid)
        let highMid = String(format: "%.1f", metrics.highMid)
        let high = String(format: "%.1f", metrics.high)
        
        switch genre {
        case "Electronic/EDM":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ELECTRONIC GOOD: 35-50%, ACCEPTABLE: 30-60%, POOR: >65%)
        • Low Mid (200-800Hz): \(lowMid)% (ELECTRONIC GOOD: 15-25%, ACCEPTABLE: 10-30%)
        • Mid (800Hz-3kHz): \(mid)% (ELECTRONIC GOOD: 15-30%, VOCAL PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (ELECTRONIC GOOD: 10-20%, SYNTH CLARITY)
        • High (8-20kHz): \(high)% (ELECTRONIC GOOD: 8-18%, SPARKLE/FX)
        """
        case "Hip-Hop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (HIP-HOP GOOD: 30-45%, ACCEPTABLE: 25-55%, POOR: >60%)
        • Low Mid (200-800Hz): \(lowMid)% (HIP-HOP GOOD: 20-35%, VOCALS/808s)
        • Mid (800Hz-3kHz): \(mid)% (HIP-HOP GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (HIP-HOP GOOD: 8-20%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (HIP-HOP ACCEPTABLE: 2-12%, MINIMAL BY DESIGN)
        """
        case "Alternative/Dark Pop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (DARK POP GOOD: 35-50%, CREATIVE CHOICE, ABBEY ROAD STYLE)
        • Low Mid (200-800Hz): \(lowMid)% (DARK POP GOOD: 18-30%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (DARK POP GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (DARK POP ACCEPTABLE: 5-15%, INTENTIONALLY REDUCED)
        • High (8-20kHz): \(high)% (DARK POP ACCEPTABLE: 1-8%, INTENTIONALLY DARK/WARM)
        """
        case "Rock/Metal":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ROCK GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (ROCK GOOD: 20-30%, GUITAR BODY)
        • Mid (800Hz-3kHz): \(mid)% (ROCK GOOD: 25-40%, VOCAL/GUITAR PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (ROCK GOOD: 15-28%, GUITAR BITE/CLARITY)
        • High (8-20kHz): \(high)% (ROCK GOOD: 8-18%, CYMBALS/AIR)
        """
        case "Pop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (POP GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (POP GOOD: 18-28%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (POP GOOD: 28-45%, VOCAL CLARITY CRITICAL)
        • High Mid (3-8kHz): \(highMid)% (POP GOOD: 15-25%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (POP GOOD: 8-15%, SPARKLE/AIR)
        """
        default:
            return """
        • Low End (20-200Hz): \(lowEnd)% (GENERAL GOOD: 15-30%, ACCEPTABLE: 12-35%)
        • Low Mid (200-800Hz): \(lowMid)% (GENERAL GOOD: 18-30%, WARMTH)
        • Mid (800Hz-3kHz): \(mid)% (GENERAL GOOD: 25-40%, CLARITY)
        • High Mid (3-8kHz): \(highMid)% (GENERAL GOOD: 15-25%, PRESENCE)
        • High (8-20kHz): \(high)% (GENERAL GOOD: 8-18%, AIR)
        """
        }
    }
    }
    
        private func createMasteredTrackPrompt(metrics: AudioMetricsForClaude, genre: String) -> String {
        return """
        You are analyzing a MASTERED TRACK using professional mastering standards. This is NOT a pre-master mix.

        🎯 MASTERED TRACK ANALYSIS - Use MASTERING STANDARDS:
        
        🎚️ MASTERED LEVELS & DYNAMICS:
        • Peak Level: \(String(format: "%.1f", metrics.peakLevel)) dB (MASTERED TARGET: -0.1 to -1dB, GOOD: -0.3 to -3dB)
        • RMS Level: \(String(format: "%.1f", metrics.rmsLevel)) dB (MASTERED TARGET: -6 to -12dB, GOOD: -8 to -16dB)
        • Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS (STREAMING: -14 LUFS, PROFESSIONAL: -8 to -20 LUFS, CONSERVATIVE: -16 to -23 LUFS)
        • Dynamic Range: \(String(format: "%.1f", metrics.dynamicRange)) dB (MASTERED: 4-12dB Normal, 6-15dB Good, >15dB Excellent)
        • True Peak: \(String(format: "%.1f", metrics.truePeakLevel)) dBFS (MASTERED: <-0.1dBFS Required, <-0.3dBFS Safe)
        
        🎭 STEREO & PHASE (Same for mastered):
        • Stereo Width: \(String(format: "%.1f", metrics.stereoWidth))% (Excellent: 25-45%, Good: 20-55%, Wide: 55-85%)
        • Phase Coherence: \(String(format: "%.1f", metrics.phaseCoherence * 100))% (Excellent: >80%, Good: >60%, Poor: <50%)
        • Mono Compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))% (Good: >70%, Acceptable: >50%)
        
        🎵 FREQUENCY BALANCE (GENRE-AWARE STANDARDS - DETECTED: \(genre)):
        \(getGenreFrequencyGuidelines(genre: genre, metrics: metrics))
        • Low Mid (200-800Hz): \(String(format: "%.1f", metrics.lowMid))% (GOOD: 20-35%, POOR: >40% or <10%)
        • Mid (800Hz-3kHz): \(String(format: "%.1f", metrics.mid))% (GOOD: 15-35%, VOCAL CLARITY CRITICAL, POOR: <10%)
        • High Mid (3-6kHz): \(String(format: "%.1f", metrics.highMid))% (GOOD: 8-20%, PRESENCE/CLARITY, POOR: <3%)
        • High (6-18kHz): \(String(format: "%.1f", metrics.high))% (VARIES BY GENRE: Dark/Warm 0.5-5%, Balanced 3-12%, Bright 8-20%)

        🚨 MASTERED TRACK ISSUES:
        • Clipping: \(metrics.hasClipping ? "❌ YES (Major penalty)" : "✅ No")
        • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES (Major penalty)" : "✅ No")
        • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES (Penalty)" : "✅ No")
        • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES (Penalty)" : "✅ No")
        • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ Only if <4dB (over-limited)" : "✅ No")

        ⚠️ MASTERED TRACK SCORING ADJUSTMENTS:
        • Peak Level -0.1 to -1dB = PERFECT (no penalty)
        • Peak Level -1 to -3dB = GOOD (no penalty)  
        • Peak Level >0dB = Digital clipping (Score -15)
        • True Peak >-0.1dBFS = Clipping risk (Score -10)
        • Dynamic Range 6-15dB = GOOD (no penalty)
        • Dynamic Range 4-6dB = ACCEPTABLE (no penalty)
        • Dynamic Range <4dB = Over-limited (Score -10)
        • Loudness -8 to -23 LUFS = PROFESSIONAL RANGE (no penalty)
        • Loudness <-23 LUFS = Too quiet (Score -5)
        • Loudness >-8 LUFS = Too loud/aggressive (Score -5)

        MASTERED TRACK SCORING:
        • Start at 80 points (baseline mastered track - higher than before)
        • PENALTIES for mastered track issues:
          - Peak >0dB: -15 points (critical for masters)
          - True Peak >-0.1: -10 points
          - Dynamic Range <4dB: -10 points (over-limited)
          - Phase Coherence <50%: -10 points (serious issue)
          - Phase Coherence 50-60%: -5 points (minor issue)
          - Extreme bass dominance (>85% combined low): -5 points (was too harsh)
          - Clipping detected: -10 points
        • BONUSES for mastered excellence:
          - Peak level -0.1 to -1dB: +5 points (perfect mastering)
          - Loudness -8 to -23 LUFS: +3 points (professional range)
          - Dynamic Range 6-15dB: +5 points (good dynamics preserved)
          - Excellent phase coherence (>85%): +5 points
          - Genre-appropriate frequency response: +5 points (NEW)
          - Professional dark/warm masters (like Abbey Road): +3 points for intentional character

        Be REALISTIC for MASTERED TRACKS:
        • IMPORTANT: Dark/warm masters are a PROFESSIONAL CHOICE, not a flaw
        • ABBEY ROAD/VINTAGE STYLE: Low high frequencies (0.5-3%) is ACCEPTABLE for this style
        • ELECTRONIC/HIP-HOP: Bass-heavy (40-70% low end) is normal and acceptable
        • POP: Balanced but can vary (20-40% lows, 3-12% highs)
        • Focus on TECHNICAL QUALITY: no clipping, good phase coherence, appropriate dynamics
        • Genre detection should INFORM scoring, not penalize creative choices
        • For ELECTRONIC: Bass dominance is expected and should not be heavily penalized
        
        Scoring ranges:
        • Excellent master: 88-100 points (Abbey Road quality should be here)
        • Very good commercial master: 80-87 points  
        • Good commercial master: 72-79 points
        • Acceptable master: 65-71 points
        • Problematic master: 50-64 points

        Format response as:
        SCORE: [realistic 0-100 score for MASTERED TRACK - be generous for professional work]
        ANALYSIS: [2-3 sentences about the master quality and technical assessment]
        RECOMMENDATIONS: [Mastering-specific feedback, or "Excellent master - ready for distribution" if great]
        """
    }
    
    private func createPreMasterPrompt(from metrics: AudioMetricsForClaude, genre: String) -> String {
        return """
        You are analyzing a PRE-MASTERED MIX using professional mixing standards. This is NOT a final master.

        🎯 PRE-MASTER MIX ANALYSIS - Use MIXING STANDARDS:
        
        🎚️ PRE-MASTER LEVELS & DYNAMICS:
        • Peak Level: \(String(format: "%.1f", metrics.peakLevel)) dB (MIX TARGET: -3 to -6dB, GOOD: -3 to -8dB)
        • RMS Level: \(String(format: "%.1f", metrics.rmsLevel)) dB (MIX TARGET: -12 to -18dB, GOOD: -10 to -22dB)
        • Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS (MIX TARGET: -16 to -23 LUFS, GOOD: -14 to -30)
        • Dynamic Range: \(String(format: "%.1f", metrics.dynamicRange)) dB (EXCELLENT: >15dB, GOOD: 8-15dB, POOR: <6dB)
        • True Peak: \(String(format: "%.1f", metrics.truePeakLevel)) dBFS (MIX: <-3dBFS Good, <-1dBFS Acceptable)
        
        🎭 STEREO & PHASE:
        • Stereo Width: \(String(format: "%.1f", metrics.stereoWidth))% (Excellent: 25-45%, Good: 20-55%, Wide: 55-85%)
        • Phase Coherence: \(String(format: "%.1f", metrics.phaseCoherence * 100))% (Excellent: >80%, Good: >60%, Poor: <50%)
        • Mono Compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))% (Good: >70%, Acceptable: >50%)
        
        🎵 FREQUENCY BALANCE:
        • Low End: \(String(format: "%.1f", metrics.lowEnd))% (Balanced: 15-35%, Acceptable: 10-45%)
        • Low Mid: \(String(format: "%.1f", metrics.lowMid))% (Balanced: 15-30%, Acceptable: 10-40%)
        • Mid: \(String(format: "%.1f", metrics.mid))% (Balanced: 20-40%, Acceptable: 15-50%)
        • High Mid: \(String(format: "%.1f", metrics.highMid))% (Balanced: 15-30%, Acceptable: 10-35%)
        • High: \(String(format: "%.1f", metrics.high))% (Balanced: 8-25%, Acceptable: 5-30%)

        🚨 PRE-MASTER MIX ISSUES:
        • Clipping: \(metrics.hasClipping ? "❌ YES (Major penalty)" : "✅ No")
        • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES (Major penalty)" : "✅ No")
        • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES (Penalty)" : "✅ No")
        • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES (Penalty)" : "✅ No")
        • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES (Penalty)" : "✅ No")

        PRE-MASTER MIX SCORING:
        • Start at 70 points (baseline professional mix)
        • PENALTIES for mix issues:
          - Peak >0dB: -15 points (clipping)
          - Peak >-1dB: -5 points (insufficient headroom)
          - True Peak >-1dBFS: -5 points 
          - Stereo Width <15% OR >85%: -5 points
          - Phase Coherence <60%: -10 points
          - Low End >50%: -10 points
          - Frequency Imbalance: -5 points
          - Dynamic Range <6dB: -10 points
        • BONUSES for mix excellence:
          - Peak level -3 to -6dB: +5 points (perfect headroom)
          - Good dynamic range (>15dB): +5 points
          - Balanced frequency spectrum: +5 points
          - Excellent phase coherence (>85%): +5 points
          - Excellent stereo width (25-45%): +5 points

        Be REALISTIC for PRE-MASTERS:
        • Excellent mix ready for mastering: 85-95 points
        • Good mix ready for mastering: 75-84 points
        • Decent mix needing work: 60-74 points
        • Poor/amateur mix: 30-59 points

        Format response as:
        SCORE: [realistic 0-100 score for PRE-MASTER MIX]
        ANALYSIS: [2-3 sentences explaining the mix quality and readiness for mastering]
        RECOMMENDATIONS: [Specific mixing improvements, or "Ready for mastering" if excellent]
        """
    }
    
    private func isPositiveRecommendation(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let positiveKeywords = [
            "none",
            "well balanced",
            "ready for mastering",
            "excellent",
            "no issues",
            "good balance",
            "professional quality",
            "mastering ready",
            "well mixed",
            "no recommendations",
            "sounds great",
            "technical balance"
        ]
        
        return positiveKeywords.contains { lowercased.contains($0) }
    }
    
    private func parseClaudeResponse(_ data: Data) throws -> ClaudeAnalysisResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let content = json?["content"] as? [[String: Any]],
              let textContent = content.first?["text"] as? String else {
            throw ClaudeAPIError.parseError
        }
        
        // DEBUG: Print Claude's raw response
        print("🤖 Claude's raw response:")
        print(textContent)
        print("🤖 End raw response\n")
        
        // Parse the structured response
        let lines = textContent.components(separatedBy: .newlines)
        var score: Int?
        // 🔍 COMMENTED OUT - parsing analysis and recommendations to show raw output
        // var analysis = ""
        // var recommendations: [String] = []
        
        // var currentSection = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for SCORE: with or without asterisks/formatting
            if trimmedLine.contains("SCORE:") {
                // currentSection = "score"  // 🔍 COMMENTED OUT
                let scoreText = trimmedLine.replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "SCORE:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔍 Parsing score: '\(scoreText)'")
                
                // Try to extract just the number (handle cases like "25 points", "25/100", etc.)
                let numbers = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let firstNumber = numbers.first {
                    score = Int(firstNumber)
                    print("🔍 Extracted score: \(score!)")
                } else {
                    score = Int(scoreText) // fallback to original parsing
                }
                print("🔍 Parsed score: \(score ?? -1)")
            }
            /* 🔍 COMMENTED OUT - summary and recommendations parsing
            else if trimmedLine.hasPrefix("ANALYSIS:") {
                currentSection = "analysis"
                analysis = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.hasPrefix("RECOMMENDATIONS:") {
                currentSection = "recommendations"
                let recText = String(trimmedLine.dropFirst(16)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !recText.isEmpty && !isPositiveRecommendation(recText) {
                    recommendations.append(recText)
                }
            } else if !trimmedLine.isEmpty {
                if currentSection == "analysis" {
                    analysis += " " + trimmedLine
                } else if currentSection == "recommendations" {
                    if trimmedLine.hasPrefix("-") || trimmedLine.hasPrefix("•") {
                        let cleanRec = trimmedLine.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanRec.isEmpty && !isPositiveRecommendation(cleanRec) {
                            recommendations.append(cleanRec)
                        }
                    } else if !isPositiveRecommendation(trimmedLine) {
                        recommendations.append(trimmedLine)
                    }
                }
            }
            */
        }
        
        // 🔍 COMMENTED OUT - fallback parsing logic
        // If no structured format found, use the raw text as analysis
        // if analysis.isEmpty && recommendations.isEmpty {
        //     analysis = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        // }
        
        // Determine if ready for mastering: few or no recommendations AND good score
        // let isReadyForMastering = recommendations.count <= 2 && (score ?? 0) >= 75  // 🔍 COMMENTED OUT - using simple score check instead
        
        return ClaudeAnalysisResponse(
            score: score ?? 50, // Default score if not found
            summary: textContent.trimmingCharacters(in: .whitespacesAndNewlines), // 🔍 RAW CLAUDE OUTPUT - no parsing
            recommendations: [], // 🔍 COMMENTED OUT - showing raw output instead
            isReadyForMastering: (score ?? 0) >= 75
        )
    }
    
    private func getGenreFrequencyGuidelines(genre: String, metrics: AudioMetricsForClaude) -> String {
        let lowEnd = String(format: "%.1f", metrics.lowEnd)
        let lowMid = String(format: "%.1f", metrics.lowMid)
        let mid = String(format: "%.1f", metrics.mid)
        let highMid = String(format: "%.1f", metrics.highMid)
        let high = String(format: "%.1f", metrics.high)
        
        switch genre {
        case "Electronic/EDM":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ELECTRONIC GOOD: 35-50%, ACCEPTABLE: 30-60%, POOR: >65%)
        • Low Mid (200-800Hz): \(lowMid)% (ELECTRONIC GOOD: 15-25%, ACCEPTABLE: 10-30%)
        • Mid (800Hz-3kHz): \(mid)% (ELECTRONIC GOOD: 15-30%, VOCAL PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (ELECTRONIC GOOD: 10-20%, SYNTH CLARITY)
        • High (8-20kHz): \(high)% (ELECTRONIC GOOD: 8-18%, SPARKLE/FX)
        """
        case "Hip-Hop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (HIP-HOP GOOD: 30-45%, ACCEPTABLE: 25-55%, POOR: >60%)
        • Low Mid (200-800Hz): \(lowMid)% (HIP-HOP GOOD: 20-35%, VOCALS/808s)
        • Mid (800Hz-3kHz): \(mid)% (HIP-HOP GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (HIP-HOP GOOD: 8-20%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (HIP-HOP ACCEPTABLE: 2-12%, MINIMAL BY DESIGN)
        """
        case "Alternative/Dark Pop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (DARK POP GOOD: 35-50%, CREATIVE CHOICE, ABBEY ROAD STYLE)
        • Low Mid (200-800Hz): \(lowMid)% (DARK POP GOOD: 18-30%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (DARK POP GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (DARK POP ACCEPTABLE: 5-15%, INTENTIONALLY REDUCED)
        • High (8-20kHz): \(high)% (DARK POP ACCEPTABLE: 1-8%, INTENTIONALLY DARK/WARM)
        """
        case "Rock/Metal":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ROCK GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (ROCK GOOD: 20-30%, GUITAR BODY)
        • Mid (800Hz-3kHz): \(mid)% (ROCK GOOD: 25-40%, VOCAL/GUITAR PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (ROCK GOOD: 15-28%, GUITAR BITE/CLARITY)
        • High (8-20kHz): \(high)% (ROCK GOOD: 8-18%, CYMBALS/AIR)
        """
        case "Pop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (POP GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (POP GOOD: 18-28%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (POP GOOD: 28-45%, VOCAL CLARITY CRITICAL)
        • High Mid (3-8kHz): \(highMid)% (POP GOOD: 15-25%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (POP GOOD: 8-15%, SPARKLE/AIR)
        """
        default:
            return """
        • Low End (20-200Hz): \(lowEnd)% (GENERAL GOOD: 15-30%, ACCEPTABLE: 12-35%)
        • Low Mid (200-800Hz): \(lowMid)% (GENERAL GOOD: 18-30%, WARMTH)
        • Mid (800Hz-3kHz): \(mid)% (GENERAL GOOD: 25-40%, CLARITY)
        • High Mid (3-8kHz): \(highMid)% (GENERAL GOOD: 15-25%, PRESENCE)
        • High (8-20kHz): \(high)% (GENERAL GOOD: 8-18%, AIR)
        """
        }
    }


// MARK: - Data Models

struct AudioMetricsForClaude {
    // Basic Level Metrics
    let peakLevel: Double
    let rmsLevel: Double
    let loudness: Double
    let dynamicRange: Double
    
    // Basic Stereo Metrics  
    let stereoWidth: Double
    let phaseCoherence: Double
    let monoCompatibility: Double
    
    // Basic Frequency Balance (5 bands)
    let lowEnd: Double
    let lowMid: Double
    let mid: Double
    let highMid: Double
    let high: Double
    
    // Professional Spectral Balance (7 bands)
    let subBassEnergy: Double        // 20-60Hz
    let bassEnergy: Double           // 60-250Hz  
    let lowMidEnergy: Double         // 250-500Hz
    let midEnergy: Double            // 500Hz-2kHz
    let highMidEnergy: Double        // 2kHz-6kHz
    let presenceEnergy: Double       // 6kHz-12kHz
    let airEnergy: Double            // 12kHz-20kHz
    let balanceScore: Double         // 0-100
    let spectralTilt: Double         // -1 to 1 (negative=dark, positive=bright)
    
    // Professional Stereo Analysis
    let correlationCoefficient: Double  // -1 to 1
    let sideEnergy: Double              // Side channel energy %
    let centerImage: Double             // Center image strength %
    
    // Professional Dynamic Range Analysis
    let lufsRange: Double               // Dynamic range in LUFS
    let crestFactor: Double             // Peak-to-RMS ratio in dB
    let percentile95: Double            // 95th percentile level
    let percentile5: Double             // 5th percentile level
    let compressionRatio: Double        // Estimated compression ratio
    let headroom: Double                // Available headroom in dB
    
    // Professional Peak-to-Average Analysis
    let peakToRmsRatio: Double          // Peak-to-RMS in dB
    let peakToLufsRatio: Double         // Peak-to-LUFS in dB
    let truePeakLevel: Double           // True peak in dBFS
    let integratedLoudness: Double      // Integrated loudness in LUFS
    let loudnessRange: Double           // LRA in LU
    let punchiness: Double              // Punchiness factor 0-100
    
    // Issue Detection Flags
    let hasClipping: Bool
    let hasPhaseIssues: Bool
    let hasStereoIssues: Bool
    let hasFrequencyImbalance: Bool
    let hasDynamicRangeIssues: Bool
    
    // User Status
    let isProUser: Bool
}

struct ClaudeAnalysisResponse {
    let score: Int
    let summary: String
    let recommendations: [String]
    let isReadyForMastering: Bool
}

// MARK: - Error Handling

enum ClaudeAPIError: Error, LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case parseError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code, let message):
            return "Claude API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Claude response"
        case .networkError:
            return "Network error connecting to Claude API"
        }
    }
}
