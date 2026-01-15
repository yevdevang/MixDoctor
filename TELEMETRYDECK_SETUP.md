# TelemetryDeck Setup Guide

## Overview

This guide explains how to configure and use TelemetryDeck analytics in the MixDoctor app. TelemetryDeck is a privacy-focused analytics service that helps track user behavior, app statistics, and feature usage without collecting personally identifiable information.

## Configuration

### 1. Get Your TelemetryDeck App ID

1. Sign up for a free account at [telemetrydeck.com](https://telemetrydeck.com/)
2. Create a new app in your TelemetryDeck dashboard
3. Copy your App ID (format: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`)

### 2. Add App ID to Build Configuration

1. Copy `Config.xcconfig.template` to `Config.xcconfig` (if not already done)
2. Add your TelemetryDeck App ID to `Config.xcconfig`:

```xcconfig
TELEMETRYDECK_APP_ID = YOUR_TELEMETRYDECK_APP_ID_HERE
```

3. Rebuild the project in Xcode

### 3. Verify Configuration

The app will initialize TelemetryDeck automatically on launch. If the App ID is not configured, the app will show a fatal error with instructions.

## Event Catalog

### Dashboard Events

#### `dashboard_viewed`
Triggered when the dashboard screen is displayed.

**Properties:**
- `total_files` (string): Total number of audio files
- `analyzed_count` (string): Number of files with analysis results
- `issues_count` (string): Number of files with detected issues
- `average_score` (string): Average overall score (formatted to 1 decimal)

#### `dashboard_statistics_updated`
Triggered when dashboard statistics are recalculated.

**Properties:** Same as `dashboard_viewed`

#### `sync_icloud_clicked`
Triggered when user taps the iCloud sync button.

**Properties:** None

### Analysis Events

#### `analysis_started`
Triggered when user starts analyzing an audio file.

**Properties:**
- `file_name` (string): Sanitized filename (no extension, truncated if long)
- `file_duration` (string): File duration in seconds (formatted to 1 decimal)
- `is_pro_user` (string): "true" or "false"
- `is_trial_user` (string): "true" or "false"

#### `analysis_completed`
Triggered when analysis finishes successfully.

**Properties:**
- `file_name` (string): Sanitized filename
- `overall_score` (string): Overall analysis score (formatted to 1 decimal)
- `has_issues` (string): "true" or "false"
- `analysis_duration_seconds` (string): Time taken for analysis (formatted to 1 decimal)

#### `analysis_failed`
Triggered when analysis encounters an error.

**Properties:**
- `file_name` (string): Sanitized filename
- `error_message` (string): Sanitized error message (paths removed, truncated if long)

#### `analysis_count_updated`
Triggered when analysis count changes (from Settings or after analysis).

**Properties:**
- `total_analyses` (string): Total number of analyses performed
- `remaining_free` (string): Remaining free analyses
- `remaining_pro` (string): Remaining Pro analyses this month
- `is_pro_user` (string): "true" or "false"

### Subscription & Paywall Events

#### `paywall_viewed`
Triggered when paywall is displayed.

**Properties:**
- `source` (string): Where paywall was opened from (e.g., "dashboard", "settings", "analysis_limit")

#### `subscription_package_selected`
Triggered when user selects monthly or yearly package.

**Properties:**
- `package_type` (string): "monthly" or "yearly"
- `price` (string): Localized price string
- `has_trial` (string): "true" or "false"

#### `subscription_purchase_clicked`
Triggered when user taps the subscribe button.

**Properties:**
- `package_type` (string): "monthly" or "yearly"
- `price` (string): Localized price string
- `trial_days` (string): Number of trial days (typically "3")

#### `subscription_purchased`
Triggered when purchase completes successfully.

**Properties:**
- `package_type` (string): "monthly" or "yearly"
- `price` (string): Localized price string
- `is_trial` (string): "true" or "false"
- `trial_days_remaining` (string, optional): Days remaining in trial (if in trial)

#### `subscription_trial_started`
Triggered when free trial begins.

**Properties:**
- `package_type` (string): "monthly" or "yearly"
- `trial_days` (string): Number of trial days
- `expiration_date` (string): ISO8601 formatted expiration date

#### `subscription_trial_days_remaining`
Triggered on subscription status updates when user is in trial period.

**Properties:**
- `days_remaining` (string): Days remaining in trial
- `package_type` (string): "monthly" or "yearly"
- `will_renew` (string): "true" or "false"

#### `subscription_cancelled`
Triggered when subscription cancellation is detected (willRenew changes to false).

**Properties:**
- `package_type` (string): "monthly" or "yearly"
- `expires_at` (string): ISO8601 formatted expiration date
- `was_trial` (string): "true" or "false"

#### `subscription_restored`
Triggered when user restores purchases.

**Properties:**
- `has_active_subscription` (string): "true" or "false"
- `is_trial` (string): "true" or "false"

#### `subscription_status_refreshed`
Triggered when subscription status is manually refreshed.

**Properties:**
- `is_pro_user` (string): "true" or "false"
- `is_trial` (string): "true" or "false"
- `will_renew` (string): "true" or "false"

### Audio Playback Events

#### `audio_playback_started`
Triggered when user starts playing audio.

**Properties:**
- `file_name` (string): Sanitized filename
- `file_duration` (string): File duration in seconds (formatted to 1 decimal)
- `has_analysis` (string): "true" or "false"

#### `audio_playback_paused`
Triggered when playback is paused.

**Properties:**
- `file_name` (string): Sanitized filename
- `playback_position_seconds` (string): Current playback position (formatted to 1 decimal)

#### `audio_playback_stopped`
Triggered when playback stops (user action).

**Properties:**
- `file_name` (string): Sanitized filename
- `total_playback_duration_seconds` (string): Total time played (formatted to 1 decimal)

#### `audio_playback_completed`
Triggered when track finishes playing naturally.

**Properties:**
- `file_name` (string): Sanitized filename
- `total_duration_seconds` (string): Full track duration (formatted to 1 decimal)

### File Import Events

#### `file_import_started`
Triggered when import process begins.

**Properties:**
- `file_count` (string): Number of files being imported
- `source` (string): Import source - "picker", "drag_drop", or "icloud_scan"

#### `file_import_completed`
Triggered when file is successfully imported.

**Properties:**
- `file_name` (string): Sanitized filename
- `file_size_mb` (string): File size in MB (formatted to 2 decimals)
- `duration` (string): File duration in seconds (formatted to 1 decimal)
- `format` (string): File format (uppercase, e.g., "WAV", "MP3")
- `source` (string): Import source

#### `file_import_failed`
Triggered when import fails.

**Properties:**
- `file_name` (string): Sanitized filename
- `error_type` (string): Error type (e.g., "iCloudDownloadFailed", "duplicateFile", "unknown")
- `source` (string): Import source

#### `file_deleted`
Triggered when user deletes a file.

**Properties:**
- `file_name` (string): Sanitized filename
- `had_analysis` (string): "true" or "false"

### User Interaction Events

#### `button_clicked`
Generic button click tracking.

**Properties:**
- `button_name` (string): Button identifier (e.g., "browse_files", "import_more", "play_audio", "analyze_now")
- `screen` (string): Screen name (e.g., "import", "results", "dashboard")
- `context` (string, optional): Additional context (e.g., filename for play button)

#### `navigation_occurred`
Track screen navigation.

**Properties:**
- `from_screen` (string): Previous screen name
- `to_screen` (string): New screen name

#### `settings_viewed`
Triggered when settings screen is opened.

**Properties:** None

#### `settings_refresh_subscription_clicked`
Triggered when user refreshes subscription status.

**Properties:** None

#### `settings_clear_cache_clicked`
Triggered when user clears cache.

**Properties:** None

## Privacy & Data Handling

### Privacy Features

- **No PII Collection**: File names are sanitized (extensions removed, truncated)
- **Anonymous Tracking**: No user identification required
- **Error Sanitization**: File paths and sensitive information removed from error messages
- **Opt-in by Default**: TelemetryDeck only tracks when initialized

### Data Sanitization

The `TelemetryService` automatically sanitizes:
- **File Names**: Extensions removed, truncated to 50 characters
- **Error Messages**: File paths replaced with `[path]`, truncated to 200 characters
- **User State**: Only boolean flags (is_pro_user, is_trial_user) - no user IDs

## Testing

### Testing Events

1. **Dashboard**: Open app, view dashboard, check statistics update
2. **Analysis**: Start analysis, verify started/completed events
3. **Paywall**: Open paywall, select package, attempt purchase
4. **Playback**: Play audio, pause, stop, let complete
5. **Import**: Import files via picker and drag-drop
6. **Navigation**: Switch between tabs/screens

### Verifying Events

1. Check TelemetryDeck dashboard for incoming events
2. Events appear within a few seconds of being triggered
3. Verify event properties are correctly formatted
4. Check that no PII is included in events

### Debug Mode

TelemetryDeck events are queued and sent asynchronously. In development, you can check the TelemetryDeck dashboard to verify events are being received.

## Troubleshooting

### Events Not Appearing

1. **Check App ID**: Verify `TELEMETRYDECK_APP_ID` is set in `Config.xcconfig`
2. **Check Initialization**: Ensure `TelemetryService.shared.initialize()` is called in `MixDoctorApp.swift`
3. **Check Network**: TelemetryDeck requires internet connection (events are queued offline)
4. **Check Dashboard**: Events may take a few seconds to appear in TelemetryDeck dashboard

### Common Issues

- **Fatal Error on Launch**: App ID not configured - add to `Config.xcconfig`
- **No Events**: Check that TelemetryService is initialized before events are tracked
- **Missing Properties**: Verify event tracking calls include all required properties

## Event Frequency

Some events are tracked more frequently than others:

- **High Frequency**: `dashboard_statistics_updated`, `audio_playback_paused`
- **Medium Frequency**: `navigation_occurred`, `button_clicked`
- **Low Frequency**: `subscription_purchased`, `analysis_completed`, `file_import_completed`

TelemetryDeck automatically handles rate limiting and batching, so high-frequency events won't cause performance issues.

## Best Practices

1. **Don't Track Sensitive Data**: Never include user emails, IDs, or file paths
2. **Use Consistent Property Names**: Follow snake_case convention
3. **Include Context**: Add relevant context (screen, source) to events
4. **Track User State**: Include subscription status in relevant events
5. **Test Events**: Verify events appear correctly in TelemetryDeck dashboard

## Support

For TelemetryDeck-specific issues:
- Documentation: [docs.telemetrydeck.com](https://docs.telemetrydeck.com/)
- Support: Contact TelemetryDeck support through their dashboard

For app-specific tracking issues:
- Check `TelemetryService.swift` for event definitions
- Verify event calls are on MainActor when needed
- Check console logs for initialization errors
