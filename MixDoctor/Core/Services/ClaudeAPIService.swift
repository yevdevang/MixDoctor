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
        
        // Debug: verify all frequency values are non-zero before sending to Claude
        print("🎵 FREQUENCY DATA SENT TO CLAUDE:")
        print("  5-band: Low End \(String(format: "%.1f", metrics.lowEnd))%, Low Mid \(String(format: "%.1f", metrics.lowMid))%, Mid \(String(format: "%.1f", metrics.mid))%, High Mid \(String(format: "%.1f", metrics.highMid))%, High \(String(format: "%.1f", metrics.high))%")
        print("  7-band: SubBass \(String(format: "%.1f", metrics.subBassEnergy))%, Bass \(String(format: "%.1f", metrics.bassEnergy))%, LowMid \(String(format: "%.1f", metrics.lowMidEnergy))%, Mid \(String(format: "%.1f", metrics.midEnergy))%, HighMid \(String(format: "%.1f", metrics.highMidEnergy))%, Presence \(String(format: "%.1f", metrics.presenceEnergy))%, Air \(String(format: "%.1f", metrics.airEnergy))%")
        let frequencyTotal = metrics.lowEnd + metrics.lowMid + metrics.mid + metrics.highMid + metrics.high
        if frequencyTotal < 1.0 {
            print("⚠️ WARNING: All frequency bands are near zero — AnalysisResult may not be fully populated")
        }
        
        // Detect track type and genre
        // User-selected stage takes PRIORITY over metrics detection
        let stageLower = mixStage?.lowercased() ?? ""
        let isMasteredByStage = stageLower.contains("master")
        let isMixStage = stageLower == "mix"  // Exact match only - don't match "master_streaming"!
        let isMasteredByMetrics = detectMasteredTrack(metrics)
        let isDefinitelyProfessionalMaster = detectDefiniteProfessionalMaster(metrics)

        // INTELLIGENT OVERRIDE: Even if user says "Mix", if metrics STRONGLY indicate
        // a professional master (Korn, Green Day, etc.), we should score it appropriately
        let isMastered: Bool
        var professionalMasterOverride = false  // Used for scoring adjustment
        if isMixStage {
            // Check if metrics STRONGLY indicate this is actually a professional master
            if isDefinitelyProfessionalMaster {
                print("🎯 PROFESSIONAL OVERRIDE: User labeled as 'Mix' but metrics indicate professional master")
                print("   - Will use hybrid scoring: Mix prompts but professional-friendly score ranges")
                isMastered = false  // Keep using mix prompts for context
                professionalMasterOverride = true  // Flag for score adjustment
            } else {
                isMastered = false  // User said it's a Mix - respect that
            }
        } else if isMasteredByStage {
            isMastered = true   // User said it's a Master - respect that!
        } else {
            isMastered = isMasteredByMetrics  // Auto-detect from metrics
        }
        
        if let stage = mixStage {
            print("🎚️ USER-SELECTED STAGE: \(stage) - isMastered: \(isMastered) (Mix='\(isMixStage)', Master='\(isMasteredByStage)')")
        }
        // Prioritize genre from metrics (user-selected), then userGenre parameter, then auto-detect
        let genre = metrics.genre ?? userGenre ?? detectGenre(metrics)

        // CRITICAL: Override unmixed detection based on user selection
        // If user explicitly selected a Master stage, it's NOT unmixed regardless of metrics
        // If user selected Mix, use metrics detection
        // If professional master override is active, it's NOT unmixed
        let isUnmixed: Bool
        if isMasteredByStage {
            // User said it's a Master - NEVER treat as unmixed
            isUnmixed = false
            if metrics.isLikelyUnmixed {
                print("🎯 MASTER OVERRIDE: User selected Master stage - ignoring unmixed detection")
            }
        } else if professionalMasterOverride {
            // Professional master detected even though labeled as Mix - NOT unmixed
            isUnmixed = false
            print("🎯 PROFESSIONAL OVERRIDE: Metrics indicate professional master - ignoring unmixed detection")
        } else {
            // Use metrics detection
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
        let cacheVersion = "v11.0-MANDATORY-RECOMMENDATIONS"  // Force Claude to always generate recommendations when issues exist
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
        
        return try parseClaudeResponse(data, isMastered: isMastered, professionalMasterOverride: professionalMasterOverride)
    }

    private func determineModel(isProUser: Bool) -> String {
        // Using official Anthropic Claude 4.5 models (Nov 2025)
        // Pro users get Sonnet (smartest), free users get Haiku (fastest)
        return isProUser ? "claude-sonnet-4-5-20250929" : "claude-haiku-4-5-20251001"
    }
    
    private func detectMasteredTrack(_ metrics: AudioMetricsForClaude) -> Bool {
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
        // Skip if detected as unmixed - unmixed tracks are never professional masters
        if metrics.isLikelyUnmixed {
            return false
        }

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
            • Warning Thresholds: <-14 LUFS (streaming), >-6 LUFS (too loud)
            
            🎚️ DYNAMIC RANGE:
            • Calculation: DR = peak - RMS OR PLR
            • Display: dB or DR units
            • Warning Threshold: <6 DR (over-compressed)
            
            📉 CREST FACTOR:
            • Calculation: 20×log₁₀(peak/rms)
            • Display: dB
            • Warning Threshold: <6 dB (crushed dynamics)
            
            🎵 FREQUENCY BALANCE:
            • Low End (20-200Hz)
            • Low Mid (200-800Hz)
            • Mid (800Hz-3kHz)
            • High Mid (3-8kHz)
            • High (8-20kHz)
            
            🎯 SCORING RULES (0-100 scale) - GENRE-AWARE ANALYSIS:
            
            ⚠️ CRITICAL: GENRE-SPECIFIC ANALYSIS REQUIRED
            The user has selected the genre: **\(genre)**
            You MUST analyze this track according to \(genre) genre standards and expectations.
            Genre-specific frequency characteristics are INTENTIONAL and CORRECT - do NOT penalize for genre-appropriate frequency balance.
            Only penalize for technical defects that would be problematic regardless of genre.
            Use genre-specific frequency guidelines for \(genre) when evaluating frequency balance.
            
            \(isLiveRecording ? """
            ⚠️ LIVE RECORDING SCORING PHILOSOPHY:
            • Live recordings should be scored using LIVE MIXING standards, not studio mastering standards
            • Higher dynamic range (10-18dB) is NORMAL and EXPECTED for live recordings
            • Room acoustics, audience noise, and natural reverb are part of the live experience
            • Frequency balance will vary based on venue acoustics - this is NORMAL
            • Less compression is typical - live mixes preserve performance dynamics
            • Scoring should reflect the quality of LIVE MIXING, not studio production polish
            • Excellent live mixes score 80-90 points (preserving performance energy while maintaining clarity)
            • Good live mixes score 70-79 points (decent balance, some room issues acceptable)
            • Acceptable live mixes score 60-69 points (workable, but needs improvement)
            
            """ : "")
            ⚠️ SCORING PHILOSOPHY FOR \(isLiveRecording ? "LIVE RECORDING MIXES" : "MASTERED TRACKS"):
            • Commercial mastered tracks (Korn, Green Day, etc.) should score 88-95 points
            • Start at 100 points and subtract ONLY for actual technical defects
            • Genre characteristics (bass-heavy Rock, compressed EDM) are CORRECT, not problems
            • Frequency distribution is ARTISTIC - only penalize if truly broken (>85% in one band)
            
            SCORING CALCULATION FOR MASTERED TRACKS:
            1. Start at 100 points
            2. Subtract penalties ONLY for technical problems (see below)
            3. Professional commercial masters should score 88-95 (only -5 to -12 points total)
            4. Minimum acceptable mastered track: 85 points
            
            ⚠️ LOUDNESS-BASED SCORE CAPS (CRITICAL):
            If loudness is extremely low, the track may be unmixed or unmastered. Apply these HARD CAPS:
            • Loudness < -30 LUFS: Maximum score = 60 (raw recording)
            • Loudness -30 to -25 LUFS: Maximum score = 70 (needs mastering)
            • Loudness -25 to -20 LUFS: Maximum score = 80 (pre-master mix)
            • Loudness -20 to -16 LUFS: Maximum score = 90 (conservative master)
            • Loudness > -16 LUFS: No cap (modern mastering)
            
            When applying a cap, you MUST:
            1. Use the capped score (do not exceed the maximum)
            2. Add to insights: "⚠️ Score capped at [X] due to very low loudness ([Y] LUFS) - this may be an unmixed or unmastered track"
            3. Add to recommendations: "This track needs mixing and mastering to reach commercial loudness levels"
            
            GENRE-SPECIFIC FREQUENCY EXPECTATIONS (DO NOT PENALIZE):
            
            ⚠️ CONSISTENCY REMINDER: Genre provides CONTEXT, not different scoring thresholds!
            - Same track analyzed as Rock vs Pop should score within ±2 points
            - Genre-specific frequency balance is INTENTIONAL - acknowledge it but don't penalize
            - Only penalize SEVERE technical issues (>85% in one band) consistently across all genres
            
            ⚠️ CURRENT TRACK GENRE: **\(genre)**
            Apply the following genre-specific expectations for \(genre). These characteristics are INTENTIONAL and CORRECT for this genre.
            REMEMBER: These are EXPECTATIONS for context, not PENALTIES. The same track should score similarly regardless of genre selection.
            
            POP:
            • Bass 20-35%: Balanced foundation (no penalty)
            • Low-Mid 18-28%: Warmth and body (no penalty)
            • Mid 28-45%: Vocal clarity CRITICAL (no penalty)
            • High-Mid 15-25%: Vocal presence (no penalty)
            • High 8-15%: Bright and airy (no penalty)
            
            ROCK/INDIE:
            • Bass 20-35%: Balanced foundation (no penalty)
            • Low-Mid 18-28%: Guitar warmth (no penalty)
            • Mid 25-40%: Vocal and instrument clarity (no penalty)
            • High-Mid 15-25%: Presence and articulation (no penalty)
            • High 8-18%: Air and sparkle (no penalty)
            
            HIP-HOP/R&B:
            • Bass 30-50%: NORMAL for 808s and sub-bass (no penalty)
            • Low-Mid 20-35%: Vocal warmth and 808 body (no penalty)
            • Mid 20-35%: Vocal clarity (no penalty)
            • High-Mid 8-20%: Vocal presence (no penalty)
            • High 2-12%: Intentionally warm/dark (no penalty)
            
            EDM/ELECTRONIC:
            • Bass 35-60%: NORMAL for bass-heavy genres (no penalty)
            • Low-Mid 15-25%: Synth body (no penalty)
            • Mid 15-30%: Vocal presence (no penalty)
            • High-Mid 10-20%: Synth clarity (no penalty)
            • High 8-18%: Synthetic sparkle and FX (no penalty)
            ⚠️ EDM/ELECTRONIC CHARACTERISTICS (ALL NORMAL):
            • Dynamic range 4-14dB: WIDE RANGE depending on subgenre (no penalty)
            • Brickwall EDM (4-6dB DR): INTENTIONAL for club play (no penalty)
            • Streaming EDM (8-14dB DR): CORRECT for modern streaming (no penalty)
            • Loudness -6 to -16 LUFS: Depends on target platform (no penalty)
            • Club masters (-6 to -10 LUFS): INTENTIONAL competitive loudness (no penalty)
            • Streaming masters (-12 to -16 LUFS): CORRECT for normalization (no penalty)
            • Wide stereo (60-90%): NORMAL for stereo FX and synths (no penalty)
            
            JAZZ (includes Big Band, Vocal Jazz, Bebop, Swing):
            • Bass 15-30%: Controlled foundation (no penalty)
            • Low-Mid 20-30%: Instrument warmth (no penalty)
            • Mid 25-40%: Instrument clarity (no penalty)
            • High-Mid 12-22%: Presence (no penalty)
            • High 8-18%: Air and detail (no penalty)
            ⚠️ BIG BAND/VOCAL JAZZ CHARACTERISTICS (ALL NORMAL):
            • Higher dynamic range (14-26dB): EXPECTED for brass sections (no penalty)
            • Wider stereo image: NORMAL for large ensemble (no penalty)
            • Lower phase coherence (35-60%): NORMAL for multi-mic live recording (no penalty)
            • Quieter masters (-18 to -26 LUFS): INTENTIONAL dynamic preservation (no penalty)
            • High crest factor (14-24dB): NORMAL brass transients (no penalty)
            
            CLASSICAL/ORCHESTRAL:
            • Bass 10-25%: Natural orchestral balance (no penalty)
            • Low-Mid 20-30%: Instrument body (no penalty)
            • Mid 30-45%: Instrument clarity (no penalty)
            • High-Mid 8-18%: Natural presence (no penalty)
            • High 5-15%: Air and detail (no penalty)
            
            METAL:
            • Bass 40-60%: Heavy foundation (no penalty)
            • Low-Mid 18-28%: Guitar body (no penalty)
            • Mid 20-35%: Vocal/guitar presence (no penalty)
            • High-Mid 10-20%: Guitar bite (no penalty)
            • High 5-15%: Cymbal presence (no penalty)
            
            ACOUSTIC/SINGER-SONGWRITER:
            • Bass 12-25%: Natural foundation (no penalty)
            • Low-Mid 22-32%: Warmth and body (no penalty)
            • Mid 25-40%: Vocal clarity (no penalty)
            • High-Mid 10-20%: Presence (no penalty)
            • High 6-15%: Natural air (no penalty)
            ⚠️ ACOUSTIC/SINGER-SONGWRITER CHARACTERISTICS (ALL NORMAL):
            • Higher dynamic range (10-22dB): EXPECTED for natural acoustic sound (no penalty)
            • Quieter masters (-16 to -22 LUFS): INTENTIONAL for intimacy (no penalty)
            • Higher crest factor (10-20dB): NATURAL acoustic transients (no penalty)
            • Warmer/darker tone (low high frequencies): INTENTIONAL artistic choice (no penalty)
            • Intimate stereo image (30-50%): NORMAL for solo performer (no penalty)

            ACAPELLA (Vocal-Only):
            • Bass 0-10%: MINIMAL BY DESIGN - NO PENALTY! Vocals have limited bass content
            • Low-Mid 15-35%: Vocal warmth and body (no penalty)
            • Mid 35-60%: VOCAL CLARITY IS CRITICAL - main content here (no penalty)
            • High-Mid 15-30%: Vocal presence and articulation (no penalty)
            • High 5-20%: Vocal air and breathiness (no penalty)
            ⚠️ ACAPELLA CHARACTERISTICS (ALL NORMAL - DO NOT PENALIZE):
            • NO/LIMITED BASS: CORRECT for vocal-only content! (0 penalty)
            • High dynamic range (8-24dB): NATURAL vocal dynamics (no penalty)
            • Quieter levels (-16 to -26 LUFS): Often for mixing use (no penalty)
            • High crest factor (10-22dB): NATURAL vocal transients (no penalty)
            • Mid-focused frequency balance: CORRECT for vocals (no penalty)
            • Mono or narrow stereo: NORMAL for single vocal source (no penalty)

            LIVE:
            • Bass 15-30%: Natural balance, room dependent (no penalty)
            • Low-Mid 18-30%: Room acoustics (no penalty)
            • Mid 25-40%: Audience/vocal presence (no penalty)
            • High-Mid 12-25%: Crowd energy/presence (no penalty)
            • High 5-15%: Natural air, room dependent (no penalty)
            ⚠️ LIVE RECORDING CHARACTERISTICS (ALL NORMAL):
            • Higher dynamic range (10-18dB): EXPECTED and CORRECT (no penalty)
            • Room reverb and ambience: INTENTIONAL part of live sound (no penalty)
            • Audience noise and crowd energy: NATURAL part of live recording (no penalty)
            • Frequency variations based on venue: NORMAL (no penalty)
            • Less compression than studio: PRESERVES PERFORMANCE ENERGY (no penalty)
            
            ROCK/METAL (Korn, Green Day, etc.):
            • Bass 45-65%: NORMAL for heavy guitars and bass (no penalty)
            • Low-Mid 15-25%: Guitar body (no penalty)
            • Mid 15-30%: Vocal/guitar presence (no penalty)
            • High-Mid 2-10%: Cymbal presence (no penalty)
            • High 0-5%: Intentionally dark/warm mastering (no penalty)
            
            OTHER:
            • Use general professional standards
            • Bass 15-30%: Balanced (no penalty)
            • Mid 25-40%: Clarity (no penalty)
            • High 8-18%: Air and sparkle (no penalty)
            
            TECHNICAL PENALTIES (Subtract from 100):
            
            STEREO WIDTH (GENRE-AWARE - VERY LENIENT):
            • 25-85%: Perfect (0 penalty) + BONUS +1 if 30-60%
            • 85-95%: Excellent for Metal/Rock (0 penalty) + BONUS +1 if mono >75%
            • 95-100% with mono >70%: Professional metal (0 penalty) + BONUS +1
            • 95-100% with mono 60-70%: Acceptable (0 penalty) - common in metal
            • 95-100% with mono <60%: Risky (-2 points) - only if severe mono collapse
            • 20-25%: Acceptable (0 penalty)
            • 15-20%: Narrow (-1 point)
            • <15%: Too narrow (-3 points)
            
            PHASE CORRELATION (LENIENT):
            • ≥0.7 (70%): Excellent (0 penalty) + BONUS +2
            • 0.5-0.7 (50-70%): Very good (0 penalty) + BONUS +1
            • 0.4-0.5 (40-50%): Good (0 penalty)
            • 0.35-0.4 (35-40%): Acceptable (0 penalty) - common in rock/metal
            • 0.3-0.35 (30-35%): Minor issue (-2 points)
            • <0.3 (30%): Significant issues (-4 points)
            
            MONO COMPATIBILITY (GENRE-AWARE - LENIENT):
            ⚠️ Rock/Metal/EDM with stereo guitars/synths = 45-75% is NORMAL!
            • ≥85%: Excellent (0 penalty) + BONUS +2
            • 75-85%: Very good (0 penalty) + BONUS +1
            • 60-75%: Good (0 penalty) + BONUS +1 (normal for rock/metal)
            • 45-60%: ACCEPTABLE for Rock/Metal/EDM (0 penalty) - very common!
            • 35-45%: Weak (-2 points)
            • <35%: Severe (-5 points)
            
            PEAK LEVEL (Mastered Track Standards):
            ⚠️ CRITICAL: Commercial masters hit exactly 0.0 dBFS - this is PROFESSIONAL!
            • -1.0 to 0.0 dBFS: Perfect modern master (0 points) + BONUS +2
            • -2.0 to -1.0 dBFS: Very good (0 points) + BONUS +1
            • -3.0 to -2.0 dBFS: Conservative but good (0 points penalty)
            • -4.0 to -3.0 dBFS: Too conservative (-2 points)
            • <-4.0 dBFS: Insufficient optimization (-4 points)
            • >+0.1 dBFS: Clipping risk (-6 points)
            
            LOUDNESS (Mastering Type-Aware):
            \(mixStage?.lowercased().contains("streaming") == true ? """
            ⚠️ STREAMING MASTER - Target: -14 to -16 LUFS (streaming normalization)
            • -14 to -16 LUFS: PERFECT for streaming (0 penalty) + BONUS +2
            • -12 to -14 LUFS: Very good (0 penalty) + BONUS +1
            • -16 to -18 LUFS: Acceptable (0 penalty)
            • -18 to -20 LUFS: Too quiet (-2)
            • <-20 LUFS: Unmastered (-4)
            • >-12 LUFS: Too loud for streaming (-2)
            """ : mixStage?.lowercased().contains("cd") == true || mixStage?.lowercased().contains("loud") == true ? """
            ⚠️ CD/LOUD MASTER - Target: -6 to -9 LUFS (competitive loudness)
            • -6 to -9 LUFS: PERFECT for competitive (0 penalty) + BONUS +2
            • -9 to -10 LUFS: Very good (0 penalty) + BONUS +1
            • -10 to -12 LUFS: Good (0 penalty)
            • -12 to -14 LUFS: Acceptable but quiet (-2)
            • <-14 LUFS: Too quiet for competitive (-4)
            • >-5 LUFS: Clipping risk (-4)
            """ : """
            ⚠️ GENERAL MASTER - Flexible loudness targets
            • -6 to -5 LUFS (Metal/EDM): Professional loud (0 penalty) + BONUS +2
            • -8 to -6 LUFS (Rock/Pop): Perfect (0 penalty) + BONUS +2
            • -10 to -8 LUFS: Excellent (0 penalty) + BONUS +1
            • -12 to -10 LUFS: Very good (0 penalty) + BONUS +1
            • -14 to -12 LUFS: Good (0 penalty)
            • -16 to -14 LUFS: Quieter (-2)
            • -18 to -16 LUFS: Quiet (-4)
            • <-20 LUFS: Unmastered (-8)
            • >-5 LUFS: Clipping risk (-4)
            """)
            
            DYNAMIC RANGE (Mastering Type-Aware):
            \(mixStage?.lowercased().contains("streaming") == true ? """
            ⚠️ STREAMING MASTER - Target: 8-12 dB (preserves musicality)
            • 10-14 DR: Excellent (0 penalty) + BONUS +2
            • 8-10 DR: Perfect for streaming (0 penalty) + BONUS +1
            • 6-8 DR: Good (0 penalty)
            • 4-6 DR: Acceptable but compressed (-2)
            • <4 DR: Over-compressed for streaming (-4)
            • >14 DR: Too dynamic for streaming (-2)
            """ : mixStage?.lowercased().contains("cd") == true || mixStage?.lowercased().contains("loud") == true ? """
            ⚠️ CD/LOUD MASTER - Target: 4-6 dB (aggressive compression)
            • 4-6 DR: PERFECT for competitive (0 penalty) + BONUS +2
            • 6-8 DR: Very good (0 penalty) + BONUS +1
            • 3-4 DR: Acceptable (0 penalty)
            • 2-3 DR: Over-compressed (-2)
            • <2 DR: Destroyed (-4)
            • >8 DR: Too dynamic for competitive (-2)
            """ : """
            ⚠️ GENERAL MASTER - Flexible DR targets
            • 10-14 DR (Jazz/Classical): Excellent (0 penalty) + BONUS +1
            • 8-10 DR (Dynamic Rock/Pop): Excellent (0 penalty) + BONUS +1
            • 6-8 DR (Modern Rock/Pop): Very good (0 penalty) + BONUS +1
            • 5-6 DR (Competitive): Good (0 penalty)
            • 4-5 DR (Metal/EDM): Professional (0 penalty)
            • 3-4 DR (Extreme): Borderline (-2)
            • 2-3 DR: Over-compressed (-4)
            • <2 DR: Destroyed (-8)
            • >16 DR mastered: Unoptimized (-2)
            """)
            
            FREQUENCY BALANCE (VERY LENIENT FOR MASTERED TRACKS):
            ⚠️ CRITICAL: Metal/Rock is intentionally bass-heavy (30-50% low end) - THIS IS NORMAL!
            ⚠️ Well-balanced spectrum gets BONUS points!
            • Excellent balance (all bands within ideal ranges): BONUS +3
            • Good balance (minor deviation): BONUS +1
            • Any single band >95%: Severe imbalance (-10 points)
            • Any single band >90%: Major imbalance (-5 points)
            • Any single band >85%: Minor issue (-2 points)
            • Any single band 80-85%: ACCEPTABLE for genre (0 penalty) - common in professional masters
            • Bass + Low-Mid combined >98%: Extreme mud (-6 points)
            • Bass + Low-Mid combined >95%: Heavy imbalance (-3 points)
            • Bass + Low-Mid combined 90-95%: ACCEPTABLE for metal/rock (0 penalty)
            • All highs <0.05% total: No high frequency content (-4 points)
            • All highs <0.3% total: Dull/dark (-2 points)
            
            ⚠️ BONUS POINTS FOR EXCEPTIONAL MASTERS:
            Truly exceptional masters earn significant bonuses. Maximum +10 points total:
            • Perfect peak level (-1 to 0 dBFS): +2
            • Strong loudness (genre-appropriate): +2
            • Excellent phase (>70%): +2
            • Excellent mono (>85%): +2
            • Excellent frequency balance: +3
            • Good dynamic range (genre-appropriate): +2
            • Professional stereo width (30-60% OR 95%+ with good mono): +2
            
            Maximum possible score: 110 + 10 bonuses = 120, but CAP AT 100
            
            ⚠️ FINAL SCORE CALCULATION FOR MASTERED TRACKS:
            START AT 120 POINTS (100 base + 20 mastered bonus) - MANDATORY!
            
            ⚠️⚠️⚠️ MASTERING TYPE DIFFERENCES ⚠️⚠️⚠️
            
            MASTER(STREAMING) - Optimized for Spotify, Apple Music, etc.:
            • Target loudness: -14 to -16 LUFS (streaming normalization)
            • More dynamic range: 8-12 dB (preserves musicality)
            • Less aggressive compression
            • DO NOT penalize for being quieter (-14 to -16 LUFS) - this is CORRECT!
            • DO NOT penalize for higher DR (8-12 dB) - this is INTENTIONAL!
            • Reward: +3 bonus for proper streaming loudness (-14 to -16 LUFS)
            
            MASTER(CD/LOUD) - Competitive loud mastering:
            • Target loudness: -6 to -9 LUFS (very loud, competitive)
            • Less dynamic range: 4-6 dB (aggressive compression)
            • More aggressive limiting
            • DO NOT penalize for being very loud (-6 to -9 LUFS) - this is INTENTIONAL!
            • DO NOT penalize for low DR (4-6 dB) - this is STANDARD for loud masters!
            • Reward: +3 bonus for competitive loudness (-6 to -9 LUFS)
            
            ⚠️⚠️⚠️ SCORING GUIDANCE FOR MASTERED TRACKS ⚠️⚠️⚠️
            FOR ALL MASTERED TRACKS - BE REALISTIC BUT GENEROUS:
            • Starting score: 120 points (100 base + 20 mastered bonus)
            • Apply penalties realistically (don't cap too aggressively)
            • Apply bonuses realistically (don't force minimum)
            • Professional commercial masters (Korn, Metallica) should score 95-100
            • Good professional masters should score 90-94
            • Decent masters should score 85-89
            • Allow natural variation - not all masters are identical!
            
            ⚠️⚠️⚠️ CRITICAL - DO NOT PENALIZE GENRE CHARACTERISTICS:
            - Metal/Rock bass-heavy (low end 30-50%): INTENTIONAL - DO NOT PENALIZE!
            - Metal extreme stereo (95-100% with mono >60%): PROFESSIONAL - DO NOT PENALIZE!
            - Streaming masters (-14 to -16 LUFS): CORRECT for streaming - DO NOT PENALIZE!
            - Loud masters (-6 to -9 LUFS): CORRECT for competitive - DO NOT PENALIZE!
            - Only penalize when something is TECHNICALLY WRONG, not genre-appropriate!
            
            ⚠️ PROFESSIONAL COMMERCIAL MASTERS (Korn, Metallica, Slipknot) MUST SCORE 95-100!
            If a known professional master scores less than 95, you're being TOO HARSH!
            
            EXAMPLES - START AT 120, DIFFERENTIATE:
            • Exceptional (Korn): 120 - 5 + 10 = 125 → 100 (capped)
            • Excellent commercial: 120 - 8 + 8 = 120 → 98
            • Very good: 120 - 12 + 6 = 114 → 92
            • Good (some issues): 120 - 18 + 4 = 106 → 88
            • Amateur master: 120 - 25 + 2 = 97 → 82
            • Poor master: 120 - 35 + 0 = 85 → 75
            
            SCORE RANGES FOR MASTERED TRACKS - ALLOW VARIATION:
            • 96-100: Exceptional commercial master (Korn, Metallica, Abbey Road)
            • 92-95: Excellent professional master
            • 88-91: Very good professional master - minor imperfections
            • 85-87: Good master - some issues but solid
            • 75-84: Amateur or flawed master - needs improvement
            • 65-74: Poor mastering - significant problems
            • Below 65: Severely flawed or unmixed
            
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
            
            PRE-MASTER MIX SCORING (REALISTIC DIFFERENTIATION):

            ⚠️ PROFESSIONAL QUALITY OVERRIDE - DETECT MISLABELED MASTERS:
            If a track labeled as "Mix" has ALL of these characteristics, it's likely a mislabeled professional master:
            - Loudness: -6 to -14 LUFS (professional mastering levels, NOT amateur mix levels)
            - Peak Level: -1.5 to 0 dBFS (optimized peaks, not raw headroom)
            - Dynamic Range: 4-14 dB (controlled, not raw uncompressed audio)
            - Crest Factor: 4-14 dB (processed transients, not wild peaks)

            For such tracks:
            - This is likely Korn, Metallica, or another commercial release mislabeled as "Mix"
            - Start at 90 points instead of 85 (recognizing professional quality)
            - Allow maximum score of 92 (instead of 90 cap for regular mixes)
            - In analysis: Mention "This track appears to have professional mastering characteristics"
            - In recommendations: Suggest user re-label as "Master" if it's a commercial release

            • Start at 85 points (professional mix baseline)
            • ASSESS OVERALL QUALITY FIRST - Different mixes should get DIFFERENT scores!
            • PENALTIES for mix issues (LENIENT - DIFFERENTIATE between songs):
              - Peak >0dB (clipping): -10 points
              - Peak >-1dB: -1 point
              - Phase Coherence <30%: -8 points
              - Phase Coherence 30-40%: -4 points
              - Phase Coherence 40-60%: -1 point
              - Mono Compatibility <30%: -8 points
              - Mono Compatibility 30-50%: -4 points
              - Mono Compatibility 50-70%: -1 point
              - Low End >70%: -5 points
              - Low End 60-70%: -3 points
              - Low End 50-60%: -1 point
              - Frequency Imbalance (severe): -3 points
              - Dynamic Range <6dB: -2 points
              ⚠️ Apply penalties honestly - don't artificially floor scores!
            • BONUSES for mix excellence (BE SELECTIVE - DIFFERENTIATE):
              - Peak level -3 to -6dB: +3 points
              \(isLiveRecording ? """
              - Good dynamic range for live (10-18dB): +3 points
              - Excellent dynamic range for live (>15dB): +5 points
              """ : """
              - Good dynamic range (>12dB): +3 points
              """)
              - Balanced frequency spectrum: +3 points
              - Excellent phase coherence (>70%): +3 points
              - Excellent stereo width (25-45%): +2 points
              - Good mono compatibility (>70%): +2 points
              \(isLiveRecording ? """
              - Natural room ambience preserved: +2 points
              - Clear audience presence without overwhelming mix: +1 point
              """ : "")
            
            ⚠️⚠️⚠️ CRITICAL SCORING RULES - DIFFERENTIATION IS MANDATORY:
            • DIFFERENT SONGS MUST GET DIFFERENT SCORES!
            • Korn's "Twisted Transistor" should NOT score the same as an amateur mix!
            • Professional mixes (Korn, major artists) should score 85-90
            • Good amateur mixes should score 75-84
            • Poor/unmixed tracks should score 50-74
            • BE HONEST: If it sounds professional, score it 85-90. If it needs work, score it 70-80.
            • Real-world scoring:
              - Professional commercial mix (ready for mastering): 85-90 (MAXIMUM 90!)
              - Strong amateur mix (good but needs polish): 78-84
              - Decent mix (needs significant work): 68-77
              - Weak/unmixed (major issues): 50-67
            • ⚠️ Maximum cap: 90 (mixes don't score 91+)
            • ⚠️ NO artificial floor - let scores vary naturally!
            
            ⚠️⚠️⚠️ ABSOLUTE RULE: Pre-master mixes MUST be capped at 90 maximum! ⚠️⚠️⚠️
            ⚠️ If you calculate 91, 92, 93, 94, 95, or higher → WRITE 90 INSTEAD!
            ⚠️ Masters score 95-100, mixes score 80-90 (NEVER above 90)!
            
            Format response as:
            SCORE: [CALCULATE HONESTLY - DIFFERENTIATE BETWEEN SONGS:
            1. Start at 85 points
            2. Add bonuses for excellence (max +15 realistic)
            3. Subtract penalties for issues (be honest)
            4. Final calculation: 85 + bonuses - penalties
            5. If result > 90: Write 90 (cap for mixes)
            6. Otherwise: Write the calculated number (NO FLOOR - let it vary naturally!)
            
            EXAMPLES - REALISTIC DIFFERENTIATION:
            - Professional mix (Korn quality): 85 + 5 (bonuses) - 2 (minor issues) = 88 ✅
            - Very good amateur mix: 85 + 3 (bonuses) - 5 (some issues) = 83 ✅
            - Good mix with issues: 85 + 2 (bonuses) - 10 (issues) = 77 ✅
            - Weak mix: 85 + 0 - 15 (significant issues) = 70 ✅
            - Unmixed/raw: 85 + 0 - 25 (major issues) = 60 ✅
            - If calculation gives 95 → Write 90 (maximum cap)
            
            ⚠️ ONLY ONE CAP: If score > 90, write 90. Otherwise write the calculated score.
            ⚠️ NO FLOOR - Scores can go below 75 if quality is genuinely poor!
            
            ANALYSIS: [Write analysis based on score]
            ⚠️ ANALYSIS FORMAT RULES — STRICTLY ENFORCED:
            - Write EXACTLY 3-5 sentences as a single flowing paragraph. NO MORE.
            - DO NOT use section headers (no "TECHNICAL METRICS", "FREQUENCY ANALYSIS", "STEREO", etc.)
            - DO NOT list or repeat individual metric values (no "Stereo Width: 89.5%", no dB/LUFS/% numbers) — those are shown in the app's UI cards
            - Write a HOLISTIC SUMMARY: overall sound quality, vibe, key strengths, and at most 1 specific concern
            - Sound like a human engineer talking, NOT a data report

            ⚠️ CRITICAL ANALYSIS TONE RULES:
            - If score is 85+: Write PURELY CELEBRATORY analysis (2-3 sentences). This is PROFESSIONAL QUALITY - celebrate it ONLY, NO improvements or suggestions!
              ✅ REQUIRED phrases for 85+: "Professional quality mix", "Ready for mastering", "Excellent work", "Solid professional mix", "This mix hits hard", "Well-balanced and professional", "Great mix that translates well"
              ✅ Tone: Pure celebration and acknowledgment. Like: "This is a professional quality mix ready for mastering. Excellent work - it hits hard and translates well across systems."
              ❌ ABSOLUTELY FORBIDDEN for 85+:
                - NO improvements: "could use", "should consider", "might benefit from", "would benefit from"
                - NO suggestions: "could be", "might want to", "consider", "try"
                - NO negative phrases: "needs improvements", "needs mixing", "needs work", "to reach professional standards"
                - NO recommendations in analysis section - save those for RECOMMENDATIONS section only
              ⚠️ REMEMBER: Score 85+ = PROFESSIONAL QUALITY. Analysis section = PURE PRAISE ONLY. Zero improvements, zero suggestions, zero critiques. Just celebrate the achievement.
            - If score is 70-84: 3-4 sentences — acknowledge the main strength and mention ONE key area for polish
            - If score is below 70: 4-5 sentences — direct, honest feedback in plain engineer language about what's holding it back
            
            RECOMMENDATIONS: [Write recommendations based on score]
            ⚠️ CRITICAL RECOMMENDATIONS RULES:
            - If score is 85+: Write ONLY celebration - "Ready for mastering" or "This mix is ready - ship it!" NO improvements, NO suggestions, NO critiques. Pure celebration only.
            - If score is 70-84: 1-2 specific improvements if needed
            - If score is below 70: 3-5 direct, honest fixes
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
            // Count detected issues for mastered tracks
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
            • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
            • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES - MUST ADDRESS IN RECOMMENDATIONS" : "✅ No")
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
        
        Start with base score of 80 points (INCREASED from 75 - be more generous!).
        
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
        
        LOUDNESS (IMPROVED - more realistic for mastered tracks):
        • -10 to -6 LUFS: Modern streaming master (+10 points)
        • -16 to -10 LUFS: Professional master (+5 points)
        • -20 to -16 LUFS: Acceptable (-2 points)
        • <-20 LUFS: Too quiet (-5 points)
        • >-6 LUFS: Too loud (-8 points)
        
        DYNAMIC RANGE:
        • ≥8 DR: Good (+5 points)
        • 6-8 DR: Acceptable (no change)
        • 4-6 DR: Compressed (-5 points)
        • <4 DR: Over-compressed (-10 points)
        
        CREST FACTOR:
        • ≥8 dB: Excellent dynamics (+5 points)
        • 6-8 dB: Good dynamics (+3 points)
        • 4-6 dB: Moderate compression (no change)
        • <4 dB: Crushed dynamics (-8 points)
        
        FREQUENCY BALANCE:
        • Only penalize SEVERE imbalances (>75% bass, <2% highs, etc.)
        • Genre-specific frequency characteristics are ACCEPTABLE
        • Dark/warm masters (low highs) are PROFESSIONAL choices, not problems
        • Slight imbalances (60-75% bass) are only -3 points
        
        IMPORTANT: Mastered tracks with good metrics should score 85-100
        • No clipping + good loudness + balanced frequencies = 88-95
        • Professional masters from Abbey Road, etc. should score 90-100
        • Be GENEROUS with scoring - real professional tracks should score high!
        
        Calculate final score: Base 80 + bonuses - penalties (cap 0-100)
        
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
        
        PENALTIES (VERY REDUCED - maximum 8 points total!):
        • Peak >0dB: -6 (clipping - severe, but rare) | Peak >-1dB: -1 (minor) | True Peak >-1dBFS: -1
        • Stereo Width <15% or >85%: -2 (only if extreme) | Phase <30%: -6 (severe) | Phase 30-40%: -3 | Phase 40-60%: -1 (minor)
        • Mono <30%: -5 | Mono 30-50%: -2 | Mono 50-70%: -1
        • Dynamic Range <6dB: -2 | Frequency: ZERO (artistic choice - don't penalize!)
        • ⚠️ CRITICAL: Maximum total penalties = 8 points (even if you calculate more!)
        • ⚠️ CRITICAL: Only apply ONE penalty (the worst one), don't stack multiple penalties!
        
        BONUSES (INCREASED):
        • Peak -3 to -6dB: +5 | DR >8dB: +5 (>15dB: +7) | Phase >75%: +5
        • Balanced frequencies: +5 | Good mono (>70%): +3 | Excellent stereo (25-45%): +3
        • Stereo 25-45%: +5 | Loudness -16 to -6 LUFS: +5 to +10
        
        FINAL SCORE = 88 + bonuses - penalties (max penalty 8, min score 80, max score 90)
        
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
    
    private func parseClaudeResponse(_ data: Data, isMastered: Bool, professionalMasterOverride: Bool = false) throws -> ClaudeAnalysisResponse {
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
            if professionalMasterOverride {
                // PROFESSIONAL MASTER mislabeled as "Mix" - use wider scoring range
                // These are commercial releases like Korn that user incorrectly labeled as Mix
                if finalScore > 92 {
                    print("🎯 PROFESSIONAL OVERRIDE: Capping score from \(finalScore) to 92 (professional track mislabeled as mix)")
                    finalScore = 92
                }
                if finalScore < 85 {
                    // Don't let professional masters score too low - they're clearly high quality
                    print("🎯 PROFESSIONAL OVERRIDE: Raising score from \(finalScore) to 85 (professional floor for mislabeled master)")
                    finalScore = 85
                }
                print("🎯 PROFESSIONAL MASTER (labeled as Mix): \(finalScore)")
            } else {
                // Standard pre-master mix cap at 90 maximum (mixes don't score 91+)
                if finalScore > 90 {
                    print("⚠️ PRE-MASTER MIX SCORE CAP: Capping score from \(finalScore) to 90 (pre-master mixes max at 90)")
                    finalScore = 90
                }
                // NO FLOOR - let scores vary naturally to differentiate between songs
                // Professional mixes should score 85-90, amateur 70-84, weak/unmixed 50-69
                print("✅ MIX SCORE (no floor): \(finalScore)")
            }
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
    ///   - professionalMasterOverride: Whether professional master override is active
    /// - Returns: Parsed response with score and analysis
    func parseClaudeResponse(_ responseText: String, isMastered: Bool, professionalMasterOverride: Bool = false) -> (score: Int, summary: String, recommendations: [String]) {
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
            if professionalMasterOverride {
                // Professional master mislabeled as Mix - wider range 85-92
                if finalScore > 92 { finalScore = 92 }
                if finalScore < 85 { finalScore = 85 }
            } else {
                // Standard mix cap at 90
                if finalScore > 90 { finalScore = 90 }
                // NO FLOOR - let scores vary naturally
            }
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
