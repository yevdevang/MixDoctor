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
    var remainingFreeAnalyses: Int = 5
    var hasReachedFreeLimit: Bool = false
    
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
        
        if remainingFreeAnalyses > 0 {
            remainingFreeAnalyses -= 1
            hasReachedFreeLimit = remainingFreeAnalyses <= 0
            saveState()
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
        remainingFreeAnalyses = 5
        hasReachedFreeLimit = false
        saveState()
    }
    
    func mockCancelSubscription() async -> Bool {
        // Simulate network delay for cancellation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In real world, cancellation always succeeds
        // Subscription remains active until end of billing period
        // For testing, we'll downgrade immediately
        isProUser = false
        remainingFreeAnalyses = 5 // Reset to free tier
        hasReachedFreeLimit = false
        saveState()
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func saveState() {
        UserDefaults.standard.set(isProUser, forKey: "mock_isProUser")
        UserDefaults.standard.set(remainingFreeAnalyses, forKey: "mock_remainingAnalyses")
        UserDefaults.standard.set(hasReachedFreeLimit, forKey: "mock_hasReachedLimit")
    }
    
    private func loadState() {
        isProUser = UserDefaults.standard.bool(forKey: "mock_isProUser")
        remainingFreeAnalyses = UserDefaults.standard.integer(forKey: "mock_remainingAnalyses")
        if remainingFreeAnalyses == 0 && !isProUser {
            remainingFreeAnalyses = 5 // Default to 5 on first launch
        }
        hasReachedFreeLimit = UserDefaults.standard.bool(forKey: "mock_hasReachedLimit")
    }
}
