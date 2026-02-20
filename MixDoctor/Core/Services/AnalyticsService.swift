//
//  AnalyticsService.swift
//  MixDoctor
//
//  Centralized analytics service — only logs events in production (Release) builds.
//  In DEBUG builds, all calls are no-ops to keep console clean and avoid polluting analytics data.
//

import Foundation
#if !DEBUG
import FirebaseAnalytics
#endif

enum AnalyticsEvent: String {
    // App lifecycle
    case appLaunched = "app_launched"

    // Onboarding
    case onboardingStarted = "onboarding_started"
    case onboardingScreenViewed = "onboarding_screen_viewed"
    case onboardingSkipped = "onboarding_skipped"
    case onboardingCompleted = "onboarding_completed"

    // Dashboard
    case dashboardViewed = "dashboard_viewed"

    // File management
    case fileImported = "file_imported"
    case fileDeleted = "file_deleted"
    case allFilesDeleted = "all_files_deleted"

    // Analysis
    case analysisStarted = "analysis_started"
    case analysisCompleted = "analysis_completed"
    case analysisFailed = "analysis_failed"
    case freeAnalysisCount = "free_analysis_count"

    // Paywall & subscription
    case paywallShown = "paywall_shown"
    case paywallDismissed = "paywall_dismissed"
    case upgradeButtonTapped = "upgrade_button_tapped"
    case trialStarted = "trial_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case restoreCompleted = "restore_completed"
    case restoreFailed = "restore_failed"

    // Settings
    case settingsViewed = "settings_viewed"
    case iCloudSyncToggled = "icloud_sync_toggled"
    case themeChanged = "theme_changed"
}

enum AnalyticsService {
    /// Log an analytics event. No-op in DEBUG builds.
    static func log(_ event: AnalyticsEvent, parameters: [String: String]? = nil) {
        #if !DEBUG
        Analytics.logEvent(event.rawValue, parameters: parameters)
        #endif
    }
}
