# Current Feature: Spectrogram-Based Claude Analysis

## Status

In Progress

## Goals

- Generate a true spectrogram (time × frequency × magnitude image) from the imported audio file — not the single-frame FFT snapshot the app produces today
- Send that spectrogram image to Claude (via the Messages API image/vision content block) instead of the current numeric-metrics-as-text prompt, so Claude reasons over the visual the way a sound engineer would
- Replace the frequency chart in the Results screen with the actual spectrogram image, so users see the same picture Claude analyzed
- Rewrite the Claude system/user prompts to describe and reference a spectrogram image instead of walking through numeric metric values
- Keep this additive: the existing DSP metrics pipeline (`AudioMetricsForClaude`) must keep working as-is for the on-device `DeterministicScoreEngine` fallback scorer and other non-Claude consumers (dashboard/import warning badges, PDF/JSON export, band-summary bars) — don't delete or restructure it just because Claude stops consuming it directly
- Try this as an experiment — approach/prompt design may need iteration once real spectrograms are seen by Claude

## Notes

**Why (user's framing):** current approach sends Claude a text dump of ~35 numeric fields; the user wants to try sending a spectrogram image instead since it's how sound engineers actually read a mix, and may be clearer/more accurate for Claude too. Longer-term (explicitly out of scope now, don't design against it): the user may eventually drop Claude entirely in favor of an on-device Core ML model — keep the spectrogram-generation step decoupled from `ClaudeAPIService` so it could feed a Core ML model later instead.

**1. Claude API integration — `MixDoctor/Core/Services/ClaudeAPIService.swift` (2109 lines)**
- Request body (lines 216–228) is a `[String: Any]` dict with `"messages": [["role": "user", "content": userMessage]]` where `content` is a bare `String` — the old text-only shorthand. No image content-block usage anywhere in the file (`base64`/`image`/`source_type` all zero hits). To send an image, `content` needs to become an array of blocks: one `{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": ...}}` block plus a `{"type": "text", "text": ...}` block.
- `getUserMessage(metrics:genre:isMastered:)` (lines 1212–1327) is the function that currently embeds numeric metrics as text (e.g. stereo width %, LUFS, frequency band %) — this is the primary rewrite target.
- `getSystemPrompt(isMastered:isUnmixed:genre:mixStage:)` (lines 591–~1210) and `getGenreFrequencyGuidelines(genre:metrics:)` (lines 465–589) also assume/render numeric thresholds and would need rewriting to describe what to look for in a spectrogram image instead (or alongside minimal numeric context — TBD during design).
- `determineModel(isProUser:)` (lines 282–286) — both current models (Sonnet 4.5 / Haiku 4.5) already support vision, so no model change is required for this feature.
- `validateMetrics(_:)` (line 1331+) validates the numeric struct pre-send; needs reconsideration if numeric metrics become secondary/optional in the Claude request.

**2. Current frequency chart UI to replace**
- `MixDoctor/Features/Analysis/Views/PAZFrequencyAnalyzer.swift` (964 lines): `PAZFrequencyAnalyzer` (line 11) takes `result.frequencySpectrum`/`result.spectrumSampleRate`; `FrequencyChart` (line 391) renders `SpectrumCanvasView` from `SpectrumImageGenerator.swift`; `SpectrumCurve` (line 492) is a Swift-Charts-based alternate rendering (`LineMark` at 548–550). Band bars/insights (`FrequencyChartBar`, `FrequencyBandDetail`, `PAZAnalysisInsights`) are derived from the 5-band percentages, not the raw spectrum — those can likely stay since they're independent of the image swap.
- `MixDoctor/Features/Analysis/Views/ResultsView.swift:199` instantiates `PAZFrequencyAnalyzer(result: result)`; lines 616–617 also read `result.frequencySpectrum`/`spectrumSampleRate` directly.
- Don't touch `AnalysisHistoryView.swift` — its Swift Charts usage is an unrelated score-over-time timeline.

**3. No spectrogram generator exists yet — must be built**
- Nothing today produces a real time×frequency image. `SpectrumImageGenerator.swift` (159 lines) despite its name only draws a single-frame spectrum line chart as a SwiftUI `Canvas` view (not rasterized to `UIImage`, not multi-frame).
- Closest existing building block: `AudioKitService.swift` `analyzeSpectralBalance(...)` (~2570–2731) already loops over multiple time-windows (`topWindows`, line 2609) and runs `performFFTAnalysis` (line 611, Hann-windowed vDSP FFT, `fftSize = 2048`) per window — but it immediately averages per-band energy into percentages (2622–2649) and discards the per-window data. The new STFT step needs to retain the full per-window magnitude matrix instead of collapsing it.
- New work required: (a) an STFT loop producing a 2D magnitude array (time × frequency), (b) a magnitude→dB→color mapping and image rasterizer (likely `CGContext`/`vImage` for performance over full-length tracks — a per-pixel SwiftUI `Canvas` would be too slow), (c) PNG encoding sized appropriately both for Claude's vision API (image size affects token cost) and for on-screen display. `vImage` is not used anywhere in the codebase today.

**4. Data model changes — `MixDoctor/Core/Models/AudioFile.swift`**
- `AnalysisResult` (line 125) already has the CloudKit-safe large-array pattern for `frequencySpectrum` (`@Transient` computed property at 182–202, backed by `frequencySpectrumData: Data?` at line 203) — CLAUDE.md's documented rule.
- A spectrogram image fits the same pattern: add `var spectrogramImageData: Data?` (PNG bytes; `Data` itself is CloudKit-safe, no `@Transient` wrapper needed — that's only required for `[Float]`/custom arrays). Optionally add a `@Transient var spectrogramImage: UIImage?` convenience accessor mirroring the `frequencySpectrum` getter/setter style.
- Watch CloudKit per-asset size limits for full-track spectrogram PNGs — consider `@Attribute(.externalStorage)` (not used anywhere in the model currently) or a fixed downsampled image size.

**5. Coexistence / don't-break list**
- `DeterministicScoreEngine.swift` (`score`/`scoreMixOrMaster`/`scoreUnmixed`, lines 258/286/374) — on-device fallback scorer, reuses `AudioMetricsForClaude` directly. Must keep receiving real numeric metrics regardless of what Claude gets.
- `AnalysisResultPersistence.swift` — `resultToDictionary`/`resultFromDictionary` (lines 214/251) serialize numeric fields + `frequencySpectrum`/`spectrumSampleRate` to iCloud JSON; a new `spectrogramImageData` field needs equivalent base64 (de)serialization, mirroring how `unmixedDetectionData` is base64-encoded (line 247).
- `ExportService.swift` — PDF/JSON export reads numeric fields directly (e.g. line 115, 280 `result.lowEndBalance`); likely want the spectrogram image embedded in exports too eventually, but numeric lines should stay for now.
- `AudioAnalysisService.swift:275,280` computes `result.lowEndBalance` etc. — upstream DSP, unaffected.
- `DashboardView.swift:521` / `ImportView.swift:1220` — frequency-issue badge logic reads `result.lowEndBalance` etc. directly — independent of this change.
- Tests constructing `AudioMetricsForClaude(...)` directly (one site each in `StageMismatchDetectionTests.swift`, `ClaudeAPIScoringTests.swift`, `ClaudeAPIScoringIntegrationTests.swift`, `ProfessionalMasterOverrideTests.swift`, `DeterministicScoreEngineTests.swift`) — unaffected unless the struct's shape changes, which this feature shouldn't require since the approach is additive.

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.

- **Fix "Could Not Read Any Frequencies" Intermittent Error** — Investigated AVFoundation audio reading pipeline and async timing issues; adjusted cache key usage and enhanced FFT analysis error handling to resolve intermittent failure on same audio file.

- **Fix Prompt & Scoring Issues** — Added `validateMetrics` guard, `AudioAnalysisError` enum, genre-aware scoring adjustments for electronic/acoustic/rock baselines, fixed scoring contradictions in mastered track and pre-master prompts.

- **Fix Scoring System** — Replaced contradictory scoring rules with BaseScore + Bonuses − Penalties formula, 9 genre groups with per-metric thresholds, universal bonuses/penalties, Metal/Hard Rock scoring fix, pre-master cap at 90 / master cap at 100.

- **Fix Mislabeled Master Shown as Unmixed** — When `professionalMasterOverride = true`, show "Detected as Master" label instead of "Unmixed - Needs Processing" in `scoreDescription()`, and assign a proper master-level score.

- **Mix Version History Timeline** — Added `AnalysisHistoryView.swift` with `AnalysisHistorySectionView` (score timeline chart + tappable past-result rows) and `AnalysisHistoryDetailSheet` (read-only metrics + AI summary for a past result). History section appears automatically in `ResultsView` after any re-analysis. Added "Upload New Version" button that lets the user replace the underlying audio file (copies new file, archives current result to history, triggers re-analysis) — enabling score progression tracking across mix revisions.
