# MixDoctor Testing Guide

## Dear Testers! 👋

Thank you for helping test **MixDoctor**, a professional audio analysis app for musicians, producers, and sound engineers. This guide will walk you through everything you need to test to ensure the app works perfectly before release.

---

## 📱 What is MixDoctor?

MixDoctor is an iOS app that analyzes audio mixes and provides professional feedback on:
- Frequency balance (bass, mids, treble)
- Stereo imaging and spatial characteristics
- Dynamic range and compression
- Overall mix quality scores
- Detailed recommendations for improvement

---

## 🎯 Test Environment Setup

### What You'll Need:
- ✅ **iPhone or iPad** running iOS 17.0 or later
- ✅ **Test audio files** (WAV, MP3, M4A, AIFF formats)
- ✅ **iCloud account** (for testing sync features)
- ✅ **Multiple devices** (optional, for testing iCloud sync)
- ✅ **Headphones** (for testing playback quality)

### Before You Start:
1. **Delete any previous version** of MixDoctor from your device
2. **Install the latest build** provided via TestFlight or Xcode
3. **Enable iCloud Drive** in Settings → [Your Name] → iCloud
4. **Prepare 5-10 audio files** of different formats for testing

---

## 🧪 Testing Checklist

### 1️⃣ First Launch Experience

**Test the app's initial setup and welcome flow:**

- [ ] **Launch Screen**
  - App shows animated launch screen with MixDoctor logo
  - Audio plays during launch (3 bars @ 120bpm = ~6 seconds)
  - Animation smoothly transitions to main app
  
- [ ] **Welcome Message** (Free users only)
  - Alert appears: "Welcome to Mix Doctor! 🎵"
  - Message mentions "3 free analyses"
  - "Got It!" button dismisses the alert
  - Alert only shows ONCE (not on subsequent launches)

- [ ] **Initial Tab**
  - App opens on **Dashboard** tab
  - Dashboard shows "No audio files yet" state
  - UI is clean and responsive

**Expected Result:** Smooth, professional first-time experience with clear messaging.

---

### 2️⃣ Audio Import & File Management

**Test importing audio files from various sources:**

#### Import Methods to Test:

- [ ] **Files App Import**
  - Go to **Import** tab
  - Tap "Import Audio from Files"
  - Navigate to Files app
  - Select a WAV file → Import successful
  - Select an MP3 file → Import successful
  - Select an M4A file → Import successful
  - Select an AIFF file → Import successful

- [ ] **iCloud Drive Import**
  - Put test files in iCloud Drive
  - Import from iCloud Drive location
  - Files appear in Dashboard

- [ ] **Multiple File Import**
  - Try selecting multiple files at once
  - All files import successfully
  - Each file appears in Dashboard

- [ ] **Unsupported Format**
  - Try importing a .TXT or .PDF file
  - App should show error: "Unsupported file format"

#### File Display:

- [ ] **Dashboard View**
  - All imported files appear as cards
  - Each card shows:
    - ✅ File name
    - ✅ File format (WAV, MP3, etc.)
    - ✅ File size
    - ✅ Duration (if available)
    - ✅ Import date
    - ✅ Waveform visualization (if analyzed)

- [ ] **File Sorting**
  - Files appear in reverse chronological order (newest first)
  - Recent imports appear at the top

**Expected Result:** All standard audio formats import smoothly with clear visual feedback.

---

### 3️⃣ Audio Analysis (Core Feature)

**Test the AI-powered audio analysis functionality:**

#### Free User Analysis (3 analyses limit):

- [ ] **First Analysis**
  - Import an audio file
  - Tap "Analyze Mix" button
  - Loading indicator appears
  - Analysis completes successfully
  - Results screen shows with detailed metrics
  - Status bar shows "Free (2/3 remaining)" or similar

- [ ] **Second & Third Analysis**
  - Analyze 2 more files
  - Each analysis completes successfully
  - Counter decrements: "Free (1/3)", then "Free (0/3)"

- [ ] **Analysis Limit Reached**
  - Try to analyze a 4th file
  - **Paywall appears** instead of analysis
  - Paywall shows upgrade options
  - "Restore Purchases" button visible

#### Analysis Results Screen:

When analysis completes, verify these sections:

- [ ] **Overall Score**
  - Large circular score (0-100)
  - Color-coded: Green (>80), Yellow (60-80), Red (<60)
  - Clear rating label

- [ ] **Frequency Balance**
  - Bass, Mids, Treble breakdown
  - Visual bar charts for each range
  - Score for each frequency range
  - Recommendations for improvement

- [ ] **Stereo Imaging**
  - Stereo width analysis
  - Visual representation of stereo field
  - Mono compatibility check
  - Spatial balance metrics

- [ ] **Dynamic Range**
  - Peak levels
  - RMS levels
  - Crest factor
  - Compression analysis

- [ ] **Detailed Recommendations**
  - AI-generated suggestions
  - Specific frequency adjustments
  - Mix improvement tips
  - Genre-specific advice (if applicable)

- [ ] **Visual Elements**
  - Waveform display
  - Spectrum analyzer
  - Frequency response graph
  - All charts render correctly

**Expected Result:** Professional, detailed analysis with actionable insights.

---

### 4️⃣ Subscription & Paywall

**Test the monetization flow (requires sandbox tester account):**

#### Paywall Display:

- [ ] **Trigger Paywall**
  - Use up 3 free analyses
  - Attempt 4th analysis
  - Paywall appears automatically

- [ ] **Paywall Design**
  - Title: "Upgrade to Pro"
  - Beautiful gradient background
  - Feature list with icons:
    - ✅ Unlimited analyses
    - ✅ 50 analyses per month (Pro tier)
    - ✅ Advanced AI insights
    - ✅ Export detailed reports
    - ✅ Priority support
  - Both Monthly and Annual packages visible
  - Prices display correctly
  - "SAVE 25%" badge on Annual plan

- [ ] **Package Selection**
  - Can select Monthly package
  - Can select Annual package
  - Selected package highlights
  - Price updates based on selection

#### Purchase Flow (Sandbox Testing):

**Note:** You need an App Store Sandbox tester account for this.

- [ ] **Subscribe Button**
  - Tap "Subscribe Now"
  - StoreKit purchase sheet appears
  - Sign in with sandbox tester account
  - Complete purchase flow
  - Paywall dismisses on success
  - Analysis completes automatically

- [ ] **Purchase Success**
  - Settings tab shows "Pro" status
  - Analysis counter shows "Pro (50/50 analyses)"
  - Can now analyze unlimited files (within 50/month limit)

- [ ] **Restore Purchases**
  - Delete and reinstall app
  - Trigger paywall
  - Tap "Restore Purchases"
  - Subscription restores successfully
  - Pro status activated

#### Trial Testing (if configured):

- [ ] **Free Trial**
  - Start trial from paywall
  - Settings shows trial status
  - Trial users get appropriate analysis limit
  - Trial converts to paid after period ends

**Expected Result:** Smooth, trustworthy purchase experience with clear value proposition.

---

### 5️⃣ Audio Playback

**Test the built-in audio player:**

#### Player Tab:

- [ ] **Select File**
  - Go to Player tab
  - Select an audio file from list
  - File loads successfully

- [ ] **Playback Controls**
  - Tap Play button → Audio plays
  - Tap Pause button → Audio pauses
  - Seek slider works smoothly
  - Time display shows current position
  - Total duration displays correctly

- [ ] **Playback Quality**
  - Audio plays without distortion
  - Volume controls work
  - No crackling or stuttering
  - Plays through device speakers
  - Plays through headphones (if connected)

- [ ] **Background Playback** (if supported)
  - Start playback
  - Lock device → Audio continues
  - Switch apps → Audio continues
  - Control Center shows controls

- [ ] **Playlist Navigation**
  - Multiple files in queue
  - Next/Previous buttons work
  - Auto-advance to next track (if enabled)

**Expected Result:** Professional-grade audio playback with smooth controls.

---

### 6️⃣ Settings & Preferences

**Test all settings and configuration options:**

#### Settings Tab:

- [ ] **Subscription Status**
  - Shows "Free (X/3 analyses)" for free users
  - Shows "Pro (X/50 analyses this month)" for subscribers
  - Shows "Trial" status if in trial period
  - Displays subscription expiry date (if applicable)

- [ ] **Theme Selection**
  - System theme (default)
  - Light theme
  - Dark theme
  - Theme applies immediately
  - Theme persists after app restart

- [ ] **iCloud Sync Toggle**
  - "Sync with iCloud" switch visible
  - Toggle ON → Enables iCloud sync
  - Toggle OFF → Disables iCloud sync
  - Alert appears: "App restart required for changes"

- [ ] **Storage Management**
  - Shows total storage used
  - Shows number of files stored
  - "Clear Cache" button works
  - "Delete All Files" works (with confirmation)

- [ ] **About Section**
  - App version number displays
  - Privacy Policy link works
  - Terms of Service link works
  - Contact Support link works

**Expected Result:** All settings work as expected with clear feedback.

---

### 7️⃣ iCloud Sync (Multi-Device)

**Test cloud synchronization between devices:**

**You'll need:** 2 iOS devices signed into the same Apple ID with iCloud enabled.

#### Sync Setup:

- [ ] **Enable on Both Devices**
  - Device 1: Settings → Enable "Sync with iCloud"
  - Device 2: Settings → Enable "Sync with iCloud"
  - Restart both apps

#### Test Sync:

- [ ] **Upload from Device 1**
  - Import an audio file on Device 1
  - Wait 10-30 seconds for upload
  - Check iCloud sync status banner

- [ ] **Download on Device 2**
  - Open app on Device 2
  - Pull down on Dashboard to refresh
  - File appears in Dashboard
  - File is playable (not just metadata)
  - Analysis results sync (if analyzed)

- [ ] **Bidirectional Sync**
  - Import file on Device 2
  - Check if it appears on Device 1
  - Both devices have all files

- [ ] **Sync Status**
  - "Syncing files from iCloud..." banner appears
  - Progress indicator shows during sync
  - Banner dismisses when complete

- [ ] **Offline Behavior**
  - Turn off WiFi on Device 2
  - Import file on Device 1
  - Turn WiFi back ON on Device 2
  - File syncs automatically

**Expected Result:** Seamless file synchronization across all devices with clear status feedback.

---

### 8️⃣ Performance & Stability

**Test app performance under various conditions:**

#### Memory & CPU:

- [ ] **Large File Handling**
  - Import a 100MB+ audio file
  - Analysis completes without crash
  - Playback is smooth
  - App doesn't freeze

- [ ] **Multiple Files**
  - Import 20+ audio files
  - Dashboard scrolls smoothly
  - No lag when switching tabs
  - App remains responsive

- [ ] **Background Performance**
  - Start long analysis
  - Switch to another app
  - Return to MixDoctor
  - Analysis continues/completes

#### Edge Cases:

- [ ] **No Internet Connection**
  - Turn off WiFi and cellular
  - App still opens and functions
  - Local files play normally
  - Subscription status cached (shows last known state)
  - Clear error if trying to purchase

- [ ] **Low Storage**
  - Test with device at 95%+ storage
  - Import attempt shows storage warning
  - App doesn't crash

- [ ] **Interruptions**
  - Phone call during playback → Playback pauses
  - After call → Playback resumes
  - Siri interruption → Graceful handling
  - Notification sounds don't break playback

**Expected Result:** Stable, responsive app under all conditions.

---

### 9️⃣ UI/UX & Accessibility

**Test user interface quality and accessibility features:**

#### Visual Design:

- [ ] **Dark Mode**
  - Switch to Dark Mode
  - All screens adapt correctly
  - Text remains readable
  - No white flashes

- [ ] **Light Mode**
  - Switch to Light Mode
  - All screens adapt correctly
  - Colors look professional

- [ ] **Different Screen Sizes**
  - iPhone SE (small screen): UI fits properly
  - iPhone 15 Pro Max (large screen): No empty spaces
  - iPad: Layout adapts to tablet size

#### Accessibility:

- [ ] **VoiceOver Support**
  - Enable VoiceOver in Settings
  - Navigate app with VoiceOver
  - All buttons/elements are labeled
  - Meaningful descriptions provided

- [ ] **Dynamic Type**
  - Settings → Display & Brightness → Text Size
  - Increase text size → App text scales
  - Decrease text size → UI still looks good

- [ ] **Color Blindness**
  - Enable Color Filters (Settings → Accessibility)
  - Test Protanopia, Deuteranopia filters
  - Important info still distinguishable

**Expected Result:** Professional, accessible design that works for all users.

---

### 🔟 Error Handling

**Test how the app handles errors gracefully:**

#### Expected Errors:

- [ ] **Corrupted File**
  - Import a corrupted/incomplete audio file
  - App shows error: "Unable to analyze file"
  - App doesn't crash
  - Can still import other files

- [ ] **Network Timeout**
  - Start analysis with poor connection
  - Disconnect internet mid-analysis
  - Graceful error message
  - Option to retry

- [ ] **iCloud Quota Exceeded**
  - If iCloud storage full
  - Clear error message
  - Suggestion to manage storage

- [ ] **Payment Failure**
  - Attempt purchase with invalid payment
  - Sandbox tester with no payment method
  - Clear error message
  - Can retry or cancel

**Expected Result:** Clear, helpful error messages with recovery options.

---

## 🐛 Bug Reporting

If you find any issues, please report them with these details:

### Information to Include:

1. **Device Info:**
   - Device model (iPhone 14, iPad Pro, etc.)
   - iOS version (Settings → General → About)
   - App version (Settings tab in MixDoctor)

2. **Steps to Reproduce:**
   - What were you trying to do?
   - What did you tap/select?
   - When did the issue occur?

3. **Expected vs Actual:**
   - What did you expect to happen?
   - What actually happened?

4. **Screenshots/Videos:**
   - Take screenshots of the issue
   - Screen recording if it's a visual bug

5. **Frequency:**
   - Does it happen every time?
   - Only sometimes?
   - Only on certain files?

### Where to Report:
- **Email:** [Your support email]
- **TestFlight Feedback:** Use the "Send Feedback" button in TestFlight
- **Bug Tracker:** [If you have one]

---

## ✅ Final Checklist

Before signing off on testing, confirm:

- [ ] All core features work (Import, Analyze, Play, Settings)
- [ ] Subscription flow works (paywall, purchase, restore)
- [ ] iCloud sync works across devices
- [ ] No crashes or freezes
- [ ] UI looks professional on all screens
- [ ] Errors are handled gracefully
- [ ] Performance is smooth
- [ ] Audio quality is excellent

---

## 🙏 Thank You!

Your testing helps make MixDoctor the best audio analysis app for musicians and producers. Every bug you find and piece of feedback you provide makes the app better for all users.

**Questions?** Don't hesitate to reach out!

**Happy Testing!** 🎵🎧

---

## 📋 Quick Reference

### Test Audio Files Needed:
- ✅ WAV file (lossless)
- ✅ MP3 file (320kbps)
- ✅ M4A file (AAC)
- ✅ AIFF file
- ✅ Large file (>100MB)
- ✅ Short file (<10 seconds)
- ✅ Long file (>5 minutes)
- ✅ Stereo mix
- ✅ Mono file (if available)

### Priority Test Areas:
1. **Critical:** Audio import and analysis (core functionality)
2. **High:** Subscription and paywall flow
3. **Medium:** iCloud sync, playback, settings
4. **Low:** Edge cases, accessibility, specific device sizes

### Estimated Testing Time:
- **Quick Test:** 30 minutes (core features only)
- **Full Test:** 2-3 hours (everything above)
- **Multi-Device Test:** +1 hour (iCloud sync)

---

**Version:** 1.0  
**Last Updated:** November 29, 2025  
**Build:** 3
