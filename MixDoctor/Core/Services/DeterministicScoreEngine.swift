//
//  DeterministicScoreEngine.swift
//  MixDoctor
//
//  Deterministic, testable mix scoring computed entirely in Swift.
//
//  WHY THIS EXISTS
//  ---------------
//  The current system asks Claude to produce the *number*, then uses Swift to
//  police that number (caps, contradiction suppression, genre overrides). That
//  makes the score non-deterministic: the same track can score differently when
//  re-analyzed or when the genre label is toggled.
//
//  This engine inverts the design: CODE decides the score, the LLM only explains
//  it. Same input → same score, every time. It is pure (no I/O), so it is fully
//  unit-testable against a ground-truth set of reference tracks.
//
//  It reuses the EXACT rubric encoded in the existing Claude prompts
//  (baselines, genre thresholds, penalties, bonuses, caps) so its output is
//  directly comparable to the current LLM scores. See ClaudeAPIService for the
//  prompt sources this mirrors.
//

import Foundation

// MARK: - Track Type

/// Which scoring track applies. Mirrors the three prompt variants in
/// `getSystemPrompt(isMastered:isUnmixed:...)`.
enum ScoringTrackType: String {
    case mastered      // 0–100, professional commercial quality
    case preMaster     // ≤90,   mix ready for a mastering engineer
    case unmixed       // ≤75,   raw multitrack, needs mixing

    var baseline: Double {
        switch self {
        // NOTE: the Claude prompt starts mastered tracks at 120 and caps at 100.
        // That creates a 20-point DEAD ZONE — a clipping master can lose 15 points
        // and still score 100, so faults become invisible and everything bunches
        // at 90–100 (the core "can't differentiate" complaint). We start a clean
        // master at 92 instead: bonuses still reach 100 for excellent work, but a
        // real fault drops the score immediately and visibly.
        case .mastered:  return 92
        case .preMaster: return 65
        case .unmixed:   return 65
        }
    }

    var maxScore: Double {
        switch self {
        case .mastered:  return 100
        case .preMaster: return 90
        case .unmixed:   return 75
        }
    }

    var minScore: Double { 0 }
}

// MARK: - Genre Profile

/// Genre-specific target ranges. Values mirror the genre tables in the mastered
/// and pre-master prompts and the genre-aware thresholds in AudioKitService.
/// A `ClosedRange` is the "excellent" band; metrics inside it earn bonuses and
/// avoid penalties.
struct GenreProfile {
    let name: String

    /// Excellent integrated-loudness band (LUFS) for a *mastered* track.
    let masteredLoudness: ClosedRange<Double>
    /// Excellent dynamic-range band (dB) for a *mastered* track.
    let masteredDynamicRange: ClosedRange<Double>

    /// Target integrated-loudness band (LUFS) for a *pre-master* mix.
    let preMasterLoudness: ClosedRange<Double>
    /// Target dynamic-range band (dB) for a *pre-master* mix.
    let preMasterDynamicRange: ClosedRange<Double>

    /// Minimum acceptable phase correlation (-1…1). Below this is penalized.
    let minPhaseCoherence: Double
    /// Minimum acceptable mono compatibility (0…1).
    let minMonoCompatibility: Double
    /// Acceptable stereo-width band (% as 0…100+).
    let stereoWidth: ClosedRange<Double>

    // Default / fallback profile (conservative).
    static let `default` = GenreProfile(
        name: "Default",
        masteredLoudness: -16 ... -8,
        masteredDynamicRange: 6 ... 14,
        preMasterLoudness: -24 ... -16,
        preMasterDynamicRange: 8 ... 16,
        minPhaseCoherence: 0.35,
        minMonoCompatibility: 0.45,
        stereoWidth: 25 ... 60
    )
}

// MARK: - Genre Resolution

/// Maps a free-text genre string (user-selected or auto-detected) to a profile.
/// Uses substring matching so labels like "Rock/Metal" resolve correctly.
enum ScoringGenreResolver {
    static func profile(for genre: String?) -> GenreProfile {
        guard let g = genre?.lowercased(), !g.isEmpty else { return .default }

        func has(_ keys: [String]) -> Bool { keys.contains { g.contains($0) } }

        if has(["metal", "hard rock", "punk"]) {
            // Metal: DR 4–8 is INDUSTRY STANDARD, loud masters are intentional.
            return GenreProfile(
                name: "Metal/Hard Rock",
                masteredLoudness: -10 ... -6,
                masteredDynamicRange: 4 ... 10,
                preMasterLoudness: -18 ... -14,
                preMasterDynamicRange: 8 ... 14,
                minPhaseCoherence: 0.40, minMonoCompatibility: 0.40, stereoWidth: 15 ... 100
            )
        }
        if has(["edm", "electronic", "dance", "house", "techno", "dubstep"]) {
            return GenreProfile(
                name: "Electronic/EDM",
                masteredLoudness: -9 ... -6,
                masteredDynamicRange: 3 ... 10,
                preMasterLoudness: -20 ... -14,
                preMasterDynamicRange: 6 ... 12,
                minPhaseCoherence: 0.50, minMonoCompatibility: 0.40, stereoWidth: 15 ... 40
            )
        }
        if has(["hip", "rap", "trap", "r&b", "rnb"]) {
            return GenreProfile(
                name: "Hip-Hop/Trap/R&B",
                masteredLoudness: -9 ... -6,
                masteredDynamicRange: 3 ... 10,
                preMasterLoudness: -18 ... -14,
                preMasterDynamicRange: 6 ... 12,
                minPhaseCoherence: 0.50, minMonoCompatibility: 0.50, stereoWidth: 10 ... 35
            )
        }
        if has(["pop"]) {
            return GenreProfile(
                name: "Pop",
                masteredLoudness: -10 ... -7,
                masteredDynamicRange: 5 ... 10,
                preMasterLoudness: -20 ... -16,
                preMasterDynamicRange: 7 ... 12,
                minPhaseCoherence: 0.45, minMonoCompatibility: 0.50, stereoWidth: 25 ... 55
            )
        }
        if has(["classical", "orchestral", "orchestra", "symphony"]) {
            return GenreProfile(
                name: "Classical/Orchestral",
                masteredLoudness: -23 ... -16,
                masteredDynamicRange: 10 ... 22,
                preMasterLoudness: -28 ... -18,
                preMasterDynamicRange: 12 ... 24,
                minPhaseCoherence: 0.20, minMonoCompatibility: 0.40, stereoWidth: 40 ... 95
            )
        }
        if has(["jazz", "blues"]) {
            return GenreProfile(
                name: "Jazz/Blues",
                masteredLoudness: -18 ... -12,
                masteredDynamicRange: 10 ... 18,
                preMasterLoudness: -24 ... -16,
                preMasterDynamicRange: 11 ... 20,
                minPhaseCoherence: 0.20, minMonoCompatibility: 0.35, stereoWidth: 30 ... 90
            )
        }
        if has(["acapella", "a capella", "a cappella", "vocal"]) {
            return GenreProfile(
                name: "Acapella/Vocal",
                masteredLoudness: -16 ... -12,
                masteredDynamicRange: 9 ... 14,
                preMasterLoudness: -26 ... -18,
                preMasterDynamicRange: 10 ... 18,
                minPhaseCoherence: 0.25, minMonoCompatibility: 0.50, stereoWidth: 10 ... 60
            )
        }
        if has(["acoustic", "folk", "singer", "songwriter", "country"]) {
            return GenreProfile(
                name: "Acoustic/Folk",
                masteredLoudness: -18 ... -12,
                masteredDynamicRange: 9 ... 16,
                preMasterLoudness: -28 ... -18,
                preMasterDynamicRange: 10 ... 20,
                minPhaseCoherence: 0.25, minMonoCompatibility: 0.35, stereoWidth: 20 ... 60
            )
        }
        if has(["live"]) {
            return GenreProfile(
                name: "Live",
                masteredLoudness: -16 ... -12,
                masteredDynamicRange: 10 ... 16,
                preMasterLoudness: -24 ... -16,
                preMasterDynamicRange: 11 ... 22,
                minPhaseCoherence: 0.15, minMonoCompatibility: 0.25, stereoWidth: 30 ... 95
            )
        }
        if has(["rock", "indie", "alternative"]) {
            return GenreProfile(
                name: "Rock/Indie",
                masteredLoudness: -12 ... -8,
                masteredDynamicRange: 6 ... 14,
                preMasterLoudness: -20 ... -16,
                preMasterDynamicRange: 8 ... 16,
                minPhaseCoherence: 0.40, minMonoCompatibility: 0.45, stereoWidth: 15 ... 95
            )
        }
        return .default
    }
}

// MARK: - Score Result

/// One line item in the score breakdown — makes every point fully traceable.
struct ScoreAdjustment {
    enum Kind { case penalty, bonus }
    let kind: Kind
    let points: Double      // always positive magnitude
    let reason: String
}

/// The deterministic result. `score` is the only number shown to users; the
/// rest exists so you can audit *why* and feed the LLM an explanation prompt.
struct DeterministicScoreResult {
    let score: Int
    let trackType: ScoringTrackType
    let genre: String
    let adjustments: [ScoreAdjustment]
    let rawScoreBeforeCap: Double

    var penalties: [ScoreAdjustment] { adjustments.filter { $0.kind == .penalty } }
    var bonuses: [ScoreAdjustment] { adjustments.filter { $0.kind == .bonus } }

    /// Human-readable trace for debugging / regression diffs.
    var breakdown: String {
        var lines = ["TRACK TYPE: \(trackType.rawValue)  |  GENRE: \(genre)",
                     "BASELINE: \(Int(trackType.baseline))"]
        for a in adjustments {
            let sign = a.kind == .penalty ? "-" : "+"
            lines.append("  \(sign)\(Int(a.points))  \(a.reason)")
        }
        lines.append("RAW: \(String(format: "%.0f", rawScoreBeforeCap))  →  CAPPED: \(score) (max \(Int(trackType.maxScore)))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Engine

/// Pure, deterministic mix scorer. No singletons, no I/O — construct and call.
struct DeterministicScoreEngine {

    /// Compute a score from DSP metrics, the resolved track type, and genre.
    /// - Parameters:
    ///   - metrics: the same metrics already gathered for the Claude path.
    ///   - trackType: mastered / preMaster / unmixed (resolved from user stage + detection).
    func score(_ metrics: AudioMetricsForClaude, trackType: ScoringTrackType) -> DeterministicScoreResult {
        let profile = ScoringGenreResolver.profile(for: metrics.genre)
        var adjustments: [ScoreAdjustment] = []

        switch trackType {
        case .mastered, .preMaster:
            adjustments = scoreMixOrMaster(metrics, trackType: trackType, profile: profile)
        case .unmixed:
            adjustments = scoreUnmixed(metrics)
        }

        let delta = adjustments.reduce(0.0) { acc, a in
            acc + (a.kind == .bonus ? a.points : -a.points)
        }
        let raw = trackType.baseline + delta
        let capped = min(trackType.maxScore, max(trackType.minScore, raw))

        return DeterministicScoreResult(
            score: Int(capped.rounded()),
            trackType: trackType,
            genre: profile.name,
            adjustments: adjustments,
            rawScoreBeforeCap: raw
        )
    }

    // MARK: Mastered + Pre-Master rubric

    private func scoreMixOrMaster(_ m: AudioMetricsForClaude,
                                  trackType: ScoringTrackType,
                                  profile: GenreProfile) -> [ScoreAdjustment] {
        var adj: [ScoreAdjustment] = []

        let loudnessBand = trackType == .mastered ? profile.masteredLoudness : profile.preMasterLoudness
        let drBand = trackType == .mastered ? profile.masteredDynamicRange : profile.preMasterDynamicRange

        // ---- Universal penalties (genre-independent technical faults) ----
        if m.hasClipping || m.peakLevel > 0.0 {
            adj.append(.init(kind: .penalty, points: trackType == .mastered ? 15 : 6,
                             reason: "Clipping / peak above 0 dBFS"))
        } else if m.truePeakLevel > 0.0 {
            adj.append(.init(kind: .penalty, points: 10, reason: "True peak above 0 dBTP"))
        } else if m.peakLevel > -1.0 {
            adj.append(.init(kind: .penalty, points: 1, reason: "Peak hotter than -1 dBFS"))
        }

        // Phase / mono — scaled by how far below the genre minimum.
        if m.phaseCoherence < 0.2 {
            adj.append(.init(kind: .penalty, points: 12, reason: "Severe phase incoherence (<0.2)"))
        } else if m.phaseCoherence < profile.minPhaseCoherence {
            adj.append(.init(kind: .penalty, points: 5,
                             reason: "Phase below genre minimum (\(fmt(profile.minPhaseCoherence)))"))
        }

        if m.monoCompatibility < 0.3 {
            adj.append(.init(kind: .penalty, points: trackType == .mastered ? 15 : 5,
                             reason: "Poor mono compatibility (<30%)"))
        } else if m.monoCompatibility < profile.minMonoCompatibility {
            adj.append(.init(kind: .penalty, points: 2,
                             reason: "Mono below genre minimum (\(Int(profile.minMonoCompatibility * 100))%)"))
        }

        // Loudness vs genre target.
        if !loudnessBand.contains(m.integratedLoudness) {
            let distance = rangeDistance(m.integratedLoudness, loudnessBand)
            let pts = min(8.0, max(3.0, distance))   // 3–8 pts by how far off
            adj.append(.init(kind: .penalty, points: pts,
                             reason: "Loudness \(fmt(m.integratedLoudness)) LUFS outside target \(fmtRange(loudnessBand))"))
        }

        // Dynamic range vs genre target.
        if !drBand.contains(m.dynamicRange) {
            adj.append(.init(kind: .penalty, points: 4,
                             reason: "Dynamic range \(fmt(m.dynamicRange)) dB outside target \(fmtRange(drBand))"))
        }

        // Severe frequency imbalance (one band dominating). Only SEVERE, per prompt.
        let bands = [m.lowEnd, m.lowMid, m.mid, m.highMid, m.high]
        if let maxBand = bands.max(), maxBand > 80 {
            adj.append(.init(kind: .penalty, points: 5,
                             reason: "Severe frequency imbalance (\(fmt(maxBand))% in one band)"))
        }

        // ---- Bonuses (reward hitting genre targets cleanly) ----
        if !m.hasClipping && loudnessBand.contains(m.integratedLoudness) {
            adj.append(.init(kind: .bonus, points: 8, reason: "Clean + loudness in target"))
        }
        if m.phaseCoherence >= profile.minPhaseCoherence {
            adj.append(.init(kind: .bonus, points: 5, reason: "Phase coherence healthy"))
        }
        if m.monoCompatibility >= profile.minMonoCompatibility {
            adj.append(.init(kind: .bonus, points: 3, reason: "Mono compatibility healthy"))
        }
        if drBand.contains(m.dynamicRange) {
            adj.append(.init(kind: .bonus, points: 5, reason: "Dynamic range in target"))
        }
        if profile.stereoWidth.contains(m.stereoWidth) {
            adj.append(.init(kind: .bonus, points: 3, reason: "Stereo width appropriate for genre"))
        }

        // Pre-master safety valve: the prompt caps total penalties at 8 so a
        // promising mix isn't buried. We replicate that here for parity.
        if trackType == .preMaster {
            let totalPenalty = adj.filter { $0.kind == .penalty }.reduce(0) { $0 + $1.points }
            if totalPenalty > 8 {
                let removed = totalPenalty - 8
                adj.append(.init(kind: .bonus, points: removed,
                                 reason: "Pre-master penalty cap (max 8 total penalty)"))
            }
        }

        return adj
    }

    // MARK: Unmixed rubric

    private func scoreUnmixed(_ m: AudioMetricsForClaude) -> [ScoreAdjustment] {
        var adj: [ScoreAdjustment] = []

        // Penalties — only genuine recording faults (NOT lack of mixing).
        if m.hasClipping || m.peakLevel > 0.0 {
            adj.append(.init(kind: .penalty, points: 20, reason: "Clipping / distortion (recording damaged)"))
        }
        if m.phaseCoherence < 0.2 {
            adj.append(.init(kind: .penalty, points: 15, reason: "Severe phase issues (mic placement)"))
        }
        let bands = [m.lowEnd, m.lowMid, m.mid, m.highMid, m.high]
        if let maxBand = bands.max(), maxBand > 80 {
            adj.append(.init(kind: .penalty, points: 10, reason: "Complete frequency imbalance (>80% one band)"))
        }
        if m.peakLevel < -12.0 {
            adj.append(.init(kind: .penalty, points: 10, reason: "Under-recorded (peak <-12 dBFS)"))
        }
        if m.monoCompatibility < 0.4 {
            adj.append(.init(kind: .penalty, points: 5, reason: "Poor mono compatibility (<40%)"))
        }

        // Bonuses — reward clean capture (never push past the 75 cap).
        if !m.hasClipping && m.peakLevel <= 0.0 {
            adj.append(.init(kind: .bonus, points: 5, reason: "Clean capture (no clipping)"))
        }
        if m.peakLevel >= -6.0 && m.peakLevel <= -3.0 {
            adj.append(.init(kind: .bonus, points: 5, reason: "Good peak levels (-3 to -6 dBFS)"))
        }
        if m.phaseCoherence > 0.4 {
            adj.append(.init(kind: .bonus, points: 3, reason: "Reasonable phase (>40%)"))
        }

        return adj
    }

    // MARK: Helpers

    private func rangeDistance(_ v: Double, _ r: ClosedRange<Double>) -> Double {
        if v < r.lowerBound { return r.lowerBound - v }
        if v > r.upperBound { return v - r.upperBound }
        return 0
    }
    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
    private func fmtRange(_ r: ClosedRange<Double>) -> String {
        "\(fmt(r.lowerBound))…\(fmt(r.upperBound))"
    }
}
