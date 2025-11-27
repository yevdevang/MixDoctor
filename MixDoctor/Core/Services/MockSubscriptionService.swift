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
    
    // Pro user monthly analysis tracking
    var remainingProAnalyses: Int = 50
    var proAnalysisResetDate: Date?
    
    private let freeAnalysisLimit = 3
    private let proMonthlyLimit = 50
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
        
        // Check if we need to reset monthly analysis count
        if let resetDate = proAnalysisResetDate {
            if Date() >= resetDate {
                // Reset for new month
                remainingProAnalyses = proMonthlyLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                saveState()
            }
        } else {
            // First time - set reset date to next month
            proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
            remainingProAnalyses = proMonthlyLimit
            saveState()
        }
    }
    
    // MARK: - Public Methods
    
    func canPerformAnalysis() -> Bool {
        // Check monthly reset for Pro users
        if isProUser {
            checkProAnalysisReset()
            return remainingProAnalyses > 0
        }
        // Trial users and free users have 3 analyses limit
        return remainingFreeAnalyses > 0
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
        
        // Free tier and trial users have 3 analyses limit
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
            // Simulate starting a trial
            isInTrialPeriod = true
            isProUser = false // Trial users treated as free tier
            hasReachedFreeLimit = false
            remainingFreeAnalyses = freeAnalysisLimit // Reset to 3 analyses for trial
            trialStartDate = Date() // Track when trial started
            saveState()
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
            isProUser = true // Paid subscriber gets 20 per month
            hasReachedFreeLimit = false
            remainingFreeAnalyses = 0 // Not used for Pro users
            remainingProAnalyses = proMonthlyLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
            trialStartDate = nil
            saveState()
        }
        
        return success
    }
    
    func mockConvertTrialToPaid() {
        // Simulate trial period ending and converting to paid subscription
        isInTrialPeriod = false
        isProUser = true // Now they get 50 analyses per month
        hasReachedFreeLimit = false
        remainingProAnalyses = proMonthlyLimit
        proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        saveState()
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
            remainingProAnalyses = proMonthlyLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
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
            return "Pro (\(remainingProAnalyses)/\(proMonthlyLimit) analyses this month)"
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
