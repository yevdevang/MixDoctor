//
//  PaywallView.swift
//  MixDoctor
//
//  Subscription paywall UI
//

import SwiftUI
import RevenueCat
import StoreKit

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
    @State private var isPurchasingLifetime = false
    @State private var showActiveSubscriptionWarning = false
    
    let onPurchaseComplete: () -> Void
    let onDismiss: (() -> Void)?
    
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

                        // Lifetime Pro one-time unlock
                        lifetimeSection

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
                        AnalyticsService.log(.paywallDismissed)
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
            .alert("You Still Have an Active Subscription", isPresented: $showActiveSubscriptionWarning) {
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                    finishLifetimePurchase()
                }
                Button("OK", role: .cancel) {
                    finishLifetimePurchase()
                }
            } message: {
                Text("Lifetime Pro doesn't automatically cancel your existing subscription — you'll keep being charged for it unless you cancel it yourself.")
            }
            .task {
                await loadOfferings()

                // Log paywall shown event
                AnalyticsService.log(.paywallShown)
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
            if subscriptionService.hasReachedFreeLimit {
                Text("You've used 4 free analyses")
                    .font(.largeTitle.bold())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("Upgrade for up to 50 AI-powered mix analyses per month")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Unlock Pro Features")
                    .font(.largeTitle.bold())
                    .foregroundColor(.black)

                Text("Get up to 50 AI analyses per month and access to all premium features")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Features Section
    
    private var analysisLimitTitle: String {
        selectedPackage?.packageType == .weekly ? "Up to 10 Analyses/Week" : "Up to 50 Analyses/Month"
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Premium Features")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)

            PaywallFeatureRow(
                icon: "waveform.badge.plus",
                title: analysisLimitTitle,
                description: "Analyze your mixes with AI-powered feedback"
            )

            PaywallFeatureRow(
                icon: "music.note.list",
                title: "4 Sample Tracks Included",
                description: "Learn from pre-analyzed professional mixes"
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
        let sortedPackages = offering.availablePackages
            .filter { $0.packageType != .lifetime }
            .sorted { a, b in
                let order: [PackageType: Int] = [.annual: 0, .monthly: 1, .weekly: 2]
                return (order[a.packageType] ?? 3) < (order[b.packageType] ?? 3)
            }
        return VStack(spacing: 16) {
            ForEach(sortedPackages, id: \.identifier) { package in
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
                AnalyticsService.log(.upgradeButtonTapped)

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
                            Text("Subscribe for \(package.localizedPriceString) per \(package.packageType == .annual ? "year" : package.packageType == .weekly ? "week" : "month")")
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
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
            if selectedPackage != nil {
                Text("Payment starts immediately. Cancel anytime.")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
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
    
    // MARK: - Lifetime Section

    @ViewBuilder
    private var lifetimeSection: some View {
        if let lifetimePackage = subscriptionService.currentOffering?.lifetime {
            VStack(spacing: 16) {
                HStack {
                    Divider()
                    Text("OR")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    Divider()
                }

                Button {
                    AnalyticsService.log(.upgradeButtonTapped)
                    Task {
                        await purchaseLifetime(package: lifetimePackage)
                    }
                } label: {
                    VStack(spacing: 6) {
                        if isPurchasingLifetime {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Unlock Local Analysis — \(lifetimePackage.localizedPriceString) once")
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal)
                }
                .background(Color.black.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(14)
                .disabled(isPurchasingLifetime)

                Text("One-time purchase. Analyze on-device forever, with no monthly limit.")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Free users get 4 analyses per month and demo tracks. Upgrade to Pro for up to 50 AI analyses per month and premium features, or unlock unlimited on-device analysis forever with Lifetime Pro. Cancel anytime.")
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
                selectedPackage = offering.annual ?? offering.availablePackages.first { $0.packageType != .lifetime }
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
            let result = try await subscriptionService.purchase(package: package)
            let customerInfo = result.customerInfo

            // User dismissed the native payment sheet — not an error, nothing to report
            if result.userCancelled {
                await MainActor.run { isPurchasing = false }
                return
            }

            // Wait a bit for state to propagate (especially on MacCatalyst)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Force refresh customer info to ensure latest state
            await subscriptionService.updateCustomerInfo()
            
            // Wait longer for UI state to update                                                                                                                                    
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            print("   - subscriptionService.isProUser: \(subscriptionService.isProUser)")

            // Verify purchase was successful
            let hasActiveEntitlement = customerInfo.entitlements["pro"]?.isActive == true
            let isProOrTrial = subscriptionService.isProUser || subscriptionService.isInTrialPeriod

            print("   - Will dismiss: \(hasActiveEntitlement || isProOrTrial)")

            if hasActiveEntitlement || isProOrTrial {
                AnalyticsService.log(.purchaseCompleted)

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
            AnalyticsService.log(.purchaseFailed, parameters: [
                "error": error.localizedDescription
            ])
            await MainActor.run {
                isPurchasing = false
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func purchaseLifetime(package: Package) async {
        isPurchasingLifetime = true

        do {
            let result = try await subscriptionService.purchaseLifetime(package: package)

            // User dismissed the native payment sheet — not an error, nothing to report
            if result.userCancelled {
                await MainActor.run { isPurchasingLifetime = false }
                return
            }

            // Wait a bit for state to propagate (especially on MacCatalyst)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Force refresh customer info to ensure latest state
            await subscriptionService.updateCustomerInfo()

            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            await MainActor.run {
                isPurchasingLifetime = false
                guard subscriptionService.hasLifetimeAccess else {
                    errorMessage = "Purchase completed but Lifetime access not activated. Please try restoring purchases."
                    showError = true
                    return
                }
                AnalyticsService.log(.purchaseCompleted)
                if subscriptionService.isProUser {
                    // Active subscription still running — warn them it won't auto-cancel
                    showActiveSubscriptionWarning = true
                } else {
                    finishLifetimePurchase()
                }
            }
        } catch {
            AnalyticsService.log(.purchaseFailed, parameters: [
                "error": error.localizedDescription
            ])
            await MainActor.run {
                isPurchasingLifetime = false
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func finishLifetimePurchase() {
        onPurchaseComplete()
        #if targetEnvironment(macCatalyst)
        onDismiss?()
        #else
        dismiss()
        #endif
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
                AnalyticsService.log(.restoreCompleted)

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
            AnalyticsService.log(.restoreFailed, parameters: [
                "error": error.localizedDescription
            ])
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

    private var periodLabel: String {
        switch package.packageType {
        case .annual: return "year"
        case .weekly: return "week"
        default: return "month"
        }
    }
    
    // Get the actual billed amount (final price user will pay)
    private var finalBilledAmount: String {
        package.localizedPriceString
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
                    
                    Text("per \(periodLabel)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
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
