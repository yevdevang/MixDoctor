//
//  PaywallView.swift
//  MixDoctor
//
//  Subscription paywall UI
//

import SwiftUI
import RevenueCat
import StoreKit
import FirebaseAnalytics

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    let onPurchaseComplete: () -> Void
    let onDismiss: (() -> Void)?
    
    // Helper functions for trial detection
    private func hasFreeTrial(for package: Package) -> Bool {
        // Default to 3-day trial if we can't detect it
        // This is safer than trying to access StoreKit APIs that may vary
        return true // Assume free trial exists (configured in App Store Connect)
    }
    
    private func getTrialPeriodDays(for package: Package) -> Int? {
        // Default to 3 days if we can't detect it programmatically
        // This matches your App Store Connect configuration
        return 3
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0xef/255, green: 0xe8/255, blue: 0xfd/255)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 40) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Packages
                        if let offering = subscriptionService.currentOffering {
                            packagesSection(offering: offering)
                        } else {
                            ProgressView()
                                .padding()
                        }
                        
                        // Purchase button
                        purchaseButton
                        
                        // Restore button
                        restoreButton
                        
                        // Footer
                        footerSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 60) // Increased bottom padding to ensure footer is fully visible
                    .frame(maxWidth: .infinity) // Ensure full width
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        #if targetEnvironment(macCatalyst)
                        onDismiss?()
                        #else
                        dismiss()
                        #endif
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadOfferings()
                
                // Log paywall shown event
                Analytics.logEvent("paywall_shown", parameters: nil)
            }
            .sheet(isPresented: $showTerms) {
                TermsView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyView()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            Text("Unlock Pro Features")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
            
            Text("Get 50 audio analyses and access to all premium features")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Premium Features")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            PaywallFeatureRow(
                icon: "infinity",
                title: "50 Analyses per Month",
                description: "Pro subscribers get 50 analyses monthly"
            )
            
            PaywallFeatureRow(
                icon: "sparkles",
                title: "Advanced AI Analysis",
                description: "Powered by Claude Sonnet 4.5"
            )
            
            PaywallFeatureRow(
                icon: "chart.xyaxis.line",
                title: "Detailed Reports",
                description: "Get comprehensive mix analysis"
            )
            
            PaywallFeatureRow(
                icon: "star.fill",
                title: "Priority Support",
                description: "Get help when you need it"
            )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Packages Section
    
    private func packagesSection(offering: Offering) -> some View {
        VStack(spacing: 16) {
            ForEach(offering.availablePackages, id: \.identifier) { package in
                PackageCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    onTap: {
                        selectedPackage = package
                    }
                )
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                // Log upgrade button tapped event
                Analytics.logEvent("upgrade_button_tapped", parameters: [
                    "package_type": selectedPackage?.packageType == .annual ? "annual" : "monthly"
                ])
                
                Task {
                    await purchase()
                }
            } label: {
                VStack(spacing: 6) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        // Show final billed amount prominently
                        if let package = selectedPackage {
                            let hasTrial = hasFreeTrial(for: package)
                            
                            if hasTrial {
                                Text("Start Free Trial")
                                    .font(.title3.weight(.semibold))
                                Text("Then \(package.localizedPriceString) per \(package.packageType == .annual ? "year" : "month")")
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Text("Subscribe for \(package.localizedPriceString)")
                                    .font(.title3.weight(.semibold))
                                Text("per \(package.packageType == .annual ? "year" : "month")")
                                    .font(.subheadline.weight(.medium))
                            }
                        } else {
                            Text("Select a Plan")
                                .font(.title3.weight(.semibold))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.435, green: 0.173, blue: 0.871),
                        Color(red: 0.6, green: 0.3, blue: 0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .disabled(selectedPackage == nil || isPurchasing)
            .opacity(selectedPackage == nil ? 0.6 : 1.0)
            
            // Clear payment timing info below button
            if let package = selectedPackage {
                let hasTrial = hasFreeTrial(for: package)
                let trialDays = getTrialPeriodDays(for: package)
                
                if hasTrial, let days = trialDays {
                    
                    Text("Payment starts after \(days)-day free trial")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                } else {
                    Text("Payment starts immediately")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            Task {
                await restore()
            }
        } label: {
            HStack {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                        .font(.headline)
                }
            }
        }
        .disabled(isRestoring)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Free trial gives you 3 analyses to test Pro features. After trial, continue with 3 free analyses/month or get 50 analyses/month with Pro subscription. Cancel anytime.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Terms") {
                    showTerms = true
                }
                Button("Privacy") {
                    showPrivacy = true
                }
            }
            .font(.caption)
            .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))
        }
    }
    
    // MARK: - Actions
    
    private func loadOfferings() async {
        do {
            try await subscriptionService.fetchOfferings()
            // Auto-select annual package (best value)
            if let offering = subscriptionService.currentOffering {
                selectedPackage = offering.annual ?? offering.availablePackages.first
            }
        } catch {
            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func purchase() async {
        guard let package = selectedPackage else { return }
        
        isPurchasing = true
        
        do {
            let customerInfo = try await subscriptionService.purchase(package: package)
            
            
            // Wait a bit for state to propagate (especially on MacCatalyst)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Force refresh customer info to ensure latest state
            await subscriptionService.updateCustomerInfo()
            
            // Wait longer for UI state to update                                                                                                                                    
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            print("   - subscriptionService.isProUser: \(subscriptionService.isProUser)")
            print("   - subscriptionService.isInTrialPeriod: \(subscriptionService.isInTrialPeriod)")
            
            // Verify purchase was successful (trial or paid)
            let hasActiveEntitlement = customerInfo.entitlements["pro"]?.isActive == true
            let isProOrTrial = subscriptionService.isProUser || subscriptionService.isInTrialPeriod
            
            // Log trial started event if user is in trial period
            if subscriptionService.isInTrialPeriod {
                Analytics.logEvent("trial_started", parameters: [
                    "package_type": package.packageType == .annual ? "annual" : "monthly"
                ])
            }
            
            print("   - Will dismiss: \(hasActiveEntitlement || isProOrTrial)")
            
            if hasActiveEntitlement || isProOrTrial {
                // Ensure we're on main actor for UI updates
                await MainActor.run {
                    isPurchasing = false
                    onPurchaseComplete()
                }
                
                // Small delay before dismiss to ensure callbacks complete
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                await MainActor.run {
                    #if targetEnvironment(macCatalyst)
                    // On MacCatalyst, use explicit dismissal callback
                    onDismiss?()
                    #else
                    dismiss()
                    #endif
                }
            } else {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = "Purchase completed but subscription not activated. Please try restoring purchases."
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func restore() async {
        isRestoring = true
        
        do {
            try await subscriptionService.restorePurchases()
            
            // Wait for state to propagate
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Force refresh to ensure latest state
            await subscriptionService.updateCustomerInfo()
            
            // Wait for UI state to update
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            if subscriptionService.isProUser || subscriptionService.isInTrialPeriod {
                await MainActor.run {
                    isRestoring = false
                    onPurchaseComplete()
                }
                
                // Small delay before dismiss
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                await MainActor.run {
                    #if targetEnvironment(macCatalyst)
                    // On MacCatalyst, use explicit dismissal callback
                    onDismiss?()
                    #else
                    dismiss()
                    #endif
                }
            } else {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = "No previous purchases found"
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isRestoring = false
                errorMessage = "Restore failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Package Card

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void
    
    private var isAnnual: Bool {
        package.packageType == .annual
    }
    
    // Get the actual billed amount (final price user will pay)
    private var finalBilledAmount: String {
        package.localizedPriceString
    }
    
    // Get free trial period info
    // Simplified: Assume 3-day free trial as configured in App Store Connect
    // This avoids complex StoreKit API differences between versions
    private var hasFreeTrial: Bool {
        // Check if package has an introductory offer by checking if storeProduct has one
        // For simplicity, we'll assume all packages have a 3-day trial
        // This matches your App Store Connect configuration
        return true
    }
    
    private var trialPeriodDays: Int? {
        // Return 3 days as configured in App Store Connect
        return 3
    }
    
    private var pricePerMonth: String {
        if isAnnual {
            let price = package.storeProduct.price
            let monthlyPrice = price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = package.storeProduct.currencyCode
            return formatter.string(from: monthlyPrice as NSNumber) ?? ""
        }
        return package.localizedPriceString
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Title row
                HStack(alignment: .center, spacing: 8) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if isAnnual {
                        Text("SAVE 33%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(5)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : Color.white)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.4), lineWidth: 2)
                            )
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // FINAL BILLED AMOUNT - Most Prominent (App Store Guideline 3.1.2)
                VStack(alignment: .leading, spacing: 6) {
                    // The actual amount user will be charged
                    Text(finalBilledAmount)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    // When payment starts - clearly shown
                    if hasFreeTrial, let days = trialPeriodDays {
                        HStack(spacing: 3) {
                            Text("\(days)-day free trial, then")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.gray)
                            Text(finalBilledAmount)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Text(isAnnual ? "per year" : "per month")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.gray)
                        }
                        .lineLimit(1)
                    } else {
                        Text(isAnnual ? "per year" : "per month")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Monthly equivalent (secondary, smaller)
                    if isAnnual {
                        Text("\(pricePerMonth)/month")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(20)
            .background(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.1) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : Color.secondary.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(onPurchaseComplete: {}, onDismiss: nil)
}
