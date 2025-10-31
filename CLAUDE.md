# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MixDoctor** is an iOS audio analysis application that evaluates audio mixes using AI-powered analysis. It provides professional mixing feedback on stereo width, phase coherence, frequency balance, dynamic range, loudness, and offers actionable recommendations for improvement.

The app integrates **OpenAI's GPT-4o** for direct audio analysis, **RevenueCat** for subscriptions, **SwiftData with CloudKit** for data persistence and sync, and uses a clean MVVM architecture with SwiftUI.

## Building & Running

### Prerequisites
1. **Xcode 26.0.1+** (currently using Xcode 26.0.1 Build 17A400)
2. **OpenAI API Key** from https://platform.openai.com/api-keys
3. **RevenueCat API Key** (for subscription features)

### Setup Steps
```bash
# 1. Copy configuration template
cp Config.xcconfig.template Config.xcconfig

# 2. Edit Config.xcconfig and add your API keys
# OPENAI_API_KEY = sk-your-actual-key-here
# REVENUECAT_API_KEY = your-revenuecat-key-here

# 3. Open project in Xcode
open MixDoctor.xcodeproj

# 4. Build and run (⌘R)
```

### Testing
- **Unit Tests**: Located in `MixDoctorTests/` - Run with ⌘U
- **UI Tests**: Located in `MixDoctorUITests/`
- **Mock Testing**: See [MOCK_TESTING_GUIDE.md](MOCK_TESTING_GUIDE.md) for testing subscriptions without RevenueCat
- **Cancellation Testing**: See [CANCELLATION_TESTING.md](CANCELLATION_TESTING.md)

## Architecture

### High-Level Structure

```
MixDoctor/
├── Core/                          # Shared infrastructure
│   ├── Models/                    # SwiftData models
│   ├── Services/                  # Business logic & integrations
│   ├── Extensions/                # Swift extensions
│   ├── Utilities/                 # Constants, helpers
│   └── Views/                     # Reusable UI components
└── Features/                      # Feature modules (MVVM)
    ├── Dashboard/                 # Main audio library view
    ├── Import/                    # Audio file import
    ├── Analysis/                  # Analysis results & visualization
    ├── Player/                    # Audio playback
    ├── Settings/                  # App settings & preferences
    └── Paywall/                   # Subscription/monetization
```

### Core Design Principles

1. **MVVM with SwiftUI**: Each feature has Views + ViewModels (when needed). Simple views use `@State` directly.

2. **SwiftData + CloudKit**:
   - Primary model: `AudioFile` with cascade relationship to `AnalysisResult`
   - CloudKit integration managed via `ModelConfiguration` in `MixDoctorApp.swift`
   - File storage uses `iCloudStorageService` which abstracts local vs iCloud storage
   - **Critical**: Only filenames stored in DB, full paths computed dynamically via `fileURL` computed property

3. **Service Layer Pattern**:
   - Services are singletons (`shared`) or injected dependencies
   - Core services: `AudioAnalysisService`, `OpenAIService`, `SubscriptionService`, `iCloudStorageService`
   - Services handle all external integrations (OpenAI API, RevenueCat, file I/O)

4. **Observation Framework**: Uses Swift's `@Observable` macro for state management instead of ObservableObject

## Key Services

### AudioAnalysisService
Main orchestrator for audio analysis. Flow:
1. **Load Audio**: Uses `AudioProcessor` to load and decode audio files
2. **Extract Features**: Uses `AudioFeatureExtractor` to compute technical metrics:
   - Stereo width, phase coherence
   - Frequency bands (sub-bass, bass, low-mids, mids, high-mids, highs)
   - Dynamic range, loudness (LUFS), peak levels
   - Mixing effects detection (compression, reverb, stereo processing, EQ)
3. **AI Analysis**: Sends features to `OpenAIService` for intelligent scoring
4. **Scoring Logic**: Takes MAX of technical score and AI score to avoid unfair penalization
5. **Unmixed Detection**: Advanced algorithm scores tracks 35-50 if unmixed, 51-100 if mixed

### OpenAIService
Handles GPT-4o/GPT-4o-mini integration:
- **Model Selection**: Pro users get GPT-4o, free users get GPT-4o-mini
- **Unmixed Detection**: Multi-factor algorithm using spectral flatness, stereo correlation, dynamic range, missing effects
- **Structured Output**: Uses `responseFormat: .jsonObject` for reliable parsing
- **Score Enforcement**: Post-processing ensures AI respects unmixed (35-50) vs mixed (51-100) ranges

### iCloudStorageService
Manages audio file storage with iCloud Drive sync:
- **Dynamic Path Resolution**: `getAudioFilesDirectory()` returns iCloud or local path based on user preference
- **Migration Support**: Can migrate files between local and iCloud storage
- **Download Management**: Handles ubiquitous item downloading for iCloud files

### SubscriptionService (RevenueCat)
Handles subscription state and free tier limits:
- **Free Tier**: 3 analyses per month
- **Pro Tier**: Unlimited analyses + GPT-4o model + 5 recommendations (vs 3 for free)
- **Trial Handling**: Trial users treated as free tier for analysis limits
- **Monthly Reset**: Auto-resets free tier count on 1st of each month

### ChatGPTAudioAnalysisService (Future)
Direct audio file upload to GPT-4o for analysis (alternative to local feature extraction):
- Token estimation: ~150 tokens/second of audio
- Configurable max duration (30s - 5min)
- Returns structured analysis + optional frequency spectrum image
- See [CHATGPT_AUDIO_ANALYSIS.md](CHATGPT_AUDIO_ANALYSIS.md) for details

## Data Models

### AudioFile (SwiftData @Model)
```swift
@Model
final class AudioFile {
    var id: UUID
    var fileName: String
    private var storedFileName: String  // Only filename, not full path!
    var duration: TimeInterval
    // ... audio metadata ...

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?

    @Transient
    var fileURL: URL {
        // Computed dynamically from iCloudStorageService
    }
}
```

**Why computed `fileURL`?** iOS Simulator and app updates can change container paths. Storing full paths breaks on container changes.

### AnalysisResult (SwiftData @Model)
```swift
@Model
final class AnalysisResult {
    var overallScore: Double           // 35-50 (unmixed) or 51-100 (mixed)
    var stereoWidthScore: Double       // 0-100%
    var phaseCoherence: Double         // -1.0 to 1.0
    var dynamicRange: Double           // dB
    var loudnessLUFS: Double          // LUFS

    // Frequency bands (normalized to percentages)
    var lowEndBalance: Double          // 0-100%
    var midBalance: Double             // 0-100%
    var highBalance: Double            // 0-100%

    var recommendations: [String]
    var hasFrequencySpectrumImage: Bool
}
```

## Important Technical Details

### Audio Feature Extraction
Frequency bands are extracted at specific frequencies:
- **Sub Bass**: 20 Hz
- **Bass**: 60 Hz
- **Low Mids**: 250 Hz
- **Mids**: 500 Hz
- **High Mids**: 2000 Hz
- **Highs**: 6000 Hz

Combined into three categories for analysis:
- Low: (sub_bass + bass) / 2
- Mid: (low_mids + mids) / 2
- High: (high_mids + highs) / 2

### Unmixed Track Detection
Tracks are flagged as "unmixed" if they score >= 70 points on this weighted system:
- Spectral flatness < 0.15: +30 pts (most reliable indicator)
- Stereo correlation > 0.85: +25 pts
- Stereo width < 30%: +20 pts
- Loudness range > 15 LU: +15 pts
- Crest factor > 12 dB: +10 pts
- Missing compression/reverb/stereo processing/EQ: +5 pts each

Unmixed tracks score 35-50, mixed tracks 51-100.

### iCloud Sync Strategy
- **SwiftData + CloudKit**: Metadata syncs via CloudKit automatically
- **Audio Files**: Stored in iCloud Drive "Documents/AudioFiles" folder
- **User Control**: Users can toggle iCloud sync in Settings (requires app restart)
- **Path Resolution**: `AudioFile.fileURL` uses `iCloudStorageService.getAudioFilesDirectory()` to resolve correct path

### Subscription Tiers
```swift
// Free: 3 analyses/month, GPT-4o-mini, 3 recommendations
// Pro: Unlimited analyses, GPT-4o, 5 recommendations
```

Check before analysis:
```swift
let canAnalyze = await SubscriptionService.shared.canPerformAnalysis()
if !canAnalyze {
    // Show paywall or limit message
}
```

## Common Development Tasks

### Adding a New Audio Feature
1. Extract feature in `AudioFeatureExtractor.swift`
2. Add property to `AnalysisResult` model
3. Update `AudioAnalysisService.analyzeAudio()` to populate the property
4. Update schema version in `MixDoctorApp.init()` if model changed
5. Update `OpenAIService` prompt if AI should consider this feature

### Modifying Analysis Scoring
Primary logic in `AudioAnalysisService.analyzeAudio()`:
- Technical scoring: Lines ~232-319
- AI scoring: `OpenAIService.analyzeAudioFeatures()`
- Final score: `max(technicalScore, aiResponse.overallQuality)`

**Never change unmixed detection thresholds** without testing on multiple audio files.

### Working with iCloud Files
Always use `iCloudStorageService` for file operations:
```swift
// Get correct storage directory
let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()

// Copy file to storage
let destinationURL = try iCloudStorageService.shared.copyAudioFile(from: sourceURL)

// Ensure file is downloaded (for iCloud files)
try await iCloudStorageService.shared.ensureFileIsDownloaded(at: fileURL)
```

### Updating SwiftData Schema
1. Modify `AudioFile` or `AnalysisResult` models
2. Increment `currentSchemaVersion` in `MixDoctorApp.init()` (currently v3)
3. Test migration on device with existing data
4. If migration fails, app auto-deletes and recreates store

## API Keys & Configuration

API keys are loaded from `Config.xcconfig`:
```swift
// In code:
let apiKey = Config.openAIAPIKey  // From Bundle.main.infoDictionary
```

**Never commit `Config.xcconfig`** - it's in `.gitignore`. Use `Config.xcconfig.template` as reference.

## Documentation Files

- [QUICK_START.md](QUICK_START.md) - Getting started with ChatGPT audio analysis
- [CHATGPT_AUDIO_ANALYSIS.md](CHATGPT_AUDIO_ANALYSIS.md) - Technical details of direct audio upload to GPT-4o
- [ICLOUD_SYNC_GUIDE.md](ICLOUD_SYNC_GUIDE.md) - iCloud integration details
- [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md) - Subscription setup guide
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing strategies
- [UNMIXED_DETECTION_IMPROVEMENT.md](UNMIXED_DETECTION_IMPROVEMENT.md) - Details on unmixed track detection algorithm
- [PERFORMANCE_FIX.md](PERFORMANCE_FIX.md) - Performance optimization notes

## Git Workflow

Current branch: `feature/analyze-audio-with-ChatGpt`

The project uses feature branches. When implementing features:
1. Create feature branch from main
2. Implement and test feature
3. Create PR with detailed description
4. After merge, delete feature branch

## Platform Requirements

- **iOS**: 17.0+ (uses SwiftData, Observation framework, CloudKit)
- **Swift**: 5.9+
- **Xcode**: 26.0.1+
