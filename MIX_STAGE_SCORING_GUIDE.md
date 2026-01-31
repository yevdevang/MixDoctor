# Mix Stage Scoring System - Implementation Guide

## Overview

The Mix Stage system allows MixDoctor to provide accurate, context-aware analysis by distinguishing between:
- **Mix (Pre-Master)**: Raw mixes ready for mastering
- **Master (Streaming)**: Finals optimized for streaming platforms (-14 LUFS)
- **Master (CD/Loud)**: Finals optimized for CD/physical media (-9 to -11 LUFS)

## System Architecture

### Data Flow

```
User Selects Stage → AudioFile.mixStage → AudioKitService.getDetailedAnalysis() 
→ performAudioKitAnalysis() → performAudioKitBufferAnalysis() → Stage-Aware Scoring
```

### Files Modified

1. **`AudioFile.swift`**: Added `mixStage: String?` property
2. **`AudioImportService.swift`**: Pass mixStage through import pipeline
3. **`ImportViewModel.swift`**: Added `selectedMixStage` state
4. **`ResultsView.swift`**: Added UI picker for stage selection
5. **`AudioKitService.swift`**: Accept mixStage parameter throughout analysis chain

## Stage-Specific Expectations

### Mix (Pre-Master)

**Purpose**: Raw mix before mastering processing

**Loudness Expectations**:
- Target: **-16 to -20 LUFS**
- Peak: **-6 to -3 dB** (headroom for mastering)
- RMS: **-16 to -12 dB**

**Dynamic Range Expectations**:
- Minimum: **10 dB** (good dynamics)
- Ideal: **12-15 dB** (excellent dynamics)
- Maximum: **20 dB** (very dynamic, might need compression)

**Frequency Balance**:
- Can be slightly dark (8-12% high-mid)
- Bass can be generous (40%+ low-end acceptable)
- Focus: **Balance, phase, stereo, no clipping**

**Scoring Guidelines**:
```swift
// For Mix stage:
var score = 100

// Loudness penalties
if loudness < -20 { score -= 10 }  // Too quiet
if loudness > -10 { score -= 20 }  // Too loud for a mix!

// Dynamic range rewards
if dynamicRange >= 12 { score += 5 }  // Reward good dynamics
if dynamicRange < 8 { score -= 20 }   // Over-compressed already

// Headroom check
if peakLevel > -3 { score -= 15 }  // Not enough headroom for mastering

// Expected final score range: 75-95
```

---

### Master (Streaming)

**Purpose**: Final master optimized for Spotify, Apple Music, YouTube

**Loudness Expectations**:
- Target: **-14 LUFS** (Spotify/Apple standard)
- Tolerance: **±1 LU** (-13 to -15 LUFS is acceptable)
- Peak: **-1.0 to -0.1 dB** (true peak limited)
- RMS: **-11 to -8 dB**

**Dynamic Range Expectations**:
- Minimum: **6 dB** (streaming acceptable)
- Ideal: **8-12 dB** (balanced)
- Maximum: **14 dB** (might be too dynamic, perceived as quiet)

**Frequency Balance**:
- Should have presence (12-15% high-mid)
- Balanced low-end (30-40%)
- Focus: **Competitive loudness, translation, polish**

**Scoring Guidelines**:
```swift
// For Master (Streaming) stage:
var score = 100

// Loudness penalties (strict!)
let loudnessDeviation = abs(loudness - (-14.0))
if loudnessDeviation > 2 { score -= 20 }  // More than 2 LU off target
else if loudnessDeviation > 1 { score -= 10 }  // 1-2 LU off target
else if loudnessDeviation < 0.5 { score += 5 }  // Perfect target!

// Dynamic range
if dynamicRange < 6 { score -= 20 }   // Over-compressed
if dynamicRange > 14 { score -= 10 }  // Too dynamic for streaming
if dynamicRange >= 8 && dynamicRange <= 12 { score += 5 }  // Sweet spot

// Peak limiting
if peakLevel > -0.5 { score -= 5 }  // Could be louder
if peakLevel < -2 { score -= 10 }   // Too conservative

// High-mid presence
if highMid < 0.12 { score -= 10 }  // Too dark for streaming

// Expected final score range: 85-100
```

---

### Master (CD/Loud)

**Purpose**: Final master for CD, vinyl, or loud competitive releases

**Loudness Expectations**:
- Target: **-9 to -11 LUFS**
- Peak: **-0.1 to -0.3 dB** (maximized)
- RMS: **-8 to -6 dB**

**Dynamic Range Expectations**:
- Minimum: **5 dB** (competitive loudness)
- Ideal: **6-10 dB**
- Maximum: **12 dB** (still has dynamics)

**Frequency Balance**:
- Bright (13-16% high-mid for presence)
- Controlled low-end (28-38%)
- Focus: **Maximum impact, commercial loudness**

**Scoring Guidelines**:
```swift
// For Master (CD/Loud) stage:
var score = 100

// Loudness penalties
if loudness < -12 { score -= 20 }  // Too quiet for CD
if loudness > -8 { score -= 25 }   // Likely clipping/distortion
if loudness >= -11 && loudness <= -9 { score += 5 }  // Perfect range

// Dynamic range
if dynamicRange < 5 { score -= 30 }  // Destroyed dynamics
if dynamicRange >= 6 && dynamicRange <= 10 { score += 5 }  // Good balance

// Peak optimization
if peakLevel > -0.1 || peakLevel < -0.5 { score -= 5 }  // Not optimized

// Brightness
if highMid < 0.13 { score -= 10 }  // Too dark for loud master

// Expected final score range: 85-100
```

---

## Implementation Location

### File: `AudioKitService.swift`

**Function**: `performAudioKitBufferAnalysis()`

**Where to Add**: After calculating all metrics, before returning `AudioKitAnalysisResult`

**Approximate Line**: ~450-500 (after stereo analysis, before return statement)

### Implementation Template

```swift
// MARK: - Stage-Aware Score Adjustments
private func adjustScoreForMixStage(
    _ baseScore: Int,
    mixStage: String?,
    loudness: Double,
    dynamicRange: Double,
    peakLevel: Double,
    highMid: Double
) -> Int {
    var adjustedScore = baseScore
    
    switch mixStage {
    case "mix":
        // Pre-master expectations
        print("🎚️ STAGE-AWARE SCORING: Mix (Pre-Master)")
        
        // Loudness
        if loudness < -20 {
            adjustedScore -= 10
            print("  ⚠️ Mix too quiet (-10 points)")
        } else if loudness > -10 {
            adjustedScore -= 20
            print("  ⚠️ Mix too loud for pre-master (-20 points)")
        }
        
        // Dynamic range (reward good dynamics)
        if dynamicRange >= 12 {
            adjustedScore += 5
            print("  ✅ Excellent dynamics (+5 points)")
        } else if dynamicRange < 8 {
            adjustedScore -= 20
            print("  ⚠️ Over-compressed for a mix (-20 points)")
        }
        
        // Headroom
        if peakLevel > -3 {
            adjustedScore -= 15
            print("  ⚠️ Insufficient headroom for mastering (-15 points)")
        }
        
    case "master_streaming":
        // Streaming master expectations
        print("🎚️ STAGE-AWARE SCORING: Master (Streaming)")
        
        // Loudness (strict target: -14 LUFS)
        let loudnessDeviation = abs(loudness - (-14.0))
        if loudnessDeviation > 2 {
            adjustedScore -= 20
            print("  ⚠️ Loudness \(String(format: "%.1f", loudnessDeviation)) LU from target (-20 points)")
        } else if loudnessDeviation > 1 {
            adjustedScore -= 10
            print("  ⚠️ Loudness \(String(format: "%.1f", loudnessDeviation)) LU from target (-10 points)")
        } else if loudnessDeviation < 0.5 {
            adjustedScore += 5
            print("  ✅ Perfect streaming loudness (+5 points)")
        }
        
        // Dynamic range
        if dynamicRange < 6 {
            adjustedScore -= 20
            print("  ⚠️ Over-compressed (-20 points)")
        } else if dynamicRange > 14 {
            adjustedScore -= 10
            print("  ⚠️ Too dynamic for streaming (-10 points)")
        } else if dynamicRange >= 8 && dynamicRange <= 12 {
            adjustedScore += 5
            print("  ✅ Ideal dynamics for streaming (+5 points)")
        }
        
        // High-mid presence
        if highMid < 0.12 {
            adjustedScore -= 10
            print("  ⚠️ Too dark for streaming (-10 points)")
        }
        
    case "master_cd":
        // CD master expectations
        print("🎚️ STAGE-AWARE SCORING: Master (CD/Loud)")
        
        // Loudness
        if loudness < -12 {
            adjustedScore -= 20
            print("  ⚠️ Too quiet for CD master (-20 points)")
        } else if loudness > -8 {
            adjustedScore -= 25
            print("  ⚠️ Likely clipping/distortion (-25 points)")
        } else if loudness >= -11 && loudness <= -9 {
            adjustedScore += 5
            print("  ✅ Perfect CD loudness (+5 points)")
        }
        
        // Dynamic range
        if dynamicRange < 5 {
            adjustedScore -= 30
            print("  ⚠️ Dynamics destroyed (-30 points)")
        } else if dynamicRange >= 6 && dynamicRange <= 10 {
            adjustedScore += 5
            print("  ✅ Good dynamics balance (+5 points)")
        }
        
        // Brightness
        if highMid < 0.13 {
            adjustedScore -= 10
            print("  ⚠️ Too dark for loud master (-10 points)")
        }
        
    default:
        // No stage specified - assume mix
        print("🎚️ STAGE-AWARE SCORING: Default (assuming Mix)")
        if loudness > -10 {
            adjustedScore -= 15
        }
    }
    
    // Ensure score stays in valid range
    adjustedScore = max(0, min(100, adjustedScore))
    
    print("  📊 Score adjustment: \(baseScore) → \(adjustedScore) (Δ\(adjustedScore - baseScore))")
    
    return adjustedScore
}
```

### Integration Point

**Where to call the function**:

```swift
// In performAudioKitBufferAnalysis(), after all analysis is complete:

// Calculate base score (existing logic)
let baseScore = calculateBaseScore(analysisResult)

// Apply stage-aware adjustments
let finalScore = adjustScoreForMixStage(
    baseScore,
    mixStage: mixStage,
    loudness: analysisResult.loudness,
    dynamicRange: analysisResult.dynamicRange,
    peakLevel: analysisResult.peakLevel,
    highMid: fftAnalysis.highMid
)

// Use finalScore instead of baseScore in result
result.overallScore = Double(finalScore)
```

---

## Recommendation System

### Stage-Aware Recommendations

**Add to**: `generateAudioKitRecommendations()` function

```swift
// Add stage-specific recommendations
switch mixStage {
case "mix":
    if loudness > -12 {
        recommendations.append("🎚️ Mix is too loud. Lower faders to achieve -16 to -18 LUFS for mastering headroom.")
    }
    if peakLevel > -3 {
        recommendations.append("📊 Leave more headroom (peak at -6 to -3 dB) for mastering processing.")
    }
    if dynamicRange < 10 {
        recommendations.append("🎛️ Mix has limited dynamics. Reduce compression to preserve 12+ dB dynamic range.")
    }
    
case "master_streaming":
    let loudnessDeviation = abs(loudness - (-14.0))
    if loudnessDeviation > 1 {
        if loudness < -14 {
            recommendations.append("🔊 Master is \(String(format: "%.1f", abs(loudness + 14))) LU quieter than Spotify/Apple target. Apply more limiting.")
        } else {
            recommendations.append("🔉 Master is \(String(format: "%.1f", loudness + 14)) LU louder than streaming target. Reduce gain/limiting.")
        }
    }
    if dynamicRange < 8 {
        recommendations.append("⚠️ Master is over-compressed. Reduce limiting to preserve 8-12 dB dynamic range.")
    }
    if highMid < 0.12 {
        recommendations.append("✨ Add high-mid presence (2-6 kHz boost) for streaming brightness.")
    }
    
case "master_cd":
    if loudness < -11 {
        recommendations.append("🔊 Master can be louder. Target -9 to -11 LUFS for competitive CD loudness.")
    }
    if dynamicRange < 6 {
        recommendations.append("⚠️ Dynamics are crushed. Ease off the limiter to preserve at least 6 dB range.")
    }
    if peakLevel < -0.5 {
        recommendations.append("📈 Master has unused headroom. Push limiting closer to -0.1 dB for maximum loudness.")
    }
}
```

---

## Testing Guidelines

### Test Cases

#### Test 1: Pre-Master Mix
- **File**: Raw mix, -18 LUFS, 14 dB DR, -6 dB peak
- **Stage**: Mix (Pre-Master)
- **Expected**: Score 90-95, "Excellent pre-master" message

#### Test 2: Streaming Master
- **File**: Mastered track, -14 LUFS, 9 dB DR, -0.3 dB peak
- **Stage**: Master (Streaming)
- **Expected**: Score 95-100, "Perfect streaming master" message

#### Test 3: CD Master
- **File**: Loud master, -9 LUFS, 7 dB DR, -0.1 dB peak
- **Stage**: Master (CD/Loud)
- **Expected**: Score 90-98, "Excellent CD master" message

#### Test 4: Wrong Stage Selected
- **File**: Pre-master (-18 LUFS)
- **Stage**: Master (Streaming) ← WRONG!
- **Expected**: Lower score, "Too quiet for streaming master" warning

### Validation

```swift
// Add debug logging to verify stage detection
print("🔍 ANALYSIS SETTINGS:")
print("  Genre: \(genre ?? "auto-detect")")
print("  Mix Stage: \(mixStage ?? "mix (default)")")
print("  File: \(fileName)")
print("")
```

---

## Future Enhancements

### Phase 1 (Current)
- ✅ UI for stage selection
- ✅ Data persistence
- ✅ Parameter passing through pipeline
- ⏳ Basic scoring adjustments (this guide)

### Phase 2 (Future)
- Stage-specific frequency balance expectations
- Genre + Stage combined recommendations
- Visual indicators showing stage-appropriate ranges
- "Optimal loudness curve" visualization

### Phase 3 (Advanced)
- ML-based stage detection
- Historical analysis tracking (mix → master comparison)
- A/B comparison between stages
- Export recommendations specific to chosen mastering chain

---

## Quick Reference Tables

### Loudness Targets

| Stage | Target LUFS | Min | Max | Peak |
|-------|-------------|-----|-----|------|
| Mix | -16 to -18 | -20 | -10 | -6 to -3 dB |
| Master (Streaming) | -14 | -15 | -13 | -1 to -0.1 dB |
| Master (CD) | -9 to -11 | -12 | -8 | -0.3 to -0.1 dB |

### Dynamic Range Targets

| Stage | Minimum | Ideal | Maximum |
|-------|---------|-------|---------|
| Mix | 10 dB | 12-15 dB | 20 dB |
| Master (Streaming) | 6 dB | 8-12 dB | 14 dB |
| Master (CD) | 5 dB | 6-10 dB | 12 dB |

### Score Ranges by Stage

| Stage | Excellent | Good | Needs Work |
|-------|-----------|------|------------|
| Mix | 90-100 | 75-89 | < 75 |
| Master (Streaming) | 95-100 | 85-94 | < 85 |
| Master (CD) | 95-100 | 85-94 | < 85 |

---

## FAQ

### Q: What if user doesn't select a stage?
**A**: Default to "mix" - safest assumption for unspecified tracks.

### Q: Should we auto-detect stage from loudness?
**A**: Not recommended. A quiet master could be mistaken for a mix. Let user specify.

### Q: What about vinyl masters?
**A**: Vinyl has unique requirements (limited low-end, de-essing). Future enhancement.

### Q: How to handle live recordings?
**A**: Treat as "mix" stage. Live recordings need different expectations (covered by genre selection).

---

## Implementation Checklist

- [ ] Add `adjustScoreForMixStage()` function to `AudioKitService.swift`
- [ ] Call function in `performAudioKitBufferAnalysis()` before returning result
- [ ] Add stage-aware recommendations to `generateAudioKitRecommendations()`
- [ ] Add debug logging for stage detection
- [ ] Test with all three stage types
- [ ] Update `PHASE_COHERENCE_FIX.md` with stage scoring info
- [ ] Create test tracks for each stage
- [ ] Verify scoring differences across stages
- [ ] Check UI updates properly when stage changes
- [ ] Confirm re-analysis works with new stage selection

---

**Created**: 2026-01-24  
**Version**: 1.0  
**Status**: Ready for Implementation  
**Estimated Implementation Time**: 2-3 hours
