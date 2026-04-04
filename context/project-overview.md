# MixDoctor — Project Overview

> **AI-powered audio mix analysis for iOS, iPadOS, and macOS.**

---

## What It Does

MixDoctor lets users import audio files and receive professional mixing quality scores and actionable recommendations. Analysis is performed using AudioKit DSP algorithms combined with AI (Claude API primary, OpenAI as fallback). Results are persisted and synced across devices via iCloud.

---

## Target Platforms

- **iOS / iPadOS** — primary targets
- **macOS** — via Mac Catalyst (separate `MixDoctorMac` scheme)

---

## Monetization

Subscriptions managed through **RevenueCat**. No free trial — payment starts immediately.

| Tier | Analyses | Reset Period |
|---|---|---|
| Free | 4 | per month (includes 4 demo tracks) |
| Weekly Pro | 10 | per week |
| Monthly Pro | 50 | per month |
| Annual Pro | 50 | per month |

Analysis is gated via `SubscriptionService.canPerformAnalysis()`. When the limit is reached, the paywall is shown.

---

## Architecture

**MVVM with SwiftUI + SwiftData** — all Swift, no UIKit views.

- **Entry point**: `MixDoctorApp.swift` → `ContentView.swift` (tab-based navigation)
- **Features** (`MixDoctor/Features/`): Dashboard, Import, Analysis, Player, Settings, Paywall, Onboarding — each has `ViewModels/` and `Views/` subdirectories
- **Core** (`MixDoctor/Core/`): Services (singletons), Models, Extensions, Utilities, shared Views
- **ViewModels**: `@Observable` (not `ObservableObject`). Views use `@State private var viewModel` pattern.
- **Data queries**: `@Query` in Views, `FetchDescriptor` in ViewModels

---

## Key Services

| Service | Purpose |
|---|---|
| `AudioKitService` | DSP audio analysis (AudioKit 6) |
| `ClaudeAPIService` | Primary AI scoring via Anthropic API |
| `OpenAIService` | Fallback AI analysis |
| `AudioImportService` | File import + metadata extraction (`@MainActor`) |
| `iCloudStorageService` | iCloud Documents file operations |
| `iCloudSyncMonitor` | Real-time iCloud sync tracking |
| `SubscriptionService` | RevenueCat subscription management |
| `AnalysisResultPersistence` | JSON backup of analysis results |

All services are singletons accessed via `.shared`.

---

## Data Layer

**Two-layer iCloud sync:**

1. **SwiftData + CloudKit** — syncs `AudioFile` metadata automatically
2. **iCloud Documents** — syncs actual audio files via `iCloudStorageService`

`AudioFile` stores only the filename (not full path) — iOS Simulator container paths change per build. `fileURL` is a `@Transient` computed property that reconstructs the path at runtime.

Large arrays (e.g., frequency spectrum data) use `@Transient` computed properties backed by `Data` storage — direct `[Float]` arrays crash CloudKit sync.

---

## Configuration

API keys live in `Config.xcconfig` (gitignored). Copy `Config.xcconfig.template` → `Config.xcconfig` and fill in `OPENAI_API_KEY` and `CLAUDE_API_KEY`. Firebase requires `GoogleService-Info.plist` (template provided).

---

## Dependencies (SPM)

AudioKit, OpenAI, RevenueCat (+ RevenueCatUI, ReceiptParser), FirebaseAnalytics

---

## Schemes

| Scheme | Use |
|---|---|
| `MixDoctor` | Main iOS (includes tests) |
| `MixDoctorMac` | Mac Catalyst (device) |
| `MixDoctorMac-Simulator` | Mac Catalyst (simulator) |
| `MixDoctor-iPhone-Simulator-17-ProMax` | iPhone-specific testing |
| `MixDoctor-iPad` / `MixDoctor-iPad-real` | iPad |

---

## Key Documentation

- `CLAUDE.md` — build commands, critical patterns, architecture reference
- `SUBSCRIPTION_TESTING_GUIDE.md` — mock vs real RevenueCat testing
- `TESTING_GUIDE.md` — full app testing procedures
- `.docs/` — phase-by-phase implementation guides and design specs
