# SOLUTION: Save Genre in Filename (Same as Stage)

## The Real Problem

**Genre was not being saved in the filename**, only in the database. The stage WAS saved in the filename, which is why stage persisted but genre didn't.

## Original Filename Format

**Before:**
```
"Song Name - Stage.ext"
```

Examples:
- `"Omer_1 - Mix.mp3"`
- `"Track - Master(Streaming).wav"`

**Problem:** Genre information was lost if database record was deleted or corrupted.

## New Filename Format

**After:**
```
"Song Name - Genre - Stage.ext"
```

Examples:
- `"Omer_1 - EDM/Electronic - Mix.mp3"`
- `"Track - Rock/Indie - Master(Streaming).wav"`
- `"Song - Metal - Master(CD-Loud).wav"`

**Benefit:** Both genre AND stage are now preserved in the filename itself!

## Code Changes

### AudioImportService.swift - copyToDocuments()

```swift
let finalFileName: String
if let genreValue = genre, let stageValue = stageDisplayName {
    // ✅ NEW: Format with BOTH genre and stage
    // "Original Name - Genre - Stage.ext"
    finalFileName = "\(baseName) - \(genreValue) - \(stageValue).\(fileExtension)"
} else if let stageValue = stageDisplayName {
    // Format: "Original Name - Stage.ext" (no genre)
    finalFileName = "\(baseName) - \(stageValue).\(fileExtension)"
} else if let genreValue = genre {
    // ✅ NEW: Format with only genre (no stage)
    // "Original Name - Genre.ext"
    finalFileName = "\(baseName) - \(genreValue).\(fileExtension)"
} else {
    // No genre or stage specified, use original filename
    finalFileName = originalFileName
}
```

## Filename Patterns Supported

### 1. Full Pattern (Genre + Stage)
```
"Song Name - Genre - Stage.ext"
```
- `"Omer_1 - EDM/Electronic - Mix.mp3"`
- `"Track - Pop - Master(Streaming).wav"`

### 2. Stage Only (Legacy Support)
```
"Song Name - Stage.ext"
```
- `"Omer_1 - Mix.mp3"`
- `"Track - Master(Streaming).wav"`

### 3. Genre Only (New)
```
"Song Name - Genre.ext"
```
- `"Omer_1 - Metal.mp3"`
- `"Track - Rock/Indie.wav"`

### 4. Original (No Metadata)
```
"Song Name.ext"
```
- `"Omer_1.mp3"`
- `"Track.wav"`

## Metadata Extraction

The existing `updateMetadataFromFilename()` function already supports this pattern:

```swift
// Pattern: "Song Name - Genre - Stage"
if components.count >= 3 {
    let potentialGenre = components[components.count - 2]  // EDM/Electronic
    let potentialStage = components[components.count - 1]  // Mix
    
    // Extract and set genre if missing
    if file.genre == nil, AppConstants.availableGenres.contains(potentialGenre) {
        file.genre = potentialGenre
    }
    
    // Extract and set stage if missing
    if file.mixStage == nil {
        file.mixStage = extractMixStageFromString(potentialStage)
    }
}
```

## Benefits

### 1. Persistence
Genre and stage are now stored in THREE places:
1. ✅ Database (SwiftData)
2. ✅ Filename (filesystem)
3. ✅ User can see it in file browser

### 2. Recovery
If database is corrupted or deleted:
- ✅ Genre can be extracted from filename
- ✅ Stage can be extracted from filename
- ✅ Automatic recovery on next app launch

### 3. Organization
Files are self-documenting:
- ✅ Clear what genre it is
- ✅ Clear what stage it is
- ✅ Easy to find in file system

### 4. Synchronization
When files sync via iCloud:
- ✅ Genre travels with the file
- ✅ Stage travels with the file
- ✅ No metadata loss across devices

## Migration

### Existing Files
Old files with format `"Song - Stage.ext"` will continue to work:
- ✅ Stage will be extracted
- ✅ Genre will be `nil` (no genre in filename)
- ✅ User can re-import with genre to update

### New Imports
All new imports will use the new format:
- ✅ Both genre and stage in filename
- ✅ Full metadata preserved

## Testing

### Test 1: Import with Genre and Stage
1. Select Genre: "EDM/Electronic"
2. Select Stage: "Mix (Pre-Master)"
3. Import "Omer_1.mp3"
4. **Expected filename:** `"Omer_1 - EDM/Electronic - Mix.mp3"`

### Test 2: Verify in File System
1. Open Files app → iCloud Drive → Mix Doctor → AudioFiles
2. **Should see:** `"Omer_1 - EDM/Electronic - Mix.mp3"`

### Test 3: Metadata Extraction
1. Delete the app
2. Manually place `"Song - Metal - Master(Streaming).wav"` in AudioFiles folder
3. Launch app
4. **Expected:** File imported with genre="Metal", stage="master_streaming"

### Test 4: Console Logs
When importing, you should see:

```
  Original filename: Omer_1.mp3
  Genre: EDM/Electronic
  Mix stage: mix
  Final filename: Omer_1 - EDM/Electronic - Mix.mp3
  Destination path: /path/to/AudioFiles/Omer_1 - EDM/Electronic - Mix.mp3
```

## Summary

**The fix:** Genre is now saved in the filename exactly like stage has always been saved. This ensures both genre and stage persist reliably across app restarts, database resets, and iCloud synchronization.

**Filename format:** `"Song Name - Genre - Stage.ext"`

**Example:** `"Omer_1 - EDM/Electronic - Mix.mp3"`

This matches how the stage has always worked, ensuring genre has the same level of persistence and reliability!
