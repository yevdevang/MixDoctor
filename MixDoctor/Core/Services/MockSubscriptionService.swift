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
    
    // MARK: - Properties
    var isProUser: Bool = false
    var remainingFreeAnalyses: Int = 3
    var hasReachedFreeLimit: Bool = false
    
    private let freeAnalysisLimit = 3
    
    // Mock packages for UI
    struct MockPackage {
        let id: String
        let title: String
        let price: String
        let period: String
    }
    
    var mockPackages: [MockPackage] = [
        MockPackage(id: "monthly", title: "Monthly", price: "$19.99", period: "per month"),
        MockPackage(id: "annual", title: "Annual", price: "$16.00", period: "per month, billed annually at $192")
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadState()
    }
    
    // MARK: - Public Methods
    
    func canPerformAnalysis() -> Bool {
        if isProUser {
            return true
        }
        return remainingFreeAnalyses > 0
    }
    
    func incrementAnalysisCount() {
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
        
        // 90% success rate to simulate real-world
        let success = Int.random(in: 1...10) <= 9
        
        if success {
            isProUser = true
            hasReachedFreeLimit = false
            saveState()
        }
        
        return success
    }
    
    func mockRestore() async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For testing, let's say 50% chance of having previous purchase
        let hasPurchase = Int.random(in: 1...10) <= 5
        
        if hasPurchase {
            isProUser = true
            hasReachedFreeLimit = false
            saveState()
        }
        
        return hasPurchase
    }
    
    func resetToFree() {
        isProUser = false
        remainingFreeAnalyses = freeAnalysisLimit
        hasReachedFreeLimit = false
        // Clear initialization flag to force clean reset
        UserDefaults.standard.removeObject(forKey: "mock_hasBeenInitialized")
        saveState()
        // Re-set initialization flag
        UserDefaults.standard.set(true, forKey: "mock_hasBeenInitialized")
        print("🔄 Reset to free user: \(freeAnalysisLimit) analyses available")
    }
    
    func mockCancelSubscription() async -> Bool {
        // Simulate network delay for cancellation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In real world, cancellation always succeeds
        // Subscription remains active until end of billing period
        // For testing, we'll downgrade immediately
        isProUser = false
        remainingFreeAnalyses = freeAnalysisLimit // Reset to free tier
        hasReachedFreeLimit = false
        saveState()
        
        return true
    }
    
    // MARK: - Helper Methods
    
    var subscriptionStatus: String {
        if isProUser {
            return "Pro"
        } else {
            return "Free (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        }
    }
    
    // MARK: - Private Methods
    
    private func saveState() {
        UserDefaults.standard.set(isProUser, forKey: "mock_isProUser")
        UserDefaults.standard.set(remainingFreeAnalyses, forKey: "mock_remainingAnalyses")
        UserDefaults.standard.set(hasReachedFreeLimit, forKey: "mock_hasReachedLimit")
    }
    
    private func loadState() {
        isProUser = UserDefaults.standard.bool(forKey: "mock_isProUser")
        
        // Check if this is first launch (never saved before)
        let hasBeenInitialized = UserDefaults.standard.bool(forKey: "mock_hasBeenInitialized")
        
        if !hasBeenInitialized {
            // First launch - set to full limit
            print("🆕 First launch detected - initializing with \(freeAnalysisLimit) analyses")
            remainingFreeAnalyses = freeAnalysisLimit
            UserDefaults.standard.set(true, forKey: "mock_hasBeenInitialized")
            saveState()
        } else {
            // Load saved value
            remainingFreeAnalyses = UserDefaults.standard.integer(forKey: "mock_remainingAnalyses")
            
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
                print("📊 Loaded saved state: \(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses remaining")
            }
        }
        
        hasReachedFreeLimit = UserDefaults.standard.bool(forKey: "mock_hasReachedLimit")
    }
}
