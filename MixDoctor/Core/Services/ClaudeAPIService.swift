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
        if let key = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_CLAUDE_API_KEY_HERE",
           key != "$(CLAUDE_API_KEY)" {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Claude API key loaded: \(trimmedKey.prefix(20))...")
            print("Claude API key length: \(trimmedKey.count)")
            return trimmedKey
        } else {
            print("Claude API key NOT loaded properly - using fallback")
            return "missing-api-key"
        }
    }
    
    /// Send audio analysis metrics to Claude and get AI insights
    func analyzeAudioMetrics(_ metrics: AudioMetricsForClaude) async throws -> ClaudeAnalysisResponse {
        print("Claude API request ..")
        
        // DEBUG: Print actual values being sent to Claude
        
        let prompt = createAnalysisPrompt(from: metrics)
        
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
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(getClaudeAPIKey(), forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Claude API error: Invalid response")
            throw ClaudeAPIError.invalidResponse
        }
        
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Claude API error (\(httpResponse.statusCode)): \(errorMessage)")
            
            // Specific error messages for common issues
            switch httpResponse.statusCode {
            case 401:
                break
            case 429:
                break
            case 400:
                break
            case 500, 502, 503:
                break
            default:
                break
            }
            
            throw ClaudeAPIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        
        print("Claude API response: Success (\(httpResponse.statusCode))")
        
        // 🔍 DEBUG: Print the raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
        }
        
        return try parseClaudeResponse(data)
    }
    
    private func determineModel(isProUser: Bool) -> String {
        // Using official Anthropic Claude 4.5 models (Nov 2025)
        // Pro users get Sonnet (smartest), free users get Haiku (fastest)
        return isProUser ? "claude-sonnet-4-5-20250929" : "claude-haiku-4-5-20251001"
    }
    
    private func createAnalysisPrompt(from metrics: AudioMetricsForClaude) -> String {
        // Detect if this is likely a mastered track
        let isMasteredTrack = detectMasteredTrack(metrics)
        
        // Detect likely genre based on frequency characteristics
        let detectedGenre = detectGenre(metrics)
        
        // Debug logging
        
        if isMasteredTrack {
            return createMasteredTrackPrompt(metrics: metrics, genre: detectedGenre)
        } else {
            return createPreMasterPrompt(from: metrics, genre: detectedGenre)
        }
    }
    
    private func detectMasteredTrack(_ metrics: AudioMetricsForClaude) -> Bool {
        // FIXED: Previous version was TOO STRICT - Abbey Road masters were being scored as pre-masters!
        // Mastered tracks typically have MOST (3 out of 4) of these characteristics:
        // 1. High peak levels (>-3dB) - mastered tracks are close to 0dB
        // 2. Moderate dynamic range (4-15dB) - professional masters vary by genre
        // 3. Optimized loudness (-6 to -25 LUFS) - wide range for different streaming platforms
        // 4. High RMS levels (>-16dB) - indicates proper loudness optimization
        
        let hasHighPeaks = metrics.peakLevel > -3.0  // Relaxed from >-2.0
        let hasModerateToLowDynamicRange = metrics.dynamicRange < 15.0  // Relaxed from <12.0
        let hasOptimizedLoudness = metrics.loudness > -25.0 && metrics.loudness < -6.0  // Widened from -8 to -23
        let hasHighRMS = metrics.rmsLevel > -16.0  // Relaxed from >-14.0
        
        // Require 3 out of 4 criteria (not ALL 4) - more realistic for professional masters
        let criteriaCount = [hasHighPeaks, hasModerateToLowDynamicRange, hasOptimizedLoudness, hasHighRMS].filter { $0 }.count
        let isMastered = criteriaCount >= 3
        
        // Enhanced debug logging
        if isMastered {
        } else {
        }
        
        return isMastered
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
        You are analyzing a MASTERED TRACK using industry-standard professional mastering metrics.

        🎯 CORE ANALYSIS METRICS (Industry Standards):
        
        🎚️ STEREO WIDTH:
        • Current: \(String(format: "%.1f", metrics.stereoWidth))%
        • Calculation: width = 1 - correlation OR width = (L-R)/(L+R)
        • Display: Percentage (0-100%) or visual meter
        • Warning Thresholds: <20% (too narrow), >90% (unstable)
        
        🎭 PHASE CORRELATION:
        • Current: \(String(format: "%.1f", metrics.phaseCoherence * 100))%
        • Calculation: correlation = Σ(L×R) / √(Σ(L²)×Σ(R²))
        • Display: -1.0 to +1.0 scale + goniometer
        • Warning Threshold: <0.5 (phase issues)
        
        🔊 MONO COMPATIBILITY:
        • Current: \(String(format: "%.1f", metrics.monoCompatibility * 100))%
        • Calculation: loss = 20×log₁₀(mono_rms/stereo_rms)
        • Display: dB difference + pass/fail
        • Warning Threshold: >3dB loss (fail)
        
        📊 PEAK LEVEL:
        • Current: \(String(format: "%.1f", metrics.peakLevel)) dBFS
        • Calculation: max(abs(samples))
        • Display: dBFS
        • Warning Threshold: >-0.1 dBFS (clipping risk)
        
        📈 RMS/LOUDNESS:
        • Current: \(String(format: "%.1f", metrics.loudness)) LUFS
        • Standard: LUFS (ITU-R BS.1770-4)
        • Display: LUFS/dB
        • Warning Thresholds: <-14 LUFS (streaming), >-6 LUFS (too loud)
        
        🎚️ DYNAMIC RANGE:
        • Current: \(String(format: "%.1f", metrics.dynamicRange)) dB
        • Calculation: DR = peak - RMS OR PLR
        • Display: dB or DR units
        • Warning Threshold: <6 DR (over-compressed)
        
        📉 CREST FACTOR:
        • Current: \(String(format: "%.1f", metrics.truePeakLevel - metrics.rmsLevel)) dB
        • Calculation: 20×log₁₀(peak/rms)
        • Display: dB
        • Warning Threshold: <6 dB (crushed dynamics)

        🎵 FREQUENCY BALANCE:
        • Low End (20-200Hz): \(String(format: "%.1f", metrics.lowEnd))%
        • Low Mid (200-800Hz): \(String(format: "%.1f", metrics.lowMid))%
        • Mid (800Hz-3kHz): \(String(format: "%.1f", metrics.mid))%
        • High Mid (3-8kHz): \(String(format: "%.1f", metrics.highMid))%
        • High (8-20kHz): \(String(format: "%.1f", metrics.high))%

        🚨 DETECTED ISSUES:
        • Clipping: \(metrics.hasClipping ? "❌ YES" : "✅ No")
        • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES" : "✅ No")
        • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES" : "✅ No")
        • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES" : "✅ No")
        • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES" : "✅ No")

        🎯 SCORING RULES (0-100 scale):
        
        Start with base score of 75 points (INCREASED from 70).
        
        APPLY THRESHOLDS (use the warning thresholds above):
        
        STEREO WIDTH:
        • 20-90%: Good (no change)
        • <20% OR >90%: Problem (-10 points)
        
        PHASE CORRELATION:
        • ≥0.4 (40%): Good (no change) - RELAXED from ≥0.5
        • 0.3-0.4 (30-40%): Minor issues (-5 points)
        • <0.3 (30%): Phase issues (-15 points)
        
        MONO COMPATIBILITY:
        • ≤3dB loss: Good (no change)
        • >3dB loss: Fail (-20 points)
        
        PEAK LEVEL:
        • ≤-0.1 dBFS: Good (+5 points)
        • >-0.1 dBFS: Clipping risk (-25 points)
        
        LOUDNESS (IMPROVED - more realistic for mastered tracks):
        • -10 to -6 LUFS: Modern streaming master (+10 points)
        • -16 to -10 LUFS: Professional master (+5 points) - WIDENED RANGE
        • <-16 LUFS: Too quiet (-5 points)
        • >-6 LUFS: Too loud (-10 points)
        
        DYNAMIC RANGE:
        • ≥6 DR: Good (+5 points)
        • <6 DR: Over-compressed (-15 points)
        
        CREST FACTOR:
        • ≥6 dB: Good dynamics (+5 points)
        • <6 dB: Crushed dynamics (-15 points)
        
        FREQUENCY BALANCE:
        • Only penalize SEVERE imbalances (>70% bass, <2% highs, etc.)
        • Genre-specific frequency characteristics are ACCEPTABLE
        • Dark/warm masters (low highs) are PROFESSIONAL choices, not problems
        
        IMPORTANT: Mastered tracks with good metrics should score 85-100
        • No clipping + good loudness + balanced frequencies = 85-95
        • Professional masters from Abbey Road, etc. should score 90-100
        
        Calculate final score: Base 75 + bonuses - penalties (cap 0-100)
        
        📝 RESPONSE FORMAT:
        
        SCORE: [0-100 based on thresholds above]
        
        ANALYSIS: [2-3 sentences describing technical quality based on the core metrics]
        
        RECOMMENDATIONS: [List specific fixes for any threshold violations - use bullet points (•), NOT numbered lists]
        
        READY FOR MASTERING: [yes/no - based on whether all critical thresholds are met]
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
        • Phase Coherence: \(String(format: "%.1f", metrics.phaseCoherence * 100))% (Excellent: >75%, Good: >60%, Acceptable: 40-60%, Poor: <30%)
        • Mono Compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))% (Good: >70%, Acceptable: >50%)
        
        🎵 FREQUENCY BALANCE (Professional Standards):
        • Low End (20-200Hz): \(String(format: "%.1f", metrics.lowEnd))%
          - EXCELLENT: 15-25% (controlled, tight)
          - GOOD: 12-30% (balanced foundation)
          - ACCEPTABLE: 10-35% (workable)
          - PROBLEMATIC: >40% (muddy) or <8% (thin)
          
        • Low Mid (200-800Hz): \(String(format: "%.1f", metrics.lowMid))%
          - EXCELLENT: 18-28% (warmth without mud)
          - GOOD: 15-32% (body and fullness)
          - ACCEPTABLE: 12-38% (reasonable warmth)
          - PROBLEMATIC: >45% (boxy/muddy) or <10% (hollow)
          
        • Mid (800Hz-3kHz): \(String(format: "%.1f", metrics.mid))%
          - EXCELLENT: 25-35% (vocal clarity zone)
          - GOOD: 22-40% (presence and definition)
          - ACCEPTABLE: 18-45% (sufficient clarity)
          - PROBLEMATIC: >50% (harsh/forward) or <15% (dull/distant)
          
        • High Mid (3-8kHz): \(String(format: "%.1f", metrics.highMid))%
          - EXCELLENT: 12-22% (presence without harshness)
          - GOOD: 10-28% (articulation and bite)
          - ACCEPTABLE: 8-32% (adequate presence)
          - PROBLEMATIC: >35% (sibilant/harsh) or <5% (dull/muffled)
          
        • High (8-20kHz): \(String(format: "%.1f", metrics.high))%
          - EXCELLENT: 8-18% (air and sparkle)
          - GOOD: 6-22% (brightness and detail)
          - ACCEPTABLE: 4-25% (sufficient air)
          - PROBLEMATIC: >30% (sibilant/brittle) or <3% (dull/dark)

        📊 FREQUENCY BALANCE ANALYSIS:
        - Pop/Rock Standard: Low 15-25%, LowMid 20-30%, Mid 25-35%, HighMid 12-22%, High 8-18%
        - Electronic Standard: Low 20-30%, LowMid 15-25%, Mid 20-30%, HighMid 15-25%, High 10-20%
        - Acoustic Standard: Low 12-22%, LowMid 22-32%, Mid 25-40%, HighMid 10-20%, High 6-15%
        - Classical Standard: Low 10-20%, LowMid 20-30%, Mid 30-45%, HighMid 8-18%, High 5-12%

        🚨 PRE-MASTER MIX ISSUES:
        • Clipping: \(metrics.hasClipping ? "❌ YES (Major penalty)" : "✅ No")
        • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES (Major penalty)" : "✅ No")
        • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES (Penalty)" : "✅ No")
        • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES (Penalty)" : "✅ No")
        • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES (Penalty)" : "✅ No")

        PRE-MASTER MIX SCORING:
        • Start at 75 points (baseline professional mix - INCREASED from 70)
        • PENALTIES for mix issues:
          - Peak >0dB: -15 points (clipping)
          - Peak >-1dB: -5 points (insufficient headroom)
          - True Peak >-1dBFS: -5 points 
          - Stereo Width <15% OR >85%: -5 points
          - Phase Coherence <30%: -15 points (severe phase issues)
          - Phase Coherence 30-40%: -10 points (significant phase issues)
          - Phase Coherence 40-60%: -5 points (minor phase issues, common in stereo mixes)
          - Low End >70%: -15 points (extremely bass-heavy)
          - Low End 60-70%: -10 points (very bass-heavy)
          - Low End 50-60%: -5 points (bass-heavy, acceptable for some genres)
          - Frequency Imbalance: -5 points (only for severe imbalances)
          - Dynamic Range <6dB: -10 points
        • BONUSES for mix excellence:
          - Peak level -3 to -6dB: +5 points (perfect headroom)
          - Good dynamic range (>15dB): +5 points
          - Balanced frequency spectrum: +5 points
          - Excellent phase coherence (>75%): +5 points
          - Excellent stereo width (25-45%): +5 points

        IMPORTANT SCORING GUIDANCE:
        • Minor issues (phase 40-60%, moderate bass, slight imbalances) should NOT heavily impact scores
        • A mix with decent metrics (stereo width 25-45%, phase >40%, balanced frequencies) should score 70-80
        • Only apply multiple penalties if there are MULTIPLE SEVERE issues
        • Be generous with scores - most professional pre-masters score 75-85

        Be REALISTIC for PRE-MASTERS:
        • Excellent mix ready for mastering: 85-100 points
        • Good mix ready for mastering: 75-84 points
        • Decent mix needing work: 65-74 points
        • Poor/amateur mix: 40-64 points

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
        
        // Parse the structured response
        let lines = textContent.components(separatedBy: .newlines)
        var score: Int?
        var analysis = ""
        var recommendations: [String] = []
        var currentSection = ""
        var skipCalculationSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip "YOUR CALCULATION:" section entirely
            if trimmedLine.hasPrefix("YOUR CALCULATION:") {
                skipCalculationSection = true
                currentSection = ""
                continue
            }
            
            // ✅ FIXED: Parse score from lines with "SCORE:" or "FINAL SCORE:" (with optional asterisks)
            let cleanedLine = trimmedLine.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedLine.contains("SCORE:") {
                // Remove everything before "SCORE:" to handle "FINAL SCORE:", "**SCORE:**", etc.
                let scoreText = cleanedLine.components(separatedBy: "SCORE:").last?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Extract the first number from the score line (handle "100", "100/100", "85 points", etc.)
                let numbers = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let firstNumber = numbers.first, let parsedScore = Int(firstNumber) {
                    score = parsedScore
                } else {
                }
                continue
            }
            
            // Start of ANALYSIS section - exit calculation skip mode
            if trimmedLine.hasPrefix("ANALYSIS:") || trimmedLine.hasPrefix("## ANALYSIS:") {
                skipCalculationSection = false
                currentSection = "analysis"
                // Remove "ANALYSIS:" or "## ANALYSIS:" prefix
                let prefix = trimmedLine.hasPrefix("## ANALYSIS:") ? "## ANALYSIS:" : "ANALYSIS:"
                analysis = String(trimmedLine.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            
            // Start of RECOMMENDATIONS section
            if trimmedLine.hasPrefix("RECOMMENDATIONS:") || trimmedLine.hasPrefix("## RECOMMENDATIONS:") {
                skipCalculationSection = false
                currentSection = "recommendations"
                // Remove "RECOMMENDATIONS:" or "## RECOMMENDATIONS:" prefix
                let prefix = trimmedLine.hasPrefix("## RECOMMENDATIONS:") ? "## RECOMMENDATIONS:" : "RECOMMENDATIONS:"
                let recText = String(trimmedLine.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !recText.isEmpty && !isPositiveRecommendation(recText) {
                    recommendations.append(recText)
                }
                continue
            }
            
            // Skip lines if we're in the calculation section
            if skipCalculationSection {
                continue
            }
            
            // Process content for current section
            if !trimmedLine.isEmpty {
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
        }
        
        // 🔍 DEBUG: Print what we extracted
        if !recommendations.isEmpty {
        }
        
        // Determine if ready for mastering: few or no recommendations AND good score
        let isReadyForMastering = recommendations.count <= 2 && (score ?? 0) >= 75
        
        return ClaudeAnalysisResponse(
            score: score ?? 50,
            summary: analysis.trimmingCharacters(in: .whitespacesAndNewlines),
            recommendations: recommendations,
            isReadyForMastering: isReadyForMastering
        )
    }
    
    /// Remove numbered list formatting (1. 2. 3.) from Claude's response
    private func removeNumberedLists(from text: String) -> String {
        var result = text
        
        // Remove patterns like "1. ", "2. ", "3. " at the start of lines
        result = result.replacingOccurrences(
            of: #"(?m)^\s*\d+\.\s+"#,
            with: "• ",
            options: .regularExpression
        )
        
        // Also remove patterns in the middle of text
        result = result.replacingOccurrences(
            of: #"\n\s*\d+\.\s+"#,
            with: "\n• ",
            options: .regularExpression
        )
        
        return result
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
