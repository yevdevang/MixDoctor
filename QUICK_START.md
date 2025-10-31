# Quick Start Guide: ChatGPT Audio Analysis

## Overview

Your MixDoctor app now sends audio files directly to ChatGPT (GPT-4o) for professional mixing analysis. No local feature extraction needed - ChatGPT analyzes the actual audio and provides detailed feedback.

## What You Get

### Analysis Results
- **Overall Score** (0-100): Professional quality assessment
- **Stereo Width** (0-100%): Spatial positioning evaluation
- **Phase Coherence** (-1.0 to 1.0): Mono compatibility check
- **Frequency Balance** (6 bands): Sub Bass, Bass, Low Mids, Mids, High Mids, Highs
- **Dynamic Range** (dB): Compression assessment
- **Loudness** (LUFS + Peak): Streaming compliance
- **Recommendations** (3-5 items): Specific, actionable advice
- **Frequency Spectrum Image**: Visual frequency distribution (optional)

## Token Usage & Cost

**Formula**: ~150 tokens per second of audio

| Duration | Tokens | GPT-4o Cost | GPT-4o-mini Cost |
|----------|--------|-------------|------------------|
| 30s      | 4,500  | $0.011      | $0.0007          |
| 1min     | 9,000  | $0.023      | $0.0014          |
| 2min     | 18,000 | $0.045      | $0.0027          |
| 3min     | 27,000 | $0.068      | $0.0041          |
| 5min     | 45,000 | $0.113      | $0.0068          |

**Recommendation**: Use 30-60 second clips of the most important parts of your mix for cost-effective analysis.

## Setup (3 Steps)

### 1. Get OpenAI API Key
```bash
# Visit: https://platform.openai.com/api-keys
# Create a new API key
# Copy the key (starts with sk-...)
```

### 2. Configure API Key
```bash
# In your project directory
cd /Users/yevgenylevin/Documents/Develop/iOS/MixDoctor

# Copy template
cp Config.xcconfig.template Config.xcconfig

# Edit Config.xcconfig and add your key:
OPENAI_API_KEY = sk-your-actual-key-here
```

### 3. Build Project
```bash
# Build in Xcode
# The API key will be loaded automatically
```

## Usage

### Basic Analysis
```swift
// In your analysis code
let audioAnalysisService = AudioAnalysisService()

// Use ChatGPT direct analysis (recommended)
audioAnalysisService.useChatGPTDirectAnalysis = true

// Analyze
do {
    let result = try await audioAnalysisService.analyzeAudio(audioFile)
    
    // Results available:
    print("Score: \(result.overallScore)")
    print("Stereo Width: \(result.stereoWidthScore)%")
    print("Phase: \(result.phaseCoherence)")
    print("Dynamic Range: \(result.dynamicRange) dB")
    print("Loudness: \(result.loudnessLUFS) LUFS")
    print("Recommendations: \(result.recommendations)")
    
} catch {
    print("Analysis failed: \(error)")
}
```

### With Settings Integration
```swift
// In your SettingsView
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        Form {
            // Your existing settings...
            
            // Add analysis limits section
            AnalysisLimitSettingsView(viewModel: viewModel)
        }
    }
}
```

### Display Frequency Spectrum
```swift
// In your analysis detail view
if result.hasFrequencySpectrumImage {
    FrequencySpectrumImageView(audioFileID: audioFile.id)
        .padding()
}
```

## Settings Configuration

### Monthly Limit
Set how many analyses you want per month:
- **10 / month**: Light usage (~$0.11-0.68/month at 3min avg)
- **25 / month**: Moderate usage (~$0.28-1.70/month)
- **50 / month**: Regular usage (~$0.56-3.40/month) - **Default**
- **100 / month**: Heavy usage (~$1.13-6.80/month)
- **250 / month**: Professional usage (~$2.83-17.00/month)
- **Unlimited** (1000): Enterprise (~$11.30-113.00/month)

### Max Duration
Set maximum audio duration to analyze:
- **30 seconds**: Quick checks, lowest cost
- **1 minute**: Short clips
- **2 minutes**: Standard analysis
- **3 minutes**: Full song - **Default**
- **4 minutes**: Extended tracks
- **5 minutes**: Long tracks, highest cost

**Tip**: Longer songs will be trimmed to this duration automatically.

## Monthly Limit Management

### Automatic Reset
- Limits reset on the 1st of each month at midnight
- Counter syncs across devices via iCloud
- No manual intervention needed

### Check Remaining
```swift
let viewModel = SettingsViewModel()
print("Remaining: \(viewModel.remainingAnalyses)")
print("Resets in: \(viewModel.daysUntilReset) days")
```

### Manual Reset (for testing)
```swift
viewModel.manuallyResetAnalysisCount()
```

## Error Handling

### Common Errors

**1. Monthly Limit Reached**
```
Error: "Monthly analysis limit reached. Please wait until next month or upgrade your plan."

Solutions:
- Wait until next month
- Increase monthly limit in Settings
- Analyze shorter clips
```

**2. API Key Not Configured**
```
Error: "OpenAI API key not configured"

Solution:
- Add API key to Config.xcconfig
- Rebuild project in Xcode
```

**3. File Not Found**
```
Error: "Audio file not found at path..."

Solution:
- Re-import the audio file
- Check file permissions
```

## Cost Management Tips

### 1. Analyze Key Sections
Instead of analyzing a full 5-minute song:
- Analyze the chorus (30s) - **$0.011**
- Analyze the verse (30s) - **$0.011**
- Analyze the bridge (30s) - **$0.011**
- **Total: $0.033 vs $0.113 for full song**

### 2. Use Shorter Clips
Set max duration to 60 seconds:
- Captures the essential mix characteristics
- **Saves 80% on costs** (60s vs 300s)
- Still provides detailed analysis

### 3. Set Appropriate Limits
Start with 25-50 analyses per month:
- **25 @ 60s clips**: ~$0.58/month
- **50 @ 60s clips**: ~$1.15/month
- Adjust based on actual usage

### 4. Monitor Usage
Check Settings regularly:
```
Current: 15 / 50
Remaining: 35
Resets in: 12 days
```

## Pro vs Free Users

### Free Users
- GPT-4o-mini model
- 3 recommendations
- $0.15 per 1M tokens
- **60s analysis: ~$0.0014**

### Pro Users
- GPT-4o model (better quality)
- 5 recommendations
- $2.50 per 1M tokens
- **60s analysis: ~$0.023**

## Troubleshooting

### Analysis Takes Too Long
- Longer files take more time to upload
- Reduce max duration setting
- Check internet connection

### Unexpected Costs
- Check actual analysis duration
- Review monthly limit setting
- Monitor token usage in console logs

### Image Not Showing
- Check `hasFrequencySpectrumImage` flag
- ChatGPT may not always generate images
- Check console for save errors

## Console Logging

Enable detailed logging:
```swift
// Look for these logs:
📊 Audio Analysis Info:
   Duration: 180.0s
   Estimated tokens: 27000
   Estimated cost: $0.0675
   Model: GPT-4o (Pro)

✅ ChatGPT Analysis Complete
   Overall Score: 85
   Stereo Width: 65
   Phase Coherence: 0.85
   Dynamic Range: 8.5 dB
   Loudness: -10.5 LUFS

📊 Analysis count: 16/50
```

## Next Steps

1. **Test Analysis**: Analyze a sample audio file
2. **Check Results**: Verify all metrics are populated
3. **Review Costs**: Monitor actual token usage
4. **Adjust Settings**: Set appropriate limits
5. **Add UI**: Integrate `AnalysisLimitSettingsView` in Settings
6. **Deploy**: Test with real users

## Support

### Resources
- OpenAI API Status: https://status.openai.com
- API Documentation: https://platform.openai.com/docs
- Token Usage: https://platform.openai.com/usage

### Documentation
- Full details: `CHATGPT_AUDIO_ANALYSIS.md`
- Implementation: `IMPLEMENTATION_SUMMARY.md`
- This guide: `QUICK_START.md`

## Example Workflow

```swift
// 1. User imports audio
let audioFile = importedAudioFile

// 2. Check if analysis allowed
let settings = SettingsViewModel()
guard settings.canPerformAnalysis else {
    showAlert("Monthly limit reached")
    return
}

// 3. Analyze with ChatGPT
let service = AudioAnalysisService()
service.useChatGPTDirectAnalysis = true

do {
    let result = try await service.analyzeAudio(audioFile)
    
    // 4. Display results
    showAnalysisResults(result)
    
    // 5. Show frequency spectrum if available
    if result.hasFrequencySpectrumImage {
        showFrequencySpectrum(audioFile.id)
    }
    
} catch {
    showError(error)
}
```

## FAQ

**Q: Can I analyze offline?**
A: No, ChatGPT analysis requires internet connection.

**Q: What happens if I hit my limit?**
A: Analysis will fail with "Monthly limit reached" error. Increase limit or wait until next month.

**Q: Can I change the model?**
A: Yes, it's based on Pro subscription status. Pro users get GPT-4o, free users get GPT-4o-mini.

**Q: Are images always generated?**
A: No, ChatGPT may not always generate frequency spectrum images. Check `hasFrequencySpectrumImage`.

**Q: What audio formats are supported?**
A: WAV, MP3, M4A, and other common formats supported by GPT-4o.

**Q: Is my audio stored by OpenAI?**
A: No, OpenAI doesn't store audio after processing (per their API policy).

---

**Ready to start?** Follow the 3-step setup above and test your first analysis! 🎵
