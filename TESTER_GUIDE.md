# MixDoctor Testing Guide - Build 5

## Setup Requirements
- iOS 17.0+ device
- Test audio files (WAV, MP3, M4A, AIFF)
- iCloud account (for sync testing)
- Enable iCloud Drive in Settings

## Critical Test Areas

### 1. First Launch
- [ ] Launch screen plays (3 bars @ 120bpm)
- [ ] Welcome alert shows "3 free analyses" (once only)
- [ ] Opens to Dashboard

### 2. Import
- [ ] Import WAV, MP3, M4A, AIFF from Files app
- [ ] Import from iCloud Drive
- [ ] Multiple file selection works
- [ ] Unsupported formats show error

### 3. Analysis (Core Feature)
- [ ] First 3 analyses work (free tier)
- [ ] Counter shows remaining analyses
- [ ] 4th analysis triggers paywall
- [ ] Results show: overall score, frequency balance, stereo imaging, dynamic range, recommendations

### 4. Subscription
- [ ] Paywall appears after 3 free analyses
- [ ] Monthly/Annual packages display with prices
- [ ] "SAVE 25%" badge on Annual
- [ ] Purchase completes (sandbox account)
- [ ] Status shows "Pro (50/50)"
- [ ] "Restore Purchases" works after reinstall

### 5. Playback
- [ ] Select file in Player tab
- [ ] Play/pause/seek controls work
- [ ] Audio quality is clear
- [ ] Works with headphones/speakers

### 6. Settings
- [ ] Shows subscription status correctly
- [ ] Theme changes apply (System/Light/Dark)
- [ ] iCloud sync toggle works
- [ ] Storage info displays

### 7. iCloud Sync (2 devices, same Apple ID)
- [ ] Enable sync on both devices
- [ ] Import file on Device 1
- [ ] File appears on Device 2 within 30s
- [ ] Analysis results sync
- [ ] Sync status banner shows progress

### 8. Performance
- [ ] Large files (100MB+) import/analyze without crash
- [ ] 20+ files scroll smoothly
- [ ] Works offline (local files only)
- [ ] Phone calls pause playback gracefully

### 9. Accessibility
- [ ] Dark/Light mode adapts correctly
- [ ] VoiceOver labels all buttons
- [ ] Dynamic Type scales text

### 10. Error Handling
- [ ] Corrupted files show clear error
- [ ] Network timeout has retry option
- [ ] Payment failures show helpful message

## Test Files Needed
WAV, MP3, M4A, AIFF | Large (100MB+) | Short (<10s) | Long (>5min) | Stereo/Mono

## Bug Reports
Include: Device model, iOS version, steps to reproduce, expected vs actual behavior, screenshots

## Testing Time
Quick: 30min | Full: 2-3hrs | Multi-device: +1hr

**Version 1.0 | Build 5 | December 2025**
