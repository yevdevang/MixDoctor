# Tonn API Integration for MixDoctor

This document explains how to integrate and use the Tonn API service in your MixDoctor app.

## Overview

The Tonn API, powered by RoEx Audio, provides professional audio analysis capabilities including:

- **Clipping Detection**: Identifies unwanted distortion and peaks
- **Dynamic Range Analysis**: Evaluates compression levels and dynamics
- **Loudness Analysis**: Compares track loudness to streaming platform standards
- **Stereo Field Assessment**: Analyzes stereo imaging and mono compatibility
- **Tonal Balance**: Provides insights on frequency distribution
- **Phase Issues Detection**: Identifies phase correlation problems

## Setup

### 1. API Key Configuration

Your API key is already configured in `Info.plist`:
```xml
<key>TONN_API_KEY</key>
<string>AIzaSyBCLq6x3oQdm8a6nAy7G_zGJlpLhsdNE6o</string>
```

### 2. Service Files

The following files have been created:

- **`TonnAPIService.swift`**: Main service class with full API integration
- **`TonnAnalysisView.swift`**: Example SwiftUI view demonstrating usage

## API Endpoints Used

### Upload Endpoint
```
POST https://tonn.roexaudio.com/upload
```
Uploads audio files to secure cloud storage.

### Analysis Endpoint  
```
POST https://tonn.roexaudio.com/mixanalysis
```
Analyzes uploaded audio files for mix quality.

## Usage Example

### Basic Analysis

```swift
import SwiftUI

struct MyAnalysisView: View {
    @State private var tonnService = TonnAPIService.shared
    @State private var result: TonnAnalysisResult?
    
    var body: some View {
        VStack {
            if tonnService.isAnalyzing {
                ProgressView("Analyzing...", value: tonnService.analysisProgress)
            }
            
            Button("Analyze Audio") {
                analyzeAudio()
            }
            .disabled(tonnService.isAnalyzing)
        }
    }
    
    private func analyzeAudio() {
        // Assuming you have an AudioFile instance
        guard let audioFile = selectedAudioFile else { return }
        
        Task {
            do {
                let result = try await tonnService.analyzeAudio(
                    audioFile,
                    musicalStyle: .rock,  // Choose appropriate style
                    isMaster: false       // true if this is a mastered track
                )
                
                await MainActor.run {
                    self.result = result
                    displayResults(result)
                }
                
            } catch {
                print("Analysis failed: \(error)")
            }
        }
    }
    
    private func displayResults(_ result: TonnAnalysisResult) {
        print("Analysis completed!")
        print("Clipping: \(result.clipping.displayName)")
        print("Dynamic Range: \(result.dynamicRange.displayName)")
        print("Loudness: \(result.loudness.displayName)")
        print("LUFS: \(result.integratedLoudnessLufs)")
        print("Mono Compatible: \(result.monoCompatible)")
        
        // Display recommendations
        for (index, recommendation) in result.recommendations.enumerated() {
            print("\(index + 1). \(recommendation)")
        }
    }
}
```

## Musical Styles

The API supports these musical styles:

- `rock`, `metal`, `punk`
- `pop`, `indiePop`, `indieRock`
- `electronic`, `dance`, `house`, `techno`, `trance`
- `hipHopGrime`, `trap`, `rnb`
- `acoustic`, `folk`, `country`
- `jazz`, `blues`, `soul`, `funk`
- `instrumental`, `ambient`, `experimental`
- `orchestral`, `afrobeat`, `drumNBass`
- `loFi`, `reggae`, `latin`

## Analysis Results

### TonnAnalysisResult Structure

```swift
struct TonnAnalysisResult {
    let completionTime: Date
    let bitDepth: Int
    let sampleRate: Int
    let clipping: ClippingLevel          // .none, .minor, .moderate, .severe
    let dynamicRange: DynamicRangeLevel  // .less, .normal, .more
    let loudness: LoudnessLevel          // .less, .normal, .more
    let integratedLoudnessLufs: Double   // LUFS measurement
    let peakLoudnessDbfs: Double         // Peak level in dBFS
    let monoCompatible: Bool             // Mono compatibility
    let phaseIssues: Bool                // Phase correlation issues
    let stereoField: StereoFieldType     // .mono, .narrow, .normal, .wide, .stereoUpmix
    let tonalProfile: TonalProfile?      // Frequency analysis
    let musicalStyle: TonnMusicalStyle   // Detected/specified style
    let recommendations: [String]        // AI-generated recommendations
}
```

### Tonal Profile

```swift
struct TonalProfile {
    let bass: FrequencyLevel      // .low, .normal, .high
    let lowMid: FrequencyLevel
    let highMid: FrequencyLevel
    let high: FrequencyLevel
}
```

## Integration with Existing Analysis

You can integrate Tonn API results with your existing analysis system:

```swift
// In your existing AudioAnalysisService
func analyzeWithTonn(_ audioFile: AudioFile) async throws -> CombinedAnalysisResult {
    // Run both analyses in parallel
    async let localAnalysis = self.analyzeAudio(audioFile)
    async let tonnAnalysis = TonnAPIService.shared.analyzeAudio(audioFile, musicalStyle: .rock)
    
    let (local, tonn) = try await (localAnalysis, tonnAnalysis)
    
    return CombinedAnalysisResult(
        localResults: local,
        tonnResults: tonn,
        combinedRecommendations: mergerecommendations(local, tonn)
    )
}
```

## Error Handling

The service provides comprehensive error handling:

```swift
enum TonnAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse(String)
    case httpError(Int, String)
    case uploadFailed(String)
    case analysisError(String)
    case decodingError(String)
    case timeout(String)
}
```

## Progress Tracking

The service provides real-time progress updates:

```swift
// Monitor progress
@State private var tonnService = TonnAPIService.shared

var body: some View {
    VStack {
        if tonnService.isAnalyzing {
            ProgressView(value: tonnService.analysisProgress) {
                Text("Analyzing with Tonn API...")
            } currentValueLabel: {
                Text("\(Int(tonnService.analysisProgress * 100))%")
            }
        }
    }
}
```

## Best Practices

1. **Musical Style Selection**: Choose the most appropriate style for accurate analysis
2. **Master vs Mix**: Correctly specify whether the track is mastered for proper evaluation
3. **Error Handling**: Always wrap API calls in do-catch blocks
4. **Progress Updates**: Use the built-in progress tracking for better UX
5. **Rate Limiting**: Be mindful of API rate limits and costs

## API Documentation

For complete API documentation, visit: https://roex.stoplight.io/docs/tonn-api/

## Support

For Tonn API support:
- Portal: https://tonn-portal.roexaudio.com
- Email: support@roexaudio.com

## Features Comparison

| Feature | MixDoctor Local | Tonn API |
|---------|----------------|----------|
| Speed | Fast | Moderate (upload + analysis) |
| Accuracy | Good | Professional Grade |
| Cost | Free | Pay per analysis |
| Offline | Yes | No |
| Professional Insights | Basic | Advanced |
| Streaming Standards | Limited | Comprehensive |

Use Tonn API for professional-grade analysis and local analysis for quick feedback during development.