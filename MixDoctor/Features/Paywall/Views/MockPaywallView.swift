//
//  MockPaywallView.swift
//  MixDoctor
//
//  Mock paywall for testing without RevenueCat/App Store
//

import SwiftUI

struct MockPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mockService = MockSubscriptionService.shared
    @State private var selectedPackageId: String = "monthly"
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Packages
                        packagesSection
                        
                        // Purchase button
                        purchaseButton
                        
                        // Skip trial button (testing only)
                        skipTrialButton
                        
                        // Restore button
                        restoreButton
                        
                        // Mock controls
                        mockControlsSection
                        
                        // Footer
                        footerSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
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
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("mix-doctor-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            Text("Unlock Pro Features")
                .font(.title.bold())
            
            Text("Get unlimited access to advanced AI-powered mix analysis and professional features")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.headline)
            
            MockFeatureRow(
                icon: "infinity",
                title: "50 Analyses per Month",
                description: "Pro subscribers get 50 analyses monthly"
            )
            
            MockFeatureRow(
                icon: "sparkles",
                title: "Advanced AI",
                description: "Powered by OpenAI's latest models"
            )
            
            MockFeatureRow(
                icon: "chart.xyaxis.line",
                title: "Detailed Reports",
                description: "Get comprehensive mix analysis"
            )
            
            MockFeatureRow(
                icon: "star.fill",
                title: "Priority Support",
                description: "Get help when you need it"
            )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Packages Section
    
    private var packagesSection: some View {
        VStack(spacing: 16) {
            ForEach(mockService.mockPackages, id: \.id) { package in
                MockPackageCard(
                    package: package,
                    isSelected: selectedPackageId == package.id,
                    onTap: {
                        selectedPackageId = package.id
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
        .disabled(isPurchasing)
    }
    
    // MARK: - Skip Trial Button
    
    private var skipTrialButton: some View {
        Button {
            Task {
                isPurchasing = true
                let success = await mockService.mockPurchaseSkipTrial(packageId: selectedPackageId)
                isPurchasing = false
                
                if success {
                    onPurchaseComplete()
                    dismiss()
                } else {
                    errorMessage = "Failed to skip trial and subscribe"
                    showError = true
                }
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                } else {
                    Image(systemName: "bolt.fill")
                    Text("Skip Trial - Subscribe Now")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isPurchasing)
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
    
    // MARK: - Mock Controls
    
    private var mockControlsSection: some View {
        VStack(spacing: 8) {
            Text("🧪 Mock Testing")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Button("Reset to Free") {
                    mockService.resetToFree()
                }
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(6)
                
                Button("Reset Analysis Count") {
                    mockService.remainingFreeAnalyses = 3
                    mockService.hasReachedFreeLimit = false
                    UserDefaults.standard.set(3, forKey: "mock_remainingAnalyses")
                    UserDefaults.standard.set(false, forKey: "mock_hasReachedLimit")
                }
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            
            if mockService.isInTrialPeriod {
                Button("Convert Trial → Paid") {
                    mockService.mockConvertTrialToPaid()
                }
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("7-day free trial with 3 analyses, then \(selectedPackageId == "annual" ? "$47.88/year" : "$5.99/month")")
                .font(.caption2.bold())
                .foregroundStyle(.primary)
            
            Text("Test Pro features during trial. Continue with 3 analyses/month free or subscribe for 50 analyses/month.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Terms") { }
                Button("Privacy") { }
            }
            .font(.caption2)
            .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))
        }
    }
    
    // MARK: - Actions
    
    private func purchase() async {
        isPurchasing = true
        
        let success = await mockService.mockPurchase(packageId: selectedPackageId)
        
        isPurchasing = false
        
        if success {
            onPurchaseComplete()
            dismiss()
        } else {
            errorMessage = "Purchase failed. Please try again."
            showError = true
        }
    }
    
    private func restore() async {
        isRestoring = true
        
        let success = await mockService.mockRestore()
        
        isRestoring = false
        
        if success {
            onPurchaseComplete()
            dismiss()
        } else {
            errorMessage = "No purchases to restore."
            showError = true
        }
    }
}

// MARK: - Supporting Views

private struct MockFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue.gradient)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
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

private struct MockPackageCard: View {
    let package: MockSubscriptionService.MockPackage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(package.title)
                            .font(.headline)
                        
                        if package.id == "annual" {
                            Text("SAVE 33%")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(package.price)
                        .font(.title2.bold())
                        .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))
                    
                    Text(package.period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(red: 0.435, green: 0.173, blue: 0.871) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MockPaywallView {
    }
}
