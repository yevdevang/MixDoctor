# Filename Metadata Extraction

## Overview

MixDoctor now automatically extracts genre and stage information from filenames for legacy files that were imported before these fields were required.

## Supported Filename Patterns

### Pattern 1: Full Metadata (Song - Genre - Stage)
```
Twisted Transistor - Metal - Master(Streaming).wav
Beautiful Day - Pop - Mix.wav
Thunderstruck - Rock/Indie - Master(CD-Loud).wav
```

**Extraction:**
- Genre: Second-to-last component (must match available genres)
- Stage: Last component

### Pattern 2: Stage Only (Song - Stage)
```
My Song - Mix.wav
Track Name - Master(Streaming).wav
Another Track - Master(CD-Loud).wav
```

**Extraction:**
- Genre: Not extracted (remains `nil` → shows "Not set")
- Stage: Last component

### Pattern 3: No Metadata (Song.wav)
```
My Song.wav
Track Name.mp3
```

**Extraction:**
- Genre: Not extracted (remains `nil` → shows "Not set")
- Stage: Not extracted (defaults to `mix` in some contexts)

## Recognized Genres

Genre must exactly match one of these values (case-insensitive):
- Pop
- Rock/Indie
- Hip-Hop/R&B
- EDM/Electronic
- Jazz
- Classical/Orchestral
- Metal
- Acapella
- Live

## Recognized Stages

Stage patterns (case-insensitive):

| Filename Suffix | Internal Value | Display Name |
|----------------|----------------|--------------|
| `Mix` | `mix` | Mix (Pre-Master) |
| `Master(Streaming)` | `master_streaming` | Master (Streaming) |
| `Master(CD-Loud)` | `master_cd` | Master (CD/Loud) |
| `Master(CD)` | `master_cd` | Master (CD/Loud) |

**Partial matches:**
- Contains "streaming" → `master_streaming`
- Contains "cd" or "loud" → `master_cd`
- Contains "master" (without other keywords) → `master_streaming` (default)
- Default fallback → `mix`

## When Extraction Happens

1. **On App Launch**: When ImportView appears (`.task` modifier)
2. **Conditions**:
   - Only updates files where `genre == nil` OR `mixStage == nil`
   - Does not overwrite existing metadata
   - Only processes files already in database

## Implementation Details

### Functions

**`updateMetadataFromFilename(_ file: AudioFile) -> Bool`**
- Parses filename to extract genre and stage
- Updates file object if metadata is missing
- Returns `true` if file was updated

**`updateAllFilesMetadataFromFilenames() async`**
- Iterates through all imported files
- Calls `updateMetadataFromFilename()` for each file missing metadata
- Saves changes to database if any files were updated
- Refreshes the import list

**`extractMixStageFromString(_ string: String) -> String`**
- Helper function to parse stage from filename component
- Handles various formats and typos
- Returns internal stage value (`mix`, `master_streaming`, `master_cd`)

## Examples

### Example 1: Full Extraction
```
Filename: "Korn - Twisted Transistor - Metal - Master(Streaming).wav"

Before:
- genre: nil
- mixStage: nil

After:
- genre: "Metal"
- mixStage: "master_streaming"
```

### Example 2: Stage Only
```
Filename: "My Track - Mix.wav"

Before:
- genre: nil
- mixStage: nil

After:
- genre: nil (still "Not set")
- mixStage: "mix"
```

### Example 3: Invalid Genre (Not Extracted)
```
Filename: "Song - Heavy Rock - Mix.wav"

Before:
- genre: nil
- mixStage: nil

After:
- genre: nil (still "Not set" - "Heavy Rock" not in available genres)
- mixStage: "mix"
```

### Example 4: Already Has Metadata (No Change)
```
Filename: "Track - Pop - Mix.wav"

Before:
- genre: "Rock/Indie" (user-selected)
- mixStage: "master_streaming" (user-selected)

After:
- genre: "Rock/Indie" (unchanged)
- mixStage: "master_streaming" (unchanged)

Note: Existing metadata is never overwritten
```

## Logging

When files are updated, console logs show:

```
📝 Updated genre from filename: Metal for Twisted Transistor - Metal - Master(Streaming).wav
📝 Updated stage from filename: master_streaming for Twisted Transistor - Metal - Master(Streaming).wav
✅ Updated metadata for 2 file(s) from filenames
```

## User Experience

1. **Transparent**: Happens automatically in background
2. **Safe**: Never overwrites user-selected metadata
3. **Silent**: No UI notifications (uses console logging for debugging)
4. **Fast**: Only processes files missing metadata
5. **Consistent**: Runs every time ImportView appears to catch new files

## Testing

To test manually:

1. Import a file without selecting genre/stage (if possible from old app version)
2. Name the file following a pattern: `Song - Genre - Stage.wav`
3. Navigate to Import tab
4. Check console logs for update messages
5. Verify metadata appears in Results view
