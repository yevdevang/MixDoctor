import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
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
                
                // MARK: - Storage Section
                Section {
                    HStack {
                        Text("Local Storage")
                        Spacer()
                        Text(calculateStorageSize())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        viewModel.showResetConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Storage")
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
            .confirmationDialog("Clear All Data", isPresented: $viewModel.showResetConfirmation, titleVisibility: .visible) {
                Button("Clear All Data", role: .destructive) {
                    viewModel.resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all imported audio files and analysis results. This action cannot be undone.")
            }
            .sheet(isPresented: $viewModel.showAbout) {
                AboutView()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateStorageSize() -> String {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return "Unknown"
        }
        
        do {
            let size = try FileManager.default.allocatedSizeOfDirectory(at: documentsPath)
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } catch {
            return "Unknown"
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

// MARK: - FileManager Extension

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int {
        guard let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey]
        ) else {
            return 0
        }
        
        var totalSize = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            totalSize += resourceValues.totalFileAllocatedSize ?? 0
        }
        
        return totalSize
    }
}

#Preview {
    SettingsView()
}
