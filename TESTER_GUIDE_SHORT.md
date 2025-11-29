# MixDoctor Testing Guide

## Dear Testers! 👋

Thank you for testing **MixDoctor** - a professional audio analysis app for musicians and producers.

## 📱 Setup Required
- iPhone/iPad running iOS 17.0+
- Test audio files (WAV, MP3, M4A, AIFF)
- iCloud account enabled
- Delete any previous app version before installing

## 🧪 Critical Tests

### 1. First Launch
- [ ] Launch screen animates smoothly (~6 seconds)
- [ ] Welcome message appears: "3 free analyses"
- [ ] Dashboard shows "No audio files yet"

### 2. Import Audio
- [ ] Import WAV, MP3, M4A, AIFF files from Files app
- [ ] Multiple files import successfully
- [ ] Unsupported formats show error
- [ ] Files display with name, format, size, duration

### 3. Audio Analysis (Core Feature)
- [ ] Tap "Analyze Mix" → loading indicator → results
- [ ] Counter shows "Free (2/3 remaining)"
- [ ] After 3 analyses, paywall appears
- [ ] Results show: Overall Score, Frequency Balance, Stereo Imaging, Dynamic Range, AI Recommendations
- [ ] All charts/waveforms render correctly

### 4. Subscription
- [ ] Paywall displays Monthly & Annual options with prices
- [ ] "Subscribe Now" → StoreKit sheet → complete purchase
- [ ] Settings shows "Pro (50/50 analyses)"
- [ ] Restore Purchases works after reinstall

### 5. Audio Player
- [ ] Play/Pause buttons work
- [ ] Seek slider responds smoothly
- [ ] Time display accurate
- [ ] Plays through speakers & headphones
- [ ] Background playback works when locked

### 6. Settings
- [ ] Shows correct subscription status
- [ ] Theme switching works (System/Light/Dark)
- [ ] iCloud sync toggle present
- [ ] Storage info displays
- [ ] Links open (Privacy, Terms, Support)

### 7. iCloud Sync (2 devices needed)
- [ ] Import file on Device 1
- [ ] Pull-to-refresh on Device 2 → file appears
- [ ] File is playable on Device 2
- [ ] Sync banner shows progress

### 8. Performance
- [ ] Large files (100MB+) don't crash
- [ ] 20+ files import without lag
- [ ] Phone calls pause/resume playback
- [ ] App works offline (local files)
- [ ] Low storage shows warning

### 9. UI/UX
- [ ] Dark/Light mode adapts properly
- [ ] Works on iPhone SE & Pro Max
- [ ] VoiceOver labels all elements
- [ ] Dynamic Type scales text

### 10. Error Handling
- [ ] Corrupted file shows error (no crash)
- [ ] Network timeout shows retry option
- [ ] Payment failures handled gracefully

## 🐛 Bug Reporting

**Include:** Device model, iOS version, steps to reproduce, screenshots

**Report via:** TestFlight Feedback or [your email]

## ✅ Final Checklist
- [ ] Import, Analyze, Play, Settings work
- [ ] Subscription & restore work
- [ ] iCloud sync works
- [ ] No crashes
- [ ] UI professional on all screens

## 📋 Test Files Needed
WAV, MP3, M4A, AIFF | Large (100MB+) | Short (<10s) | Long (>5min)

**Priority:** 1) Import/Analysis 2) Subscription 3) Sync/Playback

**Quick Test:** 30 min | **Full Test:** 2-3 hours

Thank you! Your feedback makes MixDoctor better! 🎵

**Version 1.0 | Nov 29, 2025 | Build 3**
