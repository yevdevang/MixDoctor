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
    var remainingFreeAnalyses: Int = 3
    var hasReachedFreeLimit: Bool = false
    var trialStartDate: Date?
    
    private let freeAnalysisLimit = 3
    private let trialDurationDays = 7
    
    // Mock packages for UI
    struct MockPackage {
        let id: String
        let title: String
        let price: String
        let period: String
    }
    
    var mockPackages: [MockPackage] = [
        MockPackage(id: "monthly", title: "Monthly", price: "$5.99", period: "per month"),
        MockPackage(id: "annual", title: "Annual", price: "$3.99", period: "per month, billed annually at $47.88")
    ]
    
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
    }
    
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        print("☁️ Subscription state changed in iCloud - syncing...")
        loadState()
    }
    
    private func checkTrialExpiration() {
        // Check if trial has expired and auto-convert to paid
        guard isInTrialPeriod, let startDate = trialStartDate else { return }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        
        if daysSinceStart >= trialDurationDays {
            print("⏰ Trial period expired after \(daysSinceStart) days - converting to paid")
            mockConvertTrialToPaid()
        } else {
            print("📅 Trial day \(daysSinceStart + 1) of \(trialDurationDays)")
        }
    }
    
    // MARK: - Public Methods
    
    func canPerformAnalysis() -> Bool {
        // Paid subscribers get unlimited
        if isProUser {
            return true
        }
        // Trial users and free users have 3 analyses limit
        return remainingFreeAnalyses > 0
    }
    
    func incrementAnalysisCount() {
        // Only increment for non-paid users (free tier and trial users)
        guard !isProUser else { return }
        
        print("📊 Incrementing analysis count:")
        print("   Before: \(remainingFreeAnalyses)")
        
        if remainingFreeAnalyses > 0 {
            remainingFreeAnalyses -= 1
            hasReachedFreeLimit = remainingFreeAnalyses <= 0
            saveState()
            print("   After: \(remainingFreeAnalyses)")
            print("   Has reached limit: \(hasReachedFreeLimit)")
        } else {
            print("   ⚠️ Already at 0, not decrementing")
        }
    }
    
    func mockPurchase(packageId: String) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // 100% success rate for testing (change to 90 if you want to test failures)
        let success = true // Int.random(in: 1...10) <= 9
        
        if success {
            // Simulate starting a trial
            isInTrialPeriod = true
            isProUser = false // Trial users treated as free tier
            hasReachedFreeLimit = false
            remainingFreeAnalyses = freeAnalysisLimit // Reset to 3 analyses for trial
            trialStartDate = Date() // Track when trial started
            saveState()
            print("✅ Mock trial started successfully")
            print("   Package: \(packageId)")
            print("   Trial status: \(isInTrialPeriod)")
            print("   Pro status: \(isProUser)")
            print("   Analyses available: \(remainingFreeAnalyses)")
            print("   Trial will expire in \(trialDurationDays) days")
        }
        
        return success
    }
    
    func mockPurchaseSkipTrial(packageId: String) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let success = true
        
        if success {
            // Skip trial, go straight to paid subscription
            isInTrialPeriod = false
            isProUser = true // Paid subscriber gets unlimited
            hasReachedFreeLimit = false
            remainingFreeAnalyses = 0 // Not used for Pro users
            trialStartDate = nil
            saveState()
            print("✅ Mock paid subscription activated (skipped trial)")
            print("   Package: \(packageId)")
            print("   Trial status: \(isInTrialPeriod)")
            print("   Pro status: \(isProUser)")
            print("   Analyses: UNLIMITED")
        }
        
        return success
    }
    
    func mockConvertTrialToPaid() {
        // Simulate trial period ending and converting to paid subscription
        isInTrialPeriod = false
        isProUser = true // Now they get unlimited
        hasReachedFreeLimit = false
        saveState()
        print("✅ Mock trial converted to paid subscription - unlimited analyses")
    }
    
    func mockRestore() async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For testing, let's say 50% chance of having previous purchase
        let hasPurchase = Int.random(in: 1...10) <= 5
        
        if hasPurchase {
            // Restore as paid subscriber (not trial)
            isInTrialPeriod = false
            isProUser = true
            hasReachedFreeLimit = false
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
        print("🔄 Reset to free user: \(freeAnalysisLimit) analyses available")
    }
    
    func mockCancelSubscription() async -> Bool {
        // Simulate network delay for cancellation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        print("🚫 Cancelling subscription...")
        
        // In real world, cancellation always succeeds
        // Subscription remains active until end of billing period
        // For testing, we'll downgrade immediately
        isProUser = false
        isInTrialPeriod = false // Cancel trial too if active
        remainingFreeAnalyses = freeAnalysisLimit // Reset to free tier
        hasReachedFreeLimit = false
        trialStartDate = nil // Clear trial start date
        saveState()
        
        print("✅ Subscription cancelled - returned to free tier with \(freeAnalysisLimit) analyses")
        print("   Status synced to iCloud for all devices")
        
        return true
    }
    
    // MARK: - Helper Methods
    
    func refreshSubscriptionStatus() {
        print("🔄 Manually refreshing subscription from iCloud...")
        cloudStore.synchronize()
        loadState()
    }
    
    var subscriptionStatus: String {
        if isProUser {
            return "Pro (Unlimited)"
        } else if isInTrialPeriod {
            return "Trial (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        } else {
            return "Free (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        }
    }
    
    // MARK: - Private Methods
    
    private func saveState() {
        // Save to iCloud Key-Value Store for cross-device sync
        cloudStore.set(isProUser, forKey: "mock_isProUser")
        cloudStore.set(isInTrialPeriod, forKey: "mock_isInTrial")
        cloudStore.set(Int64(remainingFreeAnalyses), forKey: "mock_remainingAnalyses")
        cloudStore.set(hasReachedFreeLimit, forKey: "mock_hasReachedLimit")
        if let trialStartDate = trialStartDate {
            cloudStore.set(trialStartDate, forKey: "mock_trialStartDate")
        }
        
        // Force sync to iCloud
        cloudStore.synchronize()
        
        print("💾 Saved subscription state to iCloud")
        print("   Pro: \(isProUser), Trial: \(isInTrialPeriod), Analyses: \(remainingFreeAnalyses)")
    }
    
    private func loadState() {
        isProUser = cloudStore.bool(forKey: "mock_isProUser")
        isInTrialPeriod = cloudStore.bool(forKey: "mock_isInTrial")
        trialStartDate = cloudStore.object(forKey: "mock_trialStartDate") as? Date
        
        // Check if this is first launch (never saved before)
        let hasBeenInitialized = cloudStore.bool(forKey: "mock_hasBeenInitialized")
        
        if !hasBeenInitialized {
            // First launch - set to full limit
            print("🆕 First launch detected - initializing with \(freeAnalysisLimit) analyses")
            remainingFreeAnalyses = freeAnalysisLimit
            cloudStore.set(true, forKey: "mock_hasBeenInitialized")
            saveState()
        } else {
            // Load saved value from iCloud
            let savedValue = cloudStore.longLong(forKey: "mock_remainingAnalyses")
            remainingFreeAnalyses = Int(savedValue)
            
            // Handle edge cases
            if remainingFreeAnalyses == 0 && !isProUser {
                // User used all analyses - keep at 0
                print("⚠️ User has used all \(freeAnalysisLimit) free analyses")
            } else if remainingFreeAnalyses > freeAnalysisLimit {
                // Cap at current limit if migrating from higher limit (e.g., 5 -> 3)
                print("📊 Capping analyses from \(remainingFreeAnalyses) to \(freeAnalysisLimit)")
                remainingFreeAnalyses = freeAnalysisLimit
                saveState()
            } else {
                print("📊 Loaded saved state from iCloud: \(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses remaining")
            }
        }
        
        hasReachedFreeLimit = cloudStore.bool(forKey: "mock_hasReachedLimit")
        
        print("☁️ Loaded subscription from iCloud")
        print("   Pro: \(isProUser), Trial: \(isInTrialPeriod), Analyses: \(remainingFreeAnalyses)")
    }
}
