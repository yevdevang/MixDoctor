# Window Sizing Test Guide for Mac Catalyst

This guide helps ensure the MixDoctor app window displays correctly across all Mac devices.

## How the Adaptive Sizing Works

The app now uses **adaptive window sizing** that automatically adjusts based on the screen size:

### Screen Size Detection
- **Small screens** (< 1400px width): Minimum width 1200px, height 700px
  - MacBook Air 13"
  - Older MacBook Pro 13"
  
- **Medium screens** (1400-1800px width): Minimum width 1500px, height 850px
  - MacBook Pro 14"
  - MacBook Pro 15"
  
- **Large screens** (> 1800px width): Minimum width 1700px, height 900px
  - MacBook Pro 16"
  - iMac 24", 27"
  - External monitors

### Safety Features
- Minimum sizes never exceed 95% of screen width
- Minimum heights never exceed 90% of screen height
- Window is automatically centered on screen
- Initial size is 90% of screen width (max 1800px) and 85% of screen height (max 1100px)

## Testing Checklist

### 1. Physical Device Testing (Recommended)
Test on actual hardware when possible:

- [ ] **MacBook Air 13"** (M1/M2/M3)
  - Verify window fits on screen
  - Check that right side is visible
  - Test resizing to minimum size
  
- [ ] **MacBook Pro 14"**
  - Verify window opens at appropriate size
  - Check all UI elements are visible
  - Test resizing functionality
  
- [ ] **MacBook Pro 16"**
  - Verify window can utilize larger screen
  - Check maximum size constraints
  - Test window positioning

- [ ] **iMac** (if available)
  - Verify window sizing on large display
  - Check window centering

### 2. Simulator Testing
Use Xcode Simulator with different device configurations:

#### Mac Catalyst Simulator Options:
1. **Window > Devices and Simulators**
2. Create custom device configurations or use presets:
   - Mac (Designed for iPad) - simulates smaller Mac screens
   - Mac Catalyst - default size
   - Custom resolutions

#### Test Scenarios:
- [ ] Launch app and verify initial window size
- [ ] Resize window to minimum size - verify it works
- [ ] Resize window to maximum size - verify it works
- [ ] Move window to different positions - verify it stays on screen
- [ ] Test with different screen resolutions:
  - 1280x800 (small)
  - 1440x900 (medium)
  - 1680x1050 (large)
  - 1920x1080 (full HD)
  - 2560x1440 (2K)
  - 3840x2160 (4K)

### 3. External Monitor Testing
- [ ] Connect external monitor
- [ ] Test window on external display
- [ ] Verify window sizing adapts correctly
- [ ] Test moving window between displays

### 4. Edge Cases
- [ ] **Very small screens**: Window should never exceed screen bounds
- [ ] **Very large screens**: Window should utilize space appropriately
- [ ] **Multiple displays**: Window should work on any connected display
- [ ] **Window restoration**: After app restart, window should remember size (if implemented)

## What to Look For

### ✅ Good Signs:
- Window fits entirely on screen
- Right side is always visible
- Window is centered on launch
- Can resize smoothly between min/max
- No content is cut off
- Window doesn't exceed screen bounds

### ❌ Problems to Watch For:
- Window extends beyond screen edges
- Right side is cut off
- Window too small to be usable
- Window positioned off-screen
- Content overflow or clipping
- Resizing doesn't work properly

## Debugging Tips

### Check Current Screen Size
Add temporary logging to see what screen size is detected:

```swift
print("Screen size: \(screenWidth)x\(screenHeight)")
print("Adaptive minimum: \(adaptiveMinimumWidth)x\(adaptiveMinimumHeight)")
print("Window frame: \(window.frame)")
```

### Test Different Scenarios
1. **Small screen test**: Resize simulator to 1280x800
2. **Medium screen test**: Use 1440x900
3. **Large screen test**: Use 1920x1080 or larger
4. **Ultra-wide test**: Test with 21:9 aspect ratio if possible

## Verification Steps

1. **Launch Test**: 
   - Launch app on target device
   - Verify window opens at appropriate size
   - Check window is centered

2. **Resize Test**:
   - Drag window corners to resize
   - Verify minimum size constraint works
   - Verify maximum size constraint works
   - Check that content remains visible

3. **Position Test**:
   - Move window to screen edges
   - Verify window doesn't go off-screen
   - Check that all content remains accessible

4. **Content Test**:
   - Navigate through all views (Dashboard, Import, Player, Settings)
   - Verify no content is cut off
   - Check that scrollable areas work correctly
   - Test PaywallView scrolling (previously fixed)

## Common Mac Screen Resolutions Reference

| Device | Typical Resolution | Logical Points |
|--------|-------------------|----------------|
| MacBook Air 13" | 2560x1600 | 1280x800 (2x) |
| MacBook Pro 14" | 3024x1964 | 1512x982 (2x) |
| MacBook Pro 16" | 3456x2234 | 1728x1117 (2x) |
| iMac 24" | 4480x2520 | 2240x1260 (2x) |
| iMac 27" | 5120x2880 | 2560x1440 (2x) |

Note: Mac Catalyst uses logical points, so divide Retina resolutions by 2.

## Reporting Issues

If you find issues with window sizing on a specific device:

1. Note the device model and screen resolution
2. Describe the problem (e.g., "right side cut off", "window too small")
3. Check the console for any window-related errors
4. Test on multiple devices to see if it's device-specific

## Future Improvements

Potential enhancements:
- Remember window size and position between launches
- Support for split-screen/multi-window on macOS
- Better handling of ultra-wide displays
- User preference for default window size

