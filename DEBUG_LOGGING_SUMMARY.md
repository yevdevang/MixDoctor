# Debug Logging Added - Genre Persistence Issue

## Summary

I've added extensive debug logging throughout the entire import and save pipeline to track exactly where the genre data is being lost.

## Files Modified

### 1. AudioFile.swift (Model Initializer)
**Location:** Lines 47-78

**Added logging:**
```swift
print("🎵 AudioFile.init called:")
print("   fileName: \(fileName)")
print("   genre parameter: \(genre ?? "nil")")
print("   mixStage parameter: \(mixStage ?? "nil")")
print("   self.genre after assignment: \(self.genre ?? "nil")")
print("   self.mixStage after assignment: \(self.mixStage ?? "nil")")
```

**Purpose:** Verify that genre is actually being set when the AudioFile object is created

### 2. AudioImportService.swift (AudioFile Creation)
**Location:** Lines 252-269

**Added logging:**
```swift
print("✅ AudioFile object created:")
print("   ID: \(audioFile.id)")
print("   Filename: \(audioFile.fileName)")
print("   Genre: \(audioFile.genre ?? "nil")")
print("   MixStage: \(audioFile.mixStage ?? "nil")")
```

**Purpose:** Verify the AudioFile object has genre after creation

### 3. AudioImportService.swift (copyToDocuments)
**Location:** Lines 455-459

**Added logging:**
```swift
print("  Genre parameter: \(genre ?? "nil")")
print("  MixStage parameter: \(mixStage ?? "nil")")
```

**Purpose:** Verify genre is being passed to file copy operation

### 4. ImportViewModel.swift (Database Insert)
**Location:** Lines 74-97

**Added logging:**
```swift
print("📝 Inserting file into database:")
print("   Filename: \(file.fileName)")
print("   Genre: \(file.genre ?? "nil")")
print("   MixStage: \(file.mixStage ?? "nil")")

// ... after save ...

print("✅ ModelContext saved successfully")
print("📋 After loadImports(), checking first few files:")
for file in importedFiles.prefix(10) {
    print("   \(file.fileName): genre=\(file.genre ?? "nil"), stage=\(file.mixStage ?? "nil")")
}
```

**Purpose:** 
- Verify genre is present before database insert
- Verify genre persists after save and reload

## Complete Log Flow

When you import a file with genre "EDM/Electronic" and stage "Mix", you should see:

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
  
🎵 AudioFile.init called:
   fileName: Omer_1 - Mix.mp3
   genre parameter: EDM/Electronic
   mixStage parameter: mix
   self.genre after assignment: EDM/Electronic
   self.mixStage after assignment: mix

✅ AudioFile object created:
   ID: [uuid]
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

## What to Look For

### If genre shows as "nil" at:

1. **ImportViewModel.importFiles**
   - **Problem:** User selection not captured
   - **Check:** ImportView's `selectedGenre` binding

2. **AudioImportService.importAudioFile entry**
   - **Problem:** Parameter not passed from ImportViewModel
   - **Check:** ImportViewModel.importFiles() method call to importService

3. **copyToDocuments**
   - **Problem:** Parameter not passed through importAudioFile
   - **Check:** copyToDocuments call site

4. **AudioFile.init (genre parameter)**
   - **Problem:** Not passed to AudioFile constructor
   - **Check:** AudioFile creation in importAudioFile

5. **AudioFile.init (self.genre after assignment)**
   - **Problem:** Assignment failed (very unlikely)
   - **This would be a Swift language bug**

6. **AudioFile object created**
   - **Problem:** Genre lost after init
   - **Check:** Something modifying audioFile before return

7. **Database Insert**
   - **Problem:** Genre lost between creation and insert
   - **Check:** ImportViewModel's file handling between import and insert

8. **After loadImports()**
   - **Problem:** SwiftData not persisting genre
   - **This is the most critical issue** - means database is not saving genre
   - **Check:** SwiftData model configuration, container setup

## Testing Instructions

1. **Clean install:**
   ```
   - Delete app from device/simulator
   - Clean build folder (Cmd+Shift+K)
   - Rebuild and install
   ```

2. **Import test file:**
   - Select Genre: "EDM/Electronic"
   - Select Stage: "Mix (Pre-Master)"
   - Import "Omer_1.mp3"

3. **Copy all console logs** from the moment you tap Import until you see "After loadImports()"

4. **Check displays:**
   - ImportView: Should show "EDM/Electronic • Mix"
   - DashboardView: Should show "EDM/Electronic • Mix"

5. **Restart app:**
   - Force quit
   - Relaunch
   - Check both views again

6. **Report findings:**
   - Where does genre first appear as "nil"?
   - Does it show in UI before restart?
   - Does it show in UI after restart?

## Next Steps Based on Results

### Scenario A: Genre is nil from the start
→ Fix ImportView's genre selection

### Scenario B: Genre is set but lost before database insert
→ Fix ImportViewModel's import handling

### Scenario C: Genre is inserted but lost after reload
→ Fix SwiftData persistence (most likely culprit based on symptoms)

### Scenario D: Genre persists after reload but lost after app restart
→ Fix SwiftData container configuration

## Additional Check: SwiftData Container

If genre is lost after app restart, verify SwiftData setup in App.swift:

```swift
@main
struct MixDoctorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [AudioFile.self, AnalysisResult.self]) // ✅ Must include AudioFile
    }
}
```

Make sure:
1. AudioFile is in the modelContainer
2. Container is created only once
3. No separate containers for different views

## Documentation

Created comprehensive guides:
1. **GENRE_STAGE_PERSISTENCE.md** - How the system works
2. **GENRE_DEBUG_GUIDE.md** - Debugging steps
3. **This file** - Summary of logging added

Please run the test and provide the console logs so I can identify the exact point where genre is lost.
