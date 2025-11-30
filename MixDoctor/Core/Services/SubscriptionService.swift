//
//  SubscriptionService.swift
//  MixDoctor
//
//  RevenueCat subscription management service
//

import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
public final class SubscriptionService: NSObject, ObservableObject, PurchasesDelegate {
    public static let shared = SubscriptionService()
    
    // MARK: - Properties
    @Published var isProUser: Bool = false
    @Published var isInTrialPeriod: Bool = false
    @Published var willRenew: Bool = true
    @Published var currentOffering: Offering?
    @Published var customerInfo: CustomerInfo?
     
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
    
    private override init() {
        super.init()
        loadProAnalysisState()
        configureRevenueCat()
        checkMonthlyReset()
        checkProAnalysisReset()
    }
    
    private func configureRevenueCat() {
        // Configure RevenueCat with your API key
        Purchases.logLevel = .debug
        
        // Configure with app user ID - RevenueCat will generate an anonymous ID if nil
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: Config.revenueCatAPIKey)
                .with(usesStoreKit2IfAvailable: true) // Enable StoreKit 2 for better sync
                .build()
        )
        
        // Set delegate to receive real-time updates
        Purchases.shared.delegate = self
        
        // Set up listener for customer info updates
        Task {
            await updateCustomerInfo()
        }
    }
    
    // MARK: - Customer Info
    
    func updateCustomerInfo() async {
        print("🔄 updateCustomerInfo() called at \(Date())")
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            
            // Check if user has active pro entitlement
            let hasProEntitlement = info.entitlements["pro"]?.isActive == true
            print("✨ updateCustomerInfo - Has Pro: \(hasProEntitlement)")
            
            // Check if subscription will renew
            if let proEntitlement = info.entitlements["pro"] {
                print("📱 updateCustomerInfo - Will renew: \(proEntitlement.willRenew)")
            }
            
            // Check if currently in trial period
            if let proEntitlement = info.entitlements["pro"],
               proEntitlement.isActive,
           proEntitlement.periodType == .trial {
            isInTrialPeriod = true
            isProUser = false // Treat trial users as free tier for analysis limits
            willRenew = proEntitlement.willRenew
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Update renewal status
            if let proEntitlement = info.entitlements["pro"] {
                willRenew = proEntitlement.willRenew
            }
            // Initialize Pro analysis limit if becoming Pro for first time
            if remainingProAnalyses == 0 && proAnalysisResetDate == nil {
                remainingProAnalyses = proMonthlyLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                saveProAnalysisState()
            }
        } else {
            isInTrialPeriod = false
            isProUser = false
            willRenew = true // Reset to default
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
            willRenew = proEntitlement.willRenew
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Update renewal status
            if let proEntitlement = result.customerInfo.entitlements["pro"] {
                willRenew = proEntitlement.willRenew
            }
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
            willRenew = proEntitlement.willRenew
        } else if hasProEntitlement {
            isInTrialPeriod = false
            isProUser = true // Paid subscribers get monthly limit
            // Update renewal status
            if let proEntitlement = info.entitlements["pro"] {
                willRenew = proEntitlement.willRenew
            }
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
            willRenew = true // Reset to default
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
            if !willRenew {
                return "Pro (Cancels at period end) (\(remainingProAnalyses)/\(proMonthlyLimit))"
            }
            return "Pro (\(remainingProAnalyses)/\(proMonthlyLimit) analyses this month)"
        } else if isInTrialPeriod {
            return "Trial (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        } else {
            return "Free (\(remainingFreeAnalyses)/\(freeAnalysisLimit) analyses)"
        }
    }
    
    // MARK: - PurchasesDelegate
    
    nonisolated public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // This gets called automatically when subscription status changes
        Task { @MainActor in
            print("🔄 Delegate: Received updated customerInfo")
            print("⏰ Timestamp: \(Date())")
            self.customerInfo = customerInfo
            
            // Check if user has active pro entitlement
            let hasProEntitlement = customerInfo.entitlements["pro"]?.isActive == true
            print("✨ Has Pro entitlement: \(hasProEntitlement)")
            
            // Check if subscription will renew (false means cancelled but still active until period ends)
            if let proEntitlement = customerInfo.entitlements["pro"] {
                self.willRenew = proEntitlement.willRenew
                print("📱 Subscription will renew: \(proEntitlement.willRenew)")
                print("📅 Expiration date: \(proEntitlement.expirationDate?.description ?? "none")")
                print("🔍 Period type: \(proEntitlement.periodType)")
            } else {
                print("⚠️ No pro entitlement found")
            }
            
            // Check if currently in trial period
            if let proEntitlement = customerInfo.entitlements["pro"],
               proEntitlement.isActive,
               proEntitlement.periodType == .trial {
                print("✅ Status: Trial period")
                self.isInTrialPeriod = true
                self.isProUser = false
            } else if hasProEntitlement {
                print("✅ Status: Pro user (active)")
                self.isInTrialPeriod = false
                self.isProUser = true
                // Initialize Pro analysis limit if becoming Pro for first time
                if self.remainingProAnalyses == 0 && self.proAnalysisResetDate == nil {
                    self.remainingProAnalyses = self.proMonthlyLimit
                    self.proAnalysisResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                    self.saveProAnalysisState()
                }
            } else {
                print("❌ Status: Free user (no active subscription)")
                self.isInTrialPeriod = false
                self.isProUser = false
            }
        }
    }
}
