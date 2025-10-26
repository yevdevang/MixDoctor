import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    // MARK: - Mock Testing - Switch to SubscriptionService.shared for production
    @State private var mockService = MockSubscriptionService.shared
    @State private var storageInfo: StorageInfo?
    @State private var backups: [BackupInfo] = []
    @State private var isLoadingStorage = false
    @State private var isLoadingBackups = false
    @State private var showCreateBackupAlert = false
    @State private var showRestoreBackupSheet = false
    @State private var showClearCacheAlert = false
    @State private var showDeleteOldFilesSheet = false
    @State private var showPaywall = false
    @State private var showCancelSubscriptionAlert = false
    @State private var isCancelling = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Subscription Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Status")
                                .font(.headline)
                            Text(mockService.isProUser ? "Pro" : "Free (\(mockService.remainingFreeAnalyses)/5 analyses)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if mockService.isProUser {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !mockService.isProUser {
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
                        
                        // Mock testing: Cancel subscription button
                        Button(role: .destructive) {
                            showCancelSubscriptionAlert = true
                        } label: {
                            HStack {
                                if isCancelling {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Cancelling...")
                                } else {
                                    Image(systemName: "xmark.circle")
                                    Text("Cancel Subscription")
                                }
                            }
                        }
                        .disabled(isCancelling)
                    }
                } header: {
                    Text("Subscription")
                }
                
                // MARK: - Preferences Section
                Section {
                    Picker("Theme", selection: $viewModel.selectedTheme) {
                        ForEach(ThemeOption.allCases) { theme in
                            Text(theme.rawValue).tag(theme.id)
                        }
                    }
                    
                    Picker("Analysis Sensitivity", selection: $viewModel.analysisSensitivity) {
                        ForEach(AnalysisSensitivity.allCases) { sensitivity in
                            Text(sensitivity.rawValue).tag(sensitivity.rawValue)
                        }
                    }
                    
                    Toggle("Auto-Analyze New Files", isOn: $viewModel.autoAnalyze)
                    
                    Toggle("Show Detailed Metrics", isOn: $viewModel.showDetailedMetrics)
                } header: {
                    Text("Preferences")
                } footer: {
                    if let sensitivity = AnalysisSensitivity.allCases.first(where: { $0.rawValue == viewModel.analysisSensitivity }) {
                        Text(sensitivity.description)
                    }
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
                    
                    Button {
                        showDeleteOldFilesSheet = true
                    } label: {
                        Label("Delete Old Files", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Storage Management")
                } footer: {
                    Text("Free up space by clearing cache or deleting old files")
                }
                
                // MARK: - Backup & Restore Section
                Section {
                    Button {
                        createBackup()
                    } label: {
                        Label("Create Backup", systemImage: "externaldrive")
                    }
                    
                    if !backups.isEmpty {
                        Button {
                            showRestoreBackupSheet = true
                        } label: {
                            HStack {
                                Label("Restore from Backup", systemImage: "arrow.counterclockwise")
                                Spacer()
                                Text("\(backups.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Backup & Restore")
                } footer: {
                    Text("Create backups to preserve your analysis results and restore them later if needed")
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
                                
                                Text("Sync your audio files across devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(Color.accentColor)
                } header: {
                    Text("Cloud Storage")
                } footer: {
                    Text("When enabled, your imported audio files and analysis results will be synced across all your devices using iCloud. You'll need to restart the app for changes to take effect.")
                }
                
                // MARK: - Danger Zone Section
                Section {
                    Button(role: .destructive) {
                        viewModel.showResetConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will permanently delete all data and cannot be undone")
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
            }
            .navigationTitle("Settings")
            .task {
                await loadStorageInfo()
                await loadBackups()
            }
            .refreshable {
                await loadStorageInfo()
                await loadBackups()
            }
            .confirmationDialog("Clear All Data", isPresented: $viewModel.showResetConfirmation, titleVisibility: .visible) {
                Button("Clear All Data", role: .destructive) {
                    viewModel.resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all imported audio files and analysis results. This action cannot be undone.")
            }
            .alert("Cache Cleared", isPresented: $showClearCacheAlert) {
                Button("Clear Cache", role: .destructive) {
                    clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up space by removing temporary files")
            }
            .alert("Backup Created", isPresented: $showCreateBackupAlert) {
                Button("OK") {}
            } message: {
                Text("Your data has been backed up successfully")
            }
            .sheet(isPresented: $viewModel.showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showRestoreBackupSheet) {
                RestoreBackupView(backups: backups)
            }
            .sheet(isPresented: $showDeleteOldFilesSheet) {
                DeleteOldFilesView()
            }
            .sheet(isPresented: $showPaywall) {
                MockPaywallView(onPurchaseComplete: {
                    // Mock service updates automatically
                })
            }
            .alert("Cancel Subscription?", isPresented: $showCancelSubscriptionAlert) {
                Button("Cancel Subscription", role: .destructive) {
                    Task {
                        await cancelSubscription()
                    }
                }
                Button("Keep Subscription", role: .cancel) {}
            } message: {
                Text("Your Pro features will end immediately and you'll return to the Free tier with 5 analyses per month. You can resubscribe anytime.")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadStorageInfo() async {
        isLoadingStorage = true
        do {
            storageInfo = try FileManagementService.shared.calculateStorageUsage()
        } catch {
            print("Failed to load storage info: \(error)")
        }
        isLoadingStorage = false
    }
    
    private func loadBackups() async {
        isLoadingBackups = true
        do {
            backups = try FileManagementService.shared.listBackups()
        } catch {
            print("Failed to load backups: \(error)")
        }
        isLoadingBackups = false
    }
    
    private func createBackup() {
        Task {
            do {
                _ = try FileManagementService.shared.createBackup()
                showCreateBackupAlert = true
                await loadBackups()
            } catch {
                print("Failed to create backup: \(error)")
            }
        }
    }
    
    private func cancelSubscription() async {
        isCancelling = true
        
        let success = await mockService.mockCancelSubscription()
        
        isCancelling = false
        
        if success {
            print("✓ Subscription cancelled successfully")
            // UI will update automatically via @Observable
        }
    }
    
    private func clearCache() {
        Task {
            do {
                try FileManagementService.shared.clearCache()
                await loadStorageInfo()
            } catch {
                print("Failed to clear cache: \(error)")
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
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 32)
                    
                    VStack(spacing: 8) {
                        Text("MixDoctor")
                            .font(.title.weight(.bold))
                        
                        Text("Professional Audio Analysis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "waveform", title: "Audio Import", description: "Import and manage audio files")
                        FeatureRow(icon: "chart.bar.fill", title: "Analysis", description: "Advanced audio analysis powered by CoreML")
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

struct RestoreBackupView: View {
    @Environment(\.dismiss) private var dismiss
    let backups: [BackupInfo]
    @State private var selectedBackup: BackupInfo?
    @State private var showRestoreConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(backups, id: \.url) { backup in
                    Button {
                        selectedBackup = backup
                        showRestoreConfirmation = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(backup.name)
                                .font(.headline)
                            
                            HStack {
                                Label(backup.formattedDate, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Label(backup.formattedSize, systemImage: "externaldrive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { indexSet in
                    deleteBackups(at: indexSet)
                }
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Restore Backup", isPresented: $showRestoreConfirmation) {
                Button("Restore", role: .destructive) {
                    restoreBackup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace all current data with the backup. This action cannot be undone.")
            }
        }
    }
    
    private func deleteBackups(at offsets: IndexSet) {
        for index in offsets {
            let backup = backups[index]
            try? FileManagementService.shared.deleteBackup(at: backup.url)
        }
    }
    
    private func restoreBackup() {
        // Restoration logic would go here
        // This is a placeholder for now
        dismiss()
    }
}

// MARK: - Delete Old Files View

struct DeleteOldFilesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDays = 30
    @State private var showConfirmation = false
    
    let dayOptions = [7, 14, 30, 60, 90, 180]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Delete files older than", selection: $selectedDays) {
                        ForEach(dayOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                } header: {
                    Text("Time Period")
                } footer: {
                    Text("Files imported more than \(selectedDays) days ago will be permanently deleted")
                }
                
                Section {
                    Button(role: .destructive) {
                        showConfirmation = true
                    } label: {
                        Label("Delete Old Files", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Delete Old Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Old Files", isPresented: $showConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteOldFiles()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all files older than \(selectedDays) days. This action cannot be undone.")
            }
        }
    }
    
    private func deleteOldFiles() {
        Task {
            do {
                let deletedCount = try FileManagementService.shared.deleteOldFiles(olderThan: selectedDays)
                print("Deleted \(deletedCount) files")
                dismiss()
            } catch {
                print("Failed to delete old files: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
}
