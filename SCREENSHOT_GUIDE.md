# MixDoctor App Screenshots Guide

This guide will help you capture all the main views of the MixDoctor app in both Light and Dark modes for App Store submission.

## Required Screenshots

For iPhone 6.5" Display, you need:
- Up to 3 app previews (videos)
- Up to 10 screenshots
- Dimensions: 1242 × 2688px, 2688 × 1242px, 1284 × 2778px, or 2778 × 1284px

## Setup Instructions

### 1. Prepare the Simulator/Device
1. Open Xcode and run MixDoctor on iPhone 14 Pro Max or iPhone 15 Pro Max simulator (6.5" display)
2. Import some sample audio files for demonstration
3. Perform analysis on at least one file

### 2. Toggle Between Light and Dark Mode
- **Light Mode**: Settings > Display & Brightness > Light
- **Dark Mode**: Settings > Display & Brightness > Dark
- **Or use Control Center**: Long press on brightness slider > Appearance

## Screenshots to Capture

### View 1: Dashboard (Tab 1) - Empty State
**Light Mode:**
1. Launch app
2. Navigate to Dashboard tab
3. Make sure no files are imported
4. Screenshot shows:
   - Empty state with "No Audio Files" message
   - "Import audio files to get started" text
   - Pull down to sync message

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `dashboard_empty_light.png`
- `dashboard_empty_dark.png`

---

### View 2: Dashboard - With Files
**Light Mode:**
1. Import 3-5 audio files
2. Perform analysis on at least 2 files
3. Screenshot shows:
   - Statistics cards (Total Files, Analyzed, Issues Found, Avg Score)
   - Filter picker (All, Analyzed, Pending, Has Issues)
   - List of audio files with metadata

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `dashboard_files_light.png`
- `dashboard_files_dark.png`

---

### View 3: Import View (Tab 2) - Empty State
**Light Mode:**
1. Navigate to Import tab
2. Delete all imported files (or start fresh)
3. Screenshot shows:
   - Large waveform icon
   - "Import Audio Files" title
   - "Browse Files" button
   - Supported formats list (WAV, MP3, M4A, AIFF, etc.)

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `import_empty_light.png`
- `import_empty_dark.png`

---

### View 4: Import View - With Files
**Light Mode:**
1. Import 3-5 audio files
2. Screenshot shows:
   - File count header
   - "Import More" button
   - List of imported files with metadata
   - Play buttons for each file

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `import_files_light.png`
- `import_files_dark.png`

---

### View 5: Player View (Tab 3) - Active
**Light Mode:**
1. Navigate to Player tab
2. Select an audio file
3. Screenshot shows:
   - Album artwork placeholder
   - File name and metadata
   - Waveform visualization
   - Playback progress slider
   - Play/pause button and controls
   - Previous/Next track buttons
   - Channel mode selector

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `player_active_light.png`
- `player_active_dark.png`

---

### View 6: Player View - Empty State
**Light Mode:**
1. Navigate to Player tab with no files
2. Screenshot shows:
   - Music note icon
   - "No audio selected" message
   - Instructions to import files

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `player_empty_light.png`
- `player_empty_dark.png`

---

### View 7: Analysis Results View
**Light Mode:**
1. From Dashboard, tap on an analyzed file
2. Scroll to show:
   - Song title
   - Overall Score card with circular progress
   - Score description
   - Issues summary

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `results_overview_light.png`
- `results_overview_dark.png`

---

### View 8: Analysis Results - Detailed Metrics
**Light Mode:**
1. Scroll down in Results view to show:
   - Stereo Width card
   - Phase Coherence card
   - Mono Compatibility card
   - PAZ Frequency Analyzer
   - Dynamic Range card

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `results_metrics_light.png`
- `results_metrics_dark.png`

---

### View 9: Analysis Results - AI Analysis
**Light Mode:**
1. Scroll to show AI Analysis section:
   - AI Analysis header with brain icon
   - Summary text
   - AI Recommendations

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `results_ai_light.png`
- `results_ai_dark.png`

---

### View 10: Settings View (Tab 4)
**Light Mode:**
1. Navigate to Settings tab
2. Screenshot shows:
   - Subscription Status
   - Theme picker
   - Auto-Analyze toggle
   - Mute Launch Sound toggle
   - Storage Management
   - iCloud Sync toggle
   - About section

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `settings_light.png`
- `settings_dark.png`

---

### View 11: Paywall View
**Light Mode:**
1. Tap "Upgrade to Pro" in Settings
2. Screenshot shows:
   - App icon
   - "Unlock Pro Features" title
   - Premium features list
   - Subscription packages
   - "Start 3-Day Free Trial" button

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `paywall_light.png`
- `paywall_dark.png`

---

### View 12: About View
**Light Mode:**
1. Settings > About MixDoctor
2. Screenshot shows:
   - App icon
   - "Professional Audio Analysis" subtitle
   - Features list
   - Copyright notice

**Dark Mode:**
1. Switch to Dark mode
2. Take same screenshot

**File naming:**
- `about_light.png`
- `about_dark.png`

---

## Best Practices

1. **Clean Data**: Use professional-sounding file names (e.g., "Summer Mix 2024.wav" instead of "test.wav")
2. **Realistic Scores**: Use files that show varied analysis results (some good, some with issues)
3. **Consistent Theme**: Make sure the purple accent color (RGB: 111, 44, 222) is prominent
4. **No Personal Info**: Don't include any personal or sensitive information
5. **High Quality**: Use actual device screenshots, not simulator if possible
6. **Proper Dimensions**: Verify screenshot dimensions match App Store requirements

## Taking Screenshots

### On Simulator:
1. Window > Screenshot (or Cmd+S)
2. Screenshots save to Desktop by default

### On Device:
1. Volume Up + Side Button (iPhone X and later)
2. Screenshots save to Photos app

## Post-Processing

1. **Verify Dimensions**: Check that all screenshots are 1242×2688px or 1284×2778px
2. **Crop if Needed**: Use Preview or image editor to crop to exact dimensions
3. **Organize**: Create folders for Light and Dark modes
4. **Compress**: Optimize file size without losing quality (use ImageOptim or similar)

## Screenshot Order for App Store

Recommended order for maximum impact:

1. Dashboard with files (shows main functionality)
2. Analysis Results overview (shows the value proposition)
3. Analysis Results - Detailed metrics (shows depth)
4. Player view active (shows audio playback)
5. Import view with files (shows ease of use)
6. Settings view (shows customization)
7. AI Analysis section (shows premium features)
8. Paywall (shows subscription model)

## Additional Tips

- **Status Bar**: Clean up status bar (set time to 9:41, full battery, good signal)
- **Consistency**: Use same sample files across screenshots
- **Context**: Each screenshot should tell a story
- **Highlight Features**: Focus on unique selling points
- **Professional Look**: Use realistic, professional audio file names

## Color Scheme

- **Primary Accent**: RGB(111, 44, 222) - Purple
- **Background Primary**: System background
- **Background Secondary**: System secondary background
- **Text Primary**: System primary label
- **Text Secondary**: System secondary label

The app automatically adapts to Light/Dark mode, so screenshots will show the proper contrast and colors for each mode.
