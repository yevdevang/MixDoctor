# Current Feature: Shorten AI Analysis Text to 3-5 Sentence Summary

## Status

Complete

## Goals

- The AI "Analysis" section must output a concise 3–5 sentence summary, not a long technical breakdown
- The summary should be meaningful and human-readable — covering overall quality, key strengths, and main concern(s)
- Remove the verbose per-metric repetition (e.g. "Stereo Width: 89.5% Excellent stereo image... Phase Correlation: 74.0% Strong phase coherence...")
- The individual metric cards (Stereo Width, Phase Coherence, etc.) already show those details — the Analysis text should give a holistic picture, not repeat them

## Notes

- From the screenshot: the current output dumps raw metric commentary line by line ("TECHNICAL METRICS Stereo Width: 89.5%...", "Phase Correlation: 74.0%...", "FREQUENCY ANALYSIS...") — this is very long and redundant
- The fix is in the Claude API prompt instructions in `ClaudeAPIService.swift` — the system/user prompt needs to explicitly instruct Claude to respond with a short 3–5 sentence paragraph summary
- The individual metric details are already shown in dedicated UI cards; the Analysis text should be a higher-level narrative

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.
