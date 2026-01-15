# TelemetryDeck Quick Setup

## ✅ Code Changes Completed

The following code changes have been made to integrate TelemetryDeck:

1. **Config.swift** - Added `telemetryDeckAppID` property to read the App ID from build configuration
2. **MixDoctorApp.swift** - Added TelemetryDeck initialization in `init()` method
3. **MixDoctorApp.swift** - Added test signal `App.Launched` when app starts

## 📦 Required: Add TelemetryDeck Package in Xcode

You need to add the TelemetryDeck Swift package to your project:

### Steps:

1. Open `MixDoctor.xcodeproj` in Xcode
2. In the menu, select **File → Add Package Dependencies...**
3. Paste this URL into the search field:
   ```
   https://github.com/TelemetryDeck/SwiftSDK
   ```
4. Select the `SwiftSDK` package that appears
5. Set **Dependency Rule** to **Up to Next Major Version**
6. Click **Add Package**
7. On the next screen, make sure **TelemetryDeck** (not "TelemetryClient") is selected for your app target
8. Click **Add Package** to complete

### Verify Package is Added:

- The package should appear in your Project Navigator under "Package Dependencies"
- The build should succeed without the "No such module 'TelemetryDeck'" error

## 🧪 Testing

Once the package is added:

1. Build and run the app
2. The app will automatically send a test signal `App.Launched` when it starts
3. Check your TelemetryDeck dashboard at https://telemetrydeck.com/
4. Navigate to **Explore → Recent Signals**
5. Enable **Test Mode** toggle (since you're running in DEBUG mode)
6. You should see the `App.Launched` signal appear within a few seconds

## 📝 Configuration

The TelemetryDeck App ID is already configured in `Config.xcconfig`:
```
TELEMETRYDECK_APP_ID = E0B9AA4E-C886-4840-87E9-C14D93DA9EFE
```

If you need to change it, edit `Config.xcconfig` and rebuild.

## 🎯 Test Signal

The test signal is sent in `MixDoctorApp.swift` in the `.task` modifier:

```swift
TelemetryDeck.signal("App.Launched", parameters: [
    "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
])
```

This signal includes the app version as a parameter, so you can verify it's working correctly in your TelemetryDeck dashboard.

## ✅ Next Steps

After verifying the test signal works:

1. You can add more signals throughout your app using:
   ```swift
   TelemetryDeck.signal("Your.Signal.Name", parameters: ["key": "value"])
   ```

2. See `TELEMETRYDECK_SETUP.md` for a complete event catalog and best practices

3. Remember: In DEBUG builds, signals are automatically tagged as "Test Signals" in TelemetryDeck
