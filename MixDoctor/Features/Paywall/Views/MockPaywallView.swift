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
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.1),
                        Color(red: 0.435, green: 0.173, blue: 0.871).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Packages
                        packagesSection
                        
                        // Purchase button
                        purchaseButton
                        
                        // Restore button
                        restoreButton
                        
                        // Mock controls
                        mockControlsSection
                        
                        // Footer
                        footerSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
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
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.435, green: 0.173, blue: 0.871),
                            Color(red: 0.6, green: 0.3, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
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
            
            MockFeatureRow(
                icon: "waveform.badge.checkmark",
                title: "Unlimited Analysis",
                description: "Analyze as many tracks as you need"
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
            
//            MockFeatureRow(
//                icon: "icloud",
//                title: "Cloud Sync",
//                description: "Access your analysis anywhere"
//            )
            
            MockFeatureRow(
                icon: "star.fill",
                title: "Priority Support",
                description: "Get help when you need it"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
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
                    Text("Start Free Trial")
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
        VStack(spacing: 12) {
            Text("🧪 Mock Testing Controls")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            Button("Reset to Free User") {
                mockService.resetToFree()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Terms") { }
                Button("Privacy") { }
            }
            .font(.caption)
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
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
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
                            Text("SAVE 20%")
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
        print("Purchase completed!")
    }
}
