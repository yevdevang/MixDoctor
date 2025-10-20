# Import View Layout - Final Design

## Changes Applied

### 1. **Song Count Header**
- **Font:** `.headline` (smaller, more appropriate size)
- **Layout:** Single line, clean presentation
- Format: "5 Songs" or "1 Song"

### 2. **Song Row Layout**
```
┌─────────────────────────────────────────────────────┐
│  Song Title.mp3                               ●     │  ← Title + Play button aligned
│  3:45 • 44.1 kHz • 24-bit • Stereo • 12.3 MB       │  ← All metadata in ONE line
└─────────────────────────────────────────────────────┘
```

**Key Improvements:**
- **Alignment:** Play button is center-aligned with the row (not just top-aligned)
- **Metadata:** All information in a single line with bullet separators
- **Play Button:** 
  - Size: 40x40pt (slightly smaller for better proportions)
  - Icon: `play.fill` (16pt, semibold)
  - White icon on accent color background
  - Slight offset (1.5pt) for visual centering
- **Spacing:** 
  - Reduced vertical spacing (4pt between title and metadata)
  - Consistent 6pt spacing between metadata items
  - Line truncation if metadata is too long

### 3. **Complete Layout**
```
┌─────────────────────────────────────────────────────┐
│  Import Audio                       [Browse Files]  │
│                                                      │
│  5 Songs                              Import More   │  ← Headline font
│  ┌──────────────────────────────────────────────┐  │
│  │ My Mix Final.wav                      ●      │  │  ← 40x40 play button
│  │ 3:45 • 44.1 kHz • 24-bit • Stereo • 12.3 MB │  │  ← Single line metadata
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │ Drums Master.aif                      ●      │  │
│  │ 4:12 • 48 kHz • 16-bit • Stereo • 8.9 MB    │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │ Vocal Take 5.mp3                      ●      │  │
│  │ 2:58 • 44.1 kHz • 16-bit • Stereo • 4.2 MB  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Technical Details

### HStack Alignment
```swift
HStack(alignment: .center, spacing: 12)
```
- Centers play button with the entire row content

### Metadata Line
```swift
HStack(spacing: 6) {
    Text(duration) • Text(sampleRate) • Text(bitDepth) • 
    Text(channels) • Text(fileSize)
}
.lineLimit(1)  // Ensures single line, truncates if needed
```

### Play Button
```swift
Button(action: onPlayTapped) {
    ZStack {
        Circle()
            .fill(Color.primaryAccent)
            .frame(width: 40, height: 40)
        
        Image(systemName: "play.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .offset(x: 1.5)
    }
}
```

## Visual Hierarchy
1. **Song Title** - Headline font, most prominent
2. **Metadata** - Caption font, secondary text color, single line
3. **Play Button** - Accent color, right-aligned, center of row

## Interaction
- Tap play button → Loads song → Switches to Player tab
- Swipe left → Delete option
- Entire row has tap feedback (contentShape)

## Build Status
✅ **BUILD SUCCEEDED**

## Testing
1. Clean build (Cmd+Shift+K)
2. Run app
3. Navigate to Import tab
4. Verify:
   - Header shows "X Songs" in headline font
   - Each row has title + metadata in one line
   - Play button is centered vertically in row
   - Tapping play button navigates to Player tab
