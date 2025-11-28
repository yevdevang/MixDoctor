//
//  SubscriptionService.swift
//  MixDoctor
//
//  RevenueCat subscription management service
//

import Foundation
import RevenueCat
import SwiftUI

@MainActor
@Observable
public final class SubscriptionService {
    public static let shared = SubscriptionService()
    
    // MARK: - Properties
    var isProUser: Bool = false
    var isInTrialPeriod: Bool = false
    var currentOffering: Offering?
    var customerInfo: CustomerInfo?
     
    // Free tier limits
    private let freeAnalysisLimit = 3
    private let monthlyResetKey = "lastMonthlyReset"
    private let analysisCountKey = "analysisCount"
    
    // Pro tier limits (50 analyses per month)
    private let proMonthlyLimit = 50
    private let proAnalysisCountKey = "proAnalysisCount"
    private let proResetDateKey = "proAnalysisResetDate"
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    var remainingProAnalyses: Int = 50
    var proAnalysisResetDate: Date?
    
    var remainingFreeAnalyses: Int {
        let count = UserDefaults.standard.integer(forKey: analysisCountKey)
        return max(0, freeAnalysisLimit - count)
    }
    
    var hasReachedFreeLimit: Bool {
        !isProUser && remainingFreeAnalyses <= 0
    }
    
    // MARK: - Initialization
    
    private init() {
        loadProAnalysisState()
        configureRevenueCat()
        checkMonthlyReset()
        checkProAnalysisReset()
    }
    
    private func configureRevenueCat() {
        // Configure RevenueCat with your API key
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        
        // Set up listener for customer info updates
        Task {
            await updateCustomerInfo()
        }
    }
    
    // MARK: - Customer Info
    
    func updateCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            
            // Check if user has active pro entitlement
            let hasProEntitlement = info.entitlements["pro"]?.isActive == true
            
            // Check if currently in trial period
            if let proEntitlement = info.entitlements["pro"],
               proEntitlement.isActive,
           proEntitlement.periodType == .trial {
            isInTrialPeriod = true
            isProUser = false // Treat trial users as free tier for analysis limits
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Initialize Pro analysis limit if becoming Pro for first time
            if remainingProAnalyses == 0 && proAnalysisResetDate == nil {
                remainingProAnalyses = proMonthlyLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                saveProAnalysisState()
            }
        } else {
            isInTrialPeriod = false
            isProUser = false
        }        } catch {
        }
    }
    
    // MARK: - Offerings
    
    func fetchOfferings() async throws {
        let offerings = try await Purchases.shared.offerings()
        currentOffering = offerings.current
    }
    
    // MARK: - Purchase
    
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        
        // Check if user has active pro entitlement
        let hasProEntitlement = result.customerInfo.entitlements["pro"]?.isActive == true
        
        // Check if currently in trial period
        if let proEntitlement = result.customerInfo.entitlements["pro"],
           proEntitlement.isActive,
           proEntitlement.periodType == .trial {
            isInTrialPeriod = true
            isProUser = false // Treat trial users as free tier for analysis limits
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Initialize Pro analysis limit for new purchase
            remainingProAnalyses = proMonthlyLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
            saveProAnalysisState()
        }
        
        return result.customerInfo
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        
        // Check if user has active pro entitlement
        let hasProEntitlement = info.entitlements["pro"]?.isActive == true
        
        // Check if currently in trial period
        if let proEntitlement = info.entitlements["pro"],
           proEntitlement.isActive,
           proEntitlement.periodType == .trial {
            isInTrialPeriod = true
            isProUser = false // Treat trial users as free tier for analysis limits
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Initialize Pro analysis limit when restoring
            if remainingProAnalyses == 0 && proAnalysisResetDate == nil {
                remainingProAnalyses = proMonthlyLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                saveProAnalysisState()
            }
        } else {
            // No active subscription found
            isInTrialPeriod = false
            isProUser = false
        }
    }
    
    // MARK: - Usage Tracking
    
    func incrementAnalysisCount() {
        if isProUser {
            // Decrement Pro monthly limit
            remainingProAnalyses = max(0, remainingProAnalyses - 1)
            saveProAnalysisState()
        } else {
            // Increment free tier count
            let currentCount = UserDefaults.standard.integer(forKey: analysisCountKey)
            UserDefaults.standard.set(currentCount + 1, forKey: analysisCountKey)
        }
    }
    
    func canPerformAnalysis() -> Bool {
        if isProUser {
            // Check Pro monthly limit with automatic reset
            checkProAnalysisReset()
            return remainingProAnalyses > 0
        }
        // Trial users and free users have 3 analyses limit
        return remainingFreeAnalyses > 0
    }
    
    private func checkMonthlyReset() {
        let calendar = Calendar.current
        let now = Date()
        
        if let lastReset = UserDefaults.standard.object(forKey: monthlyResetKey) as? Date {
            let components1 = calendar.dateComponents([.year, .month], from: lastReset)
            let components2 = calendar.dateComponents([.year, .month], from: now)
            
            // If month or year changed, reset the count
            if components1.month != components2.month || components1.year != components2.year {
                resetMonthlyCount()
            }
        } else {
            // First time setup
            UserDefaults.standard.set(now, forKey: monthlyResetKey)
        }
    }
    
    private func resetMonthlyCount() {
        UserDefaults.standard.set(0, forKey: analysisCountKey)
        UserDefaults.standard.set(Date(), forKey: monthlyResetKey)
    }
    
    // MARK: - Pro Analysis Tracking
    
    private func checkProAnalysisReset() {
        guard isProUser, let resetDate = proAnalysisResetDate else { return }
        
        let now = Date()
        if now >= resetDate {
            // Reset to full monthly limit
            remainingProAnalyses = proMonthlyLimit
            // Set next reset date (1 month from now)
            proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: now)
            saveProAnalysisState()
        }
    }
    
    private func saveProAnalysisState() {
        cloudStore.set(Int64(remainingProAnalyses), forKey: proAnalysisCountKey)
        if let resetDate = proAnalysisResetDate {
            cloudStore.set(resetDate, forKey: proResetDateKey)
        }
        cloudStore.synchronize()
    }
    
    private func loadProAnalysisState() {
        let savedCount = cloudStore.longLong(forKey: proAnalysisCountKey)
        remainingProAnalyses = savedCount > 0 ? Int(savedCount) : proMonthlyLimit
        proAnalysisResetDate = cloudStore.object(forKey: proResetDateKey) as? Date
    }
    
    // MARK: - Helper Methods
    
    var subscriptionStatus: String {
        if isProUser {
            return "Pro (\(remainingProAnalyses)/\(proMonthlyLimit) analyses this month)"
        } else if isInTrialPeriod {
            return "Trial (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        } else {
            return "Free (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        }
    }
}
