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
            return trimmedKey
        } else {
            return "missing-api-key"
        }
    }
    
    /// Send audio analysis metrics to Claude and get AI insights
    func analyzeAudioMetrics(_ metrics: AudioMetricsForClaude) async throws -> ClaudeAnalysisResponse {
        
        // DEBUG: Print actual values being sent to Claude
        print("🎵 FREQUENCY DATA SENT TO CLAUDE:")
        print("  Low End: \(String(format: "%.1f", metrics.lowEnd))%")
        print("  Low Mid: \(String(format: "%.1f", metrics.lowMid))%")
        print("  Mid: \(String(format: "%.1f", metrics.mid))%")
        print("  High Mid: \(String(format: "%.1f", metrics.highMid))%")
        print("  High: \(String(format: "%.1f", metrics.high))%")
        
        // Detect track type and genre
        let isMastered = detectMasteredTrack(metrics)
        let genre = detectGenre(metrics)
        let isUnmixed = metrics.isLikelyUnmixed
        
        print("🏷️ DETECTED: isMastered=\(isMastered), genre=\(genre), isUnmixed=\(isUnmixed)")
        
        // Check if track was flagged as unmixed by AudioKit detection
        if metrics.isLikelyUnmixed {
            print("🚨 UNMIXED TRACK DETECTED - Using unmixed scoring rules")
            print("  Mixing Quality Score: \(String(format: "%.1f", metrics.mixingQualityScore))%")
        }
        
        // Get separated prompts for caching
        // CACHE VERSION: Update this number when scoring rules change to bust the cache
        let cacheVersion = "v8.0-STRICTER-PENALTIES-BONUSES"  // Stricter penalties + bonus points for exceptional masters
        let systemPrompt = getSystemPrompt(isMastered: isMastered, isUnmixed: isUnmixed) + "\n\n[Scoring Rules Version: \(cacheVersion)]"
        let userMessage = getUserMessage(metrics: metrics, genre: genre, isMastered: isMastered)
        
        let requestBody: [String: Any] = [
            "model": determineModel(isProUser: metrics.isProUser),
            "max_tokens": 1000,
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
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
    
    private func getSystemPrompt(isMastered: Bool, isUnmixed: Bool) -> String {
        // UNMIXED TRACKS - completely different scoring approach
        if isUnmixed {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:
            In the ANALYSIS and RECOMMENDATIONS sections:
            - Use CONVERSATIONAL, SIMPLE language
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - Describe what you HEAR in plain terms (muddy, clear, bright, dark, balanced, imbalanced, etc.)
            - Keep recommendations actionable but non-technical (e.g., "Needs more clarity in the low end" instead of "Reduce 200Hz by 3dB")
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
            
            RESPONSE FORMAT - Use this exact structure:
            
            SCORE: [60-75]
            
            ANALYSIS: Start with "This is an unmixed track that needs professional mixing and mastering." Then in 2-3 brief sentences, describe the main sonic character: Is it muddy, harsh, thin, or unbalanced? What's the overall impression? Keep it simple and conversational without numbers or technical values.
            
            RECOMMENDATIONS:
            - [Describe what needs improvement in plain language, e.g., "Needs better balance between instruments" instead of "Reduce bass by 3dB"]
            - [Focus on the most important mixing needs without technical numbers]
            - [Keep it brief and actionable]
            - [Maximum 3-4 recommendations]
            
            Keep the ANALYSIS brief (2-4 sentences). Make RECOMMENDATIONS simple and conversational without numbers or percentages.
            """
        } else if isMastered {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:
            In the ANALYSIS and RECOMMENDATIONS sections:
            - Use CONVERSATIONAL, SIMPLE language
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - Describe what you HEAR in plain terms (muddy, clear, bright, dark, punchy, compressed, etc.)
            - Keep recommendations simple and actionable without technical jargon
            - The scoring details below are for YOUR calculation only - do NOT expose them to the user
            
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
            
            ⚠️ SCORING PHILOSOPHY FOR MASTERED TRACKS:
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
            
            ROCK/METAL (Korn, Green Day, etc.):
            • Bass 45-65%: NORMAL for heavy guitars and bass (no penalty)
            • Low-Mid 15-25%: Guitar body (no penalty)
            • Mid 15-30%: Vocal/guitar presence (no penalty)
            • High-Mid 2-10%: Cymbal presence (no penalty)
            • High 0-5%: Intentionally dark/warm mastering (no penalty)
            
            ELECTRONIC/EDM:
            • Bass 50-70%: NORMAL for bass-heavy genres (no penalty)
            • High 5-20%: Synthetic sparkle (no penalty)
            
            HIP-HOP:
            • Bass 40-60%: NORMAL for 808s and sub-bass (no penalty)
            • High 0-8%: Intentionally warm/dark (no penalty)
            
            POP:
            • Bass 20-40%: Balanced (no penalty)
            • High 5-15%: Bright and airy (no penalty)
            
            TECHNICAL PENALTIES (Subtract from 100):
            
            STEREO WIDTH:
            • 25-85%: Perfect (0 points penalty) + BONUS +2 if 30-60%
            • 20-25% OR 85-90%: Acceptable (-1 point)
            • 15-20% OR 90-95%: Minor issue (-3 points)
            • <15% OR >95%: Problem (-6 points)
            
            PHASE CORRELATION:
            • ≥0.7 (70%): Excellent (0 points) + BONUS +2
            • 0.5-0.7 (50-70%): Very good (0 points) + BONUS +1
            • 0.4-0.5 (40-50%): Good (0 points penalty)
            • 0.35-0.4 (35-40%): Acceptable for Rock/Metal (-1 point)
            • 0.3-0.35 (30-35%): Minor issue (-3 points)
            • <0.3 (30%): Significant issues (-6 points)
            
            MONO COMPATIBILITY (GENRE-AWARE - STRICTER):
            ⚠️ Rock/Metal/EDM with stereo guitars/synths = 45-75% is NORMAL!
            • ≥85%: Excellent (0 points) + BONUS +2
            • 75-85%: Very good (0 points) + BONUS +1
            • 60-75%: Good (0 points penalty)
            • 45-60%: ACCEPTABLE for Rock/Metal/EDM (-1 point)
            • 35-45%: Weak (-4 points)
            • <35%: Severe (-8 points)
            
            PEAK LEVEL (Mastered Track Standards):
            ⚠️ CRITICAL: Commercial masters hit exactly 0.0 dBFS - this is PROFESSIONAL!
            • -1.0 to 0.0 dBFS: Perfect modern master (0 points) + BONUS +2
            • -2.0 to -1.0 dBFS: Very good (0 points) + BONUS +1
            • -3.0 to -2.0 dBFS: Conservative but good (0 points penalty)
            • -4.0 to -3.0 dBFS: Too conservative (-2 points)
            • <-4.0 dBFS: Insufficient optimization (-4 points)
            • >+0.1 dBFS: Clipping risk (-6 points)
            
            LOUDNESS (Genre-Aware - STRICTER):
            • -8 to -6 LUFS (Modern Rock/Pop/EDM): Perfect (0 points) + BONUS +3
            • -10 to -8 LUFS (Strong modern master): Excellent (0 points) + BONUS +2
            • -12 to -10 LUFS (Balanced master): Very good (0 points) + BONUS +1
            • -14 to -12 LUFS: Good (0 points penalty)
            • -16 to -14 LUFS: Acceptable (-1 point)
            • -20 to -16 LUFS: Conservative (-3 points)
            • <-20 LUFS: Too quiet (-5 points)
            • >-6 LUFS: Extremely loud (-4 points)
            
            DYNAMIC RANGE (Genre-Aware - STRICTER):
            • 8-12 DR (Rock/Pop with dynamics): Excellent (0 points) + BONUS +2
            • 6-8 DR (Modern Rock/Pop): Very good (0 points) + BONUS +1
            • 5-6 DR (Competitive master): Good (0 points penalty)
            • 4-5 DR (EDM/Modern): Acceptable for genre (-1 point)
            • 3-4 DR: Over-compressed (-3 points)
            • <3 DR: Severely crushed (-6 points)
            • >15 DR for mastered track: Unoptimized (-2 points)
            
            FREQUENCY BALANCE (STRICTER):
            ⚠️ Well-balanced spectrum gets BONUS points!
            • Excellent balance (all bands within ideal ranges): BONUS +3
            • Good balance (minor deviation): BONUS +1
            • Any single band >85%: Severe imbalance (-10 points)
            • Any single band >80%: Major imbalance (-6 points)
            • Bass + Low-Mid combined >90%: Extreme mud (-6 points)
            • Bass + Low-Mid combined >85%: Heavy imbalance (-3 points)
            • All highs <0.1% total: No high frequency content (-4 points)
            • All highs <0.5% total: Dull/dark (-2 points)
            
            ⚠️ BONUS POINTS FOR EXCEPTIONAL MASTERS (NEW):
            Commercial reference-quality masters can earn up to +12 bonus points:
            • Perfect peak level (-1 to 0 dBFS): +2
            • Strong loudness (-8 to -6 LUFS): +3
            • Excellent phase (>70%): +2
            • Excellent mono (>85%): +2
            • Excellent balance (all bands ideal): +3
            • Good dynamic range (6-12 DR): +2
            • Excellent stereo width (30-60%): +2
            
            Maximum possible score: 100 + 12 bonuses = 112, but CAP AT 100
            
            ⚠️ FINAL SCORE CALCULATION FOR MASTERED TRACKS:
            1. Start: 100 points
            2. Subtract technical penalties (now -1 to -15 points for typical tracks)
            3. Add bonus points for exceptional qualities (0 to +12 points)
            4. Cap final score at 100
            5. Commercial masters like Korn: 100 - 2 (minor penalties) + 10 (bonuses) = 100 (capped)
            6. Good amateur masters: 100 - 8 (penalties) + 3 (bonuses) = 95
            7. Decent masters with issues: 100 - 12 (penalties) + 0 (bonuses) = 88
            
            SCORE RANGES FOR MASTERED TRACKS:
            • 98-100: Reference-quality professional master (Korn, major label releases)
            • 95-97: Excellent commercial master with minor room for improvement
            • 92-94: Very good commercial master
            • 88-91: Good master with some technical issues
            • 85-87: Adequate master with notable issues
            • Below 85: Significant technical problems present
            
            📝 RESPONSE FORMAT (CRITICAL - FOLLOW EXACTLY):
            
            SCORE: [CALCULATE: 100 - technical_penalties, minimum 85 for mastered tracks]
            
            Example for Korn/Green Day mastered track:
            - Starting: 100 points
            - Phase 35.7%: -0 points (acceptable for Rock with stereo guitars)
            - Peak 0.0 dBFS: -0 points (professional standard)
            - Mono 44.8%: -0 points (normal for Rock with stereo content)
            - Bass 54.5%: -0 points (normal for Rock/Metal genre)
            - Total: 100 - 0 = 100 points (or 98 if being strict on phase)
            
            ANALYSIS: [2-3 sentences describing technical quality based on the core metrics]
            
            RECOMMENDATIONS: [List specific fixes for any threshold violations - use bullet points (•), NOT numbered lists. If no recommendations, write "Ready for distribution" or similar positive message]
            
            READY FOR MASTERING: [yes/no - based on whether all critical thresholds are met]
            """
        } else {
            return """
            ⚠️ CRITICAL RESPONSE STYLE REQUIREMENT:
            In the ANALYSIS and RECOMMENDATIONS sections:
            - Use CONVERSATIONAL, SIMPLE language
            - DO NOT mention specific numbers, dB values, percentages, frequencies, LUFS, points, penalties, or bonuses
            - Describe what you HEAR in plain terms (muddy, clear, bright, dark, balanced, professional, amateur, etc.)
            - Keep recommendations actionable but simple without technical numbers
            - The scoring details below are for YOUR calculation only - do NOT expose them to the user
            
            You are analyzing a PRE-MASTERED MIX using professional mixing standards. This is NOT a final master.
            
            🎯 PRE-MASTER MIX ANALYSIS - Use MIXING STANDARDS:
            
            🎚️ PRE-MASTER LEVELS & DYNAMICS:
            • Peak Level (MIX TARGET: -3 to -6dB, GOOD: -3 to -8dB)
            • RMS Level (MIX TARGET: -12 to -18dB, GOOD: -10 to -22dB)
            • Loudness (MIX TARGET: -16 to -23 LUFS, GOOD: -14 to -30)
            • Dynamic Range (EXCELLENT: >15dB, GOOD: 8-15dB, POOR: <6dB)
            • True Peak (MIX: <-3dBFS Good, <-1dBFS Acceptable)
            
            🎭 STEREO & PHASE:
            • Stereo Width (Excellent: 25-45%, Good: 20-55%, Wide: 55-85%)
            • Phase Coherence (Excellent: >75%, Good: >60%, Acceptable: 40-60%, Poor: <30%)
            • Mono Compatibility (Good: >70%, Acceptable: >50%)
            
            🎵 FREQUENCY BALANCE (Professional Standards):
            • Low End (20-200Hz):
              - EXCELLENT: 15-25% (controlled, tight)
              - GOOD: 12-30% (balanced foundation)
              - ACCEPTABLE: 10-35% (workable)
              - PROBLEMATIC: >40% (muddy) or <8% (thin)
              
            • Low Mid (200-800Hz):
              - EXCELLENT: 18-28% (warmth without mud)
              - GOOD: 15-32% (body and fullness)
              - ACCEPTABLE: 12-38% (reasonable warmth)
              - PROBLEMATIC: >45% (boxy/muddy) or <10% (hollow)
              
            • Mid (800Hz-3kHz):
              - EXCELLENT: 25-35% (vocal clarity zone)
              - GOOD: 22-40% (presence and definition)
              - ACCEPTABLE: 18-45% (sufficient clarity)
              - PROBLEMATIC: >50% (harsh/forward) or <15% (dull/distant)
              
            • High Mid (3-8kHz):
              - EXCELLENT: 12-22% (presence without harshness)
              - GOOD: 10-28% (articulation and bite)
              - ACCEPTABLE: 8-32% (adequate presence)
              - PROBLEMATIC: >35% (sibilant/harsh) or <5% (dull/muffled)
              
            • High (8-20kHz):
              - EXCELLENT: 8-18% (air and sparkle)
              - GOOD: 6-22% (brightness and detail)
              - ACCEPTABLE: 4-25% (sufficient air)
              - PROBLEMATIC: >30% (sibilant/brittle) or <3% (dull/dark)
            
            📊 FREQUENCY BALANCE ANALYSIS:
            - Pop/Rock Standard: Low 15-25%, LowMid 20-30%, Mid 25-35%, HighMid 12-22%, High 8-18%
            - Electronic Standard: Low 20-30%, LowMid 15-25%, Mid 20-30%, HighMid 15-25%, High 10-20%
            - Acoustic Standard: Low 12-22%, LowMid 22-32%, Mid 25-40%, HighMid 10-20%, High 6-15%
            - Classical Standard: Low 10-20%, LowMid 20-30%, Mid 30-45%, HighMid 8-18%, High 5-12%
            
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
              - Mono Compatibility <30%: -20 points (severe mono collapse)
              - Mono Compatibility 30-50%: -15 points (poor mono translation)
              - Mono Compatibility 50-70%: -8 points (weak mono compatibility)
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
            • Be REALISTIC for PRE-MASTERS:
              - Excellent mix ready for mastering: 85-100 points
              - Good mix ready for mastering: 75-84 points
              - Decent mix needing work: 65-74 points
              - Poor/amateur mix: 40-64 points
            
            Format response as:
            SCORE: [realistic 0-100 score for PRE-MASTER MIX]
            ANALYSIS: [2-3 sentences explaining the mix quality and readiness for mastering]
            RECOMMENDATIONS: [Specific mixing improvements, or "Ready for mastering" if excellent]
            """
        }
    }
    
    private func getUserMessage(metrics: AudioMetricsForClaude, genre: String, isMastered: Bool) -> String {
        if isMastered {
            return """
            Analyze this MASTERED TRACK.
            Genre: \(genre)
            
            🎚️ STEREO WIDTH: \(String(format: "%.1f", metrics.stereoWidth))%
            🎭 PHASE CORRELATION: \(String(format: "%.1f", metrics.phaseCoherence * 100))%
            🔊 MONO COMPATIBILITY: \(String(format: "%.1f", metrics.monoCompatibility * 100))%
            📊 PEAK LEVEL: \(String(format: "%.1f", metrics.peakLevel)) dBFS
            📈 RMS/LOUDNESS: \(String(format: "%.1f", metrics.loudness)) LUFS
            🎚️ DYNAMIC RANGE: \(String(format: "%.1f", metrics.dynamicRange)) dB
            📉 CREST FACTOR: \(String(format: "%.1f", metrics.truePeakLevel - metrics.rmsLevel)) dB
            
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
            """
        } else {
            return """
            Analyze this PRE-MASTERED MIX.
            Genre: \(genre)
            
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
            • Low End (20-200Hz): \(String(format: "%.1f", metrics.lowEnd))%
            • Low Mid (200-800Hz): \(String(format: "%.1f", metrics.lowMid))%
            • Mid (800Hz-3kHz): \(String(format: "%.1f", metrics.mid))%
            • High Mid (3-8kHz): \(String(format: "%.1f", metrics.highMid))%
            • High (8-20kHz): \(String(format: "%.1f", metrics.high))%
            
            🚨 PRE-MASTER MIX ISSUES:
            • Clipping: \(metrics.hasClipping ? "❌ YES" : "✅ No")
            • Phase Issues: \(metrics.hasPhaseIssues ? "❌ YES" : "✅ No")
            • Stereo Issues: \(metrics.hasStereoIssues ? "❌ YES" : "✅ No")
            • Frequency Imbalance: \(metrics.hasFrequencyImbalance ? "❌ YES" : "✅ No")
            • Dynamic Range Issues: \(metrics.hasDynamicRangeIssues ? "❌ YES" : "✅ No")
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
        
        PRE-MASTER MIX SCORING (UPDATED NOVEMBER 2025):
        
        ⚠️ CRITICAL: Start at 85 points (MANDATORY BASE - do NOT use 75 or 80!)
        
        SCORING PHILOSOPHY: 
        • Be EXTREMELY GENEROUS with scoring
        • Score based on TECHNICAL QUALITY ONLY (peaks, phase, dynamics, loudness)
        • Frequency distribution is ARTISTIC, not technical - DO NOT penalize it
        • Good technical metrics = 90-95 score, regardless of frequency balance
        
        • PENALTIES (ONLY for severe TECHNICAL issues):
          - Peak >0dB: -10 points ONLY (clipping - technical problem)
          - Peak >-1dB: -2 points ONLY (insufficient headroom - technical)
          - True Peak >-1dBFS: -2 points ONLY (technical)
          - Stereo Width <15% OR >85%: -2 points ONLY (technical)
          - Phase Coherence <30%: -8 points ONLY (severe technical issue)
          - Phase Coherence 30-40%: -4 points ONLY (significant technical issue)
          - Phase Coherence 40-60%: -1 point ONLY (minor, common)
          - Dynamic Range <6dB: -5 points ONLY (technical issue)
          - Frequency: ZERO PENALTY (artistic choice, not technical)
          
        • BONUSES (reward technical excellence):
          - Peak level -3 to -6dB: +5 points (perfect headroom)
          - Good dynamic range (>8dB): +5 points (>15dB: +10 points)
          - Excellent phase coherence (>75%): +5 points
          - Excellent stereo width (25-45%): +5 points
          - Professional loudness (-16 to -6 LUFS): +5 to +10 points
        
        ⚠️ SCORING GUIDANCE (MANDATORY):
        • Base 85 + bonuses - penalties = Final Score
        • Good technical metrics (like -12 LUFS, 9dB DR, good phase) = 90-95 score
        • Frequency distribution is NOT a scoring factor
        • Only mention frequency in recommendations if genuinely concerning
        
        SCORE RANGES (FOLLOW THESE EXACTLY):
        • 92-100: Exceptional - All technical metrics excellent
        • 88-91: Excellent - Most technical metrics very good
        • 85-87: Good quality - Solid technical fundamentals
        • 80-84: Decent - Some technical improvements needed
        • Below 80: Needs technical work
        
        EXAMPLE SCORING:
        • Professional loudness + excellent dynamics + good phase + safe peaks = 90-95
        • Good loudness + decent dynamics + acceptable phase = 85-90
        • Issues with peaks or phase or dynamics = 75-84
        
        Be REALISTIC for PRE-MASTERS:
        • Excellent mix ready for mastering: 90-100 points
        • Good mix ready for mastering: 85-89 points
        • Decent mix needing minor work: 75-84 points
        • Needs improvement: 60-74 points
        
        Format response as (FOLLOW EXACTLY):
        SCORE: [realistic 0-100 score for PRE-MASTER MIX]
        
        ANALYSIS: Describe the overall sonic quality in 2-4 sentences. Is it muddy or clear? Balanced or imbalanced? Bright or dark? Professional or amateur? Focus on what you HEAR - the overall sound and feeling. Do NOT mention specific dB values, percentages, points, penalties, or technical numbers.
        
        RECOMMENDATIONS:
        - [If the mix is good, simply say "This mix sounds good and is ready for mastering" or similar]
        - [If there are issues, describe what needs improvement in plain language: e.g., "The mix could use more clarity in the low end" instead of "Cut 200Hz by 3dB"]
        - [Keep it conversational and simple - no numbers, no technical jargon]
        - [Use dash (-) for bullet points, NOT numbers]
        - [Maximum 3-4 recommendations]
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
    
    private func parseClaudeResponse(_ data: Data) throws -> ClaudeAnalysisResponse {
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
                }
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
                    } else if !trimmedLine.hasPrefix("---") && !trimmedLine.hasPrefix("===") {
                        // Skip separator lines, add everything else to analysis
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
        print("  Analysis: \(finalAnalysis)")
        print("  Recommendations count: \(recommendations.count)")
        for (i, rec) in recommendations.enumerated() {
            print("    \(i+1). \(rec)")
        }
        
        // Determine if ready for mastering: few or no recommendations AND good score
        let isReadyForMastering = recommendations.count <= 2 && (score ?? 0) >= 75
        
        return ClaudeAnalysisResponse(
            score: score ?? 50,
            summary: finalAnalysis,
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
