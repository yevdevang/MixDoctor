# Unmixed Detection Fix - Phase Coherence & Score Threshold

## Problem
User reported that an unmixed track was showing as "Good Mix Quality" (score 72) with NO unmixed banner, despite having:
- **Phase Coherence: 36.2%** (critically poor - should never be this low in professional mix)
- **Stereo Width: 101.0%** (excessive)
- **2 issues detected**

The unmixed detection was **too conservative** and failed to catch this obviously unmixed track.

## Root Cause Analysis

### 1. Score Threshold Too Low
```swift
// BEFORE (line 288):
let isUnmixedByScore = claudeResponse.score < 60
```
- Only flagged tracks with score < 60 as unmixed
- Track with score 72 was considered "professional enough" ❌

### 2. Missing Phase Coherence Detection
- No direct check for severe phase coherence issues
- Phase coherence < 40% is ALWAYS a sign of unmixed/poorly recorded audio
- Professional mixes never have phase coherence this low

### 3. Overly Conservative Tier Detection
The 6-tier classification system was too lenient:
- Tier 4: "Amateur Mix" - accepted tracks with failedTests < 10
- Tier 5: "Pre-Master" - accepted tracks with decent mono compatibility
- Track was likely classified as one of these tiers, bypassing unmixed detection

## Solution

### 1. Raised Score Threshold
```swift
// AFTER (line 288):
let isUnmixedByScore = claudeResponse.score < 75  // Raised from 60 to 75
```
- Scores below 75 indicate amateur/unmixed quality
- More realistic threshold for unmixed detection

### 2. Added Severe Technical Issues Check
```swift
// NEW (lines 291-297):
let hasSevereTechnicalIssues = (
    result.phaseCoherence < 0.45 ||  // Poor phase coherence
    (result.stereoWidthScore > 95 && result.monoCompatibility < 0.75) ||  // Excessive width + poor mono
    result.dynamicRange > 20.0  // Uncompressed
)

result.isProfessionallyMixed = !(isUnmixedByDetection || isUnmixedByScore || hasSevereTechnicalIssues)
```

### 3. Added Phase Coherence Pattern to Unmixed Detection
```swift
// NEW Pattern 8 (line 3368):
let severePhaseIssues = phaseCoherence < 0.40
```

```swift
// Added to TIER 6 detection (line 3439):
let isTrulyUnmixed = (
    !isProfessionalDynamicMaster &&
    !isStreamingMaster &&
    !isAmateurMix &&
    !isPreMaster &&
    (
        extremeDynamicRange ||
        veryLowLoudness ||
        criticallyUnprocessed ||
        severePhaseIssues ||  // NEW: Catch poor phase coherence
        // ... other patterns
    )
)
```

### 4. Updated Fallback Logic (API Failure)
```swift
// AFTER (lines 309-315):
let hasSevereTechnicalIssues = (
    result.phaseCoherence < 0.45 ||
    (result.stereoWidthScore > 95 && result.monoCompatibility < 0.75) ||
    result.dynamicRange > 20.0
)
result.isProfessionallyMixed = !(result.unmixedDetection!.isLikelyUnmixed || hasSevereTechnicalIssues)
```

## Detection Criteria

### Unmixed Banner Will Show When ANY of These Are True:

1. **Score < 75**
   - Clearly amateur or unmixed quality

2. **Phase Coherence < 45%**
   - Professional mixes NEVER have phase this poor
   - Indicates phase cancellation, poor mic placement, or no mixing

3. **Excessive Width + Poor Mono**
   - Stereo Width > 95% AND Mono Compatibility < 75%
   - Indicates overly wide stereo with no mono checking

4. **Uncompressed Audio**
   - Dynamic Range > 20dB
   - Raw recordings have 18-25+ dB DR
   - Professional mixes: 6-16 dB DR (genre-dependent)

5. **Unmixed Detection Algorithm**
   - Failed 10+ technical tests
   - Extreme DR beyond genre norms
   - Very low loudness for genre
   - Critically unprocessed
   - Critical mono failure (< 30%)

## Expected Behavior After Fix

### User's Track (Phase 36.2%, Score 72)
**Before Fix:**
- ✅ Score: 72 (above 60 threshold)
- ❌ Phase: 36.2% (no direct check)
- ❌ Banner: NOT shown
- ❌ Classification: "Good Mix Quality"

**After Fix:**
- ❌ Score: 72 (below 75 threshold) → TRIGGERS
- ❌ Phase: 36.2% (below 45% threshold) → TRIGGERS
- ✅ Banner: SHOWN
- ✅ Classification: "Unmixed/Raw Recording"

### Professional Mixes (Should NOT Trigger)
- ✅ Score: 85-100 (above 75)
- ✅ Phase: 60-95% (above 45%)
- ✅ Mono: 70-95% (above 75% for wide mixes)
- ✅ DR: 6-16 dB (below 20 dB)
- ✅ Banner: NOT shown
- ✅ Classification: "Professional Mix/Master"

### Amateur Mixes (Score 60-74)
**With Technical Issues:**
- ⚠️ Score: 60-74 (below 75 threshold) → TRIGGERS
- ⚠️ Phase/Mono/DR: One or more issues → TRIGGERS
- ✅ Banner: SHOWN
- ✅ Classification: "Amateur Mix"

**Without Technical Issues:**
- ⚠️ Score: 60-74 (below 75 threshold) → TRIGGERS
- ✅ Phase: > 50%, Mono: > 75%, DR: < 20 dB
- ✅ Banner: SHOWN (due to low score)
- ✅ Guidance: "Mix quality could be improved"

## Testing Checklist

- [ ] Track with Phase < 40% → Shows unmixed banner
- [ ] Track with Score < 75 → Shows unmixed banner
- [ ] Track with Stereo 100% + Mono 60% → Shows unmixed banner
- [ ] Track with DR > 20 dB → Shows unmixed banner
- [ ] Professional master (Score 90+, Phase 70+) → NO banner
- [ ] Professional mix (Score 80-90, Phase 60+) → NO banner
- [ ] Amateur mix (Score 60-74, some issues) → Shows banner

## Files Modified

### AudioKitService.swift

**Lines 286-297** - Main unmixed detection logic:
```swift
let isUnmixedByScore = claudeResponse.score < 75  // Raised from 60
let hasSevereTechnicalIssues = (
    result.phaseCoherence < 0.45 ||
    (result.stereoWidthScore > 95 && result.monoCompatibility < 0.75) ||
    result.dynamicRange > 20.0
)
result.isProfessionallyMixed = !(isUnmixedByDetection || isUnmixedByScore || hasSevereTechnicalIssues)
```

**Lines 309-315** - Fallback logic (API failure):
```swift
let hasSevereTechnicalIssues = (
    result.phaseCoherence < 0.45 ||
    (result.stereoWidthScore > 95 && result.monoCompatibility < 0.75) ||
    result.dynamicRange > 20.0
)
result.isProfessionallyMixed = !(result.unmixedDetection!.isLikelyUnmixed || hasSevereTechnicalIssues)
```

**Line 3368** - New phase coherence pattern:
```swift
let severePhaseIssues = phaseCoherence < 0.40
```

**Line 3439** - Added to TIER 6 detection:
```swift
severePhaseIssues ||  // Poor phase coherence < 40%
```

## Impact

### Positive
- ✅ Catches unmixed tracks that were previously missed
- ✅ Phase coherence < 40% always flagged (correct)
- ✅ Score 60-74 tracks get unmixed banner (more realistic)
- ✅ Better user guidance for amateur mixes

### Potential Concerns
- ⚠️ Slightly more aggressive detection (score threshold 60→75)
- ⚠️ Amateur mixes (score 70-74) will show banner
- ⚠️ But this is CORRECT - they need guidance!

### Validation
- Professional masters (85-100): ✅ Not affected
- Professional mixes (75-84): ✅ Not affected (assuming good phase/mono)
- Amateur mixes (60-74): ⚠️ Will show banner (CORRECT behavior)
- Unmixed tracks: ✅ Now correctly detected

## User Feedback Expected

### Before Fix
> "I know this track is unmixed but it shows 'Good Mix Quality' with 72 score and NO banner!"

### After Fix
> "Perfect! Now it shows the unmixed banner and explains what's wrong (poor phase coherence, excessive stereo width)"

## Related Issues
- Previously fixed: Unmixed banner not appearing (lines 287-289, 306)
- Previously fixed: Score < 60 threshold too low for detection

## Conclusion
The fix makes unmixed detection more realistic by:
1. Raising score threshold from 60 to 75
2. Adding direct checks for severe technical issues (phase, width, compression)
3. Ensuring phase coherence < 40% always triggers unmixed detection

This provides better guidance to users and accurately identifies tracks that need mixing work.
