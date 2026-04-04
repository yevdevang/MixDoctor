# Fix AI Analysis: Frequency Data Passed as Zeros Instead of Actual Values

## Overview

The AI analysis text describes "absolutely no frequency content across the entire spectrum - every band shows 0%", but the UI correctly displays real frequency band values (Sub Bass 71.7%, Bass 81.9%, Low Mid 30.9%, etc.). The actual measured data is not being passed to the AI prompt — zeros are sent instead.

## Root Cause

The frequency band percentages shown in the Frequency Analyzer section are calculated and displayed correctly in the UI, but when building the prompt payload sent to the Claude API, the frequency distribution values are either:
- Not yet computed at the time the prompt is assembled
- Read from an uninitialized or default-zero state
- Pulled from a different data model instance than the one bound to the UI

## Requirements

- Ensure the AI prompt is assembled **after** all audio analysis values are fully computed and available
- Pass the actual frequency band values into the prompt:  
  Sub Bass, Bass, Low Mid, Mid, High Mid, Presence, Air percentages
- Include Dynamic Range, Peak, RMS, Loudness (LUFS), Stereo Width, Phase Coherence, and Mono Compatibility values in the prompt payload
- Add a debug log before the API call to verify all values are non-zero before sending
- Do **not** call the AI analysis until the `AnalysisResult` model is fully populated