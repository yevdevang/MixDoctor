# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build for iPhone Simulator
xcodebuild build -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build for Mac Catalyst
xcodebuild build -scheme MixDoctorMac -destination 'platform=macOS'

# Run all tests
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a specific test class
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MixDoctorTests/ClaudeAPIScoringTests

# Run a specific test method
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MixDoctorTests/ClaudeAPIScoringTests/testMixStage_ScoreRange

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/MixDoctor-*
```

Integration tests are skipped by default; set `RUN_INTEGRATION_TESTS=1` to enable.

## Project Overview

MixDoctor is an AI-powered audio mix analysis iOS app. Users import audio files, which are analyzed using AudioKit DSP algorithms and AI (Claude API primary, OpenAI fallback) to produce professional mixing quality scores and recommendations. Supports iOS, iPadOS, and macOS via Mac Catalyst. Monetized through RevenueCat subscriptions with tiered analysis limits (see Subscription Tiers below). No free trial — payment starts immediately.

## Architecture

**MVVM with SwiftUI + SwiftData** — all Swift, no UIKit views.

- **Entry point**: `MixDoctor/MixDoctorApp.swift` → `ContentView.swift` (tab-based navigation)
- **Features** (`MixDoctor/Features/`): Dashboard, Import, Analysis, Player, Settings, Paywall, Onboarding — each with `ViewModels/` and `Views/` subdirectories
- **Core** (`MixDoctor/Core/`): Services (singletons), Models, Extensions, Utilities, shared Views
- **ViewModels**: Use `@Observable` (not `ObservableObject`). Use `@State private var viewModel` pattern in views.
- **Data queries**: Use SwiftData `@Query` in views, `FetchDescriptor` in ViewModels

### Key Services (all singletons via `.shared`)

| Service | Purpose |
|---------|---------|
| `AudioKitService` | DSP audio analysis (AudioKit 6) |
| `ClaudeAPIService` | Primary AI analysis via Anthropic API |
| `OpenAIService` | Fallback AI analysis |
| `AudioImportService` | File import with metadata extraction (`@MainActor`) |
| `iCloudStorageService` | iCloud Documents file operations |
| `iCloudSyncMonitor` | Real-time iCloud sync tracking |
| `SubscriptionService` | RevenueCat subscription management |
| `AnalysisResultPersistence` | JSON backup of analysis results |

### Data Layer

**Two-layer iCloud sync:**
1. **SwiftData + CloudKit** → syncs `AudioFile` metadata automatically
2. **iCloud Documents** → syncs actual audio files via `iCloudStorageService`

`AudioFile` stores only the filename (not full path) — iOS Simulator container paths change per build. The `fileURL` is a `@Transient` computed property that reconstructs the path dynamically.

Large arrays (e.g., frequency spectrum data) use `@Transient` computed properties backed by `Data` storage — direct `[Float]` arrays crash CloudKit sync.

### Subscription Tiers

| Tier | Analyses | Reset Period | Notes |
|------|----------|-------------|-------|
| Free | 4 | per month | Includes 4 demo tracks |
| Weekly Pro | 10 | per week | `isWeeklySubscriber = true` |
| Monthly Pro | 50 | per month | |
| Annual Pro | 50 | per month | |

- **No free trial** — removed from App Store Connect. Payment starts immediately.
- `SubscriptionService.currentProLimit` returns 10 or 50 based on `isWeeklySubscriber`
- Subscription type is saved to iCloud KV store (`subscriptionTypeKey`) and detected from RevenueCat offerings
- Analysis is disabled (`canPerformAnalysis() → false`) when the limit is reached

## Configuration

API keys are in `Config.xcconfig` (gitignored). Copy `Config.xcconfig.template` to `Config.xcconfig` and fill in `OPENAI_API_KEY`, `CLAUDE_API_KEY`. Firebase requires `GoogleService-Info.plist` (template provided).

## Common UI Patterns

### ViewModel Loading in Views
```swift
@State private var viewModel: ImportViewModel?

var body: some View {
    if let viewModel {
        contentView(viewModel: viewModel)
    } else {
        ProgressView("Loading...")
            .task { await initializeViewModel() }
    }
}
```

### Cross-View Updates via NotificationCenter
```swift
// Post (e.g., after file deletion)
NotificationCenter.default.post(name: .audioFileDeleted, object: nil)

// Listen in other views
.onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
    viewModel.loadImports()
}
```

### Primary Accent Color
```swift
Color(red: 0.435, green: 0.173, blue: 0.871)  // Purple
```

## MacCatalyst-Specific Patterns

Font scaling (applied in `MixDoctorApp.init`):
```swift
#if targetEnvironment(macCatalyst)
let fontScale: CGFloat = 1.4
let navBarAppearance = UINavigationBarAppearance()
navBarAppearance.largeTitleTextAttributes = [
    .font: UIFont.systemFont(ofSize: 34 * fontScale, weight: .bold)
]
#endif
```

Window sizing (applied in `ContentView.onAppear`):
```swift
#if targetEnvironment(macCatalyst)
if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    let screenBounds = windowScene.screen.bounds
    windowScene.sizeRestrictions?.minimumSize = screenBounds.size
}
#endif
```

## Subscription Testing

Use `MockSubscriptionService` + `MockPaywallView` for rapid iteration without App Store Connect. Switch by replacing `.shared` references and imports. See `SUBSCRIPTION_TESTING_GUIDE.md` for the full swap procedure.

## Critical Patterns & Pitfalls

- **Never store full file paths in SwiftData** — simulator container paths change between builds
- **Always download iCloud files before AVFoundation metadata extraction** — `AudioImportService` polls up to 30s for download completion
- **Use `@Transient` for large arrays in SwiftData models** — direct storage crashes CloudKit sync
- **Use `#if targetEnvironment(macCatalyst)` for Mac-specific code** — font scaling and window management break iOS otherwise
- **Never call `scanForOrphanedFiles()` on view appear** — causes import timeout errors
- **Singleton testing**: call `reset()` in both `setUp()` and `tearDown()` to prevent state leakage
- **AudioKit warmup**: `AudioKitWarmupTests` must run first (alphabetically) to prevent first-run test failures
- **`@MainActor` service tests** need `async setUp/tearDown` with initialization delay
- **No free trial code in UI** — all trial references were removed; `isInTrialPeriod` in `SubscriptionService` is kept only for backward compat with existing RevenueCat trial users

## Dependencies (SPM)

AudioKit, OpenAI, RevenueCat (+ RevenueCatUI, ReceiptParser), FirebaseAnalytics

## Schemes

- `MixDoctor` — main iOS scheme (includes tests)
- `MixDoctorMac` / `MixDoctorMac-Simulator` — Mac Catalyst
- Device-specific: `MixDoctor-iPhone-Simulator-17-ProMax`, `MixDoctor-iPad`, `MixDoctor-iPad-real`

## Key Documentation

- `SUBSCRIPTION_TESTING_GUIDE.md` — mock vs real RevenueCat testing
- `TESTING_GUIDE.md` — full app testing procedures
- `.docs/` — phase-by-phase implementation guides and design specs
