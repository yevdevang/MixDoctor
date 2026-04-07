# What's New

## Version 1.2.2 (since 1.2.1)

### New Features

- **Stage Mismatch Detection** — When the user selects "Mix" stage but the audio metrics clearly indicate a professional master (or vice versa), the app now detects the mismatch *before* calling the AI. Instead of producing a misleading score, it shows a "Detected as Master" / "Detected as Mix" indicator and prompts the user to switch the correct stage and re-analyze. Saves Claude API tokens and prevents confusing results.
- **Quick Stage Switching from Results Screen** — When a stage mismatch is detected, the Stage picker becomes editable directly in the Results view, with a dedicated "Analyze" button (instead of just "Delete File") so the user can fix and re-analyze in one step.
- **Smart Duplicate Handling on Import** — Importing the same audio file with a different stage now updates the existing entry instead of creating a duplicate. The app matches by file size + duration, so renamed copies of the same audio are caught too. No more two entries with conflicting scores for the same song.
- **Genre-Aware Scoring System** — Replaced the old contradictory scoring rules with a clean **BaseScore + Bonuses − Penalties** formula across **9 genre groups**: Metal/Hard Rock, Electronic/EDM, Hip-Hop/Trap/R&B, Pop, Rock/Indie, Classical/Orchestral, A Cappella/Vocal, Jazz, and Live. Each genre has per-metric Excellent / Acceptable / Penalize threshold tables.
- **Concise AI Analysis Summaries** — Claude responses are now formatted as a 3–5 sentence narrative summary instead of verbose per-metric line-by-line breakdowns.

### Improvements

- **macOS Support** — Added proper macOS app icons and improved Mac Catalyst build configuration.
- **Delete Confirmation Everywhere** — Added "Are you sure?" alerts to *all* file deletion paths: swipe-to-delete and trash buttons in Dashboard, Import, and Results views. Previously some paths deleted instantly without warning.
- **Purple Stage Mismatch Indicator** — Tracks with a stage mismatch now display a purple icon and "Detected as Master/Mix" label in the Dashboard list (instead of a red "0 score"), and are excluded from the average score calculation.
- **Stereo Width Validation Fixed** — Previously rejected legitimate values above 100% (M/S encoding can produce values up to 150%), causing "Something went wrong" errors on certain tracks (especially acapella).
- **Audio-Only Unmixed Detection** — `isProfessionallyMixed` now relies solely on AudioKit's DSP unmixed detector. A low Claude score (e.g. 58/100) is no longer treated as "unmixed" — it's just a poor-quality mix.
- **Metal/Hard Rock Scoring Fix** — DR 4–6 dB and loudness −6 to −8 LUFS are now recognized as genre-normal for Metal and never penalized.

### Bug Fixes

- **Frequency Data Showing as Zero** — The AI was receiving zeroed-out frequency band values because `result.lowEndBalance` etc. were sourced from a 4096-sample window analysis. Now uses the loudest-window spectral balance for accurate values.
- **"Could Not Read Any Frequencies" Intermittent Error** — Fixed an async timing issue in the AVFoundation audio reading pipeline that caused intermittent FFT failures on the same audio file across attempts.
- **Metrics Validation** — Added a `validateMetrics` guard with a clear `AudioAnalysisError` enum that throws meaningful errors instead of silently passing zeroed/invalid metrics to Claude. Stereo width range raised to 0–150% to accept legitimate over-wide stereo.
- **Duplicate File Deletion Bug** — Fixed a case where re-importing a file with the same filename as an existing record would delete the existing record's physical file.
- **Mislabeled Master Showing as "Unmixed"** — Tracks where the user labeled "Mix" but metrics indicated a master no longer get the misleading "Unmixed" label.

### Internal

- Removed the `professionalMasterOverride` scoring branch — now handled cleanly by the upstream stage mismatch detection.
- Cache version bumped to `v12.0-METAL-GENRE-OVERRIDE` to force fresh Claude responses with the new scoring rules.
- Updated unit tests for the new scoring logic and `parseClaudeResponse` signature.
