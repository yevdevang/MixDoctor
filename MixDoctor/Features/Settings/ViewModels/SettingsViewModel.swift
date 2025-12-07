import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    // Use iCloud Key-Value Store for cross-device sync
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var isInitializing = true
    
    // User Preferences with iCloud backing - stored property for Picker binding
    var selectedTheme: String = "system" {
        didSet {
            guard !isInitializing else { return }
            cloudStore.set(selectedTheme, forKey: "theme")
            cloudStore.synchronize()
            
            // Notify ContentView to update immediately
            NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
            
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
    
    var iCloudSyncEnabled: Bool {
        get {
            // Default to true if not set (for better UX - CloudKit enabled by default)
            UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
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
        // Load theme from iCloud
        selectedTheme = cloudStore.string(forKey: "theme") ?? "system"
        
        // Set default values if not set
        if UserDefaults.standard.object(forKey: "autoAnalyze") == nil {
            UserDefaults.standard.set(true, forKey: "autoAnalyze")
        }
        
        // Migrate theme from UserDefaults to iCloud if needed
        if cloudStore.string(forKey: "theme") == nil {
            if let localTheme = UserDefaults.standard.string(forKey: "theme") {
                cloudStore.set(localTheme, forKey: "theme")
                selectedTheme = localTheme
            } else {
                cloudStore.set("system", forKey: "theme")
            }
        }
        
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                let newTheme = self.cloudStore.string(forKey: "theme") ?? "system"
                if self.selectedTheme != newTheme {
                    self.selectedTheme = newTheme
                }
            }
        }
        
        // Sync with iCloud on launch
        cloudStore.synchronize()
        
        // Enable didSet observer after initialization
        isInitializing = false
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
                
            } catch {
            }
        }
    }
    
    private func updatePreferences() {
        Task {
            do {
                let preferences = try await DataPersistenceService.shared.fetchUserPreferences()
                preferences.theme = selectedTheme
                preferences.autoAnalyze = autoAnalyze
                try await DataPersistenceService.shared.updateUserPreferences(preferences)
            } catch {
            }
        }
    }
}
