import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @StateObject private var ratingService = RatingService.shared
    @State private var storageInfo: StorageInfo?
    @State private var isLoadingStorage = false
    @State private var showClearCacheAlert = false
    @State private var showPaywall = false
    @State private var isRefreshingSubscription = false
    @State private var showClearAnalysisAlert = false
    @State private var isClearingAnalysis = false
    @AppStorage("muteLaunchSound") private var muteLaunchSound = false
    @Environment(\.modelContext) private var modelContext
    @Query private var audioFiles: [AudioFile]

    /// Whether any non-demo file has an analysis result that can be cleared
    private var hasNonDemoAnalysis: Bool {
        audioFiles.contains { !$0.isDemoFile && $0.analysisResult != nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Subscription Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Status")
                                .font(.headline)
                            Text(subscriptionService.subscriptionStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if subscriptionService.isProUser {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.primaryAccent)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Refresh subscription button
                    Button {
                        isRefreshingSubscription = true
                        Task {
                            await subscriptionService.updateCustomerInfo()
                            // Small delay for visual feedback
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            isRefreshingSubscription = false
                        }
                    } label: {
                        HStack {
                            if isRefreshingSubscription {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Refreshing...")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Status")
                            }
                        }
                    }
                    .disabled(isRefreshingSubscription)
                    
                    if !subscriptionService.isProUser {
                        Button {
                            AnalyticsService.log(.upgradeButtonTapped)
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Upgrade to Pro")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button("Manage Subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    Text("Subscription status syncs automatically across all your devices")
                }
                
                // MARK: - Preferences Section
                Section {
                    Picker("Theme", selection: $viewModel.selectedTheme) {
                        ForEach(ThemeOption.allCases) { theme in
                            Text(theme.rawValue).tag(theme.id)
                        }
                    }
                    
                    Toggle("Mute Launch Sound", isOn: $muteLaunchSound)
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Theme preference syncs automatically across all your devices")
                }
                
                // MARK: - Storage Section
                Section {
                    if let storage = storageInfo {
                        VStack(spacing: 12) {
                            StorageInfoRow(title: "Audio Files", value: storage.formattedAudioFilesSize)
                            StorageInfoRow(title: "Cache", value: storage.formattedCacheSize)
                            Divider()
                            StorageInfoRow(title: "Total Used", value: storage.formattedTotalUsed, bold: true)
                            StorageInfoRow(title: "Available", value: storage.formattedAvailableSpace)
                            
                            // Storage Bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(storageBarColor(for: storage.usagePercentage))
                                        .frame(width: geometry.size.width * CGFloat(storage.usagePercentage / 100), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                            
                            HStack {
                                Text("\(Int(storage.usagePercentage))% used")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(storage.numberOfFiles) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else if isLoadingStorage {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    Button {
                        showClearCacheAlert = true
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                } header: {
                    Text("Storage Management")
                } footer: {
                    Text("Free up space by clearing cache")
                }
                
                // MARK: - iCloud Section
                Section {
                    Toggle(isOn: $viewModel.iCloudSyncEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iCloud Sync")
                                    .font(.body)
                                
                                Text("Sync metadata across devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(Color.accentColor)
                    
                    // Cloud Storage Info & Debug Tools
                    NavigationLink {
                        iCloudDebugView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Cloud Storage Info")
                        }
                    }
                } header: {
                    Text("Cloud Storage")
                } footer: {
                    Text("When enabled, your audio file metadata and analysis results will be synced across all your devices. Audio files remain stored locally on each device. You'll need to restart the app for changes to take effect.")
                }
                
                // MARK: - About Section
                Section {
                    Button {
                        viewModel.showAbout = true
                    } label: {
                        HStack {
                            Text("About MixDoctor")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
                
                // MARK: - Debug Section (for testing onboarding)
                #if DEBUG
                Section("Debug") {
                    Button("Reset Onboarding") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        // Force app restart to show onboarding
                        exit(0)
                    }
                    .foregroundStyle(.red)
                    
                    Button {
                        showClearAnalysisAlert = true
                    } label: {
                        HStack {
                            if isClearingAnalysis {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Clearing Analysis...")
                            } else {
                                Text("Clear All Analysis")
                            }
                        }
                    }
                    .foregroundStyle(.orange)
                    .disabled(isClearingAnalysis)
                }
                #endif
            }
            #if targetEnvironment(macCatalyst)
            .scrollContentBackground(.hidden)
            .navigationTitle("")
            #else
            .navigationTitle("Settings")
            #endif
            .navigationBarTitleDisplayMode(.inline)
            .task {
                AnalyticsService.log(.settingsViewed)
                await loadStorageInfo()
            }
            .refreshable {
                await loadStorageInfo()
            }
            .alert("Cache Cleared", isPresented: $showClearCacheAlert) {
                Button("Clear Cache", role: .destructive) {
                    clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up space by removing temporary files")
            }
            .alert("Clear All Analysis", isPresented: $showClearAnalysisAlert) {
                Button("Clear Analysis", role: .destructive) {
                    clearAllAnalysis()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all analysis results (including JSON files in iCloud) from your files. The audio files will remain, but you'll need to re-analyze them. This is useful for testing score changes.")
            }
            .sheet(isPresented: $viewModel.showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    onPurchaseComplete: {
                        // Subscription service updates automatically via RevenueCat listener
                    },
                    onDismiss: {
                        showPaywall = false
                    }
                )
                #if targetEnvironment(macCatalyst)
                .frame(width: 850, height: 1100)
                #endif
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
            }
            .task {
                // Refresh subscription status when view appears (non-blocking)
                Task.detached(priority: .utility) {
                    await subscriptionService.updateCustomerInfo()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadStorageInfo() async {
        isLoadingStorage = true
        // Run storage calculation on background thread to avoid UI freezing
        let info = await Task.detached(priority: .utility) {
            try? FileManagementService.shared.calculateStorageUsage()
        }.value
        storageInfo = info
        isLoadingStorage = false
    }
    
    private func clearCache() {
        Task {
            do {
                try FileManagementService.shared.clearCache()
                await loadStorageInfo()
            } catch {
            }
        }
    }
    
    private func clearAllAnalysis() {
        Task { @MainActor in
            isClearingAnalysis = true

            do {
                // Fetch all audio files
                let audioFilesDescriptor = FetchDescriptor<AudioFile>()
                let audioFiles = try modelContext.fetch(audioFilesDescriptor)

                print("🧹 Clearing analysis for \(audioFiles.count) files...")

                // Record the clear date so iCloud-restored JSONs won't be re-loaded
                AnalysisResultPersistence.shared.recordAnalysisClearDate()

                // Step 1: Delete JSON files from iCloud on background thread (file I/O)
                let filesToDelete = audioFiles
                    .filter { !$0.isDemoFile }
                    .map { (fileName: $0.fileName, isDemo: $0.isDemoFile) }

                await Task.detached(priority: .utility) {
                    for file in filesToDelete {
                        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: file.fileName, isDemo: file.isDemo)
                    }
                }.value
                print("💾 Deleted \(filesToDelete.count) JSON files")

                // Step 2: Delete AnalysisResult objects and clear relationships for non-demo files
                var clearedCount = 0
                for audioFile in audioFiles where !audioFile.isDemoFile {
                    // Delete the AnalysisResult directly from context
                    if let result = audioFile.analysisResult {
                        audioFile.analysisResult = nil
                        modelContext.delete(result)
                    }
                    // Also delete analysis history
                    for historyResult in audioFile.analysisHistory {
                        modelContext.delete(historyResult)
                    }
                    audioFile.analysisHistory = []
                    audioFile.dateAnalyzed = nil
                    clearedCount += 1
                }

                // Step 3: Save all changes in one batch
                try modelContext.save()
                print("✅ Cleared analysis for \(clearedCount) files")

                // Yield to let UI update
                await Task.yield()

                // Step 4: Clean up any remaining orphaned AnalysisResults
                let analysisDescriptor = FetchDescriptor<AnalysisResult>()
                let remainingResults = try modelContext.fetch(analysisDescriptor)
                let orphaned = remainingResults.filter { $0.audioFile == nil || $0.audioFile?.isDemoFile == false }
                for result in orphaned {
                    modelContext.delete(result)
                }
                if !orphaned.isEmpty {
                    try modelContext.save()
                    print("🗑️ Cleaned up \(orphaned.count) orphaned results")
                }

                // Small delay for visual feedback
                try? await Task.sleep(nanoseconds: 500_000_000)

            } catch {
                print("❌ Error clearing analysis: \(error.localizedDescription)")
            }

            isClearingAnalysis = false
        }
    }
    
    private func storageBarColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return .green
        case 50..<75:
            return .yellow
        case 75..<90:
            return .orange
        default:
            return .red
        }
    }
    
    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image("AppIconDisplay")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        .padding(.top, 32)
                    
                    Text("Professional Audio Analysis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "waveform", title: "Audio Import", description: "Import and manage audio files")
                        FeatureRow(icon: "chart.bar.fill", title: "Analysis", description: "Advanced audio analysis powered by Claude Sonnet 4.5")
                        FeatureRow(icon: "icloud.fill", title: "iCloud Sync", description: "Sync across all your devices")
                        FeatureRow(icon: "play.circle.fill", title: "Playback", description: "High-quality audio playback")
                    }
                    .padding()
                    #if !targetEnvironment(macCatalyst)
                    .background(Color(.secondarySystemGroupedBackground))
                    #endif
                    .cornerRadius(12)
                    
                    Text("© 2025 MixDoctor. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 32)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Storage Info Row

struct StorageInfoRow: View {
    let title: String
    let value: String
    var bold: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(bold ? .body.weight(.semibold) : .body)
            Spacer()
            Text(value)
                .font(bold ? .body.weight(.semibold) : .body)
                .foregroundStyle(bold ? .primary : .secondary)
        }
    }
}

// MARK: - Restore Backup View

#Preview {
    SettingsView()
}
