//
//  PaywallView.swift
//  MixDoctor
//
//  Subscription paywall UI
//

import SwiftUI
import RevenueCat

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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0xef/255, green: 0xe8/255, blue: 0xfd/255)
                    .ignoresSafeArea()
                
                ScrollView {
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
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
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
            Image("mix-doctor-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            
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
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start 3-Day Free Trial")
                        .font(.title3.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal)
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
        }
        .disabled(selectedPackage == nil || isPurchasing)
        .opacity(selectedPackage == nil ? 0.6 : 1.0)
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
            if let package = selectedPackage {
                Text("3-day free trial, then \(package.localizedPriceString) per \(package.packageType == .annual ? "year" : "month")")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.black)
            }
            
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
        defer { isPurchasing = false }
        
        do {
            let customerInfo = try await subscriptionService.purchase(package: package)
            
            // Verify purchase was successful
            if customerInfo.entitlements["pro"]?.isActive == true {
                onPurchaseComplete()
                dismiss()
            } else {
                errorMessage = "Purchase completed but subscription not activated. Please try restoring purchases."
                showError = true
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isProUser {
                onPurchaseComplete()
                dismiss()
            } else {
                errorMessage = "No previous purchases found"
                showError = true
            }
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            showError = true
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
    
    private var pricePerMonth: String {
        if isAnnual, let price = package.storeProduct.price as? Decimal {
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
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(package.storeProduct.localizedTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.black)
                        
                        if isAnnual {
                            Text("SAVE 33%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                    }
                    
                    if isAnnual {
                        Text("\(pricePerMonth)/month")
                            .font(.title.bold())
                            .foregroundColor(.black)
                        Text("Billed annually as \(package.localizedPriceString)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text(package.localizedPriceString)
                            .font(.title.bold())
                            .foregroundColor(.black)
                        Text("per month")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : .secondary)
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
    PaywallView(onPurchaseComplete: {})
}
