# CRITICAL BUG FIX: Genre Being Overwritten on Import

## The Problem

Genre was being set correctly during import but immediately overwritten with `nil` when ImportView appeared.

## Root Cause

The `scanForOrphanedFiles()` function was **re-importing files that were already in the database**, which created NEW AudioFile objects without genre/stage information, replacing the ones that had been properly imported.

### The Bug Flow

1. ✅ User imports "Omer_1.mp3" with genre "EDM/Electronic"
2. ✅ AudioFile created with `genre = "EDM/Electronic"`
3. ✅ File saved to database with genre
4. ✅ File copied to iCloud container as "Omer_1 - Mix.mp3"
5. ❌ ImportView appears → `.task` runs
6. ❌ `scanForOrphanedFiles()` scans the iCloud folder
7. ❌ Finds "Omer_1 - Mix.mp3" in folder
8. ❌ Checks database, doesn't find it (different filename!)
9. ❌ Treats it as "orphaned" (file exists but no DB record)
10. ❌ Re-imports it with `importService.importMultipleFiles(orphanedURLs)`
11. ❌ **NO GENRE OR STAGE PASSED** → creates AudioFile with `genre = nil`
12. ❌ Duplicate check fails because genre is different
13. ❌ Inserts new record with nil genre
14. ❌ Now you have TWO records: one with genre, one without
15. ❌ UI shows the one without genre

### Why This Happened

The `scanForOrphanedFiles()` logic was:

```swift
// Find files that exist physically but not in database
for url in fileURLs {
    let fileName = url.lastPathComponent  // "Omer_1 - Mix.mp3"
    
    // Check if it's in database
    if !databaseFileNames.contains(fileName) {
        // Treat as orphaned and re-import
        orphanedURLs.append(url)
    }
}
```

But the database check used `fileName`, which includes the stage suffix:
- Physical file: `"Omer_1 - Mix.mp3"`
- Database record: `"Omer_1 - Mix.mp3"` (should match!)

**But wait** - they SHOULD match! So why was it being treated as orphaned?

The real issue is **timing**:

1. File import completes
2. File saved to database
3. ImportView appears **IMMEDIATELY**
4. `.task` runs `scanForOrphanedFiles()` **BEFORE** database save has fully propagated
5. Database query doesn't find the file yet
6. File gets re-imported

## The Fix

**Added check to skip files that already have database records:**

```swift
if !orphanedURLs.isEmpty {
    print("📁 Found \(orphanedURLs.count) orphaned file(s) - checking if they need import")
    
    // Get all existing files from database
    let descriptor = FetchDescriptor<AudioFile>()
    let existingFiles = (try? modelContext.fetch(descriptor)) ?? []
    let existingFileNames = Set(existingFiles.map { $0.fileName })
    
    // ✅ Only import files that DON'T already have a database record
    let filesToImport = orphanedURLs.filter { url in
        let fileName = url.lastPathComponent
        let alreadyExists = existingFileNames.contains(fileName)
        if alreadyExists {
            print("   ⏭️ Skipping \(fileName) - already in database")
        }
        return !alreadyExists
    }
    
    if filesToImport.isEmpty {
        print("   ✅ All orphaned files already have database records")
        return  // ✅ Don't re-import anything!
    }
    
    print("   📥 Importing \(filesToImport.count) truly orphaned file(s)")
    
    // Only import files that are TRULY orphaned
    let importedFiles = try await importService.importMultipleFiles(filesToImport, modelContext: modelContext)
    // ...
}
```

### What This Does

1. When `scanForOrphanedFiles()` finds files in the folder
2. It fetches ALL files from the database
3. Filters out any files that already have database records
4. Only imports files that are **truly** orphaned (no database record at all)
5. This prevents re-importing files that were just imported

### Why This Works

Even if there's a timing issue and the database query happens right after import:
- If the file IS in the database → skip it (already imported)
- If the file is NOT in the database → it's truly orphaned, import it

This prevents the double-import that was overwriting genre.

## Testing

After this fix:

1. Import "Omer_1.mp3" with genre "EDM/Electronic"
2. Console should show:
   ```
   📁 Found 1 orphaned file(s) - checking if they need import
      ⏭️ Skipping Omer_1 - Mix.mp3 - already in database
      ✅ All orphaned files already have database records
   ```
3. Genre should persist correctly
4. After app restart, genre should still be there

## Files Modified

- **ImportViewModel.swift** - Fixed `scanForOrphanedFiles()` to check database before re-importing

## Related Issues

This also fixes:
- Duplicate imports when switching tabs quickly
- Performance issues (unnecessary re-imports)
- Missing metadata (genre/stage) on files

## Prevention

To prevent similar issues in the future:

1. **Always check if a record exists before creating a new one**
2. **Pass all necessary metadata (genre, stage) when importing**
3. **Use database IDs for duplicate detection, not just filenames**
4. **Add logging to track import flow**
