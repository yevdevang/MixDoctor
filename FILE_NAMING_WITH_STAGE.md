# File Naming with Genre and Stage

## Overview
This document describes the implementation of unique file naming for audio files with different genres and stages, allowing users to import the same audio file multiple times with different metadata, resulting in separate physical files with descriptive names.

## Problem
Previously, when importing the same audio file with different genres or stages, the system would:
- Reuse the same physical file
- Create separate database entries with different metadata
- Make it impossible to distinguish files in iCloud

## Solution
Files are now named with their stage appended to the filename, creating separate physical files:

### Filename Format
```
[Original Name] - [Stage].[ext]
```

### Examples
```
Twisted Transistor.wav → Twisted Transistor - Mix.wav
Twisted Transistor.wav → Twisted Transistor - Master(Streaming).wav
Twisted Transistor.wav → Twisted Transistor - Master(CD-Loud).wav
```

## Implementation

### 1. Stage Display Names
Internal stage values are converted to user-friendly display names:

| Internal Value | Display Name | Filename Suffix |
|---------------|--------------|-----------------|
| `mix` | Mix (Pre-Master) | `Mix` |
| `master_streaming` | Master (Streaming) | `Master(Streaming)` |
| `master_cd` | Master (CD/Loud) | `Master(CD-Loud)` |

### 2. File Copy Logic (`AudioImportService.swift`)

#### Updated `copyToDocuments` Function
```swift
private func copyToDocuments(from sourceURL: URL, genre: String? = nil, mixStage: String? = nil) throws -> URL {
    let baseName = sourceURL.deletingPathExtension().lastPathComponent
    let fileExtension = sourceURL.pathExtension
    
    // Convert internal stage names to display names
    let stageDisplayName: String?
    if let mixStage = mixStage, !mixStage.isEmpty {
        switch mixStage.lowercased() {
        case "mix":
            stageDisplayName = "Mix"
        case "master_streaming", "master(streaming)":
            stageDisplayName = "Master(Streaming)"
        case "master_cd", "master(cd/loud)":
            stageDisplayName = "Master(CD-Loud)"
        default:
            stageDisplayName = mixStage
        }
    } else {
        stageDisplayName = nil
    }
    
    let finalFileName: String
    if let displayName = stageDisplayName {
        finalFileName = "\(baseName) - \(displayName).\(fileExtension)"
    } else {
        finalFileName = originalFileName
    }
    
    let destinationURL = directoryURL.appendingPathComponent(finalFileName)
    // ... copy file to destination
}
```

### 3. Duplicate Detection Logic

#### Base Name Extraction
Files are compared by their base name (without stage suffix) along with genre and stage metadata:

```swift
// Extract base name (without stage suffix) for proper comparison
let extractBaseName: (String) -> String = { fullName in
    let nameWithoutExt = (fullName as NSString).deletingPathExtension
    // Remove stage suffix if present (format: "Name - Stage")
    if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
        return String(nameWithoutExt[..<dashIndex.lowerBound])
    }
    return nameWithoutExt
}

// Compare base names along with metadata
let existingFile = allFiles.first { existingFile in
    let existingBaseName = extractBaseName(existingFile.fileName)
    let sameBaseName = existingBaseName == baseNameToImport
    let sameFileSize = existingFile.fileSize == fileSize
    let similarDuration = abs(existingFile.duration - duration) < 1.0
    let sameGenre = (existingFile.genre ?? "") == (genre ?? "")
    let sameStage = (existingFile.mixStage ?? "") == (mixStage ?? "")
    
    return sameBaseName && sameFileSize && similarDuration && sameGenre && sameStage
}
```

#### Duplicate Detection Rules
- ✅ **Allowed**: Same audio file, different stage (creates new physical file)
- ✅ **Allowed**: Same audio file, different genre (creates new physical file)
- ❌ **Blocked**: Same audio file, same genre, same stage (true duplicate)

### 4. Default Values

#### ImportViewModel
```swift
var selectedMixStage: String? = "mix"  // Default to "mix"
```

#### AudioImportService
```swift
func importAudioFile(from url: URL, modelContext: ModelContext? = nil, genre: String? = nil, mixStage: String? = "Mix") async throws -> AudioFile
```

## User Experience

### Import Flow
1. User selects audio file: `Twisted Transistor.wav`
2. User selects stage: `Master (Streaming)`
3. File is imported as: `Twisted Transistor - Master(Streaming).wav`
4. User can import the same file again with different stage: `Mix`
5. Second import creates: `Twisted Transistor - Mix.wav`

### iCloud Storage
Each variant is stored as a separate file in iCloud:
```
📁 AudioFiles/
   ├── Twisted Transistor - Mix.wav
   ├── Twisted Transistor - Master(Streaming).wav
   └── Twisted Transistor - Master(CD-Loud).wav
```

## Benefits

### 1. Clear File Organization
- Files in iCloud have descriptive names
- Easy to identify which version is which
- No confusion between different stages of the same song

### 2. True Physical Separation
- Each stage gets its own file
- Independent storage and backup
- Can be shared/synced individually

### 3. Flexible Analysis
- Same base track can be analyzed at different mastering stages
- Compare Mix vs Master(Streaming) vs Master(CD/Loud)
- Track improvements across different versions

### 4. iCloud Compatibility
- Each file syncs independently
- Users can see all versions in Files app
- Downloads are per-file, not per-database-entry

## Testing Checklist

- [ ] Import same file with "Mix" stage → Creates `Song - Mix.wav`
- [ ] Import same file with "Master (Streaming)" → Creates `Song - Master(Streaming).wav`
- [ ] Import same file with "Master (CD/Loud)" → Creates `Song - Master(CD-Loud).wav`
- [ ] Try to import same file with same stage twice → Blocks as duplicate
- [ ] Verify all 3 files appear in iCloud
- [ ] Verify Dashboard shows 3 separate entries
- [ ] Verify each entry can be analyzed independently
- [ ] Verify each entry shows correct stage in UI

## Notes

- Stage is now **required** for proper file naming (defaults to "Mix")
- Genre is optional and doesn't affect filename (only metadata)
- Filename format is consistent: `[Name] - [Stage].[ext]`
- Base name extraction handles edge cases (songs with " - " in name)
- Duplicate detection is smart: compares base name + metadata
