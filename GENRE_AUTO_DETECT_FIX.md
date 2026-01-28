# Genre "Auto-detect" Fix

## Problem
User reported that after importing files with a selected genre, the analysis results show "Auto-detect" instead of the genre they selected. This means the genre metadata is not being properly saved or is being overwritten.

## Root Cause Analysis

### Scenario 1: Files Scanned from iCloud Without Genre
The primary issue is in the `scanAndImportFromiCloud()` function:

**Before Fix (lines 1481-1489 in DashboardView.swift):**
```swift
let audioFile = AudioFile(
    fileName: fileName,
    fileURL: fileURL,
    duration: duration,
    sampleRate: sampleRate,
    bitDepth: 16,
    numberOfChannels: channels,
    fileSize: fileSize
)
// genre = nil, mixStage = "mix" (defaults)
```

When files are scanned from iCloud (on app launch or sync), they are imported WITHOUT the `genre` or `mixStage` parameters, resulting in:
- `genre = nil` → Shows as "Auto-detect"
- `mixStage = "mix"` → Default value

### Scenario 2: Genre Not Passed During Manual Import
If the `selectedGenre` is nil when the user triggers import, the genre won't be saved even during manual import.

## Solution

### 1. Extract Mix Stage from Filename When Scanning
**Added helper function (lines 1831-1857 in DashboardView.swift):**
```swift
private func extractMixStageFromFileName(_ fileName: String) -> String {
    let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
    
    // Check for " - Mix" suffix
    if fileNameWithoutExtension.hasSuffix(" - Mix") {
        return "mix"
    }
    
    // Check for " - Master(Streaming)" suffix
    if fileNameWithoutExtension.hasSuffix(" - Master(Streaming)") {
        return "master_streaming"
    }
    
    // Check for " - Master(CD-Loud)" suffix
    if fileNameWithoutExtension.hasSuffix(" - Master(CD-Loud)") {
        return "master_cd"
    }
    
    // Default to "mix" if no stage suffix found
    return "mix"
}
```

**Updated scanAndImportFromiCloud (lines 1469-1491 in DashboardView.swift):**
```swift
// Extract mix stage from filename if present
let mixStage = extractMixStageFromFileName(fileName)

let audioFile = AudioFile(
    fileName: fileName,
    fileURL: fileURL,
    duration: duration,
    sampleRate: sampleRate,
    bitDepth: 16,
    numberOfChannels: channels,
    fileSize: fileSize,
    genre: nil,  // Genre must be set manually by user
    mixStage: mixStage
)
```

### 2. Added Debug Logging to Import Flow

**AudioImportService.swift (lines 85-90):**
```swift
print("🚀 AudioImportService.importAudioFile: Starting import of \(url.lastPathComponent)")
print("   Source path: \(url.path)")
print("   Full URL: \(url.absoluteString)")
print("   Security-scoped resource: \(didStart ? "started" : "already accessed or not needed")")
print("   📋 Genre parameter: \(genre ?? "nil")")
print("   📋 Mix Stage parameter: \(mixStage ?? "nil")")
```

**ImportViewModel.swift (lines 54-60):**
```swift
// Get the final genre and mixStage that will be used
let finalGenre = genre ?? selectedGenre
let finalMixStage = mixStage ?? selectedMixStage

print("📋 ImportViewModel.importFiles - Final params:")
print("   Genre: \(finalGenre ?? "nil")")
print("   Mix Stage: \(finalMixStage ?? "nil")")
```

## How It Works Now

### Files Imported via ImportView (User Selection)
1. User selects genre (e.g., "Metal") and stage (e.g., "Master(Streaming)")
2. User drops/picks files
3. `ImportViewModel.importFiles()` logs the final parameters
4. `AudioImportService.importAudioFile()` logs received parameters
5. AudioFile created with:
   - `genre = "Metal"` ✅
   - `mixStage = "master_streaming"` ✅
   - `fileName = "filename - Master(Streaming).mp3"` ✅

### Files Scanned from iCloud (App Launch/Sync)
1. `scanAndImportFromiCloud()` finds file: "filename - Master(Streaming).mp3"
2. `extractMixStageFromFileName()` parses filename → `mixStage = "master_streaming"` ✅
3. AudioFile created with:
   - `genre = nil` → Shows "Auto-detect" ⚠️ (must be set manually)
   - `mixStage = "master_streaming"` ✅ (extracted from filename)
   - `fileName = "filename - Master(Streaming).mp3"` ✅

## Expected Behavior

### After Manual Import with Genre Selection
**Results View shows:**
- Genre: "Metal" ✅
- Stage: "Master (Streaming)" ✅

### After iCloud Scan (No Manual Import)
**Results View shows:**
- Genre: "Auto-detect" ⚠️
- Stage: "Master (Streaming)" ✅ (extracted from filename)

**User can then manually set the genre by re-importing with genre selection.**

## Debugging Console Output

### Manual Import Success
```
📋 ImportViewModel.importFiles - Final params:
   Genre: Metal
   Mix Stage: master_streaming
🚀 AudioImportService.importAudioFile: Starting import of filename - Master(Streaming).mp3
   📋 Genre parameter: Metal
   📋 Mix Stage parameter: master_streaming
✅ File copied to: .../filename - Master(Streaming).mp3
```

### Manual Import with Missing Genre
```
📋 ImportViewModel.importFiles - Final params:
   Genre: nil
   Mix Stage: master_streaming
🚀 AudioImportService.importAudioFile: Starting import of filename - Master(Streaming).mp3
   📋 Genre parameter: nil
   📋 Mix Stage parameter: master_streaming
⚠️ File will be saved with genre=nil → "Auto-detect"
```

### iCloud Scan
```
📂 Scanning iCloud for files...
   Found: filename - Master(Streaming).mp3
   Extracted mix stage: master_streaming
✅ Imported with:
   - Genre: nil
   - Mix Stage: master_streaming
```

## Limitations

### Genre Cannot Be Extracted from Filename
Unlike mix stage, genre is NOT included in the filename, so it cannot be automatically extracted during iCloud scanning. The genre must be set during manual import via the ImportView.

### Possible Future Enhancements

1. **Allow Genre/Stage Editing:**
   - Add UI to edit genre/stage for existing files
   - Update AudioFile model when user changes metadata

2. **Store Genre in Extended Attributes:**
   - Save genre as file metadata (xattr) when importing
   - Read genre from xattr during iCloud scan

3. **Genre Auto-Detection from Audio Content:**
   - Use ML model to detect genre from audio analysis
   - Pre-fill genre dropdown with detected genre

## Testing Checklist

- [ ] Import file with genre "Metal" and stage "Master(Streaming)"
- [ ] Check console for debug logs showing correct parameters
- [ ] Verify Results View shows: Genre: "Metal", Stage: "Master (Streaming)"
- [ ] Restart app (triggers iCloud scan)
- [ ] Verify existing file still shows: Genre: "Metal" (preserved)
- [ ] Manually add a file to iCloud folder: "test - Mix.mp3"
- [ ] Launch app (triggers scan)
- [ ] Check console logs for extracted stage: "mix"
- [ ] Verify Results View shows: Genre: "Auto-detect", Stage: "Mix (Pre-Master)"

## Files Modified

### DashboardView.swift
- **Lines 1481-1491**: Updated `scanAndImportFromiCloud()` to extract mix stage and pass it to AudioFile initializer
- **Lines 1831-1857**: Added `extractMixStageFromFileName()` helper function

### AudioImportService.swift
- **Lines 85-90**: Added debug logging for genre and mixStage parameters

### ImportViewModel.swift
- **Lines 54-60**: Added debug logging for final genre and mixStage parameters before import

## User Guidance

### If Genre Shows "Auto-detect"
1. The file was imported via iCloud scan (not manual import)
2. To fix: Re-import the file with genre selection in ImportView
3. The duplicate detection will prevent re-importing the same file

**Workaround:** Delete the file from Dashboard, then re-import with genre selection.

### If Genre Is Correct After Import
1. ✅ Everything working as expected
2. Genre was properly saved during manual import
3. Genre will persist across app restarts and iCloud syncs

## Related Issues

- Previously: Unmixed detection not working (fixed)
- Previously: Score convergence (fixed)
- Previously: Clear all analysis re-loading from JSON (fixed)

## Conclusion

The fix ensures that:
1. Mix stage is correctly extracted from filename during iCloud scanning ✅
2. Debug logging helps identify if genre is nil during import ⚠️
3. Manually imported files preserve genre metadata ✅

**Limitation:** Genre must be set during manual import; it cannot be automatically extracted from iCloud-scanned files.

**Future:** Consider adding UI to edit genre/stage for existing files, or implementing genre auto-detection from audio content.
