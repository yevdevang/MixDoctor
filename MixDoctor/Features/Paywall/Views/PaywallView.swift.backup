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
    @State private var subscriptionService = SubscriptionService.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onPurchaseComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0xef/255, green: 0xe8/255, blue: 0xfd/255)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
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
                    .padding()
                    .padding(.top, -20)
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
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("mix-doctor-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22.5, style: .continuous))
            
            Text("Unlock Pro Features")
                .font(.title.bold())
            
            Text("Get unlimited audio analyses and access to all premium features")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.headline)
                .foregroundColor(.primary)
            
            PaywallFeatureRow(
                icon: "waveform.badge.checkmark",
                title: "Unlimited Analysis",
                description: "Analyze as many tracks as you need"
            )
            
            PaywallFeatureRow(
                icon: "sparkles",
                title: "Advanced AI",
                description: "Powered by OpenAI's latest models"
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
                    Text("Start 7-Day Free Trial")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
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
            .cornerRadius(12)
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
                        .font(.subheadline)
                }
            }
        }
        .disabled(isRestoring)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            // Updated footer text to reflect trial behavior
            Text("7-day free trial with 3 analyses, then $5.99/month or $47.88/year ($3.99/month). After trial, you'll get 3 free analyses per month. Subscribe anytime for unlimited analyses with Pro AI features.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Terms of Service") { }
                Button("Privacy Policy") { }
            }
            .font(.caption2)
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
            print("🛒 Starting purchase for package: \(package.identifier)")
            let customerInfo = try await subscriptionService.purchase(package: package)
            print("✅ Purchase completed successfully")
            print("   Has pro entitlement: \(customerInfo.entitlements["pro"]?.isActive == true)")
            print("   Is in trial: \(subscriptionService.isInTrialPeriod)")
            print("   Is pro user: \(subscriptionService.isProUser)")
            
            // Verify purchase was successful
            if customerInfo.entitlements["pro"]?.isActive == true {
                print("✅ Pro entitlement is active, calling completion")
                onPurchaseComplete()
                dismiss()
            } else {
                print("⚠️ Purchase succeeded but no active entitlement")
                errorMessage = "Purchase completed but subscription not activated. Please try restoring purchases."
                showError = true
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(package.storeProduct.localizedTitle)
                            .font(.headline)
                        
                        if isAnnual {
                            Text("SAVE 33%")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    if isAnnual {
                        Text("\(pricePerMonth)/month")
                            .font(.title2.bold())
                        Text("Billed annually as \(package.localizedPriceString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(package.localizedPriceString)
                            .font(.title2.bold())
                        Text("per month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : .secondary)
            }
            .padding()
            .background(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : Color.secondary.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(onPurchaseComplete: {})
}
