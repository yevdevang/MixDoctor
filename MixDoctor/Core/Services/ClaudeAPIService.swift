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
    
    // MARK: - Helper Functions
    
    /// Fixes contradictory analysis text for high scores (85+)
    /// If score is 85+ but analysis contains negative phrases, returns positive fallback
    static func fixContradictoryAnalysis(analysis: String?, score: Double) -> String? {
        guard let analysis = analysis, !analysis.isEmpty else { return analysis }
        guard score >= 85 else { return analysis }
        
        let lowercasedAnalysis = analysis.lowercased()
        
        // Comprehensive negative phrase detection
        let hasNegativePhrase: Bool = {
            // Check simple string patterns - catch ANY improvement suggestions
            let stringPatterns = [
                "needs some mixing",
                "needs mixing improvements",
                "needs improvements to reach",
                "needs work to reach",
                "to reach professional standards",
                "needs more work",
                "could use improvements",
                "needs improvement",
                "requires improvement",
                "needs mixing",
                "needs work",
                "could use",
                "should consider",
                "might benefit from",
                "would benefit from",
                "could benefit from",
                "could be",
                "might want to",
                "consider",
                "try",
                "could hit",
                "needs more",
                "needs slightly",
                "could use more"
            ]
            
            if stringPatterns.contains(where: { lowercasedAnalysis.contains($0) }) {
                return true
            }
            
            // Check complex patterns - "needs" + "improvements" or "mixing" anywhere in text
            if lowercasedAnalysis.contains("needs") && (lowercasedAnalysis.contains("improvements") || lowercasedAnalysis.contains("mixing")) {
                return true
            }
            
            // Pattern: "to reach professional" (implies needs work)
            if lowercasedAnalysis.contains("to reach professional") {
                return true
            }
            
            // Pattern: "needs" + "professional" (implies not professional yet)
            if lowercasedAnalysis.contains("needs") && lowercasedAnalysis.contains("professional") {
                return true
            }
            
            // Pattern: "could" + improvement words (suggestions)
            if lowercasedAnalysis.contains("could") && (lowercasedAnalysis.contains("more") || lowercasedAnalysis.contains("be") || lowercasedAnalysis.contains("hit")) {
                return true
            }
            
            // Pattern: "might" + improvement words (suggestions)
            if lowercasedAnalysis.contains("might") && (lowercasedAnalysis.contains("want") || lowercasedAnalysis.contains("benefit")) {
                return true
            }
            
            // Pattern: "should" + improvement words (suggestions)
            if lowercasedAnalysis.contains("should") && (lowercasedAnalysis.contains("consider") || lowercasedAnalysis.contains("try")) {
                return true
            }
            
            return false
        }()
        
        if hasNegativePhrase {
            print("⚠️ CONTRADICTION DETECTED: Score is \(score) but analysis contains negative phrases")
            print("⚠️ Original analysis: '\(analysis)'")
            let positiveFallback = "Professional quality track ready for distribution."
            print("⚠️ Using positive fallback instead: '\(positiveFallback)'")
            return positiveFallback
        }
        
        return analysis
    }
    
    // MARK: - Testing Support
    
    /// Reset service state - primarily for testing purposes
    /// Call this in test tearDown to ensure clean state between tests
    /// Note: This service is stateless, but method provided for consistency
    func reset() {
        // ClaudeAPIService is stateless - no state to reset
        // Method exists for test consistency and future-proofing
    }
    
    private func getClaudeAPIKey() -> String {
        if let key = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_CLAUDE_API_KEY_HERE",
           key != "$(CLAUDE_API_KEY)" {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedKey
        } else {
            return "missing-api-key"
        }
    }
    
    /// Send audio analysis metrics to Claude and get AI insights
    func analyzeAudioMetrics(_ metrics: AudioMetricsForClaude, userGenre: String? = nil, mixStage: String? = nil) async throws -> ClaudeAnalysisResponse {
        
        // Debug: print ALL key metrics sent to Claude for scoring diagnosis
        print("══════════════════════════════════════════════")
        print("📊 FULL METRICS SENT TO CLAUDE (mixStage: \(mixStage ?? "nil"))")
        print("══════════════════════════════════════════════")
        print("  🔊 Loudness (LUFS):     \(String(format: "%.1f", metrics.loudness))")
        print("  📊 Peak Level (dBFS):    \(String(format: "%.1f", metrics.peakLevel))")
        print("  📈 RMS Level (dB):       \(String(format: "%.1f", metrics.rmsLevel))")
        print("  🎚️ Dynamic Range (dB):   \(String(format: "%.1f", metrics.dynamicRange))")
        print("  📉 Crest Factor (dB):    \(String(format: "%.1f", metrics.truePeakLevel - metrics.rmsLevel))")
        print("  🔝 True Peak (dBFS):     \(String(format: "%.1f", metrics.truePeakLevel))")
        print("  📏 Integrated LUFS:      \(String(format: "%.1f", metrics.integratedLoudness))")
        print("  🎚️ Stereo Width:         \(String(format: "%.1f", metrics.stereoWidth))%")
        print("  🎭 Phase Coherence:      \(String(format: "%.3f", metrics.phaseCoherence)) (\(String(format: "%.1f", metrics.phaseCoherence * 100))%)")
        print("  🔊 Mono Compatibility:   \(String(format: "%.1f", metrics.monoCompatibility * 100))%")
        print("  🏷️ Genre:                \(metrics.genre ?? "nil")")
        print("  🚨 Issue Flags:")
        print("     Clipping:             \(metrics.hasClipping)")
        print("     Phase Issues:         \(metrics.hasPhaseIssues)")
        print("     Stereo Issues:        \(metrics.hasStereoIssues)")
        print("     Freq Imbalance:       \(metrics.hasFrequencyImbalance)")
        print("     DR Issues:            \(metrics.hasDynamicRangeIssues)")
        print("     Likely Unmixed:       \(metrics.isLikelyUnmixed)")
        print("  🎵 Frequency Balance:")
        print("     Low End:  \(String(format: "%.1f", metrics.lowEnd))%  |  Low Mid: \(String(format: "%.1f", metrics.lowMid))%  |  Mid: \(String(format: "%.1f", metrics.mid))%  |  High Mid: \(String(format: "%.1f", metrics.highMid))%  |  High: \(String(format: "%.1f", metrics.high))%")
        print("  7-band: SubBass \(String(format: "%.1f", metrics.subBassEnergy))%, Bass \(String(format: "%.1f", metrics.bassEnergy))%, LowMid \(String(format: "%.1f", metrics.lowMidEnergy))%, Mid \(String(format: "%.1f", metrics.midEnergy))%, HighMid \(String(format: "%.1f", metrics.highMidEnergy))%, Presence \(String(format: "%.1f", metrics.presenceEnergy))%, Air \(String(format: "%.1f", metrics.airEnergy))%")
        print("══════════════════════════════════════════════")
        let frequencyTotal = metrics.lowEnd + metrics.lowMid + metrics.mid + metrics.highMid + metrics.high
        if frequencyTotal < 1.0 {
            print("⚠️ WARNING: All frequency bands are near zero — AnalysisResult may not be fully populated")
        }

        // Validate metrics before building any prompt
        try validateMetrics(metrics)

        // Detect track type and genre
        // Stage mismatches (user says Mix but it's a Master, or vice versa) are caught
        // BEFORE this function is called — AudioKitService returns early without calling Claude.
        // By the time we get here, the user-selected stage is trusted.
        let stageLower = mixStage?.lowercased() ?? ""
        let isMasteredByStage = stageLower.contains("master")
        let isMixStage = stageLower == "mix"
        let isMasteredByMetrics = detectMasteredTrack(metrics)

        let isMastered: Bool
        if isMixStage {
            isMastered = false
        } else if isMasteredByStage {
            isMastered = true
        } else {
            isMastered = isMasteredByMetrics  // Auto-detect from metrics
        }

        if let stage = mixStage {
            print("🎚️ USER-SELECTED STAGE: \(stage) - isMastered: \(isMastered) (Mix='\(isMixStage)', Master='\(isMasteredByStage)')")
        }
        // Prioritize genre from metrics (user-selected), then userGenre parameter, then auto-detect
        let genre = metrics.genre ?? userGenre ?? detectGenre(metrics)

        // Unmixed detection
        let isUnmixed: Bool
        if isMasteredByStage {
            isUnmixed = false
        } else {
            isUnmixed = metrics.isLikelyUnmixed
        }

        if let selectedGenre = metrics.genre ?? userGenre {
            print("🏷️ USER-SELECTED GENRE: \(selectedGenre)")
        } else {
            print("🏷️ AUTO-DETECTED: isMastered=\(isMastered), genre=\(genre), isUnmixed=\(isUnmixed)")
        }

        // Check if track was flagged as unmixed by AudioKit detection
        if isUnmixed {
            print("🚨 UNMIXED TRACK DETECTED - Using unmixed scoring rules")
            print("  Mixing Quality Score: \(String(format: "%.1f", metrics.mixingQualityScore))%")
        }
        
        // Get separated prompts for caching
        // CACHE VERSION: Update this number when scoring rules change to bust the cache
        let cacheVersion = "v12.0-METAL-GENRE-OVERRIDE"  // Metal/Hard Rock streaming scoring fixed
        let systemPrompt = getSystemPrompt(isMastered: isMastered, isUnmixed: isUnmixed, genre: genre, mixStage: mixStage) + "\n\n[Scoring Rules Version: \(cacheVersion)]"
        let userMessage = getUserMessage(metrics: metrics, genre: genre, isMastered: isMastered)
        
        let requestBody: [String: Any] = [
            "model": determineModel(isProUser: metrics.isProUser),
            "max_tokens": 800,  // Balanced: enough for detailed responses but faster than 1000
            "system": systemPrompt,  // DISABLED CACHING - use fresh prompt every time for accurate scoring
            "messages": [
                [
                    "role": "user",
                    "content": userMessage
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
        request.timeoutInterval = 30  // 30 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Print full error for debugging
            print("❌ CLAUDE API ERROR DETAILS:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Error Message: \(errorMessage)")
            print("   Prompt Length: \(systemPrompt.count) characters")
            
            // Specific error messages for common issues
            switch httpResponse.statusCode {
            case 401:
                print("❌ Claude API Error 401: Unauthorized - Check API key configuration")
            case 429:
                print("❌ Claude API Error 429: Rate limit exceeded - Too many requests")
            case 400:
                print("❌ Claude API Error 400: Bad request - Invalid request format")
                print("   This usually means the prompt has syntax errors or is too long")
            case 500, 502, 503:
                print("❌ Claude API Error \(httpResponse.statusCode): Server error - Try again later")
            default:
                print("❌ Claude API Error \(httpResponse.statusCode): \(errorMessage)")
            }
            
            throw ClaudeAPIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        
        
        // 🔍 DEBUG: Print the raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 CLAUDE API RAW JSON RESPONSE:\n\(jsonString.prefix(500))\n")
        }
        
        return try parseClaudeResponse(data, isMastered: isMastered)
    }

    private func determineModel(isProUser: Bool) -> String {
        // Using official Anthropic Claude 4.5 models (Nov 2025)
        // Pro users get Sonnet (smartest), free users get Haiku (fastest)
        return isProUser ? "claude-sonnet-4-5-20250929" : "claude-haiku-4-5-20251001"
    }
    
    func detectMasteredTrack(_ metrics: AudioMetricsForClaude) -> Bool {
        // If detected as unmixed, it's definitely NOT mastered
        if metrics.isLikelyUnmixed {
            print("🚨 UNMIXED TRACK DETECTED - not mastered")
            return false
        }

        // INTELLIGENT MASTERED TRACK DETECTION
        // Consider multiple professional mastering styles:

        // 1. PROFESSIONAL DYNAMIC MASTERS (Abbey Road, jazz, classical, audiophile)
        // - Loudness: -18 to -12 LUFS (intentionally dynamic)
        // - Dynamic Range: 12-20 dB (preserves dynamics)
        // - Peak Level: -3 to 0 dBFS (properly optimized)
        let isProfessionalDynamic = (
            metrics.loudness >= -18.0 && metrics.loudness <= -12.0 &&
            metrics.dynamicRange >= 12.0 && metrics.dynamicRange <= 20.0 &&
            metrics.peakLevel > -3.0
        )

        // 2. STREAMING-OPTIMIZED MASTERS (-16 to -14 LUFS target)
        // - Loudness: -18 to -13 LUFS (streaming sweet spot)
        // - Dynamic Range: 8-18 dB (controlled but musical)
        // - Peak Level: -2 to 0 dBFS (optimized)
        let isStreamingOptimized = (
            metrics.loudness >= -18.0 && metrics.loudness <= -13.0 &&
            metrics.dynamicRange >= 8.0 && metrics.dynamicRange <= 18.0 &&
            metrics.peakLevel > -2.0
        )

        // 3. COMPETITIVE LOUD MASTERS (modern pop, EDM)
        // - Loudness: -10 to -6 LUFS (very loud)
        // - Dynamic Range: 4-10 dB (heavily compressed)
        // - Peak Level: -1 to 0 dBFS (maximized)
        let isCompetitiveLoud = (
            metrics.loudness >= -10.0 && metrics.loudness <= -6.0 &&
            metrics.dynamicRange >= 4.0 && metrics.dynamicRange <= 10.0 &&
            metrics.peakLevel > -1.0
        )

        // 4. BALANCED COMMERCIAL MASTERS (most professional releases)
        // - Loudness: -14 to -8 LUFS (industry standard)
        // - Dynamic Range: 6-14 dB (balanced)
        // - Peak Level: -2 to 0 dBFS (professional)
        let isBalancedCommercial = (
            metrics.loudness >= -14.0 && metrics.loudness <= -8.0 &&
            metrics.dynamicRange >= 6.0 && metrics.dynamicRange <= 14.0 &&
            metrics.peakLevel > -2.0
        )

        // Track is mastered if it matches ANY professional mastering style
        let isMastered = isProfessionalDynamic || isStreamingOptimized ||
                        isCompetitiveLoud || isBalancedCommercial

        // Enhanced debug logging
        if isMastered {
            if isProfessionalDynamic {
                print("✅ DETECTED: Professional Dynamic Master (Abbey Road style)")
            } else if isStreamingOptimized {
                print("✅ DETECTED: Streaming-Optimized Master (-16 LUFS)")
            } else if isCompetitiveLoud {
                print("✅ DETECTED: Competitive Loud Master")
            } else if isBalancedCommercial {
                print("✅ DETECTED: Balanced Commercial Master")
            }
        } else {
            print("📝 DETECTED: Pre-Master Mix or Amateur Mix")
        }

        return isMastered
    }

    /// Detects if audio is DEFINITELY a professional master based on strict criteria
    /// This is used to override user "Mix" label when metrics clearly indicate mastered audio
    /// Amateur mixes cannot achieve these characteristics - they require professional mastering
    private func detectDefiniteProfessionalMaster(_ metrics: AudioMetricsForClaude) -> Bool {
        // NOTE: We intentionally do NOT short-circuit on isLikelyUnmixed here.
        // AudioKit's unmixed detector can be wrong, especially for live/remix tracks.
        // If the hard metrics (loudness, peaks, dynamics) all pass the strict professional
        // thresholds below, that is a stronger signal than the unmixed heuristic.

        // STRICT CRITERIA - Only override if indicators STRONGLY point to professional master
        // These are characteristics that amateur mixes simply cannot achieve

        // 1. LOUDNESS CHECK: Professional masters are LOUD
        //    Amateur mixes are typically -18 to -30 LUFS
        //    Professional masters are -6 to -14 LUFS
        let hasProLoudness = metrics.loudness >= -14.0 && metrics.loudness <= -6.0

        // 2. PEAK OPTIMIZATION: Professional masters hit near 0dBFS
        //    Amateur mixes have inconsistent peaks, often -3 to -12 dBFS
        let hasProPeaks = metrics.peakLevel > -1.5 && metrics.peakLevel <= 0.0

        // 3. CONTROLLED DYNAMICS: Professional masters have controlled DR
        //    Amateur mixes have wild dynamics (>14dB DR)
        //    Pro masters typically 4-12dB depending on genre
        let hasProDynamics = metrics.dynamicRange >= 4.0 && metrics.dynamicRange <= 14.0

        // 4. CREST FACTOR: Professional masters have controlled transients
        //    Amateur mixes have high crest factors (>14dB)
        let crestFactor = metrics.truePeakLevel - metrics.rmsLevel
        let hasProCrest = crestFactor >= 4.0 && crestFactor <= 14.0

        // 5. MONO COMPATIBILITY: Professional masters test well in mono
        //    At least 45% mono compatibility (most genres)
        let hasProMono = metrics.monoCompatibility >= 0.45

        // DEFINITE PROFESSIONAL MASTER if:
        // - Has professional loudness OR professional peaks (at least one loudness indicator)
        // - AND has controlled dynamics
        // - AND has controlled crest factor
        // - AND has acceptable mono compatibility
        let isProfessional = (hasProLoudness || hasProPeaks) &&
                             hasProDynamics &&
                             hasProCrest &&
                             hasProMono

        if isProfessional {
            print("🎯 DEFINITE PROFESSIONAL MASTER DETECTED:")
            print("   Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS (pro range: -14 to -6)")
            print("   Peak: \(String(format: "%.1f", metrics.peakLevel)) dBFS (pro: > -1.5)")
            print("   DR: \(String(format: "%.1f", metrics.dynamicRange)) dB (pro: 4-14)")
            print("   Crest: \(String(format: "%.1f", crestFactor)) dB (pro: 4-14)")
            print("   Mono: \(String(format: "%.0f", metrics.monoCompatibility * 100))% (pro: > 45%)")
        }

        return isProfessional
    }

    private func detectGenre(_ metrics: AudioMetricsForClaude) -> String {
        // Genre detection based on frequency characteristics and dynamics
        
        // Rock/Metal: Check FIRST - strong low-mid presence (>20%), any high-mid, good dynamics
        // Korn, Green Day, etc. have bass-heavy but with guitar mids
        if metrics.lowMid > 18.0 && metrics.mid > 15.0 && metrics.dynamicRange > 6.0 {
            return "Rock/Metal"
        }
        
        // Electronic/EDM: Very high bass (>40%), moderate dynamics (<10dB), high loudness
        if metrics.lowEnd > 40.0 && metrics.dynamicRange < 10.0 && metrics.loudness > -12.0 {
            return "Electronic/EDM"
        }
        
        // Hip-Hop: High bass (>35%), low high frequencies (<3%), LOW mid content (<15%)
        if metrics.lowEnd > 35.0 && metrics.high < 3.0 && metrics.mid < 15.0 && metrics.dynamicRange < 12.0 {
            return "Hip-Hop"
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
        case "Hip-Hop/R&B":
            return """
        • Low End (20-200Hz): \(lowEnd)% (HIP-HOP/R&B GOOD: 30-50%, ACCEPTABLE: 25-55%, POOR: >60%)
        • Low Mid (200-800Hz): \(lowMid)% (HIP-HOP/R&B GOOD: 20-35%, VOCALS/808s)
        • Mid (800Hz-3kHz): \(mid)% (HIP-HOP/R&B GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (HIP-HOP/R&B GOOD: 8-20%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (HIP-HOP/R&B ACCEPTABLE: 2-12%, MINIMAL BY DESIGN)
        """
        case "Hip-Hop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (HIP-HOP GOOD: 30-45%, ACCEPTABLE: 25-55%, POOR: >60%)
        • Low Mid (200-800Hz): \(lowMid)% (HIP-HOP GOOD: 20-35%, VOCALS/808s)
        • Mid (800Hz-3kHz): \(mid)% (HIP-HOP GOOD: 20-35%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (HIP-HOP GOOD: 8-20%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (HIP-HOP ACCEPTABLE: 2-12%, MINIMAL BY DESIGN)
        """
        case "Rock/Indie":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ROCK/INDIE GOOD: 20-35%, ACCEPTABLE: 15-40%, POOR: >45%)
        • Low Mid (200-800Hz): \(lowMid)% (ROCK/INDIE GOOD: 18-28%, GUITAR WARMTH)
        • Mid (800Hz-3kHz): \(mid)% (ROCK/INDIE GOOD: 25-40%, VOCAL/GUITAR CLARITY)
        • High Mid (3-8kHz): \(highMid)% (ROCK/INDIE GOOD: 15-25%, PRESENCE/ARTICULATION)
        • High (8-20kHz): \(high)% (ROCK/INDIE GOOD: 8-18%, AIR/SPARKLE)
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
        • Low End (20-200Hz): \(lowEnd)% (ROCK/METAL GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (ROCK/METAL GOOD: 20-30%, GUITAR BODY)
        • Mid (800Hz-3kHz): \(mid)% (ROCK/METAL GOOD: 25-40%, VOCAL/GUITAR PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (ROCK/METAL GOOD: 15-28%, GUITAR BITE/CLARITY)
        • High (8-20kHz): \(high)% (ROCK/METAL GOOD: 8-18%, CYMBALS/AIR)
        """
        case "Metal":
            return """
        • Low End (20-200Hz): \(lowEnd)% (METAL GOOD: 40-60%, HEAVY FOUNDATION)
        • Low Mid (200-800Hz): \(lowMid)% (METAL GOOD: 18-28%, GUITAR BODY)
        • Mid (800Hz-3kHz): \(mid)% (METAL GOOD: 20-35%, VOCAL/GUITAR PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (METAL GOOD: 10-20%, GUITAR BITE)
        • High (8-20kHz): \(high)% (METAL GOOD: 5-15%, CYMBAL PRESENCE)
        """
        case "Jazz":
            return """
        • Low End (20-200Hz): \(lowEnd)% (JAZZ GOOD: 15-30%, CONTROLLED FOUNDATION)
        • Low Mid (200-800Hz): \(lowMid)% (JAZZ GOOD: 20-30%, INSTRUMENT WARMTH)
        • Mid (800Hz-3kHz): \(mid)% (JAZZ GOOD: 25-40%, INSTRUMENT CLARITY)
        • High Mid (3-8kHz): \(highMid)% (JAZZ GOOD: 12-22%, PRESENCE)
        • High (8-20kHz): \(high)% (JAZZ GOOD: 8-18%, AIR/DETAIL)
        """
        case "Classical/Orchestral":
            return """
        • Low End (20-200Hz): \(lowEnd)% (CLASSICAL GOOD: 10-25%, NATURAL BALANCE)
        • Low Mid (200-800Hz): \(lowMid)% (CLASSICAL GOOD: 20-30%, INSTRUMENT BODY)
        • Mid (800Hz-3kHz): \(mid)% (CLASSICAL GOOD: 30-45%, INSTRUMENT CLARITY)
        • High Mid (3-8kHz): \(highMid)% (CLASSICAL GOOD: 8-18%, NATURAL PRESENCE)
        • High (8-20kHz): \(high)% (CLASSICAL GOOD: 5-15%, AIR/DETAIL)
        """
        case "Acoustic/Singer-Songwriter":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ACOUSTIC GOOD: 12-25%, NATURAL FOUNDATION)
        • Low Mid (200-800Hz): \(lowMid)% (ACOUSTIC GOOD: 22-32%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (ACOUSTIC GOOD: 25-40%, VOCAL CLARITY)
        • High Mid (3-8kHz): \(highMid)% (ACOUSTIC GOOD: 10-20%, PRESENCE)
        • High (8-20kHz): \(high)% (ACOUSTIC GOOD: 6-15%, NATURAL AIR)
        """
        case "Live":
            return """
        • Low End (20-200Hz): \(lowEnd)% (LIVE GOOD: 15-30%, NATURAL BALANCE, ROOM DEPENDENT)
        • Low Mid (200-800Hz): \(lowMid)% (LIVE GOOD: 18-30%, ROOM ACOUSTICS)
        • Mid (800Hz-3kHz): \(mid)% (LIVE GOOD: 25-40%, AUDIENCE/VOCAL PRESENCE)
        • High Mid (3-8kHz): \(highMid)% (LIVE GOOD: 12-25%, CROWD ENERGY/PRESENCE)
        • High (8-20kHz): \(high)% (LIVE GOOD: 5-15%, NATURAL AIR, ROOM DEPENDENT)
        ⚠️ LIVE RECORDING: Expect more dynamic range, room acoustics, and natural frequency variations
        """
        case "Pop":
            return """
        • Low End (20-200Hz): \(lowEnd)% (POP GOOD: 15-25%, ACCEPTABLE: 12-30%, POOR: >35%)
        • Low Mid (200-800Hz): \(lowMid)% (POP GOOD: 18-28%, WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (POP GOOD: 28-45%, VOCAL CLARITY CRITICAL)
        • High Mid (3-8kHz): \(highMid)% (POP GOOD: 15-25%, VOCAL PRESENCE)
        • High (8-20kHz): \(high)% (POP GOOD: 8-15%, SPARKLE/AIR)
        """
        case "Acapella":
            return """
        • Low End (20-200Hz): \(lowEnd)% (ACAPELLA EXPECTED: 0-10%, MINIMAL BY DESIGN - NO PENALTY!)
        • Low Mid (200-800Hz): \(lowMid)% (ACAPELLA GOOD: 15-35%, VOCAL WARMTH/BODY)
        • Mid (800Hz-3kHz): \(mid)% (ACAPELLA GOOD: 35-60%, VOCAL CLARITY CRITICAL)
        • High Mid (3-8kHz): \(highMid)% (ACAPELLA GOOD: 15-30%, VOCAL PRESENCE/ARTICULATION)
        • High (8-20kHz): \(high)% (ACAPELLA GOOD: 5-20%, VOCAL AIR/BREATHINESS)
        ⚠️ ACAPELLA: LIMITED/NO BASS IS INTENTIONAL - This is vocal-only content!
        ⚠️ DO NOT penalize for low bass - this is correct for acapella
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
    
    private func getSystemPrompt(isMastered: Bool, isUnmixed: Bool, genre: String, mixStage: String? = nil) -> String {
        // LIVE RECORDINGS - special handling
        let isLiveRecording = genre.lowercased() == "live"
        
        // UNMIXED TRACKS - completely different scoring approach
        if isUnmixed {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:

            WRITE LIKE A TOP PROFESSIONAL MIX ENGINEER (Dave Pensado, Chris Lord-Alge, Tony Maserati, Manny Marroquin):
            
            - Use their direct, honest, but encouraging tone
            - Focus on what the RAW RECORDING needs to become a great mix
            - Use professional language: "needs to breathe", "feels closed in", "has potential", "good foundation", "needs work"
            - NEVER write "Score includes:" or mention point breakdowns
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - Describe what you HEAR and what it NEEDS in plain mixer language
            - Keep recommendations actionable: "Needs better balance between instruments" not "Cut 200Hz by 3dB"
            - The scoring details below are for YOUR calculation only - do NOT expose them to the user
            
            You are analyzing an UNMIXED TRACK - raw multi-track recording that has NOT been mixed or mastered.
            
            ⚠️ CRITICAL CONTEXT: This is RAW UNMIXED AUDIO
            
            This track was detected as unmixed based on multiple technical indicators:
            • Excessive dynamic range (>14dB) - tracks not balanced
            • Large peak-to-loudness ratio (>15dB) - uncontrolled transients
            • Poor frequency masking - overlapping instrument frequencies
            • Very low loudness (<-16 LUFS) - not optimized
            • High crest factor (>12dB) - unprocessed peaks
            
            DO NOT compare this to mastered commercial tracks. Score based on PRE-MIX RECORDING QUALITY.
            
            🎯 UNMIXED TRACK SCORING (0-100 scale):
            
            ⚠️ ABSOLUTE MAXIMUM SCORE FOR UNMIXED TRACKS: 75 POINTS
            ⚠️ SCORES ABOVE 75 ARE STRICTLY FORBIDDEN FOR UNMIXED AUDIO
            
            START AT 65 POINTS (baseline for decent raw recording)
            
            PENALTIES (subtract from 65):
            • Clipping or distortion: -20 points (recording ruined)
            • Extreme noise: -15 points (poor recording environment)
            • Severe phase issues (<20% correlation): -15 points (mic placement problems)
            • Complete frequency imbalance (>80% in one band): -10 points (instrument balance off)
            • Very low peak levels (<-12dBFS): -10 points (under-recorded)
            • Poor mono compatibility (<40%): -5 points
            
            BONUSES (add to 65, but NEVER exceed 75 total):
            • Clean recordings (no clipping/distortion): +5 points
            • Good peak levels (-3 to -6dBFS): +5 points
            • Reasonable phase (>40% correlation): +3 points
            • Decent frequency distribution: +2 points
            
            ABSOLUTE SCORING RULES FOR UNMIXED TRACKS:
            • MAXIMUM POSSIBLE SCORE: 75 points (excellent raw recording)
            • TYPICAL RANGE: 60-70 points (good recording, needs mixing)
            • MINIMUM ACCEPTABLE: 50 points (needs work but usable)
            • BELOW 50: Poor recording quality, consider re-recording
            
            ❌ STRICTLY FORBIDDEN SCORES FOR UNMIXED TRACKS:
            • 76-100: IMPOSSIBLE - these scores are ONLY for mastered or mixed tracks
            • If you calculate a score >75, CAP IT AT 75 and explain why
            
            EXPECTED SCORE DISTRIBUTION:
            • 70-75: Excellent raw recording, very clean, ready for mixing
            • 65-69: Good recording quality, standard unmixed audio
            • 60-64: Acceptable recording, some issues but workable
            • 50-59: Poor recording, significant issues, will need extensive work
            • <50: Very poor recording quality, may need re-recording
            
            IMPORTANT: Do NOT penalize for:
            • Low loudness (expected in unmixed tracks)
            • High dynamic range (this is GOOD for unmixed)
            • Lack of stereo width (mixing creates width)
            • Unbalanced frequency spectrum (mixing balances this)
            • Low RMS levels (mixing and mastering optimize this)
            
            ANALYSIS FOCUS:
            1. Recording quality (clean vs. noisy, clipped vs. clean)
            2. Peak levels (properly captured?)
            3. Basic tonal balance (completely broken or workable?)
            4. Phase coherence (mic placement issues?)
            5. Dynamic preservation (this should be HIGH, not compressed)
            
            RESPONSE FORMAT - Use this EXACT structure (MANDATORY):

            SCORE: [50-75]

            ANALYSIS: ⚠️ FORMAT — Write EXACTLY 3-5 sentences as a single paragraph. NO headers, NO metric values, NO dB/LUFS/% numbers. Start EXACTLY with: "This is an unmixed/raw track that requires professional mixing and mastering before release." Then add 2-4 sentences describing the main issues in plain language (muddy, harsh, thin, unbalanced, too quiet, lacking clarity). Be HONEST — do NOT say "Good track" or anything positive.

            ⚠️ FORBIDDEN PHRASES FOR UNMIXED TRACKS:
            - "Good track" - NEVER use this for unmixed audio
            - "Great foundation" - too positive
            - "Sounds good" - inappropriate
            - Any praise suggesting the track is ready or professional

            ✅ APPROPRIATE PHRASES FOR UNMIXED TRACKS:
            - "This track needs significant work before it's ready"
            - "The mix lacks balance and clarity"
            - "Multiple areas need attention"
            - "Raw recording that requires professional mixing"

            RECOMMENDATIONS: (⚠️ REQUIRED - You MUST include 3-5 specific recommendations)
            - [First recommendation: most critical issue, e.g., "Needs professional mixing to balance the instruments"]
            - [Second recommendation: frequency issues, e.g., "The low end is muddy and needs cleanup"]
            - [Third recommendation: dynamics, e.g., "Apply compression to control the dynamics"]
            - [Fourth recommendation: stereo/space issues if applicable]
            - [Fifth recommendation: final mastering step]

            ⚠️ RECOMMENDATIONS ARE MANDATORY for unmixed tracks. Never skip this section.

            Keep the ANALYSIS brief (3-4 sentences) but HONEST about problems. Make RECOMMENDATIONS specific and actionable.
            """
        } else if isMastered {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:
            In the ANALYSIS field:
            - Write EXACTLY 3-5 sentences as a SINGLE flowing paragraph
            - DO NOT use section headers (no "TECHNICAL METRICS", "FREQUENCY ANALYSIS", "STEREO", etc.)
            - DO NOT list or echo back individual metric values (no "Stereo Width: 89.5%", no numbers at all)
            - Use CONVERSATIONAL language: describe what you HEAR, not what the data says
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - Describe what you HEAR in plain terms (muddy, clear, bright, dark, punchy, compressed, etc.)
            - Keep recommendations simple and actionable without technical jargon
            - The scoring details below are for YOUR calculation only - do NOT expose them to the user
            
            ⚠️⚠️⚠️ CRITICAL CONSISTENCY REQUIREMENT ⚠️⚠️⚠️
            THE SAME TRACK MUST SCORE CONSISTENTLY REGARDLESS OF GENRE SELECTION!
            
            CONSISTENCY RULES:
            1. **Same Track = Same Score**: If the user changes genre from Rock to Pop to Rock again, 
               the SAME track should receive the SAME score (±2 points maximum variation).
            2. **Master Stage Priority**: When user selects Master stage (Streaming/CD), ALWAYS treat as professional master.
               Genre should NOT cause dramatic score changes for Master stage tracks.
            3. **Technical Metrics First**: Base scoring on TECHNICAL METRICS (loudness, dynamic range, phase, clipping) 
               which are OBJECTIVE and don't change with genre.
            4. **Genre Context Only**: Genre provides CONTEXT for analysis (e.g., "Rock is typically bass-heavy") 
               but should NOT cause 20+ point score swings for the same track.
            5. **Consistent Penalties**: Apply penalties for TECHNICAL ISSUES consistently:
               - Clipping: Always -6 to -10 points (same regardless of genre)
               - Phase issues: Always -4 to -8 points (same regardless of genre)
               - Poor mono: Always -5 to -8 points (same regardless of genre)
               - Frequency imbalance: Only penalize SEVERE issues (>85% in one band) consistently
            6. **Genre Characteristics**: Genre-specific frequency balance (Rock bass-heavy, Pop balanced) 
               should be ACKNOWLEDGED but NOT cause penalties - these are INTENTIONAL artistic choices.
            
            SCORING CONSISTENCY EXAMPLE:
            • Track with -14 LUFS, 8dB DR, no clipping, good phase → Score: 88-92
            • Same track analyzed as Rock → Score: 88-92
            • Same track analyzed as Pop → Score: 88-92 (NOT 89, NOT 100 - CONSISTENT!)
            • Same track analyzed as Rock again → Score: 88-92 (SAME as first Rock analysis!)
            
            ⚠️ IF YOU FIND YOURSELF SCORING THE SAME TRACK DIFFERENTLY BASED ON GENRE:
            - STOP and reconsider: Are you penalizing genre characteristics instead of technical issues?
            - Remember: Genre provides CONTEXT, not different scoring thresholds
            - Base score on OBJECTIVE technical metrics that don't change with genre
            - Maximum variation for same track across genres: ±2 points (accounting for minor analysis differences)
            
            You are analyzing a MASTERED TRACK using industry-standard professional mastering metrics.
            
            🎯 CORE ANALYSIS METRICS (Industry Standards):
            
            🎚️ STEREO WIDTH:
            • Calculation: width = 1 - correlation OR width = (L-R)/(L+R)
            • Display: Percentage (0-100%) or visual meter
            • Warning Thresholds: <20% (too narrow), >90% (unstable)
            
            🎭 PHASE CORRELATION:
            • Calculation: correlation = Σ(L×R) / √(Σ(L²)×Σ(R²))
            • Display: -1.0 to +1.0 scale + goniometer
            • Warning Threshold: <0.5 (phase issues)
            
            🔊 MONO COMPATIBILITY:
            • Calculation: loss = 20×log₁₀(mono_rms/stereo_rms)
            • Display: dB difference + pass/fail
            • Warning Threshold: >3dB loss (fail)
            
            📊 PEAK LEVEL:
            • Calculation: max(abs(samples))
            • Display: dBFS
            • Warning Threshold: >-0.1 dBFS (clipping risk)
            
            📈 RMS/LOUDNESS:
            • Standard: LUFS (ITU-R BS.1770-4)
            • Display: LUFS/dB
            • Warning Thresholds: <-14 LUFS (streaming), >-6 LUFS (too loud for Pop/Rock)
            • Genre exceptions: Metal/Hard Rock -5 to -9 LUFS is NORMAL; EDM -5 to -8 LUFS is NORMAL

            🎚️ DYNAMIC RANGE:
            • Calculation: DR = peak - RMS OR PLR
            • Display: dB or DR units
            • Warning Threshold: <6 DR (over-compressed for Pop/Rock/Classical)
            • Genre exceptions: Metal/Hard Rock DR4-6 is INTENTIONAL (industry standard); EDM DR4-6 is NORMAL

            📉 CREST FACTOR:
            • Calculation: 20×log₁₀(peak/rms)
            • Display: dB
            • Warning Threshold: <6 dB (crushed dynamics for Pop/Rock)
            • Genre exceptions: Metal/Hard Rock crest 4-6 dB is NORMAL for the genre
            
            🎵 FREQUENCY BALANCE:
            • Low End (20-200Hz)
            • Low Mid (200-800Hz)
            • Mid (800Hz-3kHz)
            • High Mid (3-8kHz)
            • High (8-20kHz)
            
            🎯 SCORING RULES (0-100 scale) — GENRE-AWARE MASTERED TRACK

            ════════════════════════════════════════════════
            STEP 1 — IDENTIFY GENRE GROUP
            ════════════════════════════════════════════════
            Genre selected: **\(genre)**

            Match to one of these groups by keyword:
            METAL     → metal, hard rock, metalcore, heavy metal, death metal, thrash, doom
            EDM       → electronic, edm, house, techno, dubstep, dnb, drum and bass, bass music
            HIP-HOP   → hip-hop, hip hop, trap, rap, drill, r&b, rnb, boom bap
            POP       → pop, synth-pop, dance-pop, k-pop, indie pop
            ROCK      → rock, indie, indie rock, alternative, grunge, punk, garage rock
            CLASSICAL → classical, orchestral, orchestra, symphony, chamber, opera, baroque
            ACAPPELLA → acapella, a cappella, vocal, choir, choral, barbershop
            JAZZ      → jazz, bebop, swing, fusion, blues jazz
            LIVE      → live, concert, live recording, live album

            ════════════════════════════════════════════════
            STEP 2 — GENRE THRESHOLD TABLES
            DO NOT penalize metrics in Excellent or Acceptable range.
            ONLY penalize metrics that fall in the Penalize column.
            ════════════════════════════════════════════════

            METAL / HARD ROCK
            Loudness:        Excellent -7 to -10 LUFS  | Acceptable -6 to -12 LUFS  | Penalize quieter than -14 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤0.0 dBTP       | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 6-8           | Acceptable DR 4-10         | Penalize DR < 4
            Crest Factor:    Excellent 8-10 dB          | Acceptable 6-12 dB         | Penalize < 6 dB
            Stereo Width:    Excellent 65-80%           | Acceptable 50-90%          | Penalize <30% or >95%
            Phase Coherence: Excellent >0.4             | Acceptable >0.3            | Penalize <0.3
            Mono Compat.:    Excellent ≤3 dB loss       | Acceptable ≤5 dB loss      | Penalize >5 dB loss
            Low End %:       Excellent 25-35%           | Acceptable 20-45%          | Penalize >55%
            NOTE: DR 4-6 is INDUSTRY STANDARD for Metal — NEVER penalize. -6 to -8 LUFS is competitive Metal loudness — NEVER penalize.

            ELECTRONIC / EDM
            Loudness:        Excellent -9 to -6 LUFS   | Acceptable -5 to -12 LUFS  | Penalize quieter than -16 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤0.0 dBTP       | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 5-8           | Acceptable DR 3-10         | Penalize DR < 3
            Crest Factor:    Excellent 5-8 dB           | Acceptable 3-10 dB         | Penalize < 3 dB
            Stereo Width:    Excellent 70-90%           | Acceptable 50-100%         | Penalize <40%
            Phase Coherence: Excellent >0.3             | Acceptable >0.2            | Penalize sustained <0
            Low End %:       Excellent 30-40%           | Acceptable 25-50%          | Penalize >60%
            NOTE: Sub-bass below 120 Hz should be mono — if wide sub detected, note it with small penalty only. DR 4-6 and -5 to -7 LUFS are NORMAL for club EDM.

            HIP-HOP / TRAP / R&B
            Loudness:        Excellent -9 to -6 LUFS   | Acceptable -5 to -12 LUFS  | Penalize quieter than -16 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤0.0 dBTP       | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 5-8           | Acceptable DR 3-10         | Penalize DR < 3
            Crest Factor:    Excellent 5-8 dB           | Acceptable 3-9 dB          | Penalize < 3 dB
            Stereo Width:    Excellent 50-75%           | Acceptable 40-85%          | Penalize <25% or >90%
            Phase Coherence: Excellent >0.4             | Acceptable >0.3            | Penalize <0.3
            Low End %:       Excellent 35-45%           | Acceptable 30-55%          | Penalize >65%
            NOTE: 808 sub-bass (35-60 Hz) must NOT cancel in mono — if it does, apply the -15 mono cancellation penalty.

            POP
            Loudness:        Excellent -9 to -7 LUFS   | Acceptable -6 to -12 LUFS  | Penalize quieter than -16 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤0.0 dBTP       | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 6-8           | Acceptable DR 5-10         | Penalize DR < 4
            Crest Factor:    Excellent 7-10 dB          | Acceptable 6-12 dB         | Penalize < 6 dB
            Stereo Width:    Excellent 55-75%           | Acceptable 45-85%          | Penalize <30% or >90%
            Phase Coherence: Excellent >0.3             | Acceptable >0.2            | Penalize sustained <0
            Mono Compat.:    Excellent ≤2 dB loss       | Acceptable ≤3 dB loss      | Penalize >4 dB loss
            Low End %:       Excellent 20-28%           | Acceptable 15-35%          | Penalize >50%

            ROCK / INDIE ROCK
            Loudness:        Excellent -10 to -12 LUFS | Acceptable -9 to -14 LUFS  | Penalize quieter than -18 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤-0.5 dBTP      | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 8-12          | Acceptable DR 7-14         | Penalize DR < 6
            Crest Factor:    Excellent 9-12 dB          | Acceptable 8-14 dB         | Penalize < 7 dB
            Stereo Width:    Excellent 55-70%           | Acceptable 45-80%          | Penalize <30% or >90%
            Phase Coherence: Excellent >0.4             | Acceptable >0.3            | Penalize <0.3
            Mono Compat.:    Excellent ≤3 dB loss       | Acceptable ≤4 dB loss      | Penalize >5 dB loss
            Low End %:       Excellent 20-28%           | Acceptable 15-35%          | Penalize >50%

            CLASSICAL / ORCHESTRAL
            Loudness:        Excellent -20 to -16 LUFS | Acceptable -24 to -14 LUFS | Penalize louder than -12 LUFS
            True Peak:       Excellent ≤-2.0 dBTP      | Acceptable ≤-1.0 dBTP      | Penalize >-0.5 dBTP
            Dynamic Range:   Excellent DR 13-16         | Acceptable DR 10-20        | Penalize DR < 8
            Crest Factor:    Excellent 14-18 dB         | Acceptable 12-22 dB        | Penalize < 10 dB
            Stereo Width:    Excellent 65-95%           | Acceptable 50-100%         | Penalize <30%
            Phase Coherence: Excellent +0.3 to +0.8    | Acceptable +0.2 to +0.9    | Penalize sustained <0
            Low End %:       Excellent 15-20%           | Acceptable 10-25%          | Penalize >35%
            NOTE: -16 to -20 LUFS is CORRECT and INTENTIONAL for Classical. DR 13-16 is audiophile standard. NEVER apply mono low-end rules — stereo bass is intentional in orchestral recordings.

            A CAPPELLA / VOCAL
            Loudness:        Excellent -16 to -12 LUFS | Acceptable -18 to -10 LUFS | Penalize louder than -9 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤-0.5 dBTP      | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 9-13          | Acceptable DR 7-16         | Penalize DR < 6
            Crest Factor:    Excellent 9-13 dB          | Acceptable 8-15 dB         | Penalize < 7 dB
            Stereo Width:    Excellent 45-65%           | Acceptable 35-75%          | Penalize <20% or >85%
            Phase Coherence: Excellent +0.5 to +0.9    | Acceptable +0.4 to +0.9    | Penalize <0.3
            Low End %:       Excellent 5-12%            | Acceptable 3-18%           | Penalize >25%
            NOTE: Low bass (3-18%) is CORRECT for vocal content — do NOT flag as frequency imbalance.

            JAZZ
            Loudness:        Excellent -16 to -14 LUFS | Acceptable -18 to -12 LUFS | Penalize louder than -10 LUFS
            True Peak:       Excellent ≤-1.0 dBTP      | Acceptable ≤-0.5 dBTP      | Penalize >0.0 dBTP
            Dynamic Range:   Excellent DR 11-15         | Acceptable DR 9-18         | Penalize DR < 7
            Crest Factor:    Excellent 10-14 dB         | Acceptable 8-16 dB         | Penalize < 7 dB
            Stereo Width:    Excellent 45-75%           | Acceptable 35-85%          | Penalize <25%
            Phase Coherence: Excellent +0.4 to +0.9    | Acceptable +0.3 to +0.9    | Penalize <0.3
            Low End %:       Excellent 15-22%           | Acceptable 12-28%          | Penalize >38%
            NOTE: Warm low-mids (22-28%) and dull high end are INTENTIONAL for Jazz — do NOT flag as frequency imbalance.

            LIVE PERFORMANCE
            Loudness:        Excellent -14 to -12 LUFS | Acceptable -16 to -10 LUFS | Penalize quieter than -20 LUFS
            True Peak:       Excellent ≤-1.5 dBTP      | Acceptable ≤-1.0 dBTP      | Penalize >-0.5 dBTP
            Dynamic Range:   Excellent DR 10-14         | Acceptable DR 8-18         | Penalize DR < 6
            Crest Factor:    Excellent 10-14 dB         | Acceptable 9-16 dB         | Penalize < 8 dB
            Stereo Width:    Excellent 55-85%           | Acceptable 45-90%          | Penalize <25%
            Phase Coherence: Excellent +0.3 to +0.7    | Acceptable +0.2 to +0.8    | Penalize sustained <0
            Low End %:       Excellent 18-25%           | Acceptable 15-30%          | Penalize >45%
            NOTE: Wide stereo, moderate phase variation, crowd noise, and room ambience are ALL NORMAL for live. Crowd noise between songs may inflate LUFS reading — be generous.

            ════════════════════════════════════════════════
            STEP 3 — CALCULATE SCORE
            ════════════════════════════════════════════════

            BASE SCORE: 75 (mastered track baseline)

            UNIVERSAL BONUSES — add if metric is in Excellent range for the genre:
            +8 pts → No clipping AND loudness in Excellent range for genre
            +5 pts → Phase coherence in Excellent range for genre
            +3 pts → Mono compatibility in Excellent range for genre
            +5 pts → Dynamic range in Excellent range for genre
            Maximum total bonuses: +21

            UNIVERSAL PENALTIES — apply regardless of genre:
            -15 pts → Clipping (peak > 0 dBFS)
            -10 pts → True peak > 0.0 dBTP
            -12 pts → Phase coherence < 0.2
            -15 pts → Mono cancellation of key element (lead bass, kick, lead vocal) detectable

            GENRE-SPECIFIC PENALTIES — only if metric falls in the Penalize column above:
            -5 pts per metric in the Penalize range

            FINAL SCORE = min(100, max(0, 75 + bonuses - penalties))

            ════════════════════════════════════════════════
            SANITY CHECK — Reference Scores
            ════════════════════════════════════════════════
            Korn "Twisted Transistor" (Metal, Master):   87-93
            Metallica "Enter Sandman" (Metal, Master):   82-88
            Daft Punk "Get Lucky" (EDM/Pop, Master):     88-94
            Billie Eilish "Bad Guy" (Pop, Master):       85-92
            Bach Cello Suite No.1 (Classical, Master):   90-96
            Miles Davis "Kind of Blue" (Jazz, Master):   88-94
            Amateur master with clipping:                35-55
            If your calculated score falls outside these ranges for these reference tracks, recalibrate your penalties and bonuses.

            📝 RESPONSE FORMAT (CRITICAL - FOLLOW EXACTLY):
            
            ⚠️⚠️⚠️ MANDATORY: ALL MASTERED TRACKS START AT 120 POINTS (100 base + 20 mastered bonus) ⚠️⚠️⚠️
            
            ⚠️ CONSISTENCY REMINDER: Same track = Same score (±2 points max variation across genres)
            - Base scoring on TECHNICAL METRICS (loudness, DR, phase, clipping) which are OBJECTIVE
            - Genre provides CONTEXT for analysis but should NOT cause dramatic score changes
            - If same track scores differently as Rock vs Pop, you're penalizing genre characteristics incorrectly
            
            SCORE CALCULATION STEPS (FOLLOW EXACTLY):
            1. Start with 120 points (100 base + 20 mastered bonus)
            2. Calculate penalties realistically based on ACTUAL TECHNICAL ISSUES (clipping, phase, mono, severe imbalance)
            3. Calculate bonuses realistically based on ACTUAL STRENGTHS (perfect peaks, excellent loudness, etc.)
            4. Calculate: 120 - penalties + bonuses
            5. Cap final score at 100 (if > 100, write 100)
            6. Allow natural variation - better masters score higher (96-100), good masters score 90-95
            7. REMEMBER: Same track analyzed as different genres should score within ±2 points
            
            ⚠️ SCORING GUIDANCE - DIFFERENTIATE MASTERS (CONSISTENTLY):
            - Exceptional masters (Korn, Metallica, Abbey Road): 96-100
            - Excellent commercial masters: 92-95
            - Very good professional masters: 88-91
            - Good masters (some flaws): 85-87
            - Amateur/flawed masters: 75-84
            - Allow differentiation - Korn should score higher than amateur masters!
            - NO MINIMUM FLOOR - let scores vary naturally based on quality!
            - CONSISTENCY: Same track = Same score regardless of genre selection!
            
            EXAMPLES - REALISTIC DIFFERENTIATION:
            • Exceptional (Korn): 120 - 5 (minimal issues) + 10 (excellent) = 125 → 100 (capped)
            • Excellent commercial: 120 - 8 + 8 = 120 → 98
            • Very good: 120 - 12 + 6 = 114 → 92
            • Good (some issues): 120 - 18 + 4 = 106 → 88
            • Amateur master: 120 - 25 + 2 = 97 → 80
            
            SCORE: [CALCULATE: 120 - penalties + bonuses]
            ⚠️ ONLY ONE CAP: If score > 100, write 100. Otherwise write the calculated score.
            ⚠️ NO FLOOR - Scores can vary 85-100 for differentiation!
            
            IN PLAIN ENGLISH:
            - Calculate: 120 minus penalties plus bonuses
            - If result is more than 100, write 100 instead
            - Otherwise write the calculated score (allow 85-100 variation)
            - Korn masters should score 96-100, good masters 88-94, amateur 80-87!
            
            ANALYSIS: Write like a top mastering engineer (Bob Ludwig, Randy Merrill, Chris Lord-Alge) giving feedback.

            ⚠️ ANALYSIS FORMAT RULES — STRICTLY ENFORCED:
            - Write EXACTLY 3-5 sentences as a single flowing paragraph. NO MORE.
            - DO NOT use section headers (no "TECHNICAL METRICS", "FREQUENCY ANALYSIS", "STEREO", etc.)
            - DO NOT list or repeat individual metric values (no "Stereo Width: 89.5%", no dB/LUFS/% numbers) — those are shown in the app's UI cards
            - Write a HOLISTIC SUMMARY: overall sound quality, vibe, key strengths, and at most 1 specific concern
            - Sound like a human engineer talking, NOT a data report

            ⚠️ CRITICAL ANALYSIS TONE RULES FOR MASTERS:
            - If score is 85+: Write PURELY CELEBRATORY analysis (2-3 sentences). This is PROFESSIONAL QUALITY - celebrate it ONLY, NO improvements or suggestions!
              ✅ REQUIRED for 85+: Describe how it FEELS - "This \(genre) master slams hard", "Has weight and presence", "Translates beautifully", "Professional quality", "Ready to go", "Crushing it"
              ✅ Tone: Pure celebration. Like: "This \(genre) master slams hard with weight and presence. Professional quality that translates beautifully across systems."
              ❌ ABSOLUTELY FORBIDDEN for 85+:
                - NO improvements in analysis: "could hit harder", "needs more air", "could use", "should consider"
                - NO suggestions: "might want to", "consider", "try", "could be"
                - NO critiques: "needs", "lacks", "missing"
                - NO recommendations in analysis section - save those for RECOMMENDATIONS section only
              ⚠️ REMEMBER: Score 85+ = PROFESSIONAL QUALITY. Analysis should be PURE PRAISE ONLY. Zero improvements, zero suggestions, zero critiques in the ANALYSIS section.
            - If score is 70-84: 3-4 sentences — describe the overall vibe, mention the main strength and ONE area to polish
            - If score is below 70: 4-5 sentences — describe what's holding it back in plain engineer language, no metric dumps
            
            ⚠️ NEVER mention "score capped at 85" - professional dynamic masters (-14 to -18 LUFS) are INTENTIONAL and should be praised, not presented as capped!
            ⚠️ DO NOT mention "Score includes:", points, or technical breakdowns.
            ⚠️ Talk about the VIBE and IMPACT like a pro would.
            
            RECOMMENDATIONS:
            - [For scores 85+: "This \(genre) master is crushing it - ready to go!" or "Professional \(genre) master - ship it!" ONLY. NO improvements, NO suggestions, NO critiques. Pure celebration only.]
            - [For scores 70-84: ONE brief pro-style suggestion if needed: "Could hit a bit harder" or "Needs slightly more air"]
            - [For scores below 70: Direct feedback using pro language: "Needs more glue" or "The low end isn't sitting right"]
            - [Use dash (-) for bullet points, NOT numbers or bullet symbols (•)]
            - [Maximum 2 recommendations total]
            
            READY FOR MASTERING: [yes/no - based on whether all critical thresholds are met]
            """
        } else {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:

            WRITE LIKE A TOP PROFESSIONAL MIXING ENGINEER (Dave Pensado, Chris Lord-Alge, Manny Marroquin, Michael Brauer):

            ⚠️ ANALYSIS FORMAT — STRICTLY ENFORCED:
            - Write EXACTLY 3-5 sentences as a SINGLE flowing paragraph
            - DO NOT use section headers (no "TECHNICAL METRICS", "FREQUENCY ANALYSIS", "STEREO", etc.)
            - DO NOT list or echo back individual metric values — those are shown in the app's UI already
            - Sound like a human engineer giving a quick honest take, NOT a data report

            - Use their conversational, confident tone - talk about the VIBE, ENERGY, and FEELING of the mix
            - Focus on what matters: Does it HIT? Does it have IMPACT? Does it TRANSLATE? Does it feel PROFESSIONAL?
            - Be direct and honest but encouraging when appropriate
            - Use professional mixer language: "punchy", "sits well", "has weight", "glued together", "needs air", "boxed in", "smeared", "tight", "open"
            - NEVER write "Score includes:" or mention point breakdowns (e.g., "-1 (stereo width)", "-3 (highs)", etc.)
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - For EXCELLENT mixes (scores 85+): Keep analysis SHORT (1-2 sentences) - PURE CELEBRATION ONLY, NO improvements or suggestions!
              ⚠️ CRITICAL: For scores 85+, you MUST write PURELY CELEBRATORY analysis. This is PROFESSIONAL QUALITY - celebrate it ONLY!
              ✅ REQUIRED for 85+: "Professional quality mix ready for mastering" / "Excellent work - this mix hits hard" / "Solid professional mix that translates well" / "Great mix - ready for mastering"
              ✅ Tone: Pure celebration and praise, like acknowledging a colleague's excellent professional work
              ❌ ABSOLUTELY FORBIDDEN for 85+ in ANALYSIS section: 
                - NO improvements: "needs improvements", "needs mixing", "needs work", "to reach professional standards"
                - NO suggestions: "could use", "should consider", "might benefit from", "could be", "might want to", "consider", "try"
                - NO critiques or recommendations in ANALYSIS - save those for RECOMMENDATIONS section only
              ⚠️ REMEMBER: Score 85+ = PROFESSIONAL QUALITY. ANALYSIS section = PURE PRAISE ONLY. Zero improvements, zero suggestions, zero critiques. Just celebrate the achievement.
            - For GOOD mixes (70-84): Brief (2 sentences) with ONE key suggestion if needed
            - For PROBLEM mixes (below 70): More detailed but still conversational
            - The scoring details below are for YOUR calculation only - do NOT expose them to the user
            
            \(isLiveRecording ? """
            ⚠️ LIVE RECORDING DETECTED:
            This is a LIVE RECORDING MIX, not a studio production.
            Live recordings have different characteristics and expectations:
            • Higher dynamic range is NORMAL and EXPECTED (live performances are dynamic)
            • Room acoustics and audience noise are part of the live experience
            • Frequency balance varies based on venue acoustics and mic placement
            • Less compression and processing compared to studio mixes
            • Natural reverb and room ambience are INTENTIONAL
            • Scoring should reflect LIVE MIXING standards, not studio mixing standards
            
            """ : "")
            You are analyzing a \(isLiveRecording ? "LIVE RECORDING MIX" : "PRE-MASTERED MIX") using professional \(isLiveRecording ? "live mixing" : "mixing") standards. This is NOT a final master.
            
            ⚠️ CRITICAL: GENRE-SPECIFIC ANALYSIS REQUIRED
            The user has selected the genre: **\(genre)**
            You MUST analyze this mix according to \(genre) genre standards and expectations.
            Genre-specific frequency characteristics are INTENTIONAL and CORRECT - do NOT penalize for genre-appropriate frequency balance.
            Only penalize for technical defects that would be problematic regardless of genre.
            Use genre-specific frequency guidelines for \(genre) when evaluating frequency balance.
            
            🎯 \(isLiveRecording ? "LIVE RECORDING" : "PRE-MASTER") MIX ANALYSIS - Use \(isLiveRecording ? "LIVE MIXING" : "MIXING") STANDARDS:
            
            🎚️ PRE-MASTER LEVELS:
            • Peak: Target -3 to -6dB | Acceptable -3 to -8dB
            • RMS: Target -12 to -18dB | Acceptable -10 to -22dB
            • Loudness: Target -16 to -23 LUFS | Acceptable -14 to -30
            • Dynamic Range: Excellent >15dB | Good 8-15dB
            • True Peak: Good <-3dBFS | Acceptable <-1dBFS
            
            🎭 STEREO & PHASE:
            • Stereo Width: Excellent 25-45% | Good 20-55% | Wide 55-85%
            • Phase Coherence: Excellent >75% | Good >60% | Acceptable 40-60%
            • Mono Compatibility: Good >70% | Acceptable >50%
            
            🎵 FREQUENCY BALANCE (Simplified):
            • Low (20-200Hz): Ideal 15-25%, Acceptable 10-35%, Problem >40% or <8%
            • Low-Mid (200-800Hz): Ideal 18-28%, Acceptable 12-38%, Problem >45% or <10%
            • Mid (800Hz-3kHz): Ideal 25-35%, Acceptable 18-45%, Problem >50% or <15%
            • High-Mid (3-8kHz): Ideal 12-22%, Acceptable 8-32%, Problem >35% or <5%
            • High (8-20kHz): Ideal 8-18%, Acceptable 4-25%, Problem >30% or <3%
            
            PRE-MASTER MIX SCORING — GENRE-AWARE
            Stage: PRE-MASTER / MIX | Maximum score: 90 (mixes NEVER exceed 90 — masters score 90-100)

            ════════════════════════════════════════════════
            PRE-MASTER TARGET RANGES BY GENRE
            A good pre-master mix leaves headroom for the mastering engineer.
            ════════════════════════════════════════════════

            METAL / HARD ROCK MIX
            Loudness target: -16 to -18 LUFS | Acceptable: -14 to -20 LUFS
            Peak: -3 to -6 dBFS | Acceptable: -1 to -8 dBFS
            Dynamic Range: DR 10-14 (target) | DR 8-16 (acceptable)
            Stereo Width: 60-80% | Acceptable: 50-85%

            ELECTRONIC / EDM MIX
            Loudness target: -24 to -18 LUFS | Acceptable: -20 to -28 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 8-14 (target) | DR 6-18 (acceptable)
            Stereo Width: 50-80% | Acceptable: 40-90%

            HIP-HOP / TRAP / R&B MIX
            Loudness target: -24 to -18 LUFS | Acceptable: -20 to -28 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 8-14 (target) | DR 6-16 (acceptable)
            Stereo Width: 40-70% | Acceptable: 30-80%

            POP MIX
            Loudness target: -24 to -18 LUFS | Acceptable: -20 to -28 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 10-14 (target) | DR 8-16 (acceptable)
            Stereo Width: 50-80% | Acceptable: 40-85%

            ROCK / INDIE MIX
            Loudness target: -16 to -20 LUFS | Acceptable: -14 to -22 LUFS
            Peak: -3 to -6 dBFS | Acceptable: -1 to -8 dBFS
            Dynamic Range: DR 10-14 (target) | DR 8-16 (acceptable)
            Stereo Width: 50-70% | Acceptable: 40-80%

            CLASSICAL / ORCHESTRAL MIX
            Loudness target: -24 to -18 LUFS | Acceptable: -28 to -16 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 12-18 (target) | DR 10-22 (acceptable)
            Stereo Width: 60-100% | Acceptable: 50-100%

            A CAPPELLA / VOCAL MIX
            Loudness target: -24 to -18 LUFS | Acceptable: -20 to -28 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 12-18 (target) | DR 10-20 (acceptable)
            Stereo Width: 35-60% | Acceptable: 25-70%

            JAZZ MIX
            Loudness target: -22 to -16 LUFS | Acceptable: -18 to -26 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 10-16 (target) | DR 8-20 (acceptable)
            Stereo Width: 40-80% | Acceptable: 30-85%

            LIVE MIX
            Loudness target: -22 to -16 LUFS | Acceptable: -18 to -26 LUFS
            Peak: -6 to -3 dBFS | Acceptable: -3 to -9 dBFS
            Dynamic Range: DR 10-16 (target) | DR 8-20 (acceptable)
            Stereo Width: 50-90% | Acceptable: 40-95%

            ════════════════════════════════════════════════
            SCORE CALCULATION
            ════════════════════════════════════════════════

            BASE SCORE: 65 (pre-master baseline)

            UNIVERSAL BONUSES (add if metric is in target/excellent range for genre):
            +8 pts → No clipping AND loudness in target range for genre
            +5 pts → Phase coherence > 0.4 (well-controlled)
            +3 pts → Mono compatibility ≤ 3 dB loss
            +5 pts → Dynamic range in target range for genre
            Maximum total bonuses: +21

            UNIVERSAL PENALTIES:
            -10 pts → Clipping (peak > 0 dBFS)
            -8 pts  → Phase coherence < 0.2
            -8 pts  → Mono cancellation of key element
            -5 pts  → Loudness outside acceptable range for genre
            -5 pts  → Severe frequency imbalance (genre-inappropriate — see genre notes in master tables above)
            -3 pts  → Dynamic range outside acceptable range for genre

            FINAL SCORE = min(90, max(0, 65 + bonuses - penalties))
            ⚠️ HARD CAP: Pre-master/Mix tracks NEVER score above 90. Masters score 90-100.
            ⚠️ NO FLOOR — let scores vary naturally based on actual quality.

            ════════════════════════════════════════════════
            SANITY CHECK — Reference Scores (Pre-master)
            ════════════════════════════════════════════════
            Professional rock pre-master (ready to master): 82-88
            Good amateur pop pre-master (needs polish):     72-80
            Mix with real problems:                         55-70
            Raw unmixed recording:                          40-55
            Amateur mix with clipping:                      35-55
            ════════════════════════════════════════════════

            SCORE: [CALCULATE: min(90, max(0, 65 + bonuses - penalties))]
            ⚠️ If result > 90: write 90. Otherwise write the calculated score.

            ANALYSIS: [Write based on score — see analysis tone rules above]
            RECOMMENDATIONS: [Based on score]
            ⚠️ Score 85-90: "Ready for mastering" ONLY. Pure celebration. No suggestions.
            ⚠️ Score 70-84: 1-2 specific polishing suggestions.
            ⚠️ Score below 70: 3-5 direct, honest fixes.
            """
        }
    }
    
    private func getUserMessage(metrics: AudioMetricsForClaude, genre: String, isMastered: Bool) -> String {
        // Use genre from metrics if available, otherwise use passed genre
        let finalGenre = metrics.genre ?? genre
        let genreContext = finalGenre.isEmpty ? "" : """
            
            🎵 GENRE-SPECIFIC ANALYSIS:
            This track is classified as: **\(finalGenre)**
            Please analyze this track according to \(finalGenre) genre standards and expectations.
            Use genre-specific frequency balance guidelines and scoring criteria for \(finalGenre).
            
            """
        
        if isMastered {
            // Determine genre-specific thresholds for issue detection
            let genreLower = finalGenre.lowercased()
            let isMetalGenre = genreLower.contains("metal") || genreLower.contains("hard rock") || genreLower.contains("metalcore")
            let isEDMGenre = genreLower.contains("edm") || genreLower.contains("electronic") || genreLower.contains("techno") || genreLower.contains("house") || genreLower.contains("trap") || genreLower.contains("dubstep")
            let isLoudGenre = isMetalGenre || isEDMGenre

            // Count detected issues for mastered tracks
            var issueCount = 0
            var issuesList: [String] = []
            if metrics.hasClipping { issueCount += 1; issuesList.append("Clipping") }
            if metrics.hasPhaseIssues { issueCount += 1; issuesList.append("Phase Issues") }
            if metrics.hasStereoIssues { issueCount += 1; issuesList.append("Stereo Issues") }
            // Only flag frequency imbalance if not a genre where bass-heavy is normal
            if metrics.hasFrequencyImbalance && !isMetalGenre { issueCount += 1; issuesList.append("Frequency Imbalance") }
            // Only flag dynamic range issues if not a genre where heavy compression is intentional
            if metrics.hasDynamicRangeIssues && !isLoudGenre { issueCount += 1; issuesList.append("Dynamic Range Issues") }

            // Check for frequency extremes — use genre-aware thresholds
            let lowEndIssueThreshold: Double = isMetalGenre ? 70.0 : 50.0  // Metal: 40-60% is NORMAL, only flag >70%
            if metrics.lowEnd > lowEndIssueThreshold { issueCount += 1; issuesList.append("Bass at \(Int(metrics.lowEnd))%") }
            if metrics.high > 25 { issueCount += 1; issuesList.append("Highs at \(Int(metrics.high))%") }

            let issuesInstruction = issueCount > 0 ? """

            ⚠️⚠️⚠️ CRITICAL: \(issueCount) ISSUE(S) DETECTED: \(issuesList.joined(separator: ", "))
            YOU MUST PROVIDE AT LEAST \(min(issueCount + 1, 4)) SPECIFIC RECOMMENDATIONS TO ADDRESS THESE ISSUES!
            DO NOT SKIP THE RECOMMENDATIONS SECTION!
            ⚠️⚠️⚠️
            """ : ""

            return """
            Analyze this MASTERED TRACK.\(genreContext)

            🎚️ STEREO WIDTH: \(String(format: "%.1f", metrics.stereoWidth))%
            🎭 PHASE CORRELATION: \(String(format: "%.1f", metrics.phaseCoherence * 100))%
            🔊 MONO COMPATIBILITY: \(String(format: "%.1f", metrics.monoCompatibility * 100))%
            📊 PEAK LEVEL: \(String(format: "%.1f", metrics.peakLevel)) dBFS
            📈 RMS/LOUDNESS: \(String(format: "%.1f", metrics.loudness)) LUFS
            🎚️ DYNAMIC RANGE: \(String(format: "%.1f", metrics.dynamicRange)) dB
            📉 CREST FACTOR: \(String(format: "%.1f", metrics.truePeakLevel - metrics.rmsLevel)) dB

            🎵 FREQUENCY BALANCE:
            \(getGenreFrequencyGuidelines(genre: finalGenre, metrics: metrics))

            🚨 DETECTED ISSUES:
            • Clipping: \(metrics.hasClipping ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? (isMetalGenre ? "ℹ️ Bass-heavy (GENRE NORMAL for Metal — do NOT penalize)" : "❌ YES - MUST ADDRESS IN RECOMMENDATIONS") : "✅ No")
            • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? (isLoudGenre ? "ℹ️ Heavily compressed (GENRE NORMAL for \(finalGenre) — do NOT penalize)" : "❌ YES - MUST ADDRESS IN RECOMMENDATIONS") : "✅ No")
            \(issuesInstruction)
            """
        } else {
            // Count detected issues
            var issueCount = 0
            var issuesList: [String] = []
            if metrics.hasClipping { issueCount += 1; issuesList.append("Clipping") }
            if metrics.hasPhaseIssues { issueCount += 1; issuesList.append("Phase Issues") }
            if metrics.hasStereoIssues { issueCount += 1; issuesList.append("Stereo Issues") }
            if metrics.hasFrequencyImbalance { issueCount += 1; issuesList.append("Frequency Imbalance") }
            if metrics.hasDynamicRangeIssues { issueCount += 1; issuesList.append("Dynamic Range Issues") }

            // Check for frequency extremes
            if metrics.lowEnd > 50 { issueCount += 1; issuesList.append("Bass at \(Int(metrics.lowEnd))%") }
            if metrics.high > 25 { issueCount += 1; issuesList.append("Highs at \(Int(metrics.high))%") }
            if metrics.lowMid > 40 { issueCount += 1; issuesList.append("Low-mids at \(Int(metrics.lowMid))%") }

            let issuesInstruction = issueCount > 0 ? """

            ⚠️⚠️⚠️ CRITICAL: \(issueCount) ISSUE(S) DETECTED: \(issuesList.joined(separator: ", "))
            YOU MUST PROVIDE AT LEAST \(min(issueCount + 1, 4)) SPECIFIC RECOMMENDATIONS TO ADDRESS THESE ISSUES!
            DO NOT SKIP THE RECOMMENDATIONS SECTION - THE USER NEEDS ACTIONABLE FEEDBACK!
            ⚠️⚠️⚠️
            """ : ""

            return """
            Analyze this PRE-MASTERED MIX.\(genreContext)

            🎚️ PRE-MASTER LEVELS & DYNAMICS:
            • Peak Level: \(String(format: "%.1f", metrics.peakLevel)) dB
            • RMS Level: \(String(format: "%.1f", metrics.rmsLevel)) dB
            • Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS
            • Dynamic Range: \(String(format: "%.1f", metrics.dynamicRange)) dB
            • True Peak: \(String(format: "%.1f", metrics.truePeakLevel)) dBFS

            🎭 STEREO & PHASE:
            • Stereo Width: \(String(format: "%.1f", metrics.stereoWidth))%
            • Phase Coherence: \(String(format: "%.1f", metrics.phaseCoherence * 100))%
            • Mono Compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))%

            🎵 FREQUENCY BALANCE:
            \(getGenreFrequencyGuidelines(genre: finalGenre, metrics: metrics))

            🚨 PRE-MASTER MIX ISSUES:
            • Clipping: \(metrics.hasClipping ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            \(issuesInstruction)
            """
        }
    }
    
    
    
    private func validateMetrics(_ metrics: AudioMetricsForClaude) throws {
        // All-zeros check — fired when audio read fails silently
        if metrics.loudness == 0.0 && metrics.peakLevel == 0.0 &&
           metrics.stereoWidth == 0.0 && metrics.phaseCoherence == 0.0 &&
           metrics.dynamicRange == 0.0 {
            throw AudioAnalysisError.allZeroMetrics
        }
        guard (-70.0...0.0).contains(metrics.loudness) else {
            throw AudioAnalysisError.invalidLoudness(metrics.loudness)
        }
        guard (-60.0...0.0).contains(metrics.peakLevel) else {
            throw AudioAnalysisError.invalidPeakLevel(metrics.peakLevel)
        }
        guard (0.0...150.0).contains(metrics.stereoWidth) else {
            throw AudioAnalysisError.invalidStereoWidth(metrics.stereoWidth)
        }
        guard (-1.0...1.0).contains(metrics.phaseCoherence) else {
            throw AudioAnalysisError.invalidPhaseCoherence(metrics.phaseCoherence)
        }
        guard (0.0...60.0).contains(metrics.dynamicRange) else {
            throw AudioAnalysisError.invalidDynamicRange(metrics.dynamicRange)
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

        Start with base score of 85 points.

        GENRE-SPECIFIC SCORING ADJUSTMENTS (apply BEFORE penalties):
        The selected genre is: \(genre)

        Metal/Hard Rock/Metalcore/Heavy Metal:
        (keywords: metal, hard rock, metalcore, death metal, heavy metal)
        • Loudness -10 to -5 LUFS: NORMAL for genre — no loudness deduction, do NOT apply the >-6 penalty
        • Dynamic Range 4-8 dB: NORMAL (heavy compression is intentional for impact) — no DR penalty for DR4-8
        • Crest Factor 4-6 dB: NORMAL for genre — no crest factor penalty
        • Low End 30-55%: NORMAL (heavy guitars and bass are genre characteristics) — no frequency penalty
        • WHY: Metal masters are intentionally loud and compressed for maximum impact. DR4-6 is industry
          standard (e.g., Korn, Metallica, Slipknot). Penalizing these would incorrectly score professional
          commercial masters below 80 despite being technically correct for the genre.

        Electronic/EDM/Hip-Hop/Trap:
        (keywords: electronic, edm, techno, house, trap, dubstep, hip-hop, hip hop)
        • Low End 40-60%: NORMAL — no frequency penalty
        • Loudness -8 to -5 LUFS: NORMAL for club/streaming masters — no loudness deduction, do NOT apply the >-6 penalty
        • Dynamic Range 4-8 dB: NORMAL (brickwall limiting is intentional) — no DR penalty

        Acoustic/Classical/Jazz/Orchestral:
        (keywords: classical, jazz, acoustic, orchestral, orchestra, singer-songwriter)
        • Low End 12-25%: NORMAL — no frequency penalty
        • Loudness -20 to -14 LUFS: NORMAL for natural dynamics — no loudness deduction, do NOT apply the <-16 or <-20 penalties
        • Dynamic Range 10-22 dB: EXPECTED — no DR penalty

        Rock/Pop (default baseline):
        • Low End 20-40%: NORMAL — no frequency penalty
        • Loudness -10 to -6 LUFS: NORMAL — no loudness deduction

        APPLY THRESHOLDS (use the warning thresholds above):

        STEREO WIDTH:
        • 20-90%: Good (no change)
        • 15-20% OR 90-95%: Minor issue (-3 points)
        • <15% OR >95%: Problem (-8 points)

        PHASE CORRELATION:
        • ≥0.4 (40%): Good (no change)
        • 0.3-0.4 (30-40%): Minor issues (-3 points)
        • <0.3 (30%): Phase issues (-8 points)

        MONO COMPATIBILITY:
        • ≤3dB loss: Good (no change)
        • 3-5dB loss: Minor issue (-5 points)
        • >5dB loss: Fail (-12 points)

        PEAK LEVEL:
        • ≤-0.1 dBFS: Good (+5 points)
        • -0.1 to 0 dBFS: Minor clipping risk (-5 points)
        • >0 dBFS: Clipping (-15 points)

        LOUDNESS (apply genre-specific norms from above first):
        • -10 to -5 LUFS: NORMAL for Metal/Hard Rock (+10 points) [Metal/Hard Rock only]
        • -10 to -6 LUFS: Modern streaming master (+10 points)
        • -16 to -10 LUFS: Professional master (+5 points)
        • -20 to -14 LUFS: Acceptable (no penalty) [waived for Acoustic/Classical/Jazz/Orchestral]
        • <-20 LUFS: Too quiet (-5 points) [waived for Acoustic/Classical/Jazz/Orchestral]
        • >-6 LUFS: Too loud (-8 points) [waived for Electronic/EDM/Hip-Hop/Trap AND Metal/Hard Rock]

        DYNAMIC RANGE (apply genre-specific norms from above first):
        • ≥8 DR: Good (+5 points)
        • 6-8 DR: Acceptable (no change)
        • 4-6 DR: Compressed (-5 points) [waived for Electronic/EDM/Hip-Hop/Trap AND Metal/Hard Rock]
        • <4 DR: Over-compressed (-10 points) [waived for Electronic/EDM/Hip-Hop/Trap AND Metal/Hard Rock]

        CREST FACTOR:
        • ≥8 dB: Excellent dynamics (+5 points)
        • 6-8 dB: Good dynamics (+3 points)
        • 4-6 dB: Moderate compression (no change)
        • <4 dB: Crushed dynamics (-8 points)

        FREQUENCY BALANCE:
        • Only penalize SEVERE imbalances (>75% bass, <2% highs, etc.)
        • Genre-specific frequency characteristics are ACCEPTABLE (see genre norms above)
        • Dark/warm masters (low highs) are PROFESSIONAL choices, not problems
        • Slight imbalances (60-75% bass) are only -3 points

        IMPORTANT: Mastered tracks with good metrics should score 85-100
        • No clipping + good loudness + balanced frequencies = 88-95
        • Professional masters from Abbey Road, etc. should score 90-100
        • Be GENEROUS with scoring - real professional tracks should score high!

        Final score = min(100, max(0, base + bonuses - penalties))
        
        📝 RESPONSE FORMAT (CRITICAL - FOLLOW EXACTLY):
        
        SCORE: [0-100 based on thresholds above]
        
        ANALYSIS: Describe the overall sonic character and quality of this mix in 2-4 sentences. Focus on what you HEAR: Is it muddy or clear? Bright or dark? Balanced or imbalanced? Punchy or compressed? Professional or amateur? Does it sound good or does it have issues? Keep it conversational and avoid mentioning specific numbers, dB values, percentages, or technical penalties.
        
        RECOMMENDATIONS:
        - [If the mix sounds good and professional, write "This mix sounds great and is ready for distribution" or similar positive statement]
        - [If there are issues, describe them in plain language without numbers: e.g., "The low end could be clearer" instead of "Reduce 200Hz by 3dB"]
        - [Keep recommendations brief, actionable, and conversational - use bullet points starting with dash (-), NOT numbers]
        - [Maximum 3-4 recommendations]
        
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
        • Stereo Width: \(String(format: "%.1f", metrics.stereoWidth))%
        • Phase Coherence: \(String(format: "%.1f", metrics.phaseCoherence * 100))%
        • Mono Compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))%
        
        🎵 FREQUENCY BALANCE:
        • Low: \(String(format: "%.1f", metrics.lowEnd))% (Ideal: 15-25%)
        • Low-Mid: \(String(format: "%.1f", metrics.lowMid))% (Ideal: 18-28%)
        • Mid: \(String(format: "%.1f", metrics.mid))% (Ideal: 25-35%)
        • High-Mid: \(String(format: "%.1f", metrics.highMid))% (Ideal: 12-22%)
        • High: \(String(format: "%.1f", metrics.high))% (Ideal: 8-18%)
        
        🚨 PRE-MASTER MIX ISSUES:
        • Clipping: \(metrics.hasClipping ? "❌ YES (Major penalty)" : "✅ No")
        • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES (Major penalty)" : "✅ No")
        • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES (Penalty)" : "✅ No")
        • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES (Penalty)" : "✅ No")
        • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES (Penalty)" : "✅ No")
        
        PRE-MASTER SCORING (Start: 88 base - BE VERY LENIENT!):

        GENRE-SPECIFIC SCORING ADJUSTMENTS (apply BEFORE penalties):
        The selected genre is: \(genre)

        Electronic/EDM/Hip-Hop/Trap:
        • Low End 40-60%: NORMAL — no frequency penalty
        • Loudness -8 to -6 LUFS: NORMAL for pre-masters targeting club play — no loudness deduction
        • Dynamic Range 4-8 dB: NORMAL (heavy bus limiting is common) — no DR penalty

        Acoustic/Classical/Jazz/Singer-Songwriter:
        • Low End 12-25%: NORMAL — no frequency penalty
        • Loudness -23 to -16 LUFS: NORMAL (natural dynamics preserved) — no loudness deduction
        • Dynamic Range 10-22 dB: EXPECTED — no DR penalty

        Rock/Pop (default baseline):
        • Low End 20-40%: NORMAL — no frequency penalty
        • Loudness -16 to -10 LUFS: NORMAL — no loudness deduction

        PENALTIES (VERY REDUCED - maximum 8 points total!):
        • Peak >0dB: -6 (clipping - severe, but rare) | Peak >-1dB: -1 (minor) | True Peak >-1dBFS: -1
        • Stereo Width <15% or >85%: -2 (only if extreme) | Phase <30%: -6 (severe) | Phase 30-40%: -3 | Phase 40-60%: -1 (minor)
        • Mono <30%: -5 | Mono 30-50%: -2 | Mono 50-70%: -1
        • Dynamic Range <6dB: -2 [waived for Electronic/EDM/Hip-Hop/Trap] | Frequency: ZERO (artistic choice - don't penalize!)
        • ⚠️ CRITICAL: Apply ALL applicable penalties, but cap total penalties at 8 points maximum

        BONUSES (INCREASED):
        • Peak -3 to -6dB: +5 | DR >8dB: +5 (>15dB: +7) | Phase >75%: +5
        • Balanced frequencies: +5 | Good mono (>70%): +3 | Excellent stereo (25-45%): +3
        • Stereo 25-45%: +5 | Loudness -16 to -6 LUFS: +5 to +10

        FINAL SCORE = min(90, max(0, 88 + bonuses - penalties)) [cap total penalties at 8 points]
        
        SCORE RANGES (DIFFERENTIATE - NO FLOOR, ONLY CAP AT 90):
        • 85-90: Professional commercial quality, ready for mastering (MAXIMUM 90!)
        • 78-84: Strong amateur/semi-pro mix, competitive quality
        • 68-77: Decent mix with improvements needed
        • 50-67: Weak mix or unmixed/raw recording
        • Allow natural variation - Korn should score 85-90, amateurs 70-84, unmixed 50-69!
        
        EXAMPLE SCORING:
        • Professional loudness + excellent dynamics + good phase + safe peaks = 85-90 (MAXIMUM 90!)
        • Good loudness + decent dynamics + acceptable phase = 75-84
        • Issues with peaks or phase or dynamics = 65-74
        
        Be REALISTIC for PRE-MASTERS:
        • Excellent mix ready for mastering: 85-90 points (MAXIMUM 90 - masters score 95-100!)
        • Good mix ready for mastering: 75-84 points
        • Decent mix needing work: 65-74 points
        • Needs significant improvement: 50-64 points
        
        ⚠️⚠️⚠️ ABSOLUTE RULE: Pre-master mixes MUST be capped at 90 maximum! ⚠️⚠️⚠️
        ⚠️ If you calculate above 90, write 90 instead (masters score 95-100, mixes score lower!)
        
        ⚠️ CRITICAL: MANDATORY RECOMMENDATIONS FOR ANY DETECTED ISSUE
        If ANY of these flags are YES, you MUST provide specific recommendations:
        • Clipping: "The mix is clipping - pull back the output gain and check your limiters"
        • Phase Issues: "There's phase cancellation happening - check your stereo sources and any parallel processing"
        • Stereo Issues: "The stereo image needs work - either too wide (collapsing in mono) or too narrow (needs more dimension)"
        • Frequency Imbalance: "The frequency balance is off - [specify which range: low end is dominating / mids are recessed / highs are harsh]"
        • Dynamic Range Issues: "The dynamics need attention - [too compressed/squashed OR too dynamic/uncontrolled]"

        ⚠️ FREQUENCY-SPECIFIC RECOMMENDATIONS (MANDATORY if any band exceeds 50%):
        • Low End >50%: "The low end is overpowering the mix - that bass needs to sit back and let the rest of the track breathe"
        • Low-Mid >40%: "There's mud building up in the low-mids - clean that up around 200-400Hz to add clarity"
        • Mid >50%: "The mids are dominating - this mix is honky and needs EQ work in the 800Hz-2kHz range"
        • High-Mid >35%: "The upper-mids are harsh - tame that 3-6kHz range, it's fatiguing to listen to"
        • High >30%: "Too much sizzle up top - the highs are brittle and need to be pulled back"

        Format response as (FOLLOW EXACTLY):
        SCORE: [FOLLOW THESE EXACT STEPS:
        1. Calculate your score based on the metrics
        2. Check: Is the result greater than 90?
        3. If YES: Write 90 (NOT the calculated number - pre-master mixes max at 90!)
        4. If NO: Write the calculated number
        5. NEVER write a number higher than 90 for pre-master mixes!

        ⚠️⚠️⚠️ MANDATORY: After calculating, if score > 90, you MUST write 90! ⚠️⚠️⚠️

        ANALYSIS: Write like a top pro mixer (Dave Pensado, Chris Lord-Alge, Tony Maserati, Manny Marroquin) giving honest feedback. In 2-3 sentences, describe the VIBE and ENERGY of this \(genre) mix. Does it HIT? Does it have IMPACT? Does it PUNCH? Does it sit right? Is it GLUED together or falling apart? Be conversational and direct. DO NOT mention "Score includes:", points, penalties, or technical numbers. Just describe how it FEELS and SOUNDS. Be HONEST about problems - if the bass is overpowering, say it. If it lacks punch, call it out.

        RECOMMENDATIONS:
        ⚠️⚠️⚠️ MANDATORY SECTION - NEVER SKIP THIS! ⚠️⚠️⚠️

        You MUST provide 2-5 specific, actionable recommendations. Think like Dave Pensado, CLA, Tony Maserati, or Manny Marroquin reviewing a mix.

        IF ANY ISSUE WAS DETECTED (Clipping, Phase, Stereo, Frequency Imbalance, Dynamic Range):
        - You MUST address EACH detected issue with a specific recommendation
        - Be direct and honest: "The low end is running wild" / "Phase issues are killing your punch" / "It's over-compressed"
        - Give actionable fixes: what to do, where to focus

        IF FREQUENCY BALANCE IS OFF (check the percentages above):
        - Low End >40%: "The bass is dominating - pull it back to let the mix breathe"
        - Low-Mid >35%: "There's mud in the 200-400Hz range - clean it up"
        - Mids recessed: "The mids are buried - bring them forward for clarity"
        - High >25%: "Too bright and harsh up top - tame those highs"

        SCORING GUIDE FOR RECOMMENDATIONS:
        - Score 85+ (EXCELLENT): "This \(genre) mix is tight and ready - ship it!" or "Ready for mastering" ONLY. NO improvements, NO suggestions, NO critiques. Pure celebration only.
        - Score 70-84: 1-2 specific improvements if needed (only if there are actual issues)
        - Score <70 OR any issues: 3-5 direct, honest fixes

        FORMAT: Use dash (-) for bullet points. Be specific. Be helpful. Be like a mentor giving feedback.

        Example recommendations:
        - "The low end is eating up the mix - high-pass unnecessary elements and tighten up that bass"
        - "Your phase coherence is suffering - check stereo sources and parallel buses"
        - "This mix is compressed to death - back off the bus compressor and let it breathe"
        - "The mids are recessed - push the vocal and main instruments forward"
        - "Nice balance, but it could use more air and dimension up top"
        """
    }
    
    private func isPositiveRecommendation(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // These are positive messages that should be shown (not filtered)
        let positiveMessages = [
            "ready for mastering",
            "ready for distribution",
            "excellent work",
            "excellent mix",
            "professional quality",
            "mastering ready",
            "well mixed",
            "sounds great",
            "no recommendations needed",
            "no issues found"
        ]
        
        // Check if it's a positive message
        if positiveMessages.contains(where: { lowercased.contains($0) }) {
            return true  // It's positive, but we'll handle it specially
        }
        
        // These should be filtered out completely
        let filterKeywords = [
            "none",
            "well balanced",
            "no issues",
            "good balance",
            "technical balance"
        ]
        
        return filterKeywords.contains { lowercased.contains($0) }
    }
    
    private func shouldShowAsRecommendation(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Show these positive messages as recommendations
        let showAsRecommendation = [
            "ready for mastering",
            "ready for distribution",
            "excellent work",
            "excellent mix",
            "professional quality",
            "mastering ready"
        ]
        
        return showAsRecommendation.contains(where: { lowercased.contains($0) })
    }
    
    private func parseClaudeResponse(_ data: Data, isMastered: Bool) throws -> ClaudeAnalysisResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let content = json?["content"] as? [[String: Any]],
              let textContent = content.first?["text"] as? String else {
            throw ClaudeAPIError.parseError
        }
        
        // DEBUG: Print Claude's raw response
        print("🤖 CLAUDE RAW RESPONSE:\n\(textContent)\n")
        
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
            let cleanedLine = trimmedLine.replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "📊", with: "")
                .replacingOccurrences(of: "🔧", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .replacingOccurrences(of: "❌", with: "")
                .replacingOccurrences(of: "⚠️", with: "")
                .replacingOccurrences(of: "🎯", with: "")
                .replacingOccurrences(of: "💡", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanedLine.contains("SCORE:") {
                // Remove everything before "SCORE:" to handle "FINAL SCORE:", "**SCORE:**", etc.
                let scoreText = cleanedLine.components(separatedBy: "SCORE:").last?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Extract the first number from the score line (handle "100", "100/100", "85 points", etc.)
                let numbers = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let firstNumber = numbers.first, let parsedScore = Int(firstNumber) {
                    score = parsedScore
                } else {
                    print("⚠️ WARNING: Failed to parse score from line: \(trimmedLine)")
                }
                // After parsing score, automatically switch to analysis section
                // (Claude often puts analysis text right after SCORE: without an ANALYSIS: header)
                skipCalculationSection = false
                currentSection = "analysis"
                continue
            }
            
            // Start of ANALYSIS section - exit calculation skip mode (handle markdown headers and emojis)
            if cleanedLine.hasPrefix("ANALYSIS") || cleanedLine.contains("PRE-MASTERED MIX ANALYSIS") || cleanedLine.contains("MASTERED TRACK ANALYSIS") {
                skipCalculationSection = false
                currentSection = "analysis"
                // Skip the header line itself, start collecting from next line
                continue
            }
            
            // Start of RECOMMENDATIONS section (handle various formats)
            if cleanedLine.hasPrefix("RECOMMENDATIONS") || cleanedLine.hasPrefix("CRITICAL RECOMMENDATIONS") || cleanedLine.hasPrefix("PRIORITY") {
                skipCalculationSection = false
                currentSection = "recommendations"
                continue
            }
            
            // Skip section headers like "STRENGTHS", "CRITICAL ISSUES", "DETAILED BREAKDOWN"
            if cleanedLine.hasPrefix("STRENGTHS") || cleanedLine.hasPrefix("CRITICAL ISSUES") || 
               cleanedLine.hasPrefix("DETAILED BREAKDOWN") || cleanedLine.hasPrefix("PRIORITY") ||
               cleanedLine.hasPrefix("Genre-Specific") || cleanedLine.hasPrefix("Mastering Preparation") {
                continue
            }
            
            // Skip lines if we're in the calculation section
            if skipCalculationSection {
                continue
            }
            
            // Process content for current section
            if !trimmedLine.isEmpty {
                if currentSection == "analysis" {
                    // Stop analysis section when we hit RECOMMENDATIONS or READY FOR MASTERING
                    if cleanedLine.contains("RECOMMENDATIONS") || cleanedLine.contains("READY FOR MASTERING") {
                        currentSection = ""
                    } else if !trimmedLine.hasPrefix("---") && !trimmedLine.hasPrefix("===") && !trimmedLine.hasPrefix("SCORE") {
                        // Skip separator lines and SCORE line, add everything else to analysis
                        analysis += " " + trimmedLine
                    }
                } else if currentSection == "recommendations" {
                    // Stop recommendations section when we hit READY FOR MASTERING
                    if cleanedLine.contains("READY FOR MASTERING") {
                        currentSection = ""
                    } else if trimmedLine.hasPrefix("-") || trimmedLine.hasPrefix("•") || 
                              trimmedLine.hasPrefix("1.") || trimmedLine.hasPrefix("2.") || 
                              trimmedLine.hasPrefix("3.") || trimmedLine.hasPrefix("4.") ||
                              trimmedLine.hasPrefix("5.") || trimmedLine.hasPrefix("6.") {
                        // Extract bullet/numbered content
                        var cleanRec = trimmedLine
                        if cleanRec.hasPrefix("-") || cleanRec.hasPrefix("•") {
                            cleanRec = String(cleanRec.dropFirst())
                        } else {
                            // Remove number prefix like "1. ", "2. "
                            if let dotIndex = cleanRec.firstIndex(of: ".") {
                                cleanRec = String(cleanRec[cleanRec.index(after: dotIndex)...])
                            }
                        }
                        cleanRec = cleanRec.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "**", with: "")
                            .replacingOccurrences(of: "*", with: "")
                        
                        if !cleanRec.isEmpty && !cleanRec.hasPrefix("---") {
                            recommendations.append(cleanRec)
                        }
                    }
                }
            }
        }
        
        // 🔍 DEBUG: Print what we extracted
        let finalAnalysis = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📊 PARSED RESULTS:")
        print("  Score: \(score ?? -1)")
        print("  Analysis length: \(finalAnalysis.count) chars")
        if finalAnalysis.isEmpty {
            print("  ⚠️ WARNING: Analysis text is empty after parsing")
            print("  ⚠️ This should NOT happen with the new parser!")
            print("  ⚠️ Raw response length: \(textContent.count) chars")
        } else {
            print("  Analysis: \(finalAnalysis)")
        }
        print("  Recommendations count: \(recommendations.count)")
        for (i, rec) in recommendations.enumerated() {
            print("    \(i+1). \(rec)")
        }
        
        // Warn if score parsing failed
        if score == nil {
            print("⚠️ WARNING: Score not found in Claude response, using fallback value 50")
        }
        
        // Determine if ready for mastering: few or no recommendations AND good score
        let isReadyForMastering = recommendations.count <= 2 && (score ?? 0) >= 75
        
        // Generate a meaningful fallback message based on score and recommendations
        let fallbackSummary: String
        if let actualScore = score {
            if actualScore >= 85 {
                fallbackSummary = "Professional quality track ready for distribution."
            } else if actualScore >= 70 {
                fallbackSummary = "Good track with a few areas that could be improved."
            } else {
                fallbackSummary = "Track needs some mixing improvements to reach professional standards."
            }
        } else {
            fallbackSummary = "Analysis completed. Check recommendations below for details."
        }
        
        // Enforce score caps and floors based on track type
        var finalScore = score ?? 50
        if !isMastered {
            // Standard pre-master mix cap at 90 maximum (mixes don't score 91+)
            if finalScore > 90 {
                print("⚠️ PRE-MASTER MIX SCORE CAP: Capping score from \(finalScore) to 90 (pre-master mixes max at 90)")
                finalScore = 90
            }
            // NO FLOOR - let scores vary naturally to differentiate between songs
            // Professional mixes should score 85-90, amateur 70-84, weak/unmixed 50-69
            print("✅ MIX SCORE (no floor): \(finalScore)")
        }
        
        // Check for contradictory analysis: if score is 85+ but analysis contains negative phrases, use fallback
        var finalAnalysisText = finalAnalysis.isEmpty ? fallbackSummary : finalAnalysis
        if let fixedAnalysis = Self.fixContradictoryAnalysis(analysis: finalAnalysisText, score: Double(finalScore)) {
            finalAnalysisText = fixedAnalysis
        }
        
        return ClaudeAnalysisResponse(
            score: finalScore,
            summary: finalAnalysisText,
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

    // MARK: - Test Helpers (for unit testing)

    /// Test helper: Parse Claude response from string (for unit testing)
    /// - Parameters:
    ///   - responseText: The raw response text to parse
    ///   - isMastered: Whether the track is mastered
    /// - Returns: Parsed response with score and analysis
    func parseClaudeResponse(_ responseText: String, isMastered: Bool) -> (score: Int, summary: String, recommendations: [String]) {
        // Extract score using same patterns as real parser
        var score: Int? = nil

        // Try SCORE: pattern first (most common)
        let scorePatterns = [
            #"SCORE:\s*(\d+)"#,
            #"Score:\s*(\d+)"#,
            #"Overall Score:\s*(\d+)"#,
            #"Final Score:\s*(\d+)"#,
            #"\*\*SCORE:\s*(\d+)\*\*"#,
            #"\*\*Score:\s*(\d+)\*\*"#
        ]

        for pattern in scorePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: responseText, options: [], range: NSRange(responseText.startIndex..., in: responseText)),
               let scoreRange = Range(match.range(at: 1), in: responseText) {
                score = Int(responseText[scoreRange])
                break
            }
        }

        // Apply enforcement logic (same as in real parseClaudeResponse)
        var finalScore = score ?? 50
        if !isMastered {
            // Standard mix cap at 90
            if finalScore > 90 { finalScore = 90 }
        }

        // Cap masters at 100
        if isMastered && finalScore > 100 {
            finalScore = 100
        }

        return (score: finalScore, summary: "Test summary", recommendations: [])
    }

    /// Test helper: Detect if audio metrics indicate a professional master
    /// - Parameter metrics: Audio metrics to analyze
    /// - Returns: True if metrics strongly indicate a professional master
    func testDetectDefiniteProfessionalMaster(_ metrics: AudioMetricsForClaude) -> Bool {
        return detectDefiniteProfessionalMaster(metrics)
    }
}

// MARK: - Validation

enum AudioAnalysisError: Error, LocalizedError {
    case allZeroMetrics
    case invalidLoudness(Double)
    case invalidPeakLevel(Double)
    case invalidStereoWidth(Double)
    case invalidPhaseCoherence(Double)
    case invalidDynamicRange(Double)

    var errorDescription: String? {
        switch self {
        case .allZeroMetrics:
            return "Audio read failed: all metrics are zero — the file may be silent, corrupt, or unreadable"
        case .invalidLoudness(let v):
            return "Invalid loudness value: \(String(format: "%.1f", v)) LUFS (expected -70 to 0)"
        case .invalidPeakLevel(let v):
            return "Invalid peak level: \(String(format: "%.1f", v)) dBFS (expected -60 to 0)"
        case .invalidStereoWidth(let v):
            return "Invalid stereo width: \(String(format: "%.1f", v))% (expected 0 to 150)"
        case .invalidPhaseCoherence(let v):
            return "Invalid phase coherence: \(String(format: "%.2f", v)) (expected -1.0 to 1.0)"
        case .invalidDynamicRange(let v):
            return "Invalid dynamic range: \(String(format: "%.1f", v)) dB (expected 0 to 60)"
        }
    }
}

// MARK: - Data Models

struct AudioMetricsForClaude {
    // User-selected genre for genre-specific analysis
    let genre: String?
    
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
    
    // Mix Quality Detection
    let isLikelyUnmixed: Bool           // TRUE = raw unmixed audio, needs mixing
    let mixingQualityScore: Double      // 0-100 from unmixed detection
    
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
