# Current Feature: Fix "Could Not Read Any Frequencies" Intermittent Error

## Status

In Progress

## Goals

- Identify why users intermittently get "could not read any frequencies from the file" on the same audio file
- Determine if the error is mode-specific (Final Mix vs Mastering) rather than file-specific
- Investigate the AVFoundation audio reading pipeline as the primary suspect
- Check for race conditions or async timing issues in the audio processing pipeline
- Handle edge cases with heavily limited/clipped electronic tracks (very high LUFS, brick-wall limiting)
- Check if the Claude API prompt differs between modes and whether one mode requests data that fails to extract

## Notes

- Known user context: Electronic music (heavy bass, heavy limiting, loud LUFS), checking volume levels for release readiness
- User was switching between "Final Mix" and "Mastering" modes on the same file
- File type not yet confirmed (WAV/MP3/AIFF?)
- Stack: SwiftUI + AVFoundation + AudioKit + Claude API (claude-sonnet-4-20250514) + RevenueCat + Firebase Analytics
- Focus areas in order: AVFoundation pipeline → mode-specific logic → async timing → Claude prompt differences per mode

## History

<!-- Keep this updated. Earliest to latest -->

- **Fix AI Analysis Frequency Data Passed as Zeros** — `result.lowEndBalance` etc. were sourced from `performAudioKitFFT` which only analyzed the first 4096 samples; replaced with `spectralBalance.*` values (loudest-window analysis) so Claude receives correct non-zero frequency data.

- **Shorten AI Analysis Text to 3-5 Sentence Summary** — Updated Claude API prompt in `ClaudeAPIService.swift` to output a concise 3–5 sentence narrative instead of verbose per-metric line-by-line breakdown.
