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

MixDoctor is an AI-powered audio mix analysis iOS app. Users import audio files, which are analyzed using AudioKit DSP algorithms and AI (Claude API primary, OpenAI fallback) to produce professional mixing quality scores and recommendations. Supports iOS, iPadOS, and macOS via Mac Catalyst. Monetized through RevenueCat subscriptions (4 free analyses/month, 50 for Pro).

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

## Configuration

API keys are in `Config.xcconfig` (gitignored). Copy `Config.xcconfig.template` to `Config.xcconfig` and fill in `OPENAI_API_KEY`, `CLAUDE_API_KEY`. Firebase requires `GoogleService-Info.plist` (template provided).

## Critical Patterns & Pitfalls

- **Never store full file paths in SwiftData** — simulator container paths change between builds
- **Always download iCloud files before AVFoundation metadata extraction** — `AudioImportService` polls up to 30s for download completion
- **Use `@Transient` for large arrays in SwiftData models** — direct storage crashes CloudKit sync
- **Use `#if targetEnvironment(macCatalyst)` for Mac-specific code** — font scaling and window management break iOS otherwise
- **Never call `scanForOrphanedFiles()` on view appear** — causes import timeout errors
- **Singleton testing**: call `reset()` in both `setUp()` and `tearDown()` to prevent state leakage
- **AudioKit warmup**: `AudioKitWarmupTests` must run first (alphabetically) to prevent first-run test failures
- **`@MainActor` service tests** need `async setUp/tearDown` with initialization delay

## Dependencies (SPM)

AudioKit, OpenAI, RevenueCat (+ RevenueCatUI, ReceiptParser), FirebaseAnalytics

## Schemes

- `MixDoctor` — main iOS scheme (includes tests)
- `MixDoctorMac` / `MixDoctorMac-Simulator` — Mac Catalyst
- Device-specific: `MixDoctor-iPhone-Simulator-17-ProMax`, `MixDoctor-iPad`, `MixDoctor-iPad-real`
