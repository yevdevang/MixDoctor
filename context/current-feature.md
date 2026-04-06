# Current Feature: Fix Mislabeled Master Shown as Unmixed

## Status

Complete

## Goals

- When user labels a track as "Mix" but metrics strongly indicate a professional master (`professionalMasterOverride = true`), show a clear message like **"Detected as Master"** in the Overall Score section instead of "Unmixed - Needs Processing"
- The track should receive a proper master-level score (e.g. 85–92) rather than an "Unmixed" label
- `scoreDescription()` in `ResultsView.swift` must be aware of the `professionalMasterOverride` case and return an appropriate label
- The `AnalysisResult` model (or a computed property) must surface the `professionalMasterOverride` flag so the view can use it

## Notes

- The override flag is set in `ClaudeAPIService.swift` around line 184: `professionalMasterOverride = true`
- Currently `isUnmixed = false` is already set when override is active (line 213), but `isProfessionallyMixed` may still be `false`, causing `scoreDescription()` to fall into the "Unmixed" branch at line 1489
- `scoreDescription(_:isProfessionallyMixed:mixStage:)` in `ResultsView.swift:1484` — need to add a third signal for the mislabeled-master case
- The fix must NOT change how a genuine "Mix" stage with truly unmixed metrics is handled
- Check whether `AnalysisResult` already stores a flag like `detectedAsMaster` or if one needs to be added

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.

- **Fix "Could Not Read Any Frequencies" Intermittent Error** — Investigated AVFoundation audio reading pipeline and async timing issues; adjusted cache key usage and enhanced FFT analysis error handling to resolve intermittent failure on same audio file.

- **Fix Prompt & Scoring Issues** — Added `validateMetrics` guard, `AudioAnalysisError` enum, genre-aware scoring adjustments for electronic/acoustic/rock baselines, fixed scoring contradictions in mastered track and pre-master prompts.

- **Fix Scoring System** — Replaced contradictory scoring rules with BaseScore + Bonuses − Penalties formula, 9 genre groups with per-metric thresholds, universal bonuses/penalties, Metal/Hard Rock scoring fix, pre-master cap at 90 / master cap at 100.
