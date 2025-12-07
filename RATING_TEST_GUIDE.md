# Rating System Test Guide

## How to Test the Rating Prompt

### Option 1: Using the Settings Panel (Recommended for Quick Testing)

1. **Open the app** in DEBUG mode (build from Xcode)
2. **Navigate to Settings** (tap the gear icon)
3. **Scroll down** to the "🧪 Test & Debug" section (only visible in DEBUG builds)
4. **Tap "Test Rating Prompt"** - This will immediately trigger the rating dialog

### Option 2: Using the Automatic Flow

1. **Reset tracking** (optional): In Settings → 🧪 Test & Debug → "Reset Rating Tracking"
2. **Perform analyses** according to your user type:
   - **Free User**: Complete 2 analyses → rating shows after 2nd
   - **Pro User**: Complete 6 analyses → rating shows after 6th
   - **Trial User**: Complete 2 analyses → rating shows after 2nd

### What You'll See

When triggered, you'll see Apple's native rating dialog that looks like:

```
┌─────────────────────────────┐
│  Enjoying Mix Doctor?       │
│                             │
│  ★ ★ ★ ★ ★                  │
│                             │
│  [Not Now]  [Rate]          │
└─────────────────────────────┘
```

## Test Section Features

In Settings → 🧪 Test & Debug:

- **Test Rating Prompt** ⭐ - Force show rating dialog immediately
- **Reset Rating Tracking** 🔄 - Clear all rating tracking data
- **Total Analyses** - Shows how many analyses have been performed

## Rating Strategy (Auto-Trigger)

| User Type | Trigger Point | Max Frequency |
|-----------|---------------|---------------|
| Free User | After 2nd analysis | Once ever |
| Pro User | After 6th analysis | 1x per month |
| Trial User | After 2nd analysis | Once ever |

## Important Notes

### For Testing:
- The test section only appears in **DEBUG builds**
- Apple may limit how often the rating dialog appears during testing
- On simulator, the rating dialog might not show - use a real device for best results

### For Production:
- The rating prompt will auto-trigger based on the strategy table
- The `#if DEBUG` section won't be visible to users
- Apple controls the final display frequency (may suppress if shown too recently)

## Console Output

Watch for these logs when testing:

```
⭐ Requesting app rating
🧪 TEST MODE: Forcing rating prompt
✅ Marked rating as shown for Free user (once)
🔄 Reset all rating tracking
```

## Troubleshooting

**Rating doesn't show?**
- Apple may suppress it if shown recently (even across different apps)
- Try on a different device or simulator
- Check console for "⭐ Requesting app rating" to confirm it was triggered
- Remember: Apple's StoreKit controls actual display frequency

**Want to test again?**
- Tap "Reset Rating Tracking" in Settings
- This clears all tracking data
- Then tap "Test Rating Prompt" or perform analyses again
