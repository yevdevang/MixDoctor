import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    // User Preferences
    var selectedTheme: String {
        get { UserDefaults.standard.string(forKey: "theme") ?? "system" }
        set {
            UserDefaults.standard.set(newValue, forKey: "theme")
            updatePreferences()
        }
    }
    
    var analysisSensitivity: String {
        get { UserDefaults.standard.string(forKey: "analysisSensitivity") ?? "medium" }
        set {
            UserDefaults.standard.set(newValue, forKey: "analysisSensitivity")
            updatePreferences()
        }
    }
    
    var autoAnalyze: Bool {
        get { UserDefaults.standard.bool(forKey: "autoAnalyze") }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoAnalyze")
            updatePreferences()
        }
    }
    
    var showDetailedMetrics: Bool {
        get { UserDefaults.standard.bool(forKey: "showDetailedMetrics") }
        set {
            UserDefaults.standard.set(newValue, forKey: "showDetailedMetrics")
            updatePreferences()
        }
    }
    
    var defaultExportFormat: String {
        get { UserDefaults.standard.string(forKey: "defaultExportFormat") ?? "pdf" }
        set {
            UserDefaults.standard.set(newValue, forKey: "defaultExportFormat")
            updatePreferences()
        }
    }
    
    var iCloudSyncEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled")
            // Post notification to update model container
            NotificationCenter.default.post(name: .iCloudSyncToggled, object: nil)
        }
    }
    
    var showResetConfirmation = false
    var showAbout = false
    
    init() {
        // Set default values if not set
        if UserDefaults.standard.object(forKey: "autoAnalyze") == nil {
            UserDefaults.standard.set(true, forKey: "autoAnalyze")
        }
        if UserDefaults.standard.object(forKey: "showDetailedMetrics") == nil {
            UserDefaults.standard.set(true, forKey: "showDetailedMetrics")
        }
    }
    
    func resetAllData() {
        Task {
            do {
                // Delete all SwiftData
                try await DataPersistenceService.shared.deleteAllData()
                
                // Delete all files
                let allFiles = try await DataPersistenceService.shared.fetchAllAudioFiles()
                let fileURLs = allFiles.map { $0.fileURL }
                try FileManagementService.shared.deleteAudioFiles(at: fileURLs)
                
                // Clear cache
                try FileManagementService.shared.clearCache()
                
                print("All data has been reset")
            } catch {
                print("Failed to reset data: \(error)")
            }
        }
    }
    
    private func updatePreferences() {
        Task {
            do {
                let preferences = try await DataPersistenceService.shared.fetchUserPreferences()
                preferences.theme = selectedTheme
                preferences.analysisSensitivity = analysisSensitivity
                preferences.autoAnalyze = autoAnalyze
                preferences.showDetailedMetrics = showDetailedMetrics
                preferences.defaultExportFormat = defaultExportFormat
                try await DataPersistenceService.shared.updateUserPreferences(preferences)
            } catch {
                print("Failed to update preferences: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let iCloudSyncToggled = Notification.Name("iCloudSyncToggled")
}

