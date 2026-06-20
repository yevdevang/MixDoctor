# Current Feature: Mix Version History Timeline

## Status

Complete

## Goals

- Add a "History" section to `ResultsView` that appears when `audioFile.analysisHistory` is non-empty
- Show a Swift Charts line chart of `overallScore` over time (x = `dateAnalyzed`, y = score 0–100)
- Below the chart, list each past result as a row: date, score badge, mix stage label
- Tapping a past result row opens a detail sheet showing that `AnalysisResult`'s full metrics (score, LUFS, dynamic range, stereo width, phase coherence, AI summary if stored)
- Section is hidden entirely on first analysis (empty history) — no empty state needed

## Notes

- `analysisHistory: [AnalysisResult]` is already in `AudioFile` (`AudioFile.swift:32-33`), cascade-deleted with parent
- History is populated in `ResultsView.swift:2440-2446` — the existing result is appended before overwrite on re-analysis; **no changes to the append logic needed**
- `AnalysisResult` key fields: `dateAnalyzed: Date`, `overallScore: Double`, `claudeScore: Int?`, `aiSummary: String?`, `mixStage` (from parent `AudioFile`), plus all DSP metrics
- `Charts` is already imported in `PAZFrequencyAnalyzer.swift` — reuse the same import, no new dependency
- Add the History section after the overall score card in `ResultsView` (~line 193 action buttons area) as a new `historySection` `@ViewBuilder`
- Sort history by `dateAnalyzed` ascending for the chart (oldest → newest), descending for the list (newest first)
- The detail sheet can be a new `AnalysisHistoryDetailView` — a lightweight read-only view (no re-analyze button), reusing metric card components already in `ResultsView`
- Keep the section self-contained: `private var historySection: some View` + `AnalysisHistoryDetailView` in the same file or a new file under `Features/Analysis/Views/`
- The mix stage label to display: map `audioFile.mixStage` string → human-readable ("Mix", "Master (Streaming)", "Master (CD)") using the existing helper if one exists, otherwise inline mapping

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.

- **Fix "Could Not Read Any Frequencies" Intermittent Error** — Investigated AVFoundation audio reading pipeline and async timing issues; adjusted cache key usage and enhanced FFT analysis error handling to resolve intermittent failure on same audio file.

- **Fix Prompt & Scoring Issues** — Added `validateMetrics` guard, `AudioAnalysisError` enum, genre-aware scoring adjustments for electronic/acoustic/rock baselines, fixed scoring contradictions in mastered track and pre-master prompts.

- **Fix Scoring System** — Replaced contradictory scoring rules with BaseScore + Bonuses − Penalties formula, 9 genre groups with per-metric thresholds, universal bonuses/penalties, Metal/Hard Rock scoring fix, pre-master cap at 90 / master cap at 100.

- **Fix Mislabeled Master Shown as Unmixed** — When `professionalMasterOverride = true`, show "Detected as Master" label instead of "Unmixed - Needs Processing" in `scoreDescription()`, and assign a proper master-level score.

- **Mix Version History Timeline** — Added `AnalysisHistoryView.swift` with `AnalysisHistorySectionView` (score timeline chart + tappable past-result rows) and `AnalysisHistoryDetailSheet` (read-only metrics + AI summary for a past result). History section appears automatically in `ResultsView` after any re-analysis. Added "Upload New Version" button that lets the user replace the underlying audio file (copies new file, archives current result to history, triggers re-analysis) — enabling score progression tracking across mix revisions.
