# Genre Not Saving - Debug Guide

## Problem
Genre appears in ImportView during import but disappears after app restart. The genre is not being persisted to the database.

## Debug Logging Added

I've added logging at every step of the import process. When you import a file, you should see these logs in order:

### 1. ImportViewModel - Initial Parameters
```
📋 ImportViewModel.importFiles - Final params:
   Genre: [your selected genre]
   Mix Stage: [your selected stage]
```

**What to check:**
- Is Genre showing correctly here?
- If it's "nil", the problem is in ImportView's genre selection

### 2. AudioImportService - Function Entry
```
🚀 AudioImportService.importAudioFile: Starting import of [filename]
   Source path: [path]
   📋 Genre parameter: [genre]
   📋 Mix Stage parameter: [stage]
```

**What to check:**
- Is Genre parameter passed correctly?
- If it's "nil" here but was set in step 1, check ImportViewModel.importFiles()

### 3. copyToDocuments - File Copy
```
  📂 copyToDocuments called
  Source: [source path]
  Genre parameter: [genre]
  MixStage parameter: [stage]
```

**What to check:**
- Is Genre still present here?

### 4. AudioFile Creation
```
✅ AudioFile object created:
   ID: [uuid]
   Filename: [filename]
   Genre: [genre]
   MixStage: [stage]
```

**What to check:**
- Is Genre set on the AudioFile object?
- **THIS IS CRITICAL** - if Genre is "nil" here, the object is created without genre

### 5. Database Insert
```
📝 Inserting file into database:
   Filename: [filename]
   Genre: [genre]
   MixStage: [mixStage]
```

**What to check:**
- Is Genre still present when inserting?

### 6. After Save
```
✅ ModelContext saved successfully
📋 After loadImports(), checking first few files:
   [filename]: genre=[genre], stage=[stage]
```

**What to check:**
- **THIS IS THE MOST IMPORTANT CHECK**
- After saving and reloading, is Genre still there?
- If Genre is "nil" here but was set in step 5, **SwiftData is not persisting the genre**

## Testing Steps

1. **Clean test:**
   - Delete the app completely
   - Reinstall and run
   - This ensures no old data interferes

2. **Import a file:**
   - Select Genre: "EDM/Electronic"
   - Select Stage: "Mix (Pre-Master)"
   - Import "Omer_1.mp3"

3. **Watch the console logs carefully** and note at which step the genre becomes "nil"

4. **Check ImportView:**
   - Does the file show `EDM/Electronic • Mix` ?
   - If YES: genre was temporarily available
   - If NO: genre was never set

5. **Check DashboardView:**
   - Switch to Dashboard tab
   - Does the file show `EDM/Electronic • Mix` ?
   - If YES: genre is working
   - If NO but showed in ImportView: genre is not persisting

6. **Restart the app:**
   - Force quit
   - Relaunch
   - Go to Dashboard
   - Check if genre is still there

## Possible Issues & Solutions

### Issue 1: Genre is nil at Step 1
**Problem:** ImportView isn't passing the selected genre

**Check:**
- ImportView.swift line ~750: Is `selectedGenre` set?
- ImportView.swift importFiles button: Does it pass `selectedGenre`?

### Issue 2: Genre is set in Steps 1-4 but nil at Step 5
**Problem:** Duplicate detection or something in ImportViewModel

**Check:**
- ImportViewModel.isDuplicate() - Does it modify the file?
- Any code between AudioFile creation and insert

### Issue 3: Genre is set in Step 5 but nil at Step 6
**Problem:** SwiftData is not persisting the genre field

**Possible causes:**
- AudioFile model issue (but genre IS defined as var genre: String?)
- ModelContext not saving properly
- SwiftData bug (unlikely)

**Solution:**
Try force-saving immediately after creation:
```swift
for file in files {
    if !isDuplicate(file) {
        modelContext.insert(file)
        // Force immediate save to test
        try? modelContext.save()
        
        // Verify it's in the database
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.id == file.id }
        )
        if let saved = try? modelContext.fetch(descriptor).first {
            print("   Verified in DB: genre=\(saved.genre ?? "nil")")
        }
    }
}
```

### Issue 4: Genre is set in Step 6 but disappears after app restart
**Problem:** SwiftData container not persisting to disk

**Check:**
- Is app using the correct SwiftData container?
- Check App.swift - is modelContainer configured correctly?

## Expected Full Log Output

Here's what you should see for a successful import:

```
📋 ImportViewModel.importFiles - Final params:
   Genre: EDM/Electronic
   Mix Stage: mix

🚀 AudioImportService.importAudioFile: Starting import of Omer_1.mp3
   📋 Genre parameter: EDM/Electronic
   📋 Mix Stage parameter: mix

  📂 copyToDocuments called
  Genre parameter: EDM/Electronic
  MixStage parameter: mix

✅ AudioFile object created:
   Filename: Omer_1 - Mix.mp3
   Genre: EDM/Electronic
   MixStage: mix

📝 Inserting file into database:
   Filename: Omer_1 - Mix.mp3
   Genre: EDM/Electronic
   MixStage: mix

✅ ModelContext saved successfully

📋 After loadImports(), checking first few files:
   Omer_1 - Mix.mp3: genre=EDM/Electronic, stage=mix
```

If ANY of these steps shows "genre=nil" or "Genre: nil", that's where the data is being lost.

## Report Back

After running the import, please:

1. Copy ALL the console logs (from start of import to end)
2. Tell me at which step the genre becomes nil
3. Send a screenshot of ImportView showing the file
4. Send a screenshot of DashboardView showing the same file

This will help me pinpoint exactly where the genre is being lost.
