# Phase 1: Project Setup & Architecture

**Duration**: Week 1
**Goal**: Establish solid foundation with proper architecture and dependencies

## Objectives

- Configure Xcode project with proper structure
- Set up required frameworks and dependencies
- Implement MVVM architecture
- Create navigation structure
- Establish coding standards and conventions

## Project Structure

```
MixDoctor/
├── App/
│   ├── MixDoctorApp.swift
│   └── AppDelegate.swift (if needed)
├── Core/
│   ├── Models/
│   │   ├── AudioFile.swift
│   │   ├── AnalysisResult.swift
│   │   └── AnalysisMetrics.swift
│   ├── Services/
│   │   ├── AudioImportService.swift
│   │   ├── AudioAnalysisService.swift
│   │   ├── AudioPlayerService.swift
│   │   └── DataPersistenceService.swift
│   ├── Utilities/
│   │   ├── AudioProcessor.swift
│   │   ├── FileManager+Extensions.swift
│   │   └── Constants.swift
│   └── Extensions/
│       ├── Color+Theme.swift
│       ├── View+Extensions.swift
│       └── Double+Formatting.swift
├── Features/
│   ├── Import/
│   │   ├── Views/
│   │   │   ├── ImportView.swift
│   │   │   └── FilePickerView.swift
│   │   └── ViewModels/
│   │       └── ImportViewModel.swift
│   ├── Analysis/
│   │   ├── CoreML/
│   │   │   └── Models/ (ML models will go here)
│   │   ├── Views/
│   │   │   ├── ResultsView.swift
│   │   │   └── VisualizationView.swift
│   │   └── ViewModels/
│   │       └── AnalysisViewModel.swift
│   ├── Dashboard/
│   │   ├── Views/
│   │   │   ├── DashboardView.swift
│   │   │   └── TrackListView.swift
│   │   └── ViewModels/
│   │       └── DashboardViewModel.swift
│   ├── Player/
│   │   ├── Views/
│   │   │   ├── PlayerView.swift
│   │   │   └── WaveformView.swift
│   │   └── ViewModels/
│   │       └── PlayerViewModel.swift
│   └── Settings/
│       ├── Views/
│       │   └── SettingsView.swift
│       └── ViewModels/
│           └── SettingsViewModel.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Info.plist
└── Supporting Files/
    └── MixDoctor.entitlements
```

## Required Frameworks

### System Frameworks (Built-in)
Add to target under "Frameworks, Libraries, and Embedded Content":

```swift
// In Xcode Project Settings:
- AVFoundation.framework
- Accelerate.framework
- CoreML.framework
- SwiftUI.framework
- Combine.framework
```

### Swift Package Dependencies

Add via File > Add Package Dependencies:

1. **Charts** (for visualizations)
   - URL: `https://github.com/danielgindi/Charts.git`
   - Version: 5.0.0+

## Step-by-Step Setup

### 1. Xcode Project Configuration

#### Update Info.plist
Add required permissions:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>MixDoctor needs access to analyze audio files you select.</string>
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.audio</string>
        </array>
        <key>UTTypeDescription</key>
        <string>Audio File</string>
        <key>UTTypeIdentifier</key>
        <string>com.mixdoctor.audio</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>wav</string>
                <string>aiff</string>
                <string>mp3</string>
                <string>m4a</string>
                <string>flac</string>
            </array>
        </dict>
    </dict>
</array>
```

#### Deployment Target
- iOS 17.0+ (to use latest SwiftData and SwiftUI features)

### 2. Create Base Models

#### AudioFile.swift
```swift
import Foundation
import SwiftData

@Model
final class AudioFile {
    var id: UUID
    var fileName: String
    var fileURL: URL
    var duration: TimeInterval
    var sampleRate: Double
    var bitDepth: Int
    var numberOfChannels: Int
    var fileSize: Int64
    var dateImported: Date
    var dateAnalyzed: Date?

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?

    init(fileName: String, fileURL: URL, duration: TimeInterval,
         sampleRate: Double, bitDepth: Int, numberOfChannels: Int, fileSize: Int64) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.numberOfChannels = numberOfChannels
        self.fileSize = fileSize
        self.dateImported = Date()
    }
}
```

#### AnalysisResult.swift
```swift
import Foundation
import SwiftData

@Model
final class AnalysisResult {
    var id: UUID
    var audioFile: AudioFile?
    var dateAnalyzed: Date
    var overallScore: Double // 0-100

    // Analysis metrics
    var stereoWidthScore: Double
    var phaseCoherence: Double
    var frequencyBalance: FrequencyBalance
    var dynamicRange: Double
    var loudnessLUFS: Double
    var peakLevel: Double

    // Issue flags
    var hasPhaseIssues: Bool
    var hasStereoIssues: Bool
    var hasFrequencyImbalance: Bool
    var hasDynamicRangeIssues: Bool

    // Recommendations
    var recommendations: [String]

    init(audioFile: AudioFile) {
        self.id = UUID()
        self.audioFile = audioFile
        self.dateAnalyzed = Date()
        self.overallScore = 0
        self.stereoWidthScore = 0
        self.phaseCoherence = 0
        self.frequencyBalance = FrequencyBalance()
        self.dynamicRange = 0
        self.loudnessLUFS = 0
        self.peakLevel = 0
        self.hasPhaseIssues = false
        self.hasStereoIssues = false
        self.hasFrequencyImbalance = false
        self.hasDynamicRangeIssues = false
        self.recommendations = []
    }
}

struct FrequencyBalance: Codable {
    var lowEnd: Double = 0 // 20-250 Hz
    var lowMids: Double = 0 // 250-500 Hz
    var mids: Double = 0 // 500-2000 Hz
    var highMids: Double = 0 // 2000-6000 Hz
    var highs: Double = 0 // 6000-20000 Hz
}
```

### 3. Create Navigation Structure

#### MainTabView.swift
```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard
        case importView
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(Tab.dashboard)

            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .tag(Tab.importView)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
}
```

#### Update MixDoctorApp.swift
```swift
import SwiftUI
import SwiftData

@main
struct MixDoctorApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [AudioFile.self, AnalysisResult.self])
    }
}
```

### 4. Create Base Services

#### AudioImportService.swift
```swift
import Foundation
import AVFoundation

@Observable
final class AudioImportService {
    func importAudioFile(from url: URL) async throws -> AudioFile {
        // Implementation in Phase 2
        fatalError("To be implemented")
    }

    func validateAudioFile(_ url: URL) throws -> Bool {
        // Implementation in Phase 2
        fatalError("To be implemented")
    }
}
```

#### AudioAnalysisService.swift
```swift
import Foundation
import CoreML
import AVFoundation

@Observable
final class AudioAnalysisService {
    func analyzeAudio(_ audioFile: AudioFile) async throws -> AnalysisResult {
        // Implementation in Phase 3
        fatalError("To be implemented")
    }
}
```

### 5. Create Theme and Constants

#### Color+Theme.swift
```swift
import SwiftUI

extension Color {
    // Primary colors
    static let primaryAccent = Color("AccentColor")

    // Status colors
    static let successGreen = Color(red: 0.3, green: 0.8, blue: 0.4)
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let errorRed = Color(red: 0.9, green: 0.3, blue: 0.3)

    // Analysis scores
    static let scoreExcellent = Color.green
    static let scoreGood = Color(red: 0.6, green: 0.8, blue: 0.3)
    static let scoreFair = Color.orange
    static let scorePoor = Color.red

    // Background
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
}
```

#### Constants.swift
```swift
import Foundation

enum AppConstants {
    // Audio settings
    static let supportedAudioFormats = ["wav", "aiff", "mp3", "m4a", "flac"]
    static let maxFileSizeMB = 500
    static let minSampleRate = 44100.0

    // Analysis settings
    static let fftSize = 2048
    static let hopSize = 512
    static let analysisTimeout: TimeInterval = 60

    // UI settings
    static let animationDuration = 0.3
    static let cornerRadius: CGFloat = 12
    static let defaultPadding: CGFloat = 16

    // Score thresholds
    static let excellentThreshold = 85.0
    static let goodThreshold = 70.0
    static let fairThreshold = 50.0
}
```

## Architecture Patterns

### MVVM (Model-View-ViewModel)

**Models**: SwiftData models for persistence
**Views**: SwiftUI views (declarative UI)
**ViewModels**: Observable objects managing state and business logic

Example ViewModel structure:
```swift
import SwiftUI

@Observable
final class ImportViewModel {
    private let importService: AudioImportService

    var isImporting = false
    var importProgress: Double = 0
    var importedFiles: [AudioFile] = []
    var errorMessage: String?

    init(importService: AudioImportService = AudioImportService()) {
        self.importService = importService
    }

    func importFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let audioFile = try await importService.importAudioFile(from: url)
            importedFiles.append(audioFile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Coding Standards

### Swift Style Guide
- Use Swift Concurrency (async/await) for asynchronous operations
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Use proper error handling (do-catch, Result types)

### File Organization
- One type per file
- Group related files in folders
- Use extensions to organize code by functionality

### Git Workflow
- Feature branch workflow
- Meaningful commit messages
- Pull requests for major features

## Testing Setup

Create test targets structure:
```
MixDoctorTests/
├── Models/
├── Services/
├── ViewModels/
└── Utilities/

MixDoctorUITests/
├── ImportFlowTests.swift
├── AnalysisFlowTests.swift
└── DashboardTests.swift
```

## Dependencies Installation

### Add Swift Packages
1. Open Xcode
2. File > Add Package Dependencies
3. Add Charts package for visualizations

### Verify Build
- Clean build folder: Cmd+Shift+K
- Build project: Cmd+B
- Run on simulator to verify setup

## Deliverables

- [ ] Project structure created with all folders
- [ ] Base models defined (AudioFile, AnalysisResult)
- [ ] Navigation structure implemented (TabView)
- [ ] Base services created (stub implementations)
- [ ] Theme and constants defined
- [ ] SwiftData model container configured
- [ ] Build succeeds with no errors
- [ ] Test targets configured

## Next Phase

Proceed to [Phase 2: Audio Import System](02-phase-audio-import.md) to implement file import functionality.

## Estimated Time
- Initial setup: 2 hours
- Model creation: 3 hours
- Navigation and architecture: 2 hours
- Theme and constants: 1 hour
- Testing and verification: 2 hours

**Total: ~10 hours (1-2 days)**
