# Mix Doctor Scoring System

## Overview

Mix Doctor uses AI-powered analysis combined with professional audio engineering standards to evaluate your audio tracks. The scoring system adapts based on whether your track is a **Mix (Pre-Master)**, **Master**, or is detected as **Unmixed/Raw**.

---

## Score Ranges by Track Type

### Master Tracks (Streaming or CD/Loud)

When you select "Master (Streaming)" or "Master (CD-Loud)" as your mix stage:

| Score Range | Quality Level | Description |
|-------------|---------------|-------------|
| **96-100** | Exceptional Commercial Master | Commercial release quality (Korn, Metallica, Abbey Road). Optimal loudness, perfect dynamics, excellent stereo imaging. |
| **92-95** | Excellent Professional Master | High-quality professional mastering with minor refinements possible. Ready for release. |
| **88-91** | Very Good Professional Master | Professional quality with small imperfections. Suitable for release. |
| **85-87** | Good Master | Solid mastering work with some areas for improvement. |
| **75-84** | Amateur/Flawed Master | Needs mastering polish. May have issues with loudness, dynamics, or balance. |
| **65-74** | Poor Mastering | Significant problems requiring re-mastering. |
| **Below 65** | Severely Flawed | Major technical issues. Needs complete re-mastering. |

### Mix Tracks (Pre-Master)

When you select "Mix (Pre-Master)" as your mix stage:

| Score Range | Quality Level | Description |
|-------------|---------------|-------------|
| **85-90** | Professional Mix | Ready for mastering. Clean, balanced, and well-prepared for the mastering stage. |
| **78-84** | Strong Amateur Mix | Good quality but needs some polish before mastering. |
| **68-77** | Decent Mix | Needs significant work before mastering. Review recommendations. |
| **50-67** | Weak Mix | Major issues requiring substantial mixing improvements. |
| **Below 50** | Critical Issues | Severe problems. May need re-recording or major repair. |

> **Note:** Mix tracks are capped at a maximum score of 90. Only mastered tracks can score above 90.

### Unmixed/Raw Recordings

When Mix Doctor detects an unmixed or raw recording:

| Score Range | Quality Level | Description |
|-------------|---------------|-------------|
| **70-75** | Excellent Raw Recording | Very clean recording, well-captured, ready for professional mixing. |
| **65-69** | Good Recording | Standard raw recording quality, suitable for mixing. |
| **60-64** | Acceptable Recording | Some issues but workable with careful mixing. |
| **50-59** | Poor Recording | Significant issues. Will require extensive work in mixing. |
| **Below 50** | Very Poor | Major recording problems. Consider re-recording. |

> **Note:** Unmixed tracks are capped at a maximum score of 75. They require professional mixing and mastering before release.

---

## Key Scoring Factors

### 1. Loudness (LUFS)

The integrated loudness measured in LUFS (Loudness Units Full Scale).

| Track Type | Target Range | Professional Standard |
|------------|--------------|----------------------|
| **Streaming Master** | -14 to -16 LUFS | Optimized for streaming platforms (Spotify, Apple Music) |
| **CD/Loud Master** | -6 to -9 LUFS | Competitive loudness for physical release |
| **Mix (Pre-Master)** | -16 to -23 LUFS | Headroom for mastering |
| **Raw Recording** | -18 to -30 LUFS | Unprocessed levels (not penalized) |

**Scoring Impact:**
- Professional loudness range: No penalty + bonus points
- Very quiet (<-18 LUFS for masters): Score capped
- Too loud (>-5 LUFS): Clipping risk, penalty applied

### 2. Dynamic Range (dB)

The difference between the loudest and quietest parts of your audio.

| Track Type | Optimal Range | Notes |
|------------|---------------|-------|
| **Streaming Master** | 8-12 dB | Preserves musicality while meeting streaming standards |
| **CD/Loud Master** | 4-6 dB | Aggressive compression for competitive loudness |
| **General Master** | 6-14 dB | Depends on genre |
| **Mix (Pre-Master)** | 8-15 dB | Good dynamics for mastering headroom |
| **Jazz/Classical** | 14-26 dB | Natural dynamics expected |

**Scoring Impact:**
- Genre-appropriate dynamic range: Bonus points
- Over-compressed (<4 dB): Penalty
- Unmixed tracks with high DR (>15 dB): Not penalized (expected)

### 3. Peak Level (dBFS)

The maximum amplitude of your audio signal.

| Peak Level | Assessment | Scoring |
|------------|------------|---------|
| **-1.0 to 0.0 dBFS** | Perfect modern master | Bonus +2 points |
| **-2.0 to -1.0 dBFS** | Very good | Bonus +1 point |
| **-3.0 to -2.0 dBFS** | Conservative but good | No penalty |
| **-4.0 to -3.0 dBFS** | Too conservative | -2 points |
| **Below -4.0 dBFS** | Insufficient optimization | -4 points |
| **Above +0.1 dBFS** | Clipping risk | -6 points |

### 4. Phase Coherence

Measures how well the left and right channels correlate.

| Phase Coherence | Assessment | Scoring |
|-----------------|------------|---------|
| **70%+** | Excellent | Bonus +2 points |
| **50-70%** | Very good | Bonus +1 point |
| **40-50%** | Good | No penalty |
| **35-40%** | Acceptable (common in rock/metal) | No penalty |
| **30-35%** | Minor issue | -2 points |
| **Below 30%** | Significant issues | -4 points |

**Genre Adjustments:**
- EDM/Electronic: Minimum 50% expected
- Pop/R&B: Minimum 45% expected
- Rock/Metal: Minimum 40% expected
- Jazz/Classical: Minimum 25-30% expected (wide stereo is normal)

### 5. Mono Compatibility

How well your track translates when summed to mono.

| Compatibility | Assessment | Scoring |
|---------------|------------|---------|
| **85%+** | Excellent | Bonus +2 points |
| **75-85%** | Very good | Bonus +1 point |
| **60-75%** | Good | Bonus +1 point |
| **45-60%** | Acceptable for Rock/Metal/EDM | No penalty |
| **35-45%** | Weak | -2 points |
| **Below 35%** | Severe | -5 points |

### 6. Stereo Width

The perceived width of the stereo field.

| Width | Assessment | Notes |
|-------|------------|-------|
| **25-85%** | Normal range | Genre-dependent ideal |
| **85-95%** | Very wide | Excellent for Metal/Rock if mono is good |
| **95-100%** | Extreme | Acceptable for Metal with 60%+ mono compatibility |
| **15-25%** | Narrow | Acceptable, may want more width |
| **Below 15%** | Too narrow | -3 points |

### 7. Frequency Balance

Distribution of energy across the frequency spectrum.

| Band | Frequency Range | Typical Balance |
|------|-----------------|-----------------|
| **Low End (Sub/Bass)** | 20-200 Hz | 15-35% (genre-dependent) |
| **Low-Mid** | 200-800 Hz | 18-30% |
| **Mid** | 800 Hz - 3 kHz | 25-40% |
| **High-Mid** | 3-8 kHz | 10-25% |
| **High** | 8-20 kHz | 5-18% |

**Genre-Specific Expectations:**

| Genre | Expected Characteristics |
|-------|-------------------------|
| **Hip-Hop/EDM** | Heavy bass (30-50%), less highs (2-12%) |
| **Metal/Rock** | Bass-heavy (40-60%), intentionally dark |
| **Pop** | Balanced, vocal-focused mids (28-45%) |
| **Jazz/Classical** | Natural balance, wide dynamics |
| **Acoustic** | Natural warmth, moderate dynamics |

---

## How Scores Are Calculated

### For Mastered Tracks

1. **Start at 120 points** (100 base + 20 mastered bonus)
2. **Subtract penalties** for technical issues
3. **Add bonuses** for exceptional quality
4. **Cap at 100** (maximum score)

### For Mix Tracks

1. **Start at 85 points** (professional mix baseline)
2. **Subtract penalties** for mixing issues
3. **Add bonuses** for excellence (max +5)
4. **Cap at 90** (mixes cannot exceed 90)

### For Unmixed/Raw Tracks

1. **Start at 65 points** (decent raw recording baseline)
2. **Subtract penalties** for recording issues
3. **Add bonuses** for clean recording (max +10)
4. **Cap at 75** (unmixed tracks cannot exceed 75)

---

## Bonus Points

| Condition | Bonus |
|-----------|-------|
| Perfect peak level (-1 to 0 dBFS) | +2 |
| Genre-appropriate loudness | +2 |
| Excellent phase coherence (>70%) | +2 |
| Excellent mono compatibility (>85%) | +2 |
| Well-balanced frequency spectrum | +3 |
| Good dynamic range (genre-appropriate) | +2 |
| Professional stereo width | +2 |

---

## Penalty Points

| Issue | Penalty |
|-------|---------|
| Clipping (peak > 0 dBFS) | -6 to -10 |
| Severe phase cancellation (<30%) | -4 to -8 |
| Poor mono compatibility (<35%) | -5 to -8 |
| Over-compressed (<4 dB DR) | -2 to -4 |
| Major frequency imbalance | -2 to -10 |
| Very quiet mastering | Score cap applied |

---

## Unmixed Track Detection

Mix Doctor automatically detects unmixed/raw recordings based on:

- **Very low loudness** (<-16 LUFS)
- **Excessive dynamic range** (>14 dB)
- **Large peak-to-loudness ratio** (>15 dB)
- **Poor frequency masking** (overlapping frequencies)
- **High crest factor** (>12 dB)

When detected, an orange "Unmixed" banner appears with specific recommendations for professional mixing.

---

## Genre-Aware Analysis

Mix Doctor adjusts expectations based on your selected genre:

- **Metal/Rock**: Wide stereo, bass-heavy mix is normal
- **EDM/Electronic**: Heavy bass, compressed dynamics acceptable
- **Hip-Hop**: 808-heavy low end, minimal highs expected
- **Jazz/Classical**: Wide dynamics, natural balance expected
- **Pop**: Vocal-focused, balanced spectrum
- **Acoustic**: Natural warmth, moderate dynamics

---

## Tips for Better Scores

1. **Use the correct Mix Stage** - Select Master for final masters, Mix for pre-master mixes
2. **Select your Genre** - Enables genre-appropriate scoring
3. **Target proper loudness** - -14 LUFS for streaming, -8 LUFS for competitive
4. **Maintain dynamics** - Don't over-compress (keep 6+ dB DR)
5. **Check mono compatibility** - Aim for 60%+ compatibility
6. **Avoid clipping** - Keep peaks below 0 dBFS
7. **Balance frequencies** - Even distribution, genre-appropriate

---

## Understanding the AI Analysis

Mix Doctor uses Claude AI to provide:

1. **Summary** - Overall assessment in professional mixer language
2. **Recommendations** - Specific, actionable improvements
3. **Mastering Readiness** - Whether your mix is ready for mastering

The AI analyzes your track like a professional mixing engineer would, using terminology and standards from the industry.

---

*Mix Doctor v1.0 - Professional Audio Analysis*
