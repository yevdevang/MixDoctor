//
//  RatingService.swift
//  MixDoctor
//
//  Service for managing app rating requests based on user type and usage
//

import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class RatingService: ObservableObject {
    static let shared = RatingService()
    
    // Published property for triggering rating UI
    @Published var shouldTriggerRating: Bool = false
    
    // UserDefaults keys
    private let hasShownRatingKey = "hasShownRatingPrompt"
    private let freeUserRatingShownKey = "freeUserRatingShown"
    private let proUserRatingCountKey = "proUserRatingCount"
    private let lastProRatingDateKey = "lastProRatingDate"
    private let trialUserRatingShownKey = "trialUserRatingShown"
    
    private init() {}
    
    // MARK: - Check if Rating Should Be Shown
    
    /// Determines if rating prompt should be shown based on user type and analysis count
    /// - Parameters:
    ///   - analysisCount: Total number of analyses performed
    ///   - isProUser: Whether user has Pro subscription
    ///   - isInTrialPeriod: Whether user is in trial period
    /// - Returns: True if rating prompt should be shown
    func shouldShowRating(analysisCount: Int, isProUser: Bool, isInTrialPeriod: Bool) -> Bool {
        if isInTrialPeriod {
            return shouldShowForTrialUser(analysisCount: analysisCount)
        } else if isProUser {
            return shouldShowForProUser(analysisCount: analysisCount)
        } else {
            return shouldShowForFreeUser(analysisCount: analysisCount)
        }
    }
    
    // MARK: - Free User Strategy
    
    /// Free User: After 2nd analysis, once during free usage
    private func shouldShowForFreeUser(analysisCount: Int) -> Bool {
        let hasShown = UserDefaults.standard.bool(forKey: freeUserRatingShownKey)
        
        // Show after 2nd analysis and only once
        if analysisCount == 2 && !hasShown {
            return true
        }
        
        return false
    }
    
    // MARK: - Pro User Strategy
    
    /// Pro User: After 5-8 analyses, 1x per month
    private func shouldShowForProUser(analysisCount: Int) -> Bool {
        // Check if we're within the range (5-8 analyses)
        guard analysisCount >= 5 && analysisCount <= 8 else {
            return false
        }
        
        // Check if we've shown it this month
        if let lastRatingDate = UserDefaults.standard.object(forKey: lastProRatingDateKey) as? Date {
            let calendar = Calendar.current
            let now = Date()
            
            // If last rating was shown this month, don't show again
            if calendar.isDate(lastRatingDate, equalTo: now, toGranularity: .month) {
                return false
            }
        }
        
        // Show at analysis 6 (middle of 5-8 range) if we haven't shown this month
        return analysisCount == 6
    }
    
    // MARK: - Trial User Strategy
    
    /// Trial User: After 2nd analysis, only once
    private func shouldShowForTrialUser(analysisCount: Int) -> Bool {
        let hasShown = UserDefaults.standard.bool(forKey: trialUserRatingShownKey)
        
        // Show after 2nd analysis and only once
        if analysisCount == 2 && !hasShown {
            return true
        }
        
        return false
    }
    
    // MARK: - Request Rating
    
    /// Request app rating - call this to trigger the rating UI
    func requestRating() {
        print("⭐ Requesting app rating")
        shouldTriggerRating = true
        
        // Reset after a delay
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            shouldTriggerRating = false
        }
    }
    
    // MARK: - Mark as Shown
    
    /// Mark that rating has been shown for the current user type
    /// - Parameters:
    ///   - isProUser: Whether user is Pro
    ///   - isInTrialPeriod: Whether user is in trial
    func markRatingAsShown(isProUser: Bool, isInTrialPeriod: Bool) {
        UserDefaults.standard.set(true, forKey: hasShownRatingKey)
        
        if isInTrialPeriod {
            UserDefaults.standard.set(true, forKey: trialUserRatingShownKey)
            print("✅ Marked rating as shown for Trial user")
        } else if isProUser {
            let count = UserDefaults.standard.integer(forKey: proUserRatingCountKey)
            UserDefaults.standard.set(count + 1, forKey: proUserRatingCountKey)
            UserDefaults.standard.set(Date(), forKey: lastProRatingDateKey)
            print("✅ Marked rating as shown for Pro user (monthly)")
        } else {
            UserDefaults.standard.set(true, forKey: freeUserRatingShownKey)
            print("✅ Marked rating as shown for Free user (once)")
        }
    }
    
    // MARK: - Reset (for testing)
    
    /// Reset all rating tracking (for testing purposes)
    func resetAllRatingTracking() {
        UserDefaults.standard.removeObject(forKey: hasShownRatingKey)
        UserDefaults.standard.removeObject(forKey: freeUserRatingShownKey)
        UserDefaults.standard.removeObject(forKey: proUserRatingCountKey)
        UserDefaults.standard.removeObject(forKey: lastProRatingDateKey)
        UserDefaults.standard.removeObject(forKey: trialUserRatingShownKey)
        print("🔄 Reset all rating tracking")
    }
    
    // MARK: - Test Mode
    
    /// Force show rating prompt for testing - bypasses all checks
    func forceShowRatingForTesting() {
        print("🧪 TEST MODE: Forcing rating prompt")
        requestRating()
    }
}
