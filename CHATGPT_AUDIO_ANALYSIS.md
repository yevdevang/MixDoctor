# ChatGPT Audio Analysis Integration

## Overview

MixDoctor now features **direct audio analysis with ChatGPT** using OpenAI's GPT-4o audio input capabilities. This allows the app to send audio files directly to ChatGPT for professional mixing and mastering analysis.

## Features

### 1. Direct Audio Analysis
- Sends audio files directly to GPT-4o (no local feature extraction needed)
- Supports audio files up to 5 minutes (configurable)
- Automatic audio trimming for longer files
- Cost-effective analysis with token estimation

### 2. Comprehensive Analysis Results

The ChatGPT analysis provides detailed feedback on:

#### **Stereo Width** (0-100 score)
- Mono compatibility assessment
- Stereo field utilization
- Spatial positioning evaluation
- Recommended range: 40-70%

#### **Phase Coherence** (-1.0 to 1.0 score)
- Phase relationship between L/R channels
- Mono compatibility issues
- Phase cancellation detection
- Recommended range: 0.6-1.0

#### **Frequency Balance** (percentage breakdown)
- Sub Bass (20-60 Hz)
- Bass (60-250 Hz)
- Low Mids (250-500 Hz)
- Mids (500-2k Hz)
- High Mids (2k-6k Hz)
- Highs (6k-20k Hz)
- Overall tonal balance assessment

#### **Dynamic Range** (dB measurement)
- Compression/limiting characteristics
- Transient preservation
- Recommended range: 6-14 dB

#### **Loudness Analysis**
- Integrated LUFS (target: -14 to -8 LUFS)
- Peak level (target: -1.0 to -0.1 dBFS)
- Streaming service compliance

#### **Actionable Recommendations**
- 3 recommendations for free users
- 5 recommendations for Pro users
- Specific, actionable advice with dB values and frequency ranges

#### **Frequency Spectrum Image** (when available)
- Visual representation of frequency distribution
- Highlights problematic areas
- Saved and displayed in analysis results

## Usage

### Analysis Limits

Users can set monthly analysis limits to manage API costs:

- **10 / month** - Light usage
- **25 / month** - Moderate usage
- **50 / month** - Regular usage (default)
- **100 / month** - Heavy usage
- **250 / month** - Professional usage
- **Unlimited** (1000) - Enterprise usage

The limit resets automatically at the start of each month.

### Maximum Duration Setting

Configure the maximum audio duration for analysis:

- **30 seconds** - Quick mix checks
- **1 minute** - Short clips
- **2 minutes** - Standard analysis
- **3 minutes** - Full song analysis (default)
- **4 minutes** - Extended tracks
- **5 minutes** - Long tracks

Longer durations use more tokens and cost more.

## Token Usage & Costs

### Token Calculation

OpenAI's GPT-4o uses approximately **150 tokens per second** of audio.

**Examples:**
- 30 seconds = ~4,500 tokens (~$0.011 with GPT-4o)
- 1 minute = ~9,000 tokens (~$0.023)
- 3 minutes = ~27,000 tokens (~$0.068)
- 5 minutes = ~45,000 tokens (~$0.113)

### Pricing (as of 2025)

- **GPT-4o**: $2.50 per 1M input tokens (Pro users)
- **GPT-4o-mini**: $0.15 per 1M input tokens (Free users)

### Cost Management

1. **Set Analysis Limits**: Configure monthly analysis limits in Settings
2. **Use Shorter Clips**: Analyze key sections instead of full songs
3. **Monitor Usage**: Track remaining analyses in Settings
4. **Upgrade Strategically**: Pro users get more recommendations and better analysis

## Technical Implementation

### Services

#### `ChatGPTAudioAnalysisService.swift`
Main service for sending audio to ChatGPT API:
- Audio duration detection
- Audio trimming (if needed)
- Base64 encoding
- API request handling
- Response parsing

#### `FrequencySpectrumImageService.swift`
Handles frequency spectrum images from ChatGPT:
- Base64 image decoding
- Image storage in app directory
- Image loading and caching
- Image cleanup

#### `AudioAnalysisService.swift` (updated)
Orchestrates analysis with two modes:
- `analyzeAudioWithChatGPT()` - Direct ChatGPT analysis
- `analyzeAudioWithLocalFeatures()` - Original local analysis
- Toggle via `useChatGPTDirectAnalysis` flag

### Models

#### `ChatGPTAudioAnalysisResponse`
```swift
struct ChatGPTAudioAnalysisResponse: Codable {
    let overallScore: Double
    let stereoWidth: StereoWidthAnalysis
    let phaseCoherence: PhaseCoherenceAnalysis
    let frequencyBalance: FrequencyBalanceAnalysis
    let dynamicRange: DynamicRangeAnalysis
    let loudness: LoudnessAnalysis
    let recommendations: [String]
    let detailedSummary: String
    let frequencySpectrumImageURL: String?
}
```

### Views

#### `FrequencySpectrumImageView.swift`
Displays frequency spectrum images in analysis results:
- Async image loading
- Error handling
- Loading states
- Responsive layout

## Settings Integration

### `SettingsViewModel.swift` (updated)

New properties:
- `maxAnalysisDuration: TimeInterval` - Max audio duration (30-300s)
- `maxAnalysesPerMonth: Int` - Monthly limit (1-1000)
- `currentMonthAnalysisCount: Int` - Usage tracking
- `remainingAnalyses: Int` - Remaining this month
- `canPerformAnalysis: Bool` - Check before analysis
- `daysUntilReset: Int` - Days until limit resets

Methods:
- `incrementAnalysisCount()` - Call after successful analysis
- `manuallyResetAnalysisCount()` - Reset for testing
- `resetMonthlyAnalysisCount()` - Auto-reset on new month

## API Configuration

### OpenAI API Key Setup

1. Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Copy `Config.xcconfig.template` to `Config.xcconfig`
3. Add your key: `OPENAI_API_KEY = sk-...`
4. Rebuild the project

The API key is loaded from `Bundle.main.infoDictionary["OPENAI_API_KEY"]`.

## Error Handling

### Common Errors

1. **Monthly Limit Reached** (429)
   - Message: "Monthly analysis limit reached"
   - Solution: Wait until next month or increase limit

2. **API Key Not Configured**
   - Message: "OpenAI API key not configured"
   - Solution: Add API key to `Config.xcconfig`

3. **Invalid Response** (invalidJSON)
   - Message: "Invalid JSON in ChatGPT response"
   - Solution: Retry analysis

4. **Audio Processing Failed**
   - Message: "Failed to process audio file"
   - Solution: Check audio file format and size

## Best Practices

### For Users

1. **Analyze Key Sections**: Don't need to analyze entire 5-minute songs
2. **Use 30-60 second clips** for cost-effective analysis
3. **Monitor Monthly Usage**: Check Settings regularly
4. **Export Important Results**: Save recommendations before limit reset

### For Developers

1. **Always Check Limits**: Call `canPerformAnalysis` before analysis
2. **Increment Counter**: Call `incrementAnalysisCount()` after successful analysis
3. **Handle Errors Gracefully**: Show helpful error messages
4. **Clean Up Images**: Delete frequency spectrum images when deleting audio files

## Future Enhancements

- [ ] Audio compression before sending to API
- [ ] Batch analysis for multiple files
- [ ] Export analysis results with images
- [ ] Comparison view for before/after mixes
- [ ] AI-powered mastering suggestions
- [ ] Integration with RevenueCat for usage-based pricing

## Support

For issues or questions:
- Check OpenAI API status: https://status.openai.com
- Review API documentation: https://platform.openai.com/docs
- Check app logs for detailed error messages
