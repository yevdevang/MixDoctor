# Genre and Stage Metadata Persistence

## Overview

Genre and Mix Stage are critical metadata fields that should persist across app launches. This document explains how they are saved and loaded.

## How Data Flows

### 1. Import Process

```
User selects genre/stage → ImportView → ImportViewModel → AudioImportService → AudioFile model → SwiftData
```

**Key Files:**
- `ImportView.swift`: User selection UI
- `ImportViewModel.swift`: Coordinates import, passes genre/stage
- `AudioImportService.swift`: Creates AudioFile with metadata
- `AudioFile.swift`: SwiftData model with `genre` and `mixStage` properties

### 2. Data Persistence

**AudioFile Model** (`AudioFile.swift` lines 25-26):
```swift
var genre: String?      // "Pop", "Rock/Indie", etc.
var mixStage: String?   // "mix", "master_streaming", "master_cd"
```

**AudioFile Initialization** (`AudioFile.swift` lines 47-72):
```swift
init(
    fileName: String,
    fileURL: URL,
    duration: TimeInterval,
    sampleRate: Double,
    bitDepth: Int,
    numberOfChannels: Int,
    fileSize: Int64,
    genre: String? = nil,        // ✅ Stored
    mixStage: String? = "mix"    // ✅ Stored
) {
    // ...
    self.genre = genre              // ✅ Persisted to SwiftData
    self.mixStage = mixStage        // ✅ Persisted to SwiftData
}
```

**AudioImportService** (`AudioImportService.swift` lines 252-262):
```swift
let audioFile = AudioFile(
    fileName: destinationURL.lastPathComponent,
    fileURL: destinationURL,
    duration: metadata.duration,
    sampleRate: metadata.sampleRate,
    bitDepth: metadata.bitDepth,
    numberOfChannels: metadata.numberOfChannels,
    fileSize: metadata.fileSize,
    genre: genre,        // ✅ Passed from user selection
    mixStage: mixStage   // ✅ Passed from user selection
)
```

**ImportViewModel** (`ImportViewModel.swift` lines 53-67):
```swift
// Get the final genre and mixStage that will be used
let finalGenre = genre ?? selectedGenre
let finalMixStage = mixStage ?? selectedMixStage

print("📋 ImportViewModel.importFiles - Final params:")
print("   Genre: \(finalGenre ?? "nil")")
print("   Mix Stage: \(finalMixStage ?? "nil")")

// Pass modelContext, genre, and mixStage to importService
let files = try await importService.importMultipleFiles(
    urls,
    modelContext: modelContext,
    genre: finalGenre,        // ✅ From user selection
    mixStage: finalMixStage   // ✅ From user selection
)
```

### 3. Data Loading

**ImportView** loads files via `ImportViewModel.loadImports()`:
```swift
func loadImports() {
    let descriptor = FetchDescriptor<AudioFile>(
        sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
    )
    if let storedFiles = try? modelContext.fetch(descriptor) {
        importedFiles = storedFiles  // ✅ Genre and stage are already in the objects
    }
}
```

**DashboardView** loads files similarly:
```swift
@Query(sort: \AudioFile.dateImported, order: .reverse) 
private var audioFiles: [AudioFile]  // ✅ SwiftData automatically fetches all properties
```

## Display Locations

### 1. ImportView - ImportedFileRow

**Location:** `ImportView.swift` lines 956-974

```swift
// Row 2: Genre and Mix stage
HStack(spacing: 4) {
    if let genre = audioFile.genre {
        Text(genre)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.purple)
        
        if audioFile.mixStage != nil {
            Text("•")
                .foregroundStyle(Color.secondaryText)
        }
    }
    
    if let mixStage = audioFile.mixStage {
        Text(formatMixStage(mixStage))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(mixStageColor(mixStage))
    }
}
```

### 2. DashboardView - AudioFileRow (SharedComponents)

**Location:** `SharedComponents.swift` lines 243-261

```swift
// Row 2: Genre and Mix stage
HStack(spacing: 4) {
    if let genre = audioFile.genre {
        Text(genre)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.purple)
        
        if audioFile.mixStage != nil {
            Text("•")
                .foregroundStyle(.secondary)
        }
    }
    
    if let mixStage = audioFile.mixStage {
        Text(formatMixStage(mixStage))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(mixStageColor(mixStage))
    }
}
```

### 3. ResultsView - Analysis Settings Display

**Location:** `ResultsView.swift` lines 335-366

```swift
// Genre Display (read-only)
HStack {
    Text("Genre:")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 80, alignment: .leading)
    
    Text(audioFile.genre ?? "Not set")
        .foregroundStyle(audioFile.genre == nil ? .secondary : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
}

// Mix Stage Display (read-only)
HStack {
    Text("Stage:")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 80, alignment: .leading)
    
    Text(mixStageDisplayName(audioFile.mixStage))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
}
```

## Debugging Checklist

If genre is not appearing after import, check these logs:

### 1. During Import
```
📋 ImportViewModel.importFiles - Final params:
   Genre: [selected genre]
   Mix Stage: [selected stage]
```

### 2. Before Database Insert
```
📝 Inserting file into database:
   Filename: [filename]
   Genre: [genre]
   MixStage: [mixStage]
```

### 3. After Database Save
```
✅ ModelContext saved successfully
📋 After loadImports(), checking first few files:
   [filename]: genre=[genre], stage=[stage]
```

### 4. During Display
Check that `audioFile.genre` is not nil when rendering the file row.

## Common Issues and Solutions

### Issue 1: Genre Shows as "Not set"

**Cause:** Genre was nil during import

**Solution:**
1. Verify user selected a genre before importing
2. Check ImportView's `selectedGenre` state
3. Verify genre is passed to `importFiles()` method
4. Check console logs for "Genre: nil"

### Issue 2: Genre Doesn't Persist After App Restart

**Cause:** SwiftData not saving properly

**Solution:**
1. Verify `modelContext.save()` is called after insert
2. Check for SwiftData errors in console
3. Verify AudioFile model has `@Model` macro
4. Verify `genre` property is not `@Transient`

### Issue 3: Mix Stage Appears But Genre Doesn't

**Cause:** Genre wasn't required initially, some files have nil genre

**Solution:**
1. Use filename extraction feature (implemented)
2. Re-import files with genre selected
3. Or manually set genre in database (not recommended)

## Filename Format for Metadata Extraction

If files are missing metadata, the app will try to extract it from the filename:

**Supported patterns:**
- `"Song - Genre - Stage.wav"` → Extracts both genre and stage
- `"Song - Stage.wav"` → Extracts only stage
- `"Song.wav"` → No extraction

**Example:**
```
"Twisted Transistor - Metal - Master(Streaming).wav"
↓
genre: "Metal"
mixStage: "master_streaming"
```

This extraction happens automatically in `ImportViewModel.updateAllFilesMetadataFromFilenames()` when ImportView appears.

## Testing

To verify genre persistence:

1. **Import a file:**
   - Select genre "Pop"
   - Select stage "Mix (Pre-Master)"
   - Import file

2. **Check console logs:**
   ```
   📋 ImportViewModel.importFiles - Final params:
      Genre: Pop
      Mix Stage: mix
   
   📝 Inserting file into database:
      Filename: Test.wav
      Genre: Pop
      MixStage: mix
   ```

3. **Verify display:**
   - ImportView should show: `Pop • Mix`
   - Dashboard should show: `Pop • Mix`
   - ResultsView should show: `Genre: Pop`, `Stage: Mix (Pre-Master)`

4. **Restart app:**
   - Navigate to ImportView
   - File should still show: `Pop • Mix`
   - This confirms SwiftData persistence is working

## Architecture Summary

```
┌─────────────────┐
│   ImportView    │
│  (User selects  │
│  genre & stage) │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ ImportViewModel │
│ (Coordinates)   │
└────────┬────────┘
         │
         v
┌──────────────────┐
│AudioImportService│
│ (Creates file)   │
└────────┬─────────┘
         │
         v
┌─────────────────┐
│  AudioFile.swift │
│  (SwiftData @Model)│
│  - genre: String?│
│  - mixStage: String?│
└────────┬────────┘
         │
         v
┌─────────────────┐
│   SwiftData     │
│   (Persists to  │
│    database)    │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Views Display  │
│  - ImportView   │
│  - DashboardView│
│  - ResultsView  │
└─────────────────┘
```

Both `genre` and `mixStage` follow the **exact same path** through the system, so if one works, the other should too.
