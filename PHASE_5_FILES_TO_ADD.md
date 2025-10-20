# Phase 5: Adding New Files to Xcode Project

## New Files to Add

The following files were created for Phase 5 and need to be added to the Xcode project target:

### 1. Core/Models
- ✅ `MixDoctor/Core/Models/UserPreferences.swift`

### 2. Core/Services  
- ✅ `MixDoctor/Core/Services/DataPersistenceService.swift`
- ✅ `MixDoctor/Core/Services/FileManagementService.swift`
- ✅ `MixDoctor/Core/Services/ExportService.swift`

## Modified Files

These files were extended and may need to be re-checked:

### Core/Models
- ✅ `MixDoctor/Core/Models/AudioFile.swift` - Added tags, notes, analysisHistory
- ✅ `Core/Models/AnalysisResult.swift` - Added analysisVersion and metrics

### Core/Utilities
- ✅ `MixDoctor/Core/Utilities/Constants.swift` - Added versioning constants

### Features/Settings
- ✅ `MixDoctor/Features/Settings/Views/SettingsView.swift` - Complete redesign
- ✅ `MixDoctor/Features/Settings/ViewModels/SettingsViewModel.swift` - Enhanced

## Step-by-Step Instructions

### Option 1: Using Xcode GUI

1. **Open Xcode**
   - Open `MixDoctor.xcodeproj`

2. **Add New Files**
   - In Project Navigator (left sidebar), locate the MixDoctor group
   - Right-click on `Core` → `Models` folder
   - Select "Add Files to MixDoctor..."
   - Navigate to and select:
     - `MixDoctor/Core/Models/UserPreferences.swift`
   - ✅ Ensure "Copy items if needed" is **UNCHECKED** (files already in place)
   - ✅ Ensure "Add to targets: MixDoctor" is **CHECKED**
   - Click "Add"

3. **Add Services**
   - Right-click on `Core` → `Services` folder
   - Select "Add Files to MixDoctor..."
   - Navigate to `MixDoctor/Core/Services/`
   - Select all three files:
     - `DataPersistenceService.swift`
     - `FileManagementService.swift`
     - `ExportService.swift`
   - ✅ Ensure "Copy items if needed" is **UNCHECKED**
   - ✅ Ensure "Add to targets: MixDoctor" is **CHECKED**
   - Click "Add"

4. **Verify Modified Files**
   - Check that these files are already in the target (they should be):
     - `MixDoctor/Core/Models/AudioFile.swift`
     - `Core/Models/AnalysisResult.swift`
     - `MixDoctor/Core/Utilities/Constants.swift`
     - `MixDoctor/Features/Settings/Views/SettingsView.swift`
     - `MixDoctor/Features/Settings/ViewModels/SettingsViewModel.swift`

### Option 2: Using Terminal (Advanced)

If you prefer command-line, you can add files programmatically:

```bash
cd /Users/yevgenylevin/Documents/Develop/iOS/MixDoctor

# Open Xcode project
open MixDoctor.xcodeproj
```

Then use Xcode GUI as described above, or use xcodeproj gem if installed.

## Verification Steps

### 1. Check Build Settings
- Select the project in Project Navigator
- Select "MixDoctor" target
- Go to "Build Phases" → "Compile Sources"
- Verify all new `.swift` files are listed:
  - `UserPreferences.swift`
  - `DataPersistenceService.swift`
  - `FileManagementService.swift`
  - `ExportService.swift`

### 2. Build the Project
```
Product → Build (⌘B)
```

Expected result: **Build Succeeded**

### 3. Check for Import Errors

The following types should now be available:
- ✅ `UserPreferences`
- ✅ `ThemeOption`
- ✅ `AnalysisSensitivity`
- ✅ `ExportFormat`
- ✅ `DataPersistenceService`
- ✅ `FileManagementService`
- ✅ `ExportService`
- ✅ `StorageInfo`
- ✅ `BackupInfo`
- ✅ `Statistics`
- ✅ `PersistenceError`
- ✅ `ExportError`

## Known Issues to Resolve

After adding Phase 5 files, you may still see errors in:

### Old Phase 4 Files (Need to be added)
These files from previous phases still need to be added:
- `MixDoctor/Features/Dashboard/Views/DashboardView.swift`
- `MixDoctor/Features/Analysis/Views/ResultsView.swift`
- `MixDoctor/Features/Analysis/Views/SharedComponents.swift`
- `MixDoctor/Features/Player/Views/PlayerView.swift`
- `MixDoctor/Features/Player/ViewModels/PlayerViewModel.swift`
- `MixDoctor/Core/Extensions/Color+Theme.swift`

## Quick Fix Checklist

After adding all files:

- [ ] Build project (⌘B)
- [ ] Fix any remaining import errors
- [ ] Run on simulator (⌘R)
- [ ] Test Settings view:
  - [ ] Change theme
  - [ ] Change analysis sensitivity
  - [ ] Toggle auto-analyze
  - [ ] Check storage info display
  - [ ] Try creating a backup
  - [ ] Test clear cache
  - [ ] Test delete old files
- [ ] Verify preferences persistence (restart app)

## Common Build Errors

### "Cannot find type 'UserPreferences' in scope"
**Solution**: Make sure `UserPreferences.swift` is added to MixDoctor target

### "Cannot find 'DataPersistenceService' in scope"
**Solution**: Make sure `DataPersistenceService.swift` is added to MixDoctor target

### "Cannot find 'FileManagementService' in scope"
**Solution**: Make sure `FileManagementService.swift` is added to MixDoctor target

### "Cannot find 'ExportService' in scope"
**Solution**: Make sure `ExportService.swift` is added to MixDoctor target

### "Cannot find 'ThemeOption' in scope"
**Solution**: Make sure `UserPreferences.swift` is compiled before files that use it

## Success Criteria

✅ All Phase 5 files added to Xcode project
✅ Build succeeds with no errors
✅ Settings view displays correctly
✅ Storage info loads and displays
✅ Preferences can be changed and persist
✅ Backup button works
✅ Clear cache works
✅ App runs on simulator without crashes

## Next Steps After Adding Files

1. Build and run on simulator
2. Import some test audio files
3. Test storage management features
4. Create a backup
5. Test export functionality (when available)
6. Verify preferences persistence

## Support

If you encounter issues:
1. Clean build folder: `Product → Clean Build Folder` (⌘⇧K)
2. Restart Xcode
3. Check that all files have correct target membership
4. Verify file paths in Project Navigator match disk locations
