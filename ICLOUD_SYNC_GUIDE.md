# iCloud Sync Implementation Guide

## Problem
You imported an audio file on the iPad Simulator, but it didn't appear on the iPhone Simulator.

## Root Cause
The app has **two-layer iCloud sync**:
1. **SwiftData + CloudKit** → Syncs AudioFile metadata ✅
2. **iCloud Documents** → Syncs actual audio files ❌ (was not monitored)

When you imported a file on iPad:
- ✅ AudioFile metadata synced to iPhone via CloudKit
- ❌ The actual audio file was uploaded to iCloud Drive but NOT downloaded on iPhone
- Result: iPhone sees the metadata but can't play the file (file missing locally)

## Solution Implemented

### 1. Created `iCloudSyncMonitor.swift`
A new service that actively monitors iCloud Drive for file changes using `NSMetadataQuery`.

**Key Features:**
- Automatically detects new files uploaded to iCloud
- Downloads files that are not yet available locally
- Provides sync status (isSyncing, syncProgress)
- Can be triggered manually via pull-to-refresh

**How it works:**
```swift
// Monitors: ~/Library/Mobile Documents/iCloud~com~yevgenylevin~animated~MixDoctor/Documents/AudioFiles/
let query = NSMetadataQuery()
query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

// Automatically downloads files when detected
FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
```

### 2. Updated `MixDoctorApp.swift`
- Added `iCloudSyncMonitor` as a @State property
- Starts monitoring automatically on app launch
- Runs in background, watching for iCloud changes

```swift
.task {
    // Start iCloud file monitoring
    iCloudMonitor.startMonitoring()
}
```

### 3. Enhanced `DashboardView.swift`
- Added sync status banner (shows when syncing)
- Added pull-to-refresh gesture to manually trigger sync
- Visual feedback for users

```swift
// Pull down to force iCloud sync
.refreshable {
    await iCloudMonitor.syncNow()
}

// Status banner
if iCloudMonitor.isSyncing {
    HStack {
        ProgressView()
        Text("Syncing files from iCloud...")
    }
}
```

## Testing the Fix

### Test 1: Cross-Device Sync
1. **iPad Simulator:**
   - Open MixDoctor app
   - Import an audio file
   - Wait 2-3 seconds for upload

2. **iPhone Simulator:**
   - Open MixDoctor app
   - **Pull down on Dashboard** to refresh
   - File should appear and be playable ✅

### Test 2: Automatic Detection
1. **iPad:** Import a file
2. **iPhone:** Keep app open
3. Within 10-30 seconds, the file should automatically appear (NSMetadataQuery detects it)

### Test 3: Background Sync
1. **iPad:** Import multiple files
2. **iPhone:** Close app
3. **iPhone:** Reopen app → sync banner should appear briefly
4. All files should download automatically

## Important Notes

### iCloud Requirements
Both simulators must:
- Be signed into the **same Apple ID**
- Have **iCloud Drive enabled** (Settings → Apple ID → iCloud)
- Be on the **same network** for faster sync

### Simulator iCloud
- Simulators use a local iCloud container (not real iCloud servers)
- Files sync through `~/Library/Developer/CoreSimulator/`
- Sometimes need to restart simulators to see changes

### Monitoring Console
Check Xcode console for sync logs:
```
✅ Started iCloud monitoring for: /path/to/iCloud/AudioFiles
📊 iCloud query finished gathering: 5 items
⬇️ Downloading 2 files from iCloud...
✅ Finished downloading files from iCloud
```

## Troubleshooting

### Files Still Not Appearing?

1. **Check iCloud Settings**
   ```bash
   # On Mac, verify iCloud Drive is working
   open ~/Library/Mobile\ Documents/iCloud~com~yevgenylevin~animated~MixDoctor/Documents/AudioFiles/
   ```

2. **Force Restart Both Simulators**
   - Sometimes iCloud sync needs a fresh start
   - Quit simulators completely
   - Relaunch both

3. **Check Console Logs**
   - Look for "iCloud monitoring" messages
   - Check for download errors

4. **Manual Sync**
   - Pull down on Dashboard
   - Should trigger immediate download check

5. **Verify Settings**
   - Open Settings tab
   - Ensure "Sync with iCloud" is **ON**
   - If OFF, turn it ON and restart app

### Common Issues

**"iCloud not available"**
- Sign in to iCloud on simulator
- Enable iCloud Drive in Settings

**"No files syncing"**
- Check UserDefaults: `iCloudSyncEnabled` should be `true`
- Restart iCloud monitoring: force quit and reopen app

**"Files show but can't play"**
- File is still downloading from iCloud
- Wait for sync to complete (watch status banner)
- Pull to refresh to check download status

## Architecture

```
Import File on iPad
        ↓
┌───────────────────────────────────┐
│ AudioImportService                │
│ - Copies file to iCloud Documents │
└───────────────┬───────────────────┘
                ↓
        ┌───────────────┐
        │ iCloud Drive  │ ← Ubiquity Container
        │   Uploads     │
        └───────┬───────┘
                ↓
    ┌────────────────────────┐
    │   SwiftData + CloudKit │ ← Metadata sync
    │   (AudioFile records)  │
    └───────┬────────────────┘
            ↓
    ┌───────────────────┐
    │ iPhone receives   │
    │ AudioFile metadata│
    └───────┬───────────┘
            ↓
    ┌───────────────────────┐
    │ iCloudSyncMonitor     │ ← NEW!
    │ - Detects new files   │
    │ - Downloads to local  │
    └───────┬───────────────┘
            ↓
    ┌───────────────────┐
    │ File playable on  │
    │ iPhone ✅         │
    └───────────────────┘
```

## Performance Considerations

- **NSMetadataQuery** runs in background, minimal battery impact
- Files only download when detected (not constantly polling)
- Pull-to-refresh gives users control over sync timing
- Large files may take longer to download (watch progress)

## Next Steps

Consider implementing:
1. Download progress per file (currently shows overall status)
2. Retry mechanism for failed downloads
3. Option to delete cloud files vs local only
4. iCloud storage usage indicator
5. Conflict resolution (if file modified on both devices)

## Files Modified

1. ✅ `iCloudSyncMonitor.swift` (NEW) - Core monitoring service
2. ✅ `MixDoctorApp.swift` - Added automatic monitoring on launch
3. ✅ `DashboardView.swift` - Added sync UI and pull-to-refresh
4. ✅ `iCloudStorageService.swift` (existing) - Already handles iCloud paths

All changes are backward compatible - app still works without iCloud!
