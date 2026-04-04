# Current Feature: Fix Prompt & Scoring Issues

## Status

In Progress

## Goals

- Add a `validateMetrics(_ metrics: AudioMetricsForClaude) throws` guard before either prompt is built, throwing on physically implausible or all-zero metrics
- Define a clear `AudioAnalysisError` enum with meaningful cases for validation failures
- Add genre-aware scoring adjustments to both `createMasteredTrackPrompt` and `createPreMasterPrompt` (electronic/EDM/hip-hop vs acoustic/classical vs rock/pop baselines)
- Fix scoring contradictions in the mastered track prompt: raise base to 85, cap at 100, add explicit `min(100, max(0, ...))` rule
- Fix scoring contradictions in the pre-master prompt: remove the "min score 80" floor, clarify penalty rule as "apply ALL applicable penalties, cap total at 8 points"

## Notes

- Two prompt functions to fix: `createMasteredTrackPrompt(metrics:genre:)` and `createPreMasterPrompt(from:genre:)`
- Genre norms: Electronic (-8 to -6 LUFS normal, 40-60% low end normal), Acoustic/Classical (-20 to -16 LUFS normal, 15-25% low end), Rock/Pop (default baseline)
- Validation rules: loudness -70…0 LUFS, peakLevel -60…0 dBFS, stereoWidth 0…100%, phaseCoherence -1.0…1.0, dynamicRange 0…60 dB; all-zeros → throw error
- Keep existing prompt structure and response format (SCORE / ANALYSIS / RECOMMENDATIONS) unchanged
- iOS 16+ minimum target, SwiftUI/SwiftData codebase
- Show before/after for any code changes; flag if fixes could affect other parts of the app

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.

- **Fix "Could Not Read Any Frequencies" Intermittent Error** — Investigated AVFoundation audio reading pipeline and async timing issues; adjusted cache key usage and enhanced FFT analysis error handling to resolve intermittent failure on same audio file.
