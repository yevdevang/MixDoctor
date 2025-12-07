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
    @AppStorage("muteLaunchSound") private var muteLaunchSound = false
    @State private var showRatingTestAlert = false
    @State private var showCleanupAlert = false
    @State private var cleanupMessage = ""
    @State private var showDatabaseInfo = false
    @State private var databaseInfo = ""
    @Environment(\.modelContext) private var modelContext
    
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
                                .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
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
                    
                    Toggle("Auto-Analyze New Files", isOn: $viewModel.autoAnalyze)
                    
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
                    
                    // Cloud Storage Info - Pro users only
                    if subscriptionService.isProUser {
                        NavigationLink {
                            iCloudDebugView()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Cloud Storage Info")
                            }
                        }
                    }
                } header: {
                    Text("Cloud Storage")
                } footer: {
                    Text("When enabled, your audio file metadata and analysis results will be synced across all your devices. Audio files remain stored locally on each device. You'll need to restart the app for changes to take effect.")
                }
                
                // MARK: - Developer/Test Section
                #if DEBUG
                Section {
                    Button {
                        let descriptor = FetchDescriptor<AudioFile>()
                        if let allFiles = try? modelContext.fetch(descriptor) {
                            var info = "Total records: \(allFiles.count)\n\n"
                            for (index, file) in allFiles.enumerated() {
                                let exists = FileManager.default.fileExists(atPath: file.fileURL.path)
                                info += "[\(index + 1)] \(file.fileName)\n"
                                info += "   Size: \(file.fileSize) bytes\n"
                                info += "   Duration: \(String(format: "%.1f", file.duration))s\n"
                                info += "   Path: \(file.fileURL.path)\n"
                                info += "   EXISTS: \(exists ? "✅" : "❌")\n\n"
                            }
                            databaseInfo = info
                        } else {
                            databaseInfo = "Failed to fetch database records"
                        }
                        showDatabaseInfo = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundStyle(.blue)
                            Text("Show All Database Records")
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        Task {
                            let count = await DatabaseCleanup.shared.cleanupOrphanedRecords(modelContext: modelContext)
                            showCleanupAlert = true
                            cleanupMessage = "Removed \(count) orphaned record(s)"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                            Text("Clean Orphaned Records")
                            Spacer()
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        ratingService.forceShowRatingForTesting()
                        showRatingTestAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Test Rating Prompt")
                            Spacer()
                            Image(systemName: "flask")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        ratingService.resetAllRatingTracking()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.orange)
                            Text("Reset Rating Tracking")
                        }
                    }
                    
                    HStack {
                        Text("Total Analyses")
                        Spacer()
                        Text("\(subscriptionService.totalAnalysisCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("🧪 Test & Debug")
                } footer: {
                    Text("These options are only visible in debug builds")
                }
                #endif
                
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
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
            .alert("Rating Request Sent", isPresented: $showRatingTestAlert) {
                Button("OK") {}
            } message: {
                Text("The rating prompt was triggered. Apple controls if/when it actually appears. If you don't see it, try:\n\n1. Reset iPhone (Device menu)\n2. Delete and reinstall app\n3. Try on a real device instead of simulator")
            }
            .alert("Database Cleanup", isPresented: $showCleanupAlert) {
                Button("OK") { }
            } message: {
                Text(cleanupMessage)
            }
            .alert("Database Records", isPresented: $showDatabaseInfo) {
                Button("OK") { }
            } message: {
                Text(databaseInfo)
            }
            .sheet(isPresented: $viewModel.showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onPurchaseComplete: {
                    // Subscription service updates automatically via RevenueCat listener
                })
            }
            .task {
                // Refresh subscription status when view appears
                await subscriptionService.updateCustomerInfo()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadStorageInfo() async {
        isLoadingStorage = true
        do {
            storageInfo = try FileManagementService.shared.calculateStorageUsage()
        } catch {
        }
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
                    .background(Color(.secondarySystemGroupedBackground))
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
