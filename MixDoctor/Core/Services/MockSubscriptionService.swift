//
//  MockSubscriptionService.swift
//  MixDoctor
//
//  Mock subscription service for testing without App Store Connect
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class MockSubscriptionService {
    static let shared = MockSubscriptionService()
    
    // Use iCloud Key-Value Store for cross-device sync
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    // MARK: - Properties
    var isProUser: Bool = false
    var isInTrialPeriod: Bool = false
    var remainingFreeAnalyses: Int = 4
    var hasReachedFreeLimit: Bool = false
    var trialStartDate: Date?
    
    // Pro user analysis tracking
    var remainingProAnalyses: Int = 50
    var proAnalysisResetDate: Date?
    var isWeeklySubscriber: Bool = false
    var hasLifetimeAccess: Bool = false

    private let freeAnalysisLimit = 4
    private let proMonthlyLimit = 50   // Monthly & Annual subscribers
    private let weeklyProLimit = 10    // Weekly subscribers
    private let trialDurationDays = 7

    var currentProLimit: Int {
        isWeeklySubscriber ? weeklyProLimit : proMonthlyLimit
    }
    
    // Mock packages for UI
    struct MockPackage {
        let id: String
        let title: String
        let price: String
        let period: String
    }
    
    var mockPackages: [MockPackage] = [
        MockPackage(id: "annual", title: "Annual", price: "$3.99", period: "per month, billed annually at $47.88"),
        MockPackage(id: "monthly", title: "Monthly", price: "$5.99", period: "per month"),
        MockPackage(id: "weekly", title: "Weekly", price: "$2.99", period: "per week")
    ]

    // Placeholder price — real price is set in App Store Connect
    var lifetimePackage = MockPackage(id: "lifetime", title: "Lifetime Pro", price: "$49.99", period: "one-time")
    
    // MARK: - Initialization
    
    private init() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        
        // Sync with iCloud first
        cloudStore.synchronize()
        
        loadState()
        checkTrialExpiration()
        checkProAnalysisReset()
    }
    
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        loadState()
    }
    
    private func checkTrialExpiration() {
        // Check if trial has expired and auto-convert to paid
        guard isInTrialPeriod, let startDate = trialStartDate else { return }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        
        if daysSinceStart >= trialDurationDays {
            mockConvertTrialToPaid()
        } else {
        }
    }
    
    private func checkProAnalysisReset() {
        guard isProUser else { return }

        let resetComponent: Calendar.Component = isWeeklySubscriber ? .weekOfYear : .month

        // Check if we need to reset analysis count
        if let resetDate = proAnalysisResetDate {
            if Date() >= resetDate {
                remainingProAnalyses = currentProLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: resetComponent, value: 1, to: Date())
                saveState()
            }
        } else {
            // First time - set reset date
            proAnalysisResetDate = Calendar.current.date(byAdding: resetComponent, value: 1, to: Date())
            remainingProAnalyses = currentProLimit
            saveState()
        }
    }
    
    // MARK: - Public Methods
    
    func canPerformAnalysis() -> Bool {
        // Lifetime purchasers get unlimited analysis when it will actually run on-device
        // (costs nothing). If their device can't run the local model, fall through to
        // their underlying free/Pro quota instead of unmetered Claude usage.
        if hasLifetimeAccess && isLocalModelUsable {
            return true
        }
        // Check monthly reset for Pro users
        if isProUser {
            checkProAnalysisReset()
            return remainingProAnalyses > 0
        }
        // Trial users and free users have 4 analyses limit
        return remainingFreeAnalyses > 0
    }

    /// Whether on-device analysis can actually run right now (OS + Apple Intelligence availability).
    private var isLocalModelUsable: Bool {
        if #available(iOS 26.0, *) {
            return LocalModelAnalysisService.isAvailable
        }
        return false
    }
    
    func incrementAnalysisCount() {
        // Pro users have monthly limit of 20
        if isProUser {
            checkProAnalysisReset()
            if remainingProAnalyses > 0 {
                remainingProAnalyses -= 1
                saveState()
            }
            return
        }
        
        // Free tier and trial users have 4 analyses limit
        if remainingFreeAnalyses > 0 {
            remainingFreeAnalyses -= 1
            hasReachedFreeLimit = remainingFreeAnalyses <= 0
            saveState()
        } else {
        }
    }
    
    func mockPurchase(packageId: String) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // 100% success rate for testing (change to 90 if you want to test failures)
        let success = true // Int.random(in: 1...10) <= 9

        if success {
            // Set subscription type based on package
            isWeeklySubscriber = (packageId == "weekly")
            let resetComponent: Calendar.Component = isWeeklySubscriber ? .weekOfYear : .month

            // Go straight to paid subscription (no trial)
            isInTrialPeriod = false
            isProUser = true
            hasReachedFreeLimit = false
            remainingFreeAnalyses = 0 // Not used for Pro users
            remainingProAnalyses = currentProLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: resetComponent, value: 1, to: Date())
            trialStartDate = nil
            saveState()
        }

        return success
    }
    
    func mockPurchaseLifetime() async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        hasLifetimeAccess = true
        saveState()
        return true
    }

    func mockPurchaseSkipTrial(packageId: String) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        let success = true

        if success {
            isWeeklySubscriber = (packageId == "weekly")
            let resetComponent: Calendar.Component = isWeeklySubscriber ? .weekOfYear : .month

            isInTrialPeriod = false
            isProUser = true
            hasReachedFreeLimit = false
            remainingFreeAnalyses = 0
            remainingProAnalyses = currentProLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: resetComponent, value: 1, to: Date())
            trialStartDate = nil
            saveState()
        }

        return success
    }

    func mockConvertTrialToPaid() {
        let resetComponent: Calendar.Component = isWeeklySubscriber ? .weekOfYear : .month
        isInTrialPeriod = false
        isProUser = true
        hasReachedFreeLimit = false
        remainingProAnalyses = currentProLimit
        proAnalysisResetDate = Calendar.current.date(byAdding: resetComponent, value: 1, to: Date())
        saveState()
    }

    func mockRestore() async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // For testing, let's say 50% chance of having previous purchase
        let hasPurchase = Int.random(in: 1...10) <= 5

        if hasPurchase {
            // Restore as paid subscriber (default to monthly if unknown)
            isInTrialPeriod = false
            isProUser = true
            hasReachedFreeLimit = false
            remainingProAnalyses = currentProLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: Date())
            saveState()
        }

        return hasPurchase
    }
    
    func resetToFree() {
        isProUser = false
        isInTrialPeriod = false
        remainingFreeAnalyses = freeAnalysisLimit
        hasReachedFreeLimit = false
        // Clear initialization flag to force clean reset
        cloudStore.removeObject(forKey: "mock_hasBeenInitialized")
        saveState()
        // Re-set initialization flag
        cloudStore.set(true, forKey: "mock_hasBeenInitialized")
        cloudStore.synchronize()
    }
    
    func mockCancelSubscription() async -> Bool {
        // Simulate network delay for cancellation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        
        // In real world, cancellation always succeeds
        // Subscription remains active until end of billing period
        // For testing, we'll downgrade immediately
        isProUser = false
        isInTrialPeriod = false // Cancel trial too if active
        remainingFreeAnalyses = freeAnalysisLimit // Reset to free tier
        hasReachedFreeLimit = false
        trialStartDate = nil // Clear trial start date
        saveState()
        
        
        return true
    }
    
    // MARK: - Helper Methods
    
    func refreshSubscriptionStatus() {
        cloudStore.synchronize()
        loadState()
    }
    
    var subscriptionStatus: String {
        if isProUser {
            let periodLabel = isWeeklySubscriber ? "week" : "month"
            let used = currentProLimit - remainingProAnalyses
            return "Pro (\(used)/\(currentProLimit) analyses this \(periodLabel))"
        } else if hasLifetimeAccess {
            return "Lifetime Pro (Unlimited on-device analysis)"
        } else {
            let used = freeAnalysisLimit - remainingFreeAnalyses
            return "Free (\(used)/\(freeAnalysisLimit) analyses)"
        }
    }
    
    // MARK: - Private Methods
    
    private func saveState() {
        // Save to iCloud Key-Value Store for cross-device sync
        cloudStore.set(isProUser, forKey: "mock_isProUser")
        cloudStore.set(isInTrialPeriod, forKey: "mock_isInTrial")
        cloudStore.set(hasLifetimeAccess, forKey: "mock_hasLifetimeAccess")
        cloudStore.set(Int64(remainingFreeAnalyses), forKey: "mock_remainingAnalyses")
        cloudStore.set(hasReachedFreeLimit, forKey: "mock_hasReachedLimit")
        cloudStore.set(Int64(remainingProAnalyses), forKey: "mock_remainingProAnalyses")
        if let trialStartDate = trialStartDate {
            cloudStore.set(trialStartDate, forKey: "mock_trialStartDate")
        }
        if let proAnalysisResetDate = proAnalysisResetDate {
            cloudStore.set(proAnalysisResetDate, forKey: "mock_proAnalysisResetDate")
        }
        
        // Force sync to iCloud
        cloudStore.synchronize()
        
    }
    
    private func loadState() {
        isProUser = cloudStore.bool(forKey: "mock_isProUser")
        isInTrialPeriod = cloudStore.bool(forKey: "mock_isInTrial")
        hasLifetimeAccess = cloudStore.bool(forKey: "mock_hasLifetimeAccess")
        trialStartDate = cloudStore.object(forKey: "mock_trialStartDate") as? Date
        proAnalysisResetDate = cloudStore.object(forKey: "mock_proAnalysisResetDate") as? Date
        
        // Check if this is first launch (never saved before)
        let hasBeenInitialized = cloudStore.bool(forKey: "mock_hasBeenInitialized")
        
        if !hasBeenInitialized {
            // First launch - set to full limit
            remainingFreeAnalyses = freeAnalysisLimit
            cloudStore.set(true, forKey: "mock_hasBeenInitialized")
            saveState()
        } else {
            // Load saved value from iCloud
            let savedValue = cloudStore.longLong(forKey: "mock_remainingAnalyses")
            remainingFreeAnalyses = Int(savedValue)
            
            // Load Pro analyses count
            let savedProValue = cloudStore.longLong(forKey: "mock_remainingProAnalyses")
            remainingProAnalyses = Int(savedProValue)
            
            // Handle edge cases
            if remainingFreeAnalyses == 0 && !isProUser {
                // User used all analyses - keep at 0
            } else if remainingFreeAnalyses > freeAnalysisLimit {
                // Cap at current limit if migrating from higher limit (e.g., 5 -> 3)
                remainingFreeAnalyses = freeAnalysisLimit
                saveState()
            } else {
            }
        }
        
        hasReachedFreeLimit = cloudStore.bool(forKey: "mock_hasReachedLimit")
        
    }
}
