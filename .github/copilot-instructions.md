# MixDoctor AI Coding Instructions

## Project Overview
MixDoctor is a professional audio analysis iOS app built with SwiftUI, SwiftData, and MacCatalyst. It analyzes audio files for mixing quality using DSP algorithms and AI (Claude API), with iCloud sync for cross-device data sharing.

## Architecture & Data Flow

### Core Pattern: MVVM with SwiftData
- **Models**: `AudioFile` (SwiftData @Model) with embedded `AnalysisResult`
- **Services**: Singleton services (`AudioImportService`, `AudioKitService`, `iCloudStorageService`)
- **ViewModels**: `@Observable` classes (not `ObservableObject`) - use `@State private var viewModel: VM?` pattern
- **Views**: SwiftUI with `@Query` for SwiftData fetches

### Critical File Storage Architecture
**Two-layer iCloud sync:**
1. **SwiftData + CloudKit** → Syncs `AudioFile` metadata automatically
2. **iCloud Documents** → Syncs actual audio files via `iCloudStorageService`

```swift
// AudioFile stores ONLY filename, not full path
@Model class AudioFile {
    private var storedFileName: String  // Just "song.wav"
    
    // Computed property regenerates path dynamically
    @Transient var fileURL: URL {
        iCloudStorageService.shared.getAudioFilesDirectory()
            .appendingPathComponent(storedFileName)
    }
}
```

**Why**: iOS Simulator container paths change on each build. Storing full paths causes "file not found" errors.

### iCloud Import: Critical Download Wait Pattern
Files from iCloud Drive timeout during metadata extraction if not downloaded first:

```swift
// In AudioImportService.importAudioFile()
if url.path.contains("Mobile Documents") {
    let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
    if resourceValues.ubiquitousItemDownloadingStatus == .notDownloaded {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        // Wait up to 30s with 500ms polling
        var attempts = 0
        while attempts < 60 {
            try await Task.sleep(nanoseconds: 500_000_000)
            // Check if .current status achieved
        }
    }
}
```

**Never** attempt AVFoundation metadata extraction before confirming download complete.

## SwiftData Patterns

### ModelContext Access
```swift
@Environment(\.modelContext) private var modelContext

// Fetch with descriptors
let descriptor = FetchDescriptor<AudioFile>(
    sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
)
let files = try? modelContext.fetch(descriptor)
```

### Transient Properties with Data Backing
Large arrays crash SwiftData. Use `@Transient` with Data backing:

```swift
@Transient
var frequencySpectrum: [Float]? {
    get {
        guard let data = frequencySpectrumData else { return nil }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
    set {
        frequencySpectrumData = newValue?.withUnsafeBytes { Data($0) }
    }
}
var frequencySpectrumData: Data?  // Actual stored property
```

## MacCatalyst-Specific Patterns

### Conditional Compilation
```swift
#if targetEnvironment(macCatalyst)
// Mac-specific code: larger fonts, window management, keyboard shortcuts
#endif
```

### Font Scaling (Applied in MixDoctorApp.init)
```swift
let fontScale: CGFloat = 1.4
let navBarAppearance = UINavigationBarAppearance()
navBarAppearance.largeTitleTextAttributes = [
    .font: UIFont.systemFont(ofSize: 34 * fontScale, weight: .bold)
]
```

### Window Sizing (Applied in ContentView.onAppear)
```swift
if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    let screenBounds = windowScene.screen.bounds
    windowScene.sizeRestrictions?.minimumSize = screenBounds.size
    if let window = windowScene.windows.first {
        window.frame = screenBounds
    }
}
```

## Subscription System (RevenueCat)

### Mock vs Real Services
**Mock**: `MockSubscriptionService` + `MockPaywallView` (for testing without App Store Connect)
**Real**: `SubscriptionService` + `PaywallView` (requires App Store Connect setup)

Switch by replacing `.shared` references and imports. See `SUBSCRIPTION_TESTING_GUIDE.md`.

### Free Tier Logic
```swift
// 3 analyses per month for free users
var remainingFreeAnalyses: Int {
    max(0, 3 - analysisCountThisMonth)
}
```

## Common Patterns

### Loading State in Views
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

### Progress Indication During Import
```swift
if viewModel.isImporting {
    HStack {
        ProgressView().progressViewStyle(.circular)
        Text("Importing files... \(Int(viewModel.importProgress * 100))%")
    }
    ProgressView(value: viewModel.importProgress).tint(.accentColor)
}
```

### NotificationCenter for Cross-View Updates
```swift
// Post when files deleted
NotificationCenter.default.post(name: .audioFileDeleted, object: nil)

// Listen in other views
.onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
    viewModel.loadImports()
}
```

## Critical Debugging Patterns

### Orphaned File Scanning (DISABLED)
Automatically re-importing iCloud files on view appear causes timeout errors. This is **disabled** in `ImportView.task`:

```swift
// DISABLED: Check for orphaned files causes timeout errors
// Task { await viewModel.scanForOrphanedFiles() }
```

Only run orphaned file scans manually via debug views, never automatically.

### iCloud File Status Checking
```swift
let service = iCloudStorageService.shared
service.printFileStatus()  // Console dumps all file locations + download status
```

## Testing & Build Commands

### Build for iPhone Simulator
```bash
xcodebuild -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Test Subscription Flow
1. Use `MockSubscriptionService` for rapid iteration (no App Store Connect needed)
2. Switch to real `SubscriptionService` only for final testing
3. See `TESTING_GUIDE.md` and `SUBSCRIPTION_TESTING_GUIDE.md` for detailed flows

### iCloud Sync Testing
Both simulators must:
- Sign into **same Apple ID**
- Enable **iCloud Drive** in Settings
- May need restart for sync to propagate

Check console for: `"✅ Started iCloud monitoring"`, `"⬇️ Downloading files from iCloud..."`

## File Organization
- `MixDoctor/Features/` - Feature modules (Dashboard, Import, Player, Analysis, Settings, Paywall)
- `MixDoctor/Core/` - Shared (Models, Services, Extensions, Views)
- `MixDoctor/App/` - App-level (MixDoctorApp.swift, ContentView.swift)
- `.docs/` - Phase-by-phase implementation guides (read these for context)

## Common Pitfalls

1. **Don't store full file paths in SwiftData** - simulator containers change
2. **Always download iCloud files before AVFoundation** - 30s timeout
3. **Use @Transient for large arrays** - direct storage crashes CloudKit sync
4. **Check targetEnvironment for MacCatalyst** - font/window code breaks iOS
5. **Never call scanForOrphanedFiles() on view appear** - causes import timeouts

## Color Scheme
```swift
Color(red: 0.435, green: 0.173, blue: 0.871)  // Primary purple accent
```

## Key Documentation Files
- `ICLOUD_SYNC_GUIDE.md` - Two-layer sync architecture explained
- `SUBSCRIPTION_TESTING_GUIDE.md` - Mock vs real subscription testing
- `TESTING_GUIDE.md` - Full app testing procedures
- `.docs/` folder - Complete phase-by-phase implementation guides
