# Demo Mixes Feature — Implementation Plan

## Context

New users open MixDoctor after onboarding to an empty dashboard with no files to analyze. They must import their own audio to experience the app. This creates a poor first impression — users who don't have mixes on their device can't try the core feature. Adding 4 bundled demo audio files lets users explore the analysis experience immediately.

## Design Decisions

- **4 demo files**: 2 Mix stage + 1 Master(Streaming) + 1 Unmixed, different genres
- **Analyses count normally** against the free 4/month limit — no special subscription bypass
- **User taps "Analyze"** themselves — no pre-analyzed results
- **Not deletable** by the user
- **New onboarding screen** (5th) explains demo files + **"DEMO" badge** on each file in dashboard
- **User provides real audio files** to bundle

---

## Files to Create

### 1. `MixDoctor/Core/Services/DemoFileService.swift`

New `@MainActor` singleton service that:
- Defines 4 `DemoFileDefinition` structs (bundleFileName, displayName, genre, mixStage)
- On first launch: copies audio files from app bundle → `AudioFiles/` directory, extracts metadata via `AVURLAsset`, creates `AudioFile` SwiftData records with `isDemoFile = true`
- Tracks loading state via `UserDefaults("hasLoadedDemoFiles")`
- Handles edge cases: re-install (checks for existing `isDemoFile == true` records), file already on disk (skips copy)

Demo file definitions:
| # | Display Name | Genre | Mix Stage | Bundle File |
|---|-------------|-------|-----------|-------------|
| 1 | Pop Demo | Pop | mix | `DemoMix_Pop_Mix.wav` |
| 2 | Rock Demo | Rock/Indie | mix | `DemoMix_Rock_Mix.wav` |
| 3 | EDM Demo | EDM/Electronic | master_streaming | `DemoMix_EDM_Master.wav` |
| 4 | Unmixed Demo | Pop | unmixed | `DemoMix_Pop_Unmixed.wav` |

*(Bundle filenames are placeholders — will match whatever the user provides)*

### 2. `MixDoctor/Features/Onboarding/Views/OnboardingDemoScreen.swift`

New onboarding screen (inserted as page 3, before Free Trial). Uses existing `OnboardingStep` and `OnboardingButton` components.

Content:
- Icon: `music.note.house.fill` (SF Symbol, 100pt, primaryAccent)
- Title: **"Sample Mixes Included"**
- Subtitle: *"We've included 4 demo audio files so you can explore the app right away"*
- Three steps using `OnboardingStep`:
  1. `waveform` — "2 Mix + 1 Master + 1 Unmixed" / "Different genres and stages to test with"
  2. `hand.tap` — "Tap to Analyze" / "Select any demo file and tap to run analysis"
  3. `square.and.arrow.down` — "Import Your Own" / "When you're ready, import your own mixes"
- "Next" button advances to page 4 (Free Trial)

### 3. `MixDoctor/Resources/DemoAudioFiles/` (directory)

User-provided audio files added to Xcode target's "Copy Bundle Resources". Recommend MP3 format or short WAV clips to minimize app bundle size increase.

---

## Files to Modify

### 4. `MixDoctor/Core/Models/AudioFile.swift`

Add `isDemoFile` property:
```swift
var isDemoFile: Bool  // after mixStage property
```

Update `init` — add parameter `isDemoFile: Bool = false`, assign `self.isDemoFile = isDemoFile`.

**Schema migration**: Keep `currentSchemaVersion = 4` in MixDoctorApp.swift. SwiftData handles adding a new `Bool` property with a default value via automatic lightweight migration — no destructive reset needed. Test to confirm; only bump to 5 if migration fails.

### 5. `MixDoctor/Features/Onboarding/Views/OnboardingView.swift`

- Insert `OnboardingDemoScreen(currentPage: $currentPage).tag(3)` before Free Trial
- Move `OnboardingFreeTrialScreen` from `.tag(3)` to `.tag(4)`
- Update completion check: `currentPage == 3` → `currentPage == 4`

### 6. `MixDoctor/Features/Analysis/Views/SharedComponents.swift` (AudioFileRow)

**Add "DEMO" badge** — after the mix stage text, wrap in an `HStack` and add:
```swift
if audioFile.isDemoFile {
    Text("DEMO")
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.primaryAccent))
}
```

**Hide Mac Catalyst trash button** for demo files:
```swift
if let onDelete = onDelete, !audioFile.isDemoFile {
```

### 7. `MixDoctor/Features/Dashboard/Views/DashboardView.swift`

- **Prevent swipe-to-delete**: In `deleteFiles(at:)`, filter out indices where `isDemoFile == true`
- **Prevent "Delete All"**: In `deleteAllFiles()`, filter out demo files from the deletion set; update confirmation count text
- **Sort demo files to bottom**: In `filteredFiles` computed property, after sorting, partition user files before demo files
- **Pass `nil` for onDelete** when constructing `AudioFileRow` for demo files

### 8. `MixDoctor/Features/Import/ViewModels/ImportViewModel.swift`

- Guard `removeImportedFile()`: `guard !file.isDemoFile else { return }`
- Guard `deleteAllFiles()`: filter out demo files

### 9. `MixDoctor/MixDoctorApp.swift`

Add demo file loading triggers:
```swift
// In body, on the ZStack:
.onChange(of: hasCompletedOnboarding) { oldValue, newValue in
    if newValue && !oldValue {
        Task {
            await DemoFileService.shared.loadDemoFilesIfNeeded(
                modelContext: modelContainer.mainContext
            )
        }
    }
}
.task {
    // Handle app update path (user already onboarded, feature newly added)
    if hasCompletedOnboarding {
        await DemoFileService.shared.loadDemoFilesIfNeeded(
            modelContext: modelContainer.mainContext
        )
    }
}
```

### 10. `MixDoctor/ContentView.swift` (minor)

After onboarding, the existing logic checks `allAudioFiles.isEmpty` to decide whether to navigate to Import tab. With demo files loaded, this will be `false` → user lands on Dashboard. Increase the post-notification sleep from 500ms to 1s for safety margin.

---

## Implementation Order

1. `AudioFile.swift` — add `isDemoFile` property
2. `DemoFileService.swift` — create service (compiles standalone)
3. Bundle audio files — add to Xcode project resources
4. `OnboardingDemoScreen.swift` — create view (compiles standalone)
5. `OnboardingView.swift` — wire in new screen, update page indices
6. `MixDoctorApp.swift` — add demo file loading triggers
7. `SharedComponents.swift` — add DEMO badge, hide delete for demo files
8. `DashboardView.swift` — deletion guards, sorting
9. `ImportViewModel.swift` — deletion guards
10. `ContentView.swift` — adjust timing

## Potential Risks

| Risk | Mitigation |
|------|-----------|
| Schema migration breaks CloudKit | Test with default `false` first; SwiftData lightweight migration should handle it. Bump schema version only if needed. |
| App bundle size increase (large WAV files) | Use MP3 or short clips (30-60s). 4 MP3 files ≈ 15-20 MB total. |
| Race condition: demo files not ready when `allAudioFiles.isEmpty` is checked | 1s delay + `.task` ensures loading completes. Worst case: user briefly sees Import tab, demo files appear on Dashboard. |
| iCloud sync: demo file records sync via CloudKit but physical files are device-local | `DemoFileService` re-copies from bundle on each device. `hasLoadedDemoFiles` is device-local UserDefaults. |

## Verification

1. **Fresh install**: Onboarding → new demo screen (page 4/5) → "Get Started" → Dashboard shows 4 demo files with DEMO badge → tap file → Analyze → results display normally
2. **Existing user (app update)**: App launches → demo files auto-load → appear at bottom of dashboard with DEMO badge
3. **Deletion blocked**: Swipe-to-delete does nothing for demo files. Mac trash button hidden. "Delete All" skips demo files.
4. **Analysis counts normally**: Analyzing a demo file decrements free tier counter (4→3→2→1→0→paywall)
5. **Re-install**: Demo files reload correctly from bundle
