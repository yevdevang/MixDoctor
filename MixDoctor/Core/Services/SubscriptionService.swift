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
    @Published var remainingProAnalyses: Int = 50
    @Published var isWeeklySubscriber: Bool = false

    // Free tier limits
    private let freeAnalysisLimit = 4
    private let monthlyResetKey = "lastMonthlyReset"
    private let analysisCountKey = "analysisCount"

    // Pro tier limits
    private let proMonthlyLimit = 50   // Monthly & Annual subscribers
    private let weeklyProLimit = 10    // Weekly subscribers
    private let proAnalysisCountKey = "proAnalysisCount"
    private let proResetDateKey = "proAnalysisResetDate"
    private let subscriptionTypeKey = "subscriptionType"
    private let cloudStore = NSUbiquitousKeyValueStore.default

    /// The current analysis limit based on subscription type
    var currentProLimit: Int {
        isWeeklySubscriber ? weeklyProLimit : proMonthlyLimit
    }
    
    // Total analysis tracking (for rating prompts)
    private let totalAnalysisCountKey = "totalAnalysisCount"
    
    var proAnalysisResetDate: Date?
    
    var remainingFreeAnalyses: Int {
        let count = UserDefaults.standard.integer(forKey: analysisCountKey)
        return max(0, freeAnalysisLimit - count)
    }
    
    var totalAnalysisCount: Int {
        UserDefaults.standard.integer(forKey: totalAnalysisCountKey)
    }
    
    var hasReachedFreeLimit: Bool {
        !isProUser && remainingFreeAnalyses <= 0
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        // Load subscription type first (needed for currentProLimit)
        isWeeklySubscriber = cloudStore.string(forKey: subscriptionTypeKey) == "weekly"
        loadProAnalysisState()
        // Skip RevenueCat during tests to prevent crashes
        if !Self.isRunningTests {
            configureRevenueCat()
        }
        checkMonthlyReset()
        checkProAnalysisReset()
    }

    /// Returns true if running under XCTest
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
        // Skip during tests
        guard !Self.isRunningTests else { return }

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
            // Detect subscription type from offerings
            detectSubscriptionType(from: info)
            // Initialize Pro analysis limit if becoming Pro for first time
            if remainingProAnalyses == 0 && proAnalysisResetDate == nil {
                remainingProAnalyses = currentProLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: Date())
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

        print("💳 Purchase result received")

        // Save subscription type based on package
        let isWeekly = package.packageType == .weekly
        isWeeklySubscriber = isWeekly
        saveSubscriptionType()

        // Check if user has active pro entitlement
        let hasProEntitlement = result.customerInfo.entitlements["pro"]?.isActive == true

        // Check if currently in trial period
        if let proEntitlement = result.customerInfo.entitlements["pro"],
           proEntitlement.isActive,
           proEntitlement.periodType == .trial {
            print("   - Setting isInTrialPeriod = true")
            isInTrialPeriod = true
            isProUser = false // Treat trial users as free tier for analysis limits
            willRenew = proEntitlement.willRenew
        } else if hasProEntitlement {
            print("   - Setting isProUser = true (weekly: \(isWeekly), limit: \(currentProLimit))")
            isInTrialPeriod = false
            isProUser = true
            // Update renewal status
            if let proEntitlement = result.customerInfo.entitlements["pro"] {
                willRenew = proEntitlement.willRenew
            }
            // Initialize Pro analysis limit for new purchase
            remainingProAnalyses = currentProLimit
            proAnalysisResetDate = Calendar.current.date(byAdding: isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: Date())
            saveProAnalysisState()
        } else {
            print("   - ⚠️ No valid entitlement detected!")
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
            isProUser = true
            // Update renewal status
            if let proEntitlement = info.entitlements["pro"] {
                willRenew = proEntitlement.willRenew
            }
            // Detect subscription type from offerings
            detectSubscriptionType(from: info)
            // Initialize Pro analysis limit when restoring
            if remainingProAnalyses == 0 && proAnalysisResetDate == nil {
                remainingProAnalyses = currentProLimit
                proAnalysisResetDate = Calendar.current.date(byAdding: isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: Date())
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
        // Increment total analysis count (for rating prompts)
        let totalCount = UserDefaults.standard.integer(forKey: totalAnalysisCountKey)
        UserDefaults.standard.set(totalCount + 1, forKey: totalAnalysisCountKey)
        
        if isProUser {
            // Decrement Pro monthly limit
            remainingProAnalyses = max(0, remainingProAnalyses - 1)
            saveProAnalysisState()
        } else {
            // Increment free tier count
            let currentCount = UserDefaults.standard.integer(forKey: analysisCountKey)
            UserDefaults.standard.set(currentCount + 1, forKey: analysisCountKey)
        }
        
        // Check if we should show rating prompt
        checkForRatingPrompt()
    }
    
    func canPerformAnalysis() -> Bool {
        if isProUser {
            // Check Pro monthly limit with automatic reset
            checkProAnalysisReset()
            return remainingProAnalyses > 0
        }
        // Trial users and free users have 4 analyses limit
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
            // Reset to full limit based on subscription type
            remainingProAnalyses = currentProLimit
            // Set next reset date based on subscription type
            proAnalysisResetDate = Calendar.current.date(byAdding: isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: now)
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
        remainingProAnalyses = savedCount > 0 ? Int(savedCount) : currentProLimit
        proAnalysisResetDate = cloudStore.object(forKey: proResetDateKey) as? Date
    }
    
    // MARK: - Rating Prompt
    
    private func checkForRatingPrompt() {
        let ratingService = RatingService.shared
        let shouldShow = ratingService.shouldShowRating(
            analysisCount: totalAnalysisCount,
            isProUser: isProUser,
            isInTrialPeriod: isInTrialPeriod
        )
        
        if shouldShow {
            // Delay slightly to avoid interrupting the user
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                ratingService.requestRating()
                ratingService.markRatingAsShown(isProUser: isProUser, isInTrialPeriod: isInTrialPeriod)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    var subscriptionStatus: String {
        if isProUser {
            if !willRenew {
                return "Pro (Cancels at period end)"
            }
            let periodLabel = isWeeklySubscriber ? "week" : "month"
            let used = currentProLimit - remainingProAnalyses
            return "Pro (\(used)/\(currentProLimit) analyses this \(periodLabel))"
        } else {
            let used = freeAnalysisLimit - remainingFreeAnalyses
            return "Free (\(used)/\(freeAnalysisLimit) analyses)"
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
                // Detect subscription type from offerings
                self.detectSubscriptionType(from: customerInfo)
                // Initialize Pro analysis limit if becoming Pro for first time
                if self.remainingProAnalyses == 0 && self.proAnalysisResetDate == nil {
                    self.remainingProAnalyses = self.currentProLimit
                    self.proAnalysisResetDate = Calendar.current.date(byAdding: self.isWeeklySubscriber ? .weekOfYear : .month, value: 1, to: Date())
                    self.saveProAnalysisState()
                }
            } else {
                print("❌ Status: Free user (no active subscription)")
                self.isInTrialPeriod = false
                self.isProUser = false
            }
        }
    }

    // MARK: - Subscription Type Detection

    /// Detect subscription type (weekly vs monthly/annual) from product identifier
    private func detectSubscriptionType(from customerInfo: CustomerInfo) {
        guard let proEntitlement = customerInfo.entitlements["pro"],
              proEntitlement.isActive,
              proEntitlement.periodType != .trial else { return }

        let productId = proEntitlement.productIdentifier

        // Try to match against current offerings
        if let offering = currentOffering {
            if let weekly = offering.weekly, weekly.storeProduct.productIdentifier == productId {
                isWeeklySubscriber = true
            } else {
                isWeeklySubscriber = false
            }
            saveSubscriptionType()
        }
        // If offerings aren't loaded, keep the saved value from cloud store
    }

    private func saveSubscriptionType() {
        cloudStore.set(isWeeklySubscriber ? "weekly" : "other", forKey: subscriptionTypeKey)
        cloudStore.synchronize()
    }
}
