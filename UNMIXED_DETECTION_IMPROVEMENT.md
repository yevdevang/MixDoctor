# Unmixed Detection Algorithm Improvement

## Problem
The previous unmixed detection algorithm was using simple threshold checks that could produce false positives/negatives.

## Solution
Integrated advanced spectral analysis techniques from professional audio analysis:

### Enhanced Detection Metrics

#### 1. **Spectral Flatness** (Primary Indicator)
- **What it measures**: The "tonality" of the audio signal
- **How it works**: Ratio of geometric mean to arithmetic mean of the frequency spectrum
- **Unmixed indicator**: < 0.15 (signal dominated by specific frequencies/harmonics)
- **Mixed target**: 0.15-0.35 (well-balanced frequency distribution)
- **Weight in algorithm**: 35%

#### 2. **Stereo Correlation** (Primary Indicator)  
- **What it measures**: How similar the left and right channels are
- **How it works**: Pearson correlation coefficient between L/R channels
- **Unmixed indicator**: > 0.85 (channels too similar, essentially mono)
- **Mixed target**: 0.60-0.85 (good stereo separation with coherence)
- **Weight in algorithm**: 35%

#### 3. **Stereo Width** (Secondary Indicator)
- **What it measures**: The spatial width of the stereo field
- **Unmixed indicator**: < 30% (too narrow)
- **Mixed target**: 40-70% (professional balanced width)
- **Weight in algorithm**: 20%

#### 4. **Phase Coherence** (Tertiary Indicator)
- **What it measures**: Phase relationship between channels
- **Unmixed indicator**: < 0.6 (poor phase alignment)
- **Mixed target**: > 0.6 (good phase coherence)
- **Weight in algorithm**: 10%

### Weighted Confidence Score

The algorithm now calculates an **Unmixed Confidence Score** (0-1):

```swift
unmixedConfidence = (spectralFlatnessScore * 0.35 + 
                    stereoCorrelationScore * 0.35 + 
                    stereoWidthScore * 0.20 + 
                    phaseCoherenceScore * 0.10)
```

- **< 0.3**: Definitely mixed (professional quality expected)
- **0.3-0.5**: Borderline (review other indicators)
- **> 0.5**: Likely unmixed (score should be 35-50)

### Additional Validation Checks

The algorithm still validates against:
- Dynamic range > 15 dB (too wide for modern mixing)
- RMS level < -25 dBFS (too quiet)
- Spectral centroid < 800 Hz (lacking high-frequency content)
- Single frequency band > 50% (severe imbalance)
- Missing processing effects (compression, reverb, stereo, EQ)

## Code Changes

### 1. OpenAIService.swift
- Added `spectralFlatness` and `stereoCorrelation` parameters
- Implemented weighted confidence scoring algorithm
- Enhanced diagnostic logging with confidence metrics
- Updated prompt to include spectral analysis results

### 2. AudioAnalysisService.swift
- Pass `spectralFlatness` from `frequencyFeatures`
- Pass `stereoCorrelation` from `stereoFeatures`

### 3. AudioFeatureExtractor.swift (No changes needed)
- Already contains `calculateSpectralFlatness()` method
- Already contains `calculateCorrelation()` method
- Already includes `spectralFlatness` in `FrequencyFeatures` struct

## Benefits

1. **More Accurate Detection**: Uses professional audio analysis metrics
2. **Fewer False Positives**: Weighted algorithm reduces single-metric errors
3. **Better Diagnostics**: Confidence score shows detection certainty
4. **Professional Standards**: Based on industry-standard spectral analysis

## Testing Recommendations

Test with:
- ✅ Known unmixed tracks (raw recordings, stems)
- ✅ Known mixed tracks (released songs, mastered audio)
- ✅ Edge cases (mono recordings, spoken word, classical music)

Expected results:
- Unmixed tracks: Confidence > 0.5, Score 35-50
- Mixed tracks: Confidence < 0.3, Score 51-100

## References

The spectral flatness and correlation approach is based on:
- ITU-R BS.1770 (loudness measurement)
- EBUR128 (broadcast standards)
- Professional audio analysis tools (iZotope Insight, Waves PAZ Analyzer)
