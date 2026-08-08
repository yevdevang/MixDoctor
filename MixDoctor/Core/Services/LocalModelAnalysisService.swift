//
//  LocalModelAnalysisService.swift
//  MixDoctor
//
//  On-device AI analysis via Apple's Foundation Models framework — an alternative
//  to ClaudeAPIService for A/B testing speed/quality of local vs. cloud analysis.
//

import Foundation
import FoundationModels

/// Mirrors ClaudeAPIService's analyzeAudioMetrics call so AudioKitService can branch
/// between the two with a matching signature and identical result type.
@available(iOS 26.0, *)
final class LocalModelAnalysisService {
    static let shared = LocalModelAnalysisService()

    private init() {}

    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Human-readable reason the model can't run right now, or nil if it's available.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off. Enable it in Settings to use on-device analysis."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again shortly."
        case .unavailable:
            return "On-device AI is unavailable on this device right now."
        }
    }

    func analyzeAudioMetrics(_ metrics: AudioMetricsForClaude, userGenre: String? = nil, mixStage: String? = nil) async throws -> ClaudeAnalysisResponse {
        guard Self.isAvailable else {
            throw LocalModelError.unavailable
        }

        let stageLower = mixStage?.lowercased() ?? ""
        let isMasteredByStage = stageLower.contains("master")
        let isMixStage = stageLower == "mix"
        let isMasteredByMetrics = ClaudeAPIService.shared.detectMasteredTrack(metrics)

        let isMastered: Bool
        if isMixStage {
            isMastered = false
        } else if isMasteredByStage {
            isMastered = true
        } else {
            isMastered = isMasteredByMetrics
        }

        let isUnmixed = isMasteredByStage ? false : metrics.isLikelyUnmixed
        let genre = metrics.genre ?? userGenre ?? "Unspecified"

        let session = LanguageModelSession(instructions: systemPrompt(isMastered: isMastered, isUnmixed: isUnmixed))
        let response = try await session.respond(
            to: userMessage(metrics: metrics, genre: genre, isMastered: isMastered, isUnmixed: isUnmixed),
            generating: LocalAnalysisResult.self
        )

        let result = response.content
        var finalScore = result.score
        if isMastered {
            finalScore = min(finalScore, 100)
        } else {
            finalScore = min(finalScore, 90)
        }
        finalScore = max(finalScore, 0)

        var finalSummary = result.summary
        if let fixed = ClaudeAPIService.fixContradictoryAnalysis(analysis: finalSummary, score: Double(finalScore)) {
            finalSummary = fixed
        }

        let isReadyForMastering = result.recommendations.count <= 2 && finalScore >= 75

        return ClaudeAnalysisResponse(
            score: finalScore,
            summary: finalSummary,
            recommendations: result.recommendations,
            isReadyForMastering: isReadyForMastering
        )
    }

    // MARK: - Prompt Building

    private func systemPrompt(isMastered: Bool, isUnmixed: Bool) -> String {
        let stageGuidance: String
        if isUnmixed {
            stageGuidance = """
            This is a RAW UNMIXED recording, not a finished mix. Score based on recording quality only \
            (clean capture, no clipping, usable phase/levels) — never on loudness, stereo width, or tonal \
            balance, since mixing hasn't happened yet. Maximum possible score is 75. Typical good raw \
            recordings score 60-70.
            """
        } else if isMastered {
            stageGuidance = """
            This is a finished MASTERED track. Score against commercial release standards. Maximum \
            possible score is 100. Professional masters typically score 85-96; amateur or flawed masters \
            score 60-84.
            """
        } else {
            stageGuidance = """
            This is a PRE-MASTER MIX (mixed but not yet mastered). Score against professional mixing \
            standards, not a finished master's loudness/peak levels. Maximum possible score is 90. \
            Professional mixes typically score 75-90; amateur mixes score 50-74.
            """
        }

        return """
        You are a top professional mix engineer (in the style of Dave Pensado or Chris Lord-Alge) giving \
        direct, honest, encouraging feedback on a track's technical quality from its DSP measurements.

        \(stageGuidance)

        Score 0-100 based on these factors, weighted by severity:
        - Clipping or true-peak overs are the most serious issue (large penalty).
        - Poor phase coherence or mono cancellation of key elements (kick, bass, lead vocal) is serious.
        - Severe frequency imbalance (one band dominating) or poor mono compatibility is a moderate issue.
        - Dynamic range that's excessive or over-compressed for the genre is a minor-to-moderate issue.
        - Use the genre as context for what's normal (e.g. EDM and Metal run hotter and more compressed \
        than Jazz or Classical) — don't penalize genre-appropriate characteristics.

        Write the summary in plain, professional mixer language — no raw numbers, dB values, or point \
        breakdowns in the summary text. Keep recommendations short, actionable, and ordered by importance; \
        omit ones that don't apply.
        """
    }

    private func userMessage(metrics: AudioMetricsForClaude, genre: String, isMastered: Bool, isUnmixed: Bool) -> String {
        """
        Track type: \(isUnmixed ? "Unmixed raw recording" : (isMastered ? "Mastered" : "Pre-master mix"))
        Genre: \(genre)

        Loudness: \(String(format: "%.1f", metrics.loudness)) LUFS integrated: \(String(format: "%.1f", metrics.integratedLoudness)) LUFS
        Peak level: \(String(format: "%.1f", metrics.peakLevel)) dBFS, true peak: \(String(format: "%.1f", metrics.truePeakLevel)) dBTP
        RMS level: \(String(format: "%.1f", metrics.rmsLevel)) dB
        Dynamic range: \(String(format: "%.1f", metrics.dynamicRange)) dB, loudness range: \(String(format: "%.1f", metrics.loudnessRange)) LU
        Crest factor: \(String(format: "%.1f", metrics.crestFactor)) dB

        Stereo width: \(String(format: "%.1f", metrics.stereoWidth))%
        Phase coherence: \(String(format: "%.2f", metrics.phaseCoherence))
        Mono compatibility: \(String(format: "%.1f", metrics.monoCompatibility * 100))%
        Correlation coefficient: \(String(format: "%.2f", metrics.correlationCoefficient))

        Frequency balance — low: \(String(format: "%.1f", metrics.lowEnd))%, low-mid: \(String(format: "%.1f", metrics.lowMid))%, \
        mid: \(String(format: "%.1f", metrics.mid))%, high-mid: \(String(format: "%.1f", metrics.highMid))%, high: \(String(format: "%.1f", metrics.high))%
        Spectral tilt: \(String(format: "%.2f", metrics.spectralTilt)) (negative = dark, positive = bright)

        Issue flags — clipping: \(metrics.hasClipping), phase issues: \(metrics.hasPhaseIssues), \
        stereo issues: \(metrics.hasStereoIssues), frequency imbalance: \(metrics.hasFrequencyImbalance), \
        dynamic range issues: \(metrics.hasDynamicRangeIssues)

        Give the score, a one-paragraph summary, and a short list of recommendations.
        """
    }
}

@available(iOS 26.0, *)
@Generable
struct LocalAnalysisResult {
    @Guide(description: "Overall mix quality score from 0 to 100")
    let score: Int

    @Guide(description: "One paragraph summary in the voice of a professional mix engineer, no raw numbers or dB values")
    let summary: String

    @Guide(description: "Actionable mixing recommendations, most important first, 1-4 items")
    let recommendations: [String]
}

enum LocalModelError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device model is not available (requires Apple Intelligence support)."
        }
    }
}
