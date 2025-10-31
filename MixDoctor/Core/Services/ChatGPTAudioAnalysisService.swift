//
//  ChatGPTAudioAnalysisService.swift
//  MixDoctor
//
//  Service for analyzing audio directly with ChatGPT using native audio input
//

import Foundation
import AVFoundation

/// Stem-based metrics for enhanced analysis
public struct StemMetrics {
    // Stem levels (0-1)
    public let vocalsLevel: Float
    public let drumsLevel: Float
    public let bassLevel: Float
    public let otherLevel: Float
    
    // Mix characteristics
    public let mixDepth: Float              // 0-1, front-to-back dimension
    public let foregroundClarity: Float     // 0-1, lead element clarity
    public let elementSeparation: Float     // 0-1, how distinct elements are
    public let frequencyMasking: Float      // 0-1, overlap (lower is better)
    public let mixDensity: Float            // 0-1, how full the mix is
    
    // Stereo width per stem
    public let vocalsStereoWidth: Float     // 0-1
    public let drumsStereoWidth: Float      // 0-1
    public let bassStereoWidth: Float       // 0-1
    
    // Spatial placement
    public let vocalsPlacement: String
    public let drumsPlacement: String
    public let bassPlacement: String
    
    // Balance ratios
    public let vocalsToInstrumentsRatio: Float  // dB
    public let drumsToMixRatio: Float          // 0-1
    public let bassToMixRatio: Float           // 0-1
    
    // Mixing effects detection (CRITICAL for unmixed detection)
    public let hasCompression: Bool            // Compression detected
    public let compressionAmount: Float        // 0-1, how much compression
    public let hasReverb: Bool                 // Reverb/delay detected
    public let reverbAmount: Float             // 0-1, how much reverb
    public let hasStereoProcessing: Bool       // Stereo enhancement detected
    public let stereoEnhancement: Float        // 0-1, stereo processing amount
    public let hasEQ: Bool                     // EQ/frequency shaping detected
    public let eqBalance: Float                // 0-1, frequency balance quality
    
    public init(
        vocalsLevel: Float,
        drumsLevel: Float,
        bassLevel: Float,
        otherLevel: Float,
        mixDepth: Float,
        foregroundClarity: Float,
        elementSeparation: Float,
        frequencyMasking: Float,
        mixDensity: Float,
        vocalsStereoWidth: Float,
        drumsStereoWidth: Float,
        bassStereoWidth: Float,
        vocalsPlacement: String,
        drumsPlacement: String,
        bassPlacement: String,
        vocalsToInstrumentsRatio: Float,
        drumsToMixRatio: Float,
        bassToMixRatio: Float,
        hasCompression: Bool,
        compressionAmount: Float,
        hasReverb: Bool,
        reverbAmount: Float,
        hasStereoProcessing: Bool,
        stereoEnhancement: Float,
        hasEQ: Bool,
        eqBalance: Float
    ) {
        self.vocalsLevel = vocalsLevel
        self.drumsLevel = drumsLevel
        self.bassLevel = bassLevel
        self.otherLevel = otherLevel
        self.mixDepth = mixDepth
        self.foregroundClarity = foregroundClarity
        self.elementSeparation = elementSeparation
        self.frequencyMasking = frequencyMasking
        self.mixDensity = mixDensity
        self.vocalsStereoWidth = vocalsStereoWidth
        self.drumsStereoWidth = drumsStereoWidth
        self.bassStereoWidth = bassStereoWidth
        self.vocalsPlacement = vocalsPlacement
        self.drumsPlacement = drumsPlacement
        self.bassPlacement = bassPlacement
        self.vocalsToInstrumentsRatio = vocalsToInstrumentsRatio
        self.drumsToMixRatio = drumsToMixRatio
        self.bassToMixRatio = bassToMixRatio
        self.hasCompression = hasCompression
        self.compressionAmount = compressionAmount
        self.hasReverb = hasReverb
        self.reverbAmount = reverbAmount
        self.hasStereoProcessing = hasStereoProcessing
        self.stereoEnhancement = stereoEnhancement
        self.hasEQ = hasEQ
        self.eqBalance = eqBalance
    }
}

actor ChatGPTAudioAnalysisService {
    
    // MARK: - Configuration
    
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Models
    
    enum ChatGPTModel: String {
        case gpt4o = "gpt-4o-audio-preview"
        case gpt4oMini = "gpt-4o-mini"
    }
    
    // MARK: - Initialization
    
    init() {
        // Load API key from secure configuration
        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_OPENAI_API_KEY_HERE",
           key != "$(OPENAI_API_KEY)" {
            self.apiKey = key
        } else {
            fatalError("⚠️ OpenAI API Key not configured!")
        }
    }
    
    // MARK: - Analysis
    
    /// Analyze audio file directly with ChatGPT using native audio input
    func analyzeAudio(
        fileURL: URL,
        maxDuration: TimeInterval? = nil,
        isProUser: Bool = false,
        stemMetrics: StemMetrics? = nil
    ) async throws -> ChatGPTAudioAnalysisResponse {
        
        let startTime = Date()
        print("🎯 ChatGPT Audio Analysis Starting...")
        
        // Get audio duration
        print("⏱️ Detecting audio duration...")
        let duration = try await getAudioDuration(from: fileURL)
        print("   Duration: \(String(format: "%.2f", duration))s")
        
        // ALWAYS extract 30 seconds from the middle for faster/cheaper analysis
        // (Full mix is usually in the middle, skip intro/outro)
        let analysisSegmentDuration: TimeInterval = 30.0
        let processedURL: URL
        
        if duration > analysisSegmentDuration {
            print("✂️ Extracting \(Int(analysisSegmentDuration))s segment from middle for analysis...")
            processedURL = try await trimAudio(fileURL: fileURL, maxDuration: analysisSegmentDuration)
            print("   ✅ Segment extracted successfully")
        } else {
            // Song is already short, use it as-is
            let ext = fileURL.pathExtension.lowercased()
            if ext == "mp3" || ext == "wav" {
                // Already compatible format
                processedURL = fileURL
            } else {
                // Convert other formats to WAV
                print("🔄 Converting \(ext.uppercased()) to WAV for OpenAI...")
                processedURL = try await convertToWAV(fileURL: fileURL)
                print("   ✅ Converted successfully")
            }
        }
        
        // Prepare audio data and detect format
        print("Preparing audio data for API...")
        let audioData = try await prepareAudioData(from: processedURL)
        let base64Audio = audioData.base64EncodedString()
        let audioFormat = getAudioFormat(from: processedURL)
        print("   ✅ Audio encoded to base64 (\(audioData.count) bytes)")
        print("   Format: \(audioFormat)")
        
        // Estimate tokens
        // Text-only analysis uses our pre-computed metrics, much cheaper!
        let useAudioModel = false  // Using reliable text-only model
        let actualDuration = min(duration, maxDuration ?? duration)
        let estimatedTokens: Int
        let estimatedCost: Double
        
        if useAudioModel {
            // Audio model: $2.50/1M tokens, ~150 tokens per second
            estimatedTokens = Int(actualDuration * 150)
            estimatedCost = (Double(estimatedTokens) / 1_000_000) * 2.50
        } else {
            // Text-only model: $2.50/1M input, ~1000 tokens for prompt
            estimatedTokens = 1500  // Prompt + response
            estimatedCost = (Double(estimatedTokens) / 1_000_000) * 2.50
        }
        
        print("📊 Analysis Parameters:")
        print("   Duration: \(String(format: "%.2f", actualDuration))s")
        print("   Model: \(useAudioModel ? "gpt-4o-audio-preview (audio)" : "gpt-4o (text-only, more reliable)")")
        print("   Estimated tokens: \(estimatedTokens)")
        print("   Estimated cost: $\(String(format: "%.4f", estimatedCost))")
        print("   Subscription: \(isProUser ? "Pro (5 recommendations)" : "Free (3 recommendations)")")
        
        // Create the prompt with stem metrics if available
        
        var stemMetricsText = ""
        if let metrics = stemMetrics {
            // Check if we have actual stem separation data (Pro users) or just mixing effects (Free users)
            let hasStemData = metrics.vocalsLevel > 0 || metrics.drumsLevel > 0 || metrics.bassLevel > 0
            
            if hasStemData {
                // Full stem analysis available
                stemMetricsText = """
                
                📊 MEASURED STEM ANALYSIS DATA (use this for accurate assessment):
                
                MIX BALANCE:
                - Vocals Level: \(Int(metrics.vocalsLevel * 100))% of mix
                - Drums Level: \(Int(metrics.drumsLevel * 100))% of mix
                - Bass Level: \(Int(metrics.bassLevel * 100))% of mix
                - Other Instruments: \(Int(metrics.otherLevel * 100))% of mix
                - Vocals-to-Instruments Ratio: \(String(format: "%.1f", metrics.vocalsToInstrumentsRatio)) dB
                
                STEREO IMAGING PER ELEMENT:
                - Vocals Stereo Width: \(Int(metrics.vocalsStereoWidth * 100))% (\(metrics.vocalsPlacement))
                - Drums Stereo Width: \(Int(metrics.drumsStereoWidth * 100))% (\(metrics.drumsPlacement))
                - Bass Stereo Width: \(Int(metrics.bassStereoWidth * 100))% (\(metrics.bassPlacement))
                
                MIX DEPTH & SEPARATION:
                - Mix Depth Score: \(Int(metrics.mixDepth * 100))% (front-to-back dimension)
                - Foreground Clarity: \(Int(metrics.foregroundClarity * 100))% (lead elements)
                - Element Separation: \(Int(metrics.elementSeparation * 100))% (how distinct each element is)
                - Frequency Masking: \(Int(metrics.frequencyMasking * 100))% (overlap - lower is better)
                - Mix Density: \(Int(metrics.mixDensity * 100))% (how full the spectrum is)
                
                🎛️ MIXING EFFECTS DETECTED (CRITICAL for unmixed detection):
                - Compression: \(metrics.hasCompression ? "YES ✓" : "NO ❌") (amount: \(Int(metrics.compressionAmount * 100))%)
                - Reverb/Delay: \(metrics.hasReverb ? "YES ✓" : "NO ❌") (amount: \(Int(metrics.reverbAmount * 100))%)
                - Stereo Processing: \(metrics.hasStereoProcessing ? "YES ✓" : "NO ❌") (enhancement: \(Int(metrics.stereoEnhancement * 100))%)
                - EQ/Frequency Shaping: \(metrics.hasEQ ? "YES ✓" : "NO ❌") (balance: \(Int(metrics.eqBalance * 100))%)
                
                ⚠️ USE THE YES/NO VALUES ABOVE - DO NOT re-evaluate based on percentages!
                The percentages are just for context. Trust the YES ✓ or NO ❌ detection.
                
                ⚠️ UNMIXED TRACK WARNING:
                - If 2+ effects are NO → Score 40-60 MAX (poorly mixed or unmixed)
                - If 3+ effects are NO → Score 35-50 MAX (completely unmixed/raw)
                - Missing stereo processing + EQ = lacks width and frequency balance = very low score!
                
                Use these MEASURED values to provide specific, accurate feedback!
                """
            } else {
                // Only mixing effects available (Free users or stem separation unavailable)
                stemMetricsText = """
                
                🎛️ MIXING EFFECTS DETECTED (CRITICAL for unmixed detection):
                - Compression: \(metrics.hasCompression ? "YES ✓" : "NO ❌") (amount: \(Int(metrics.compressionAmount * 100))%)
                - Reverb/Delay: \(metrics.hasReverb ? "YES ✓" : "NO ❌") (amount: \(Int(metrics.reverbAmount * 100))%)
                - Stereo Processing: \(metrics.hasStereoProcessing ? "YES ✓" : "NO ❌") (enhancement: \(Int(metrics.stereoEnhancement * 100))%)
                - EQ/Frequency Shaping: \(metrics.hasEQ ? "YES ✓" : "NO ❌") (balance: \(Int(metrics.eqBalance * 100))%)
                
                ⚠️ USE THE YES/NO VALUES ABOVE - DO NOT re-evaluate based on percentages!
                The percentages are just for context. Trust the YES ✓ or NO ❌ detection.
                
                ⚠️ UNMIXED TRACK WARNING:
                - If 2+ effects are NO → Score 40-60 MAX (poorly mixed or unmixed)
                - If 3+ effects are NO → Score 35-50 MAX (completely unmixed/raw)
                - Missing stereo processing + EQ = lacks width and frequency balance = very low score!
                Professional mixes ALWAYS have all 4 of these present!
                """
            }
        }
        
        let prompt = """
        You are a professional audio engineer analyzing measured data from an audio track. Score it ACCURATELY based on the MEASURED VALUES provided below.
        \(stemMetricsText)
        
        ⚠️⚠️⚠️ CRITICAL RULE - READ THIS FIRST ⚠️⚠️⚠️
        YOUR "detailedSummary" MUST MATCH YOUR "overallScore"!
        
        IF YOUR SCORE IS 35-60 (unmixed/poor):
        → Your summary CANNOT say "professionally mixed" or "well-balanced" or "good quality"
        → Your summary MUST say: "unmixed", "raw", "lacks mixing", "needs compression and EQ", "no processing applied"
        → Example: "This track appears unmixed with no compression, EQ, or stereo processing applied. It needs fundamental mixing work."
        
        IF YOUR SCORE IS 85-96 (professional):
        → Your summary MUST say: "professionally mixed", "well-balanced", "commercial quality", "polished", "excellent"
        → Your summary CANNOT say "unmixed", "needs mixing", "poor", "minimal mixing", "lacking", "weak dynamics"
        → FORBIDDEN WORDS for scores 85+: "poor", "minimal", "lacking", "weak", "needs improvement", "problematic"
        → Example for 90: "This is a professionally mixed track with excellent balance, proper compression, and good stereo imaging suitable for commercial release."
        
        A SCORE OF 44 WITH A SUMMARY SAYING "PROFESSIONALLY MIXED" IS COMPLETELY WRONG!
        A SCORE OF 90 WITH A SUMMARY SAYING "MINIMAL MIXING" OR "POOR DYNAMICS" IS COMPLETELY WRONG!
        CHECK YOUR SCORE AND SUMMARY MATCH BEFORE RETURNING THE JSON!
        
        🎯 SCORING RULES (BE ACCURATE - Don't under-score professional mixes!):
        
        ⚠️ CRITICAL RULE FOR PROFESSIONAL MIXES:
        If 3-4 mixing effects are present (Compression ✓, Reverb ✓, Stereo Processing ✓, EQ):
        → This is a PROFESSIONALLY MIXED track (even if 1 effect is borderline)
        → DEFAULT STARTING SCORE: 88-92 (not 40-60!)
        → If it sounds like a real album/commercial release = 88-92 MINIMUM
        → World-class engineers (CLA, Andrew Scheps, Bob Clearmountain, etc.) = 92-96
        → Good commercial releases (sounds like Spotify/radio/albums) = 88-92
        
        🎵 IF YOU HEAR PROFESSIONAL QUALITY:
        - Clear, punchy, polished sound = 88-92 minimum
        - Sounds like it could be on radio/Spotify = 88-92 minimum
        - Well-balanced, no major flaws = 88-92 minimum
        → DO NOT SCORE BELOW 85 if it sounds professional!
        → Only lower to 75-87 if there are OBVIOUS problems you can hear
        
        DO NOT under-score professional commercial mixes! If it sounds like a real album/single:
        - Has punch, clarity, and polish = 88-92 minimum
        - All instruments clear and balanced = 88-92 minimum  
        - Professional loudness and dynamics = 88-92 minimum
        - Good stereo imaging = 88-92 minimum
        
        ⚠️ CRITICAL RULE FOR UNMIXED TRACKS:
        If 2+ mixing effects are MISSING (NO ❌):
        → This is UNMIXED or POORLY MIXED → Score 40-60 MAX!
        → Summary MUST say: "unmixed", "raw", "lacks processing"
        → Only use this rule if the track actually sounds raw/unprocessed
        If 3+ mixing effects are MISSING (NO ❌):
        → This is COMPLETELY UNMIXED → Score 35-50 MAX!
        → Summary MUST say: "completely unmixed", "no mixing applied", "raw recordings"
        → Even if it sounds "okay", unmixed = low score
        → No compression + no EQ + no stereo = raw/unprocessed = 35-45 score
        → Summary MUST explain: "This track has no compression, no EQ, no stereo processing - it's unmixed"
        
        
        ⚠️ DON'T CONFUSE PROFESSIONAL WITH UNMIXED:
        - If 3 effects are YES and 1 is NO, but it SOUNDS professional → Score 85-92
        - Missing 1 effect doesn't mean unmixed if the mix sounds polished
        - Trust your ears: does it sound like a real album? Then score 85+
        
        Compare to PROFESSIONAL COMMERCIAL releases (Spotify, Apple Music, radio, albums).
        Use the measured metrics above as your PRIMARY guide - they are scientifically accurate!
        
        SCORING GUIDELINES:
        
        92-96: World-class professional mix (CLA, Serban Ghenea, Andrew Scheps level)
               - All 4 effects present ✓
               - Excellent stereo width (40-70%)
               - Balanced frequency distribution
               - Professional loudness (-8 to -14 LUFS)
               - Clear, punchy, competitive, sounds like a hit record
        
        88-91: Professional commercial mix (typical album/single quality)
               - All 4 effects present ✓
               - Good stereo imaging (30-70%)
               - Well-balanced frequencies
               - Competitive loudness
               - Sounds polished and radio-ready
        
        82-87: Good professional mix (indie/smaller label quality)
               - All 4 effects present ✓
               - Decent stereo and frequency balance
               - Professional but maybe not major-label polish
        
        75-81: Semi-professional mix
               - Most effects present but not optimal
               - Some balance issues but clearly processed
        
        60-74: Amateur/home studio mix
               - Some effects present but poorly applied
               - Balance issues, lacks professional polish
        
        35-55: Unmixed or severely problematic
               - 3+ mixing effects MISSING
               - Raw, unprocessed sound
               - Major balance issues
        
        UNMIXED INDICATORS (critical - apply strict scoring!):
        - If 2+ effects are NO → Maximum score 60
        - If 3+ effects are NO → Maximum score 50
        - Completely DRY sound (no reverb/delay/space at all)
        - Vocals buried or at same level as backing instruments
        - Completely MONO with no stereo width (<20%)
        - Very muddy low end (bass and kick completely masking each other)
        - No compression or dynamics processing evident
        - Harsh, unbalanced frequencies with no EQ shaping
        - Extremely quiet or very unbalanced levels
        
        ⚠️ FOR UNMIXED TRACKS (score 35-60), your recommendations MUST include:
        - "Apply compression to control dynamics and add punch"
        - "Add EQ to balance frequencies and reduce muddiness"
        - "Use stereo enhancement to create width"
        - "Add reverb/delay for depth and space"
        And your summary MUST say things like: "unmixed", "raw", "lacks processing", "needs fundamental mixing"
        
        
        SCORING SCALE (use the FULL range, especially the HIGH END!):
        20-40 = RAW/UNMIXED (no processing, sounds like raw recordings)
        40-55 = POOR MIX (major issues: buried vocals, muddy, harsh, mono)
        55-70 = AMATEUR/HOME STUDIO (has processing but lacks polish, imbalanced)
        70-79 = SEMI-PRO (well-mixed but not quite commercial quality)
        80-87 = PROFESSIONAL INDIE (high quality but not major-label)
        88-91 = PROFESSIONAL COMMERCIAL (album/single quality - this is your DEFAULT for good professional mixes!)
        92-96 = WORLD-CLASS (top-tier engineers, reference quality - CLA, Andrew Scheps, Bob Clearmountain)
        97-100 = MASTERPIECE (perfect, no improvements possible - extremely rare!)
        
        ⚠️ IMPORTANT: If all 4 effects are detected and the mix sounds polished/professional:
        - Start at 88-91 (NOT 75-84)
        - Only lower if you hear OBVIOUS problems
        - Don't be stingy with scores for professional work!
        
        PROFESSIONAL MIX CHARACTERISTICS (score 88-92 when these are present):
        ✓ Clear vocal presence, sitting appropriately in the mix
        ✓ Good stereo width (35-70%) with proper imaging
        ✓ Balanced frequency spectrum (genre-dependent: rock can be 0.05-0.15, pop 0.15-0.30, electronic 0.20-0.40)
        ✓ Proper dynamics (compression applied, punchy but controlled - crest factor 8-12 dB is excellent for rock/pop)
        ✓ Depth and space (reverb/delay used appropriately)
        ✓ Clean low end (bass and kick work together)
        ✓ Elements are distinct and serve the song
        ✓ Professional loudness levels (-8 to -12 LUFS for rock/pop)
        ✓ Cohesive and intentional sound
        ✓ Sounds like it could be on Spotify/Apple Music/radio
        ✓ Polished and competitive with commercial releases
        
        🎯 SCORING BENCHMARKS (be generous with professional work!):
        - If it sounds like a Green Day, Foo Fighters, or similar major label album = 90-94
        - If it sounds like a polished indie release that could be on radio = 88-90
        - If it sounds like a good home studio mix with all effects = 82-87
        - If it sounds like a demo with some processing = 75-81
        
        IMPORTANT: Genre affects spectral characteristics!
        - Rock/Metal: Lower spectral flatness (0.05-0.15) due to distortion/harmonics = STILL PROFESSIONAL
        - Pop/R&B: Medium flatness (0.15-0.30) = PROFESSIONAL
        - Electronic: Higher flatness (0.20-0.40) = PROFESSIONAL
        → DON'T penalize a great rock mix for having low spectral flatness!
        
        IMPORTANT: Dynamic range varies by genre!
        - Modern rock/pop: Crest factor 8-12 dB is EXCELLENT (punchy and controlled)
        - Jazz/classical: Crest factor 15-20 dB (more dynamic)
        → DON'T penalize a punchy rock mix for having controlled dynamics!
        
        When stem metrics are provided:
        - Use the measured values for objective assessment
        - Cross-reference with what you hear
        - Provide specific, data-backed recommendations
        
        ⚠️⚠️⚠️ BEFORE YOU RETURN THE JSON - FINAL CHECK ⚠️⚠️⚠️
        1. Look at your "overallScore" value
        2. Look at your "detailedSummary" text
        3. DO THEY MATCH?
           - Score 35-60 + Summary says "professional" = WRONG! Fix the summary!
           - Score 88-96 + Summary says "unmixed" = WRONG! Fix the summary!
        4. If they don't match, REWRITE the summary to match the score!
        
        RETURN ONLY JSON (no text, no markdown, no explanations):
        {
            "overallScore": 85,
            "stereoWidth": {"score": 65, "analysis": "2-3 sentences with SPECIFIC measurements"},
            "phaseCoherence": {"score": 0.85, "analysis": "2-3 sentences"},
            "frequencyBalance": {
                "subBass": 15, "bass": 22, "lowMids": 18,
                "mids": 20, "highMids": 15, "highs": 10,
                "analysis": "2-3 sentences"
            },
            "dynamicRange": {"rangeDB": 8.5, "analysis": "2-3 sentences"},
            "loudness": {"lufs": -10.5, "peakDB": -0.3, "analysis": "2-3 sentences"},
            "mixBalance": {
                "vocalsLevel": "description of vocal level and clarity",
                "drumsLevel": "description of drums prominence",
                "bassLevel": "description of bass clarity and weight",
                "depth": "description of front-to-back depth"
            },
            "recommendations": [\(isProUser ? "\"rec1\", \"rec2\", \"rec3\", \"rec4\", \"rec5\"" : "\"rec1\", \"rec2\", \"rec3\"")],
            "detailedSummary": "MUST MATCH SCORE! Score 35-60 = 'This track is unmixed/raw with no compression, EQ, or stereo processing.' Score 88-96 = 'This is a professionally mixed track with excellent balance.' CHECK THAT YOUR SUMMARY WORDS MATCH YOUR SCORE NUMBER!",
            "frequencySpectrumImageURL": null
        }
        
        ⚠️⚠️⚠️ FINAL VALIDATION BEFORE SUBMITTING JSON ⚠️⚠️⚠️
        
        CHECK YOUR "detailedSummary" MATCHES YOUR "overallScore":
        
        IF overallScore is 35-60 (unmixed/poor):
        ❌ WRONG: "This track is professionally mixed"
        ❌ WRONG: "Well-balanced and polished"
        ❌ WRONG: "Good stereo imaging and compression"
        ✅ CORRECT: "This track is unmixed with no compression, EQ, or stereo processing applied"
        ✅ CORRECT: "Raw and unprocessed - needs fundamental mixing work"
        ✅ CORRECT: "Lacks professional mixing - requires compression, EQ, and spatial effects"
        
        IF overallScore is 88-96 (professional):
        ❌ WRONG: "This track is unmixed"
        ❌ WRONG: "Needs compression and EQ"
        ❌ WRONG: "Raw and unprocessed"
        ❌ WRONG: "Minimal mixing with poor dynamics"
        ❌ WRONG: "Shows minimal mixing"
        ❌ WRONG: "Lacks polish"
        ❌ WRONG: "Weak dynamics"
        ❌ WRONG: "Poor balance"
        ✅ CORRECT for 90: "This is a professionally mixed track with excellent balance, proper compression, and solid stereo imaging suitable for commercial release"
        ✅ CORRECT for 92: "This is a world-class professionally mixed track with exceptional balance and polished sound quality"
        ✅ CORRECT for 88: "This is a professionally mixed track with good balance and commercial quality"
        
        NEVER write "professionally mixed" if your score is below 75!
        NEVER write "unmixed", "minimal", "poor", "weak", "lacking" if your score is above 85!
        
        """
        
        // Create request payload with audio input
        // NOTE: We have two options:
        // 1. gpt-4o-audio-preview: Can listen to audio but sometimes ignores instructions
        // 2. gpt-4o: More reliable at following instructions, but text-only
        // 
        // DECISION: Use gpt-4o (text-only) with our measured metrics for MORE RELIABLE summaries
        // We already have all the audio analysis (stem metrics, frequency, dynamics, etc.)
        // We just need ChatGPT to generate a good summary that matches the score

      let selectedModel = useAudioModel ? "gpt-4o-audio-preview" : "gpt-4o"

        print("   Selected model: \(selectedModel) \(useAudioModel ? "(audio input)" : "(text-only, more reliable)")")
        print("   Subscription: \(isProUser ? "Pro" : "Free") - affects recommendations count")
        
        let requestBody: [String: Any]
        
        if useAudioModel {
            // Audio model version
            requestBody = [
                "model": selectedModel,
                "modalities": ["text"],
                "audio": ["voice": "alloy", "format": "wav"],
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": prompt
                            ],
                            [
                                "type": "input_audio",
                                "input_audio": [
                                    "data": base64Audio,
                                    "format": audioFormat
                                ]
                            ]
                        ]
                    ]
                ],
                "max_tokens": 2000
            ]
        } else {
            // Text-only model (more reliable)
            requestBody = [
                "model": selectedModel,
                "messages": [
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ],
                "response_format": ["type": "json_object"],  // Enforce JSON output
                "max_tokens": 2000
            ]
        }
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Set timeout to 180 seconds (3 minutes) for large audio files
        // WAV files can be 30-50MB and take time to upload + process
        urlRequest.timeoutInterval = 180.0
        
        print("📤 Sending audio to ChatGPT...")
        let apiStartTime = Date()
        
        // Send request with timeout protection
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let apiEndTime = Date()
        let apiDuration = apiEndTime.timeIntervalSince(apiStartTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatGPTError.invalidResponse
        }
        
        print("📥 Received response: HTTP \(httpResponse.statusCode)")
        print("⏱️ API Response Time: \(String(format: "%.2f", apiDuration))s")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: \(errorMessage)")
            throw ChatGPTError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatGPTError.invalidResponse
        }
        
        print("✅ Analysis received from ChatGPT")
        print("📝 Response: \(content)")
        
        // Parse the JSON response
        let parseStartTime = Date()
        var analysisResponse = try parseAnalysisResponse(content)
        let parseDuration = Date().timeIntervalSince(parseStartTime)
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 PARSED RESPONSE FROM CHATGPT:")
        print("   Score: \(analysisResponse.overallScore)")
        print("   Summary: \(analysisResponse.detailedSummary)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // VALIDATE: Fix any mismatch between score and summary
        analysisResponse = validateAndFixSummary(analysisResponse)
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 AFTER VALIDATION:")
        print("   Score: \(analysisResponse.overallScore)")
        print("   Summary: \(analysisResponse.detailedSummary)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let preprocessingDuration = totalDuration - apiDuration - parseDuration
        
        print("⏱️ Total Analysis Time: \(String(format: "%.2f", totalDuration))s")
        print("  ├─ Preprocessing: \(String(format: "%.2f", preprocessingDuration))s")
        print("  ├─ API Call: \(String(format: "%.2f", apiDuration))s")
        print("  └─ JSON Parsing: \(String(format: "%.2f", parseDuration))s")
        
        // Clean up temporary file if we created one
        if processedURL != fileURL {
            try? FileManager.default.removeItem(at: processedURL)
        }
        
        return analysisResponse
    }
    
    // MARK: - Helper Methods
    
    private func getAudioDuration(from url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    
    private func trimAudio(fileURL: URL, maxDuration: TimeInterval) async throws -> URL {
        // Convert to WAV format (since we can't create MP3 easily on iOS)
        let wavURL = try await convertToWAV(fileURL: fileURL)
        
        // If no trimming needed, return the WAV
        let asset = AVURLAsset(url: wavURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        if durationSeconds <= maxDuration {
            return wavURL
        }
        
        // Extract from the MIDDLE of the song (where full mix is typically present)
        // Skip intro/outro which often have sparse instrumentation
        let middleStart = (durationSeconds - maxDuration) / 2.0
        
        print("   📍 Extracting \(Int(maxDuration))s from middle (starting at \(String(format: "%.1f", middleStart))s)")
        
        // Trim the WAV file from the middle
        let inputFile = try AVAudioFile(forReading: wavURL)
        let format = inputFile.processingFormat
        
        // Calculate frame positions
        let startFrame = AVAudioFramePosition(middleStart * format.sampleRate)
        let frameCount = AVAudioFrameCount(maxDuration * format.sampleRate)
        
        // Seek to the middle position
        inputFile.framePosition = startFrame
        
        // Read the segment
        let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        try inputFile.read(into: trimmedBuffer, frameCount: frameCount)
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        try outputFile.write(from: trimmedBuffer)
        
        print("   ✅ Extracted middle segment to WAV: \(outputURL.lastPathComponent)")
        return outputURL
    }
    
    private func convertToWAV(fileURL: URL) async throws -> URL {
        let inputFile = try AVAudioFile(forReading: fileURL)
        let format = inputFile.processingFormat
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        
        // Read and write in chunks
        let bufferSize: AVAudioFrameCount = 4096
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        
        while inputFile.framePosition < inputFile.length {
            try inputFile.read(into: buffer)
            try outputFile.write(from: buffer)
        }
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        print("   📦 Converted to WAV: \(String(format: "%.1f", Double(fileSize) / (1024 * 1024)))MB")
        
        return outputURL
    }
    
    private func convertToMP3(fileURL: URL) async throws -> URL {
        // iOS doesn't support direct MP3 encoding, so convert to WAV instead
        return try await convertToWAV(fileURL: fileURL)
    }
    
    private func prepareAudioData(from url: URL) async throws -> Data {
        return try Data(contentsOf: url)
    }
    
    private func getAudioFormat(from url: URL) -> String {
        // OpenAI ONLY supports: wav and mp3
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": return "wav"
        case "mp3": return "mp3"
        default: return "mp3" // All other formats should be converted to MP3
        }
    }
    
    private func parseAnalysisResponse(_ jsonString: String) throws -> ChatGPTAudioAnalysisResponse {
        // Clean up the response - remove markdown code blocks, extra text, etc.
        var cleanedString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code block markers if present
        if cleanedString.hasPrefix("```json") {
            cleanedString = cleanedString.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedString.hasPrefix("```") {
            cleanedString = cleanedString.replacingOccurrences(of: "```", with: "")
        }
        if cleanedString.hasSuffix("```") {
            cleanedString = cleanedString.replacingOccurrences(of: "```", with: "")
        }
        
        // Find the first { and last } to extract just the JSON object
        if let firstBrace = cleanedString.firstIndex(of: "{"),
           let lastBrace = cleanedString.lastIndex(of: "}") {
            cleanedString = String(cleanedString[firstBrace...lastBrace])
        }
        
        cleanedString = cleanedString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedString.data(using: .utf8) else {
            print("❌ Failed to convert cleaned string to data")
            print("Cleaned string: \(cleanedString.prefix(200))")
            throw ChatGPTError.invalidJSON
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(ChatGPTAudioAnalysisResponse.self, from: jsonData)
            return response
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            print("❌ Cleaned JSON string: \(cleanedString.prefix(500))")
            throw ChatGPTError.invalidJSON
        }
    }
    
    /// Validates that the summary matches the score and fixes any mismatches
    private func validateAndFixSummary(_ response: ChatGPTAudioAnalysisResponse) -> ChatGPTAudioAnalysisResponse {
        let score = Int(response.overallScore)
        let summary = response.detailedSummary.lowercased()
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 VALIDATING SUMMARY:")
        print("   Score: \(score)")
        print("   Summary (original): \(response.detailedSummary)")
        print("   Summary (lowercase): \(summary)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // AGGRESSIVE VALIDATION: Force correction based on score ranges
        var needsCorrection = false
        var correctedSummary = response.detailedSummary
        var reason = ""
        
        // Check for contradictions - MORE COMPREHENSIVE WORD DETECTION
        let hasProfessionalWords = summary.contains("professional") || 
                                   summary.contains("well-balanced") || 
                                   summary.contains("well balanced") ||
                                   summary.contains("polished") ||
                                   summary.contains("excellent") ||
                                   summary.contains("commercial quality") ||
                                   summary.contains("great") ||
                                   summary.contains("good quality") ||
                                   summary.contains("solid mix") ||
                                   summary.contains("cohesive") ||
                                   summary.contains("competitive") ||
                                   summary.contains("suitable for release")
        
        let hasUnmixedWords = summary.contains("unmixed") || 
                             summary.contains("raw") || 
                             summary.contains("unprocessed") ||
                             summary.contains("lacks processing") ||
                             summary.contains("no compression") ||
                             summary.contains("no eq") ||
                             summary.contains("needs mixing") ||
                             summary.contains("requires mixing") ||
                             summary.contains("needs work") ||
                             summary.contains("poorly mixed") ||
                             summary.contains("poor mix") ||
                             summary.contains("minimal mixing") ||
                             summary.contains("minimal mix") ||
                             summary.contains("needs improvement") ||
                             summary.contains("amateur") ||
                             summary.contains("home studio") ||
                             summary.contains("requires fundamental") ||
                             summary.contains("significant issues") ||
                             summary.contains("major issues") ||
                             summary.contains("poor dynamics") ||
                             summary.contains("weak dynamics") ||
                             summary.contains("lacking") ||
                             summary.contains("insufficient") ||
                             summary.contains("problematic") ||
                             summary.contains("issues with") ||
                             summary.contains("struggles with") ||
                             summary.contains("falls short") ||
                             summary.contains("subpar") ||
                             summary.contains("below standard") ||
                             summary.contains("not professional") ||
                             summary.contains("unprofessional")
        
        print("   Has professional words: \(hasProfessionalWords)")
        print("   Has unmixed words: \(hasUnmixedWords)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // STRICT ENFORCEMENT: If score is very low (≤60) and summary has ANY professional words, fix it
        if score <= 60 {
            if hasProfessionalWords {
                needsCorrection = true
                reason = "Score ≤60 but summary contains positive/professional language"
                print("⚠️⚠️⚠️ CONTRADICTION DETECTED: Score=\(score) but summary says '\(hasProfessionalWords ? "professional" : "positive")'")
                
                // Generate appropriate unmixed summary based on score
                if score <= 45 {
                    correctedSummary = "This track appears to be completely unmixed with no compression, EQ, or stereo processing applied. It requires fundamental mixing work including dynamics control, frequency balancing, and spatial enhancement to reach professional standards."
                } else if score <= 55 {
                    correctedSummary = "This track shows minimal mixing with poor dynamics control and frequency balance. It needs compression, EQ work, and stereo enhancement to improve the overall quality and achieve a more polished sound."
                } else {
                    correctedSummary = "This track has significant mixing issues including imbalanced frequencies and weak dynamics. Professional mixing techniques including compression, EQ, and spatial processing are needed to improve the quality."
                }
            } else if !hasUnmixedWords {
                // Even if no professional words, if there are NO unmixed words at all, add them
                needsCorrection = true
                reason = "Score ≤60 but summary doesn't mention unmixed/needs work"
                print("⚠️⚠️⚠️ MISSING CRITICAL INFO: Score=\(score) but summary doesn't explain the low score")
                
                if score <= 45 {
                    correctedSummary = "This track is unmixed or poorly mixed. " + response.detailedSummary + " It requires fundamental mixing work including compression, EQ, and spatial effects."
                } else if score <= 55 {
                    correctedSummary = "This track has significant mixing issues. " + response.detailedSummary + " It needs professional mixing including compression, EQ work, and stereo enhancement."
                } else {
                    correctedSummary = "This track needs improvement. " + response.detailedSummary + " Professional mixing techniques are needed to enhance the quality."
                }
            }
        } else if score >= 85 {
            // High score (85+) - should NEVER say "unmixed" or negative things
            print("🔍 Checking high score validation (score >= 85)")
            print("   hasUnmixedWords = \(hasUnmixedWords)")
            print("   hasProfessionalWords = \(hasProfessionalWords)")
            
            // AGGRESSIVE: Always fix if score >= 85 and has ANY negative words
            if hasUnmixedWords {
                needsCorrection = true
                reason = "Score ≥85 but summary contains negative/unmixed language"
                print("⚠️⚠️⚠️ CONTRADICTION DETECTED: Score=\(score) but summary says 'unmixed' or negative words")
                print("⚠️⚠️⚠️ FORCING CORRECTION NOW!")
                
                // Generate appropriate professional summary - DO NOT append original!
                if score >= 92 {
                    correctedSummary = "This is a world-class professionally mixed track with excellent stereo imaging, balanced frequency distribution, and proper dynamics control. The mix is polished, competitive, and suitable for commercial release at the highest level."
                } else if score >= 88 {
                    correctedSummary = "This is a professionally mixed track with good balance, proper compression, and solid stereo imaging. The mix quality is suitable for commercial release with a polished and cohesive sound."
                } else {
                    correctedSummary = "This is a well-mixed professional track with good balance and processing. The mix shows proper use of compression, EQ, and spatial effects, resulting in a cohesive and polished sound."
                }
            } else if !hasProfessionalWords {
                // High score but no positive words = add them - DO NOT append original!
                needsCorrection = true
                reason = "Score ≥85 but summary doesn't mention professional quality"
                print("⚠️⚠️⚠️ MISSING CRITICAL INFO: Score=\(score) but summary doesn't praise the quality")
                
                if score >= 92 {
                    correctedSummary = "This is a world-class professionally mixed track with excellent balance, polished sound, and commercial-quality production. The mix demonstrates professional-level dynamics control, frequency balance, and spatial imaging."
                } else if score >= 88 {
                    correctedSummary = "This is a professionally mixed track with commercial quality, good balance, and proper use of compression, EQ, and spatial effects. The mix is suitable for professional release."
                } else {
                    correctedSummary = "This is a well-mixed professional track showing good balance and processing with proper compression, EQ, and spatial effects creating a cohesive sound."
                }
            }
        }
        
        if needsCorrection {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✅✅✅ CORRECTED SUMMARY (\(reason)):")
            print("   OLD: \(response.detailedSummary)")
            print("   NEW: \(correctedSummary)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return ChatGPTAudioAnalysisResponse(
                overallScore: response.overallScore,
                stereoWidth: response.stereoWidth,
                phaseCoherence: response.phaseCoherence,
                frequencyBalance: response.frequencyBalance,
                dynamicRange: response.dynamicRange,
                loudness: response.loudness,
                recommendations: response.recommendations,
                detailedSummary: correctedSummary,
                frequencySpectrumImageURL: response.frequencySpectrumImageURL
            )
        }
        
        // FINAL SAFETY CHECK - catch any remaining contradictions
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔒 FINAL SAFETY CHECK:")
        
        // One more aggressive check for obvious contradictions
        if score >= 85 && (summary.contains("unmixed") || summary.contains("completely unmixed") || summary.contains("not mixed")) {
            print("⚠️⚠️⚠️ EMERGENCY CORRECTION: Score \(score) with 'unmixed' detected!")
            correctedSummary = "This is a professionally mixed track with excellent balance, proper compression, and solid stereo imaging. The mix quality is suitable for commercial release with a polished and cohesive sound."
            print("   EMERGENCY SUMMARY: \(correctedSummary)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return ChatGPTAudioAnalysisResponse(
                overallScore: response.overallScore,
                stereoWidth: response.stereoWidth,
                phaseCoherence: response.phaseCoherence,
                frequencyBalance: response.frequencyBalance,
                dynamicRange: response.dynamicRange,
                loudness: response.loudness,
                recommendations: response.recommendations,
                detailedSummary: correctedSummary,
                frequencySpectrumImageURL: response.frequencySpectrumImageURL
            )
        }
        
        if score <= 60 && (summary.contains("professional") || summary.contains("excellent") || summary.contains("polished")) {
            print("⚠️⚠️⚠️ EMERGENCY CORRECTION: Score \(score) with 'professional' detected!")
            correctedSummary = "This track appears to be unmixed or poorly mixed with no compression, EQ, or stereo processing applied. It requires fundamental mixing work including dynamics control, frequency balancing, and spatial enhancement."
            print("   EMERGENCY SUMMARY: \(correctedSummary)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return ChatGPTAudioAnalysisResponse(
                overallScore: response.overallScore,
                stereoWidth: response.stereoWidth,
                phaseCoherence: response.phaseCoherence,
                frequencyBalance: response.frequencyBalance,
                dynamicRange: response.dynamicRange,
                loudness: response.loudness,
                recommendations: response.recommendations,
                detailedSummary: correctedSummary,
                frequencySpectrumImageURL: response.frequencySpectrumImageURL
            )
        }
        
        print("✅ Summary validation complete - no correction needed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        return response
    }
}

// MARK: - Response Models

struct ChatGPTAudioAnalysisResponse: Codable {
    let overallScore: Double
    let stereoWidth: StereoWidthAnalysis
    let phaseCoherence: PhaseCoherenceAnalysis
    let frequencyBalance: FrequencyBalanceAnalysis
    let dynamicRange: DynamicRangeAnalysis
    let loudness: LoudnessAnalysis
    let recommendations: [String]
    let detailedSummary: String
    let frequencySpectrumImageURL: String?
    
    struct StereoWidthAnalysis: Codable {
        let score: Double
        let analysis: String
    }
    
    struct PhaseCoherenceAnalysis: Codable {
        let score: Double
        let analysis: String
    }
    
    struct FrequencyBalanceAnalysis: Codable {
        let subBass: Double
        let bass: Double
        let lowMids: Double
        let mids: Double
        let highMids: Double
        let highs: Double
        let analysis: String
    }
    
    struct DynamicRangeAnalysis: Codable {
        let rangeDB: Double
        let analysis: String
    }
    
    struct LoudnessAnalysis: Codable {
        let lufs: Double
        let peakDB: Double
        let analysis: String
    }
}

// MARK: - Errors

enum ChatGPTError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case invalidJSON
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from ChatGPT API"
        case .apiError(let statusCode, let message):
            return "ChatGPT API Error (\(statusCode)): \(message)"
        case .noContent:
            return "No content in ChatGPT response"
        case .invalidJSON:
            return "Invalid JSON in ChatGPT response"
        case .audioProcessingFailed:
            return "Failed to process audio file"
        }
    }
}
