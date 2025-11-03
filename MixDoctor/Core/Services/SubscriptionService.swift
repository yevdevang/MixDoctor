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
    
    var remainingFreeAnalyses: Int {
        let count = UserDefaults.standard.integer(forKey: analysisCountKey)
        return max(0, freeAnalysisLimit - count)
    }
    
    var hasReachedFreeLimit: Bool {
        !isProUser && remainingFreeAnalyses <= 0
    }
    
    // MARK: - Initialization
    
    private init() {
        configureRevenueCat()
        checkMonthlyReset()
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
                isProUser = true // Paid subscribers get unlimited
            } else {
                isInTrialPeriod = false
                isProUser = false
            }
            
            print("✅ Updated customer info - Pro user: \(isProUser), In trial: \(isInTrialPeriod)")
        } catch {
            print("❌ Failed to get customer info: \(error)")
        }
    }
    
    // MARK: - Offerings
    
    func fetchOfferings() async throws {
        let offerings = try await Purchases.shared.offerings()
        currentOffering = offerings.current
        print("✅ Fetched offerings: \(offerings.current?.availablePackages.count ?? 0) packages")
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
            isProUser = true // Paid subscribers get unlimited
        }
        
        print("✅ Purchase successful - Pro user: \(isProUser), In trial: \(isInTrialPeriod)")
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
            isProUser = true // Paid subscribers get unlimited
        }
        
        print("✅ Restored purchases - Pro user: \(isProUser), In trial: \(isInTrialPeriod)")
    }
    
    // MARK: - Usage Tracking
    
    func incrementAnalysisCount() {
        // Only increment for non-paid users (free tier and trial users)
        guard !isProUser else { return }
        
        let currentCount = UserDefaults.standard.integer(forKey: analysisCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: analysisCountKey)
        print("📊 Analysis count: \(currentCount + 1)/\(freeAnalysisLimit)")
    }
    
    func canPerformAnalysis() -> Bool {
        // Paid subscribers get unlimited
        if isProUser {
            return true
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
        print("🔄 Monthly analysis count reset")
    }
    
    // MARK: - Helper Methods
    
    var subscriptionStatus: String {
        if isProUser {
            return "Pro (Unlimited)"
        } else if isInTrialPeriod {
            return "Trial (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        } else {
            return "Free (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        }
    }
}
