# Current Feature: Fix Scoring System

## Status

In Progress

## Goals

- Replace the old contradictory scoring rules with a clean **BaseScore + Bonuses − Penalties** formula
  - Master: `min(100, max(0, 75 + bonuses − penalties))`
  - Pre-master/Mix: `min(90, max(0, 65 + bonuses − penalties))`
- Implement **9 genre groups** with per-metric Excellent / Acceptable / Penalize threshold tables: Metal/Hard Rock, Electronic/EDM, Hip-Hop/Trap/R&B, Pop, Rock/Indie, Classical/Orchestral, A Cappella/Vocal, Jazz, Live
- Implement **universal bonuses** (apply when metric is in Excellent range for genre):
  - +8 pts: no clipping AND loudness in Excellent range
  - +5 pts: phase coherence in Excellent range
  - +3 pts: mono compatibility in Excellent range
  - +5 pts: dynamic range in Excellent range
- Implement **universal penalties** (apply regardless of genre):
  - −15 pts: clipping (peak > 0 dBFS)
  - −10 pts: true peak > 0.0 dBTP
  - −12 pts: phase coherence < 0.2
  - −15 pts: mono cancellation of key element
  - −5 pts per metric: any metric in the genre's Penalize range
- Fix Metal/Hard Rock scoring: DR 4–6 and loudness −6 to −8 LUFS are genre-normal — never penalize
- Make `getUserMessage` genre-aware: skip `hasFrequencyImbalance` / `hasDynamicRangeIssues` flags for Metal/EDM; raise `lowEnd` threshold to 70% for Metal
- Pre-master cap at 90; master cap at 100 — no conflicting floor rules

## Notes

- Core principle from spec: LUFS is a result, not a goal. Score against the genre's own standard, not a universal baseline
- Reference scores (sanity check):
  - Korn "Twisted Transistor" (Metal, Master): 87–93
  - Metallica "Enter Sandman" (Metal, Master): 82–88
  - Daft Punk "Get Lucky" (EDM/Pop, Master): 88–94
  - Billie Eilish "Bad Guy" (Pop, Master): 85–92
  - Bach Cello Suite No.1 (Classical, Master): 90–96
  - Miles Davis "Kind of Blue" (Jazz, Master): 88–94
  - Professional rock pre-master: 82–88
  - Good amateur pop pre-master: 72–80
  - Amateur mix with clipping: 35–55
- Cache version bumped to `v12.0-METAL-GENRE-OVERRIDE` to force fresh Claude responses
- `createMasteredTrackPrompt` and `createPreMasterPrompt` are dead code — the active path is `getSystemPrompt` + `getUserMessage`

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.

- **Fix "Could Not Read Any Frequencies" Intermittent Error** — Investigated AVFoundation audio reading pipeline and async timing issues; adjusted cache key usage and enhanced FFT analysis error handling to resolve intermittent failure on same audio file.

- **Fix Prompt & Scoring Issues** — Added `validateMetrics` guard, `AudioAnalysisError` enum, genre-aware scoring adjustments for electronic/acoustic/rock baselines, fixed scoring contradictions in mastered track and pre-master prompts.
