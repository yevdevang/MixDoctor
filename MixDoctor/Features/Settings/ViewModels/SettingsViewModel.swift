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
            print("☁️ Theme saved to iCloud: \(selectedTheme)")
            
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
    
    // MARK: - Audio Analysis Settings
    
    /// Maximum duration for audio analysis in seconds
    /// Fixed at 60 seconds (1 minute)
    var maxAnalysisDuration: TimeInterval {
        return 60.0 // Fixed at 1 minute
    }
    
    /// Maximum number of analyses allowed per month
    /// Fixed at 50 analyses per month (not user-configurable)
    var maxAnalysesPerMonth: Int {
        return 50 // Fixed limit
    }
    
    /// Current month's analysis count
    var currentMonthAnalysisCount: Int {
        get {
            // Check if we're still in the same month
            let lastResetDate = cloudStore.object(forKey: "lastAnalysisResetDate") as? Date ?? Date.distantPast
            let calendar = Calendar.current
            
            if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
                // New month - reset counter
                resetMonthlyAnalysisCount()
                return 0
            }
            
            return Int(cloudStore.longLong(forKey: "currentMonthAnalysisCount"))
        }
        set {
            cloudStore.set(Int64(newValue), forKey: "currentMonthAnalysisCount")
            cloudStore.set(Date(), forKey: "lastAnalysisResetDate")
            cloudStore.synchronize()
        }
    }
    
    /// Remaining analyses for this month
    var remainingAnalyses: Int {
        max(0, maxAnalysesPerMonth - currentMonthAnalysisCount)
    }
    
    /// Check if user can perform another analysis
    var canPerformAnalysis: Bool {
        remainingAnalyses > 0
    }
    
    /// Progress percentage (0.0 - 1.0)
    var analysisProgress: Double {
        guard maxAnalysesPerMonth > 0 else { return 0.0 }
        return Double(currentMonthAnalysisCount) / Double(maxAnalysesPerMonth)
    }
    
    /// Preset limits for quick selection
    static let presetLimits: [(label: String, count: Int)] = [
        ("10 / month", 10),
        ("25 / month", 25),
        ("50 / month", 50),
        ("100 / month", 100),
        ("250 / month", 250),
        ("Unlimited", 1000)
    ]
    
    /// Days until reset
    var daysUntilReset: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: now))!
        let components = calendar.dateComponents([.day], from: now, to: startOfNextMonth)
        return components.day ?? 0
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
                print("📦 Migrated theme to iCloud: \(localTheme)")
            } else {
                cloudStore.set("system", forKey: "theme")
                print("📦 Set default theme in iCloud: system")
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
                    print("☁️ Theme updated from iCloud: \(newTheme)")
                }
            }
        }
        
        // Sync with iCloud on launch
        cloudStore.synchronize()
        
        // Check if month has changed and reset counter if needed
        _ = currentMonthAnalysisCount
        
        // Enable didSet observer after initialization
        isInitializing = false
    }
    
    // MARK: - Analysis Tracking Methods
    
    /// Increment the analysis counter (call this when user performs an analysis)
    func incrementAnalysisCount() {
        guard canPerformAnalysis else {
            print("⚠️ Monthly analysis limit reached")
            return
        }
        currentMonthAnalysisCount += 1
        print("📊 Analysis count: \(currentMonthAnalysisCount)/\(maxAnalysesPerMonth)")
    }
    
    /// Reset monthly analysis counter
    private func resetMonthlyAnalysisCount() {
        cloudStore.set(Int64(0), forKey: "currentMonthAnalysisCount")
        cloudStore.set(Date(), forKey: "lastAnalysisResetDate")
        cloudStore.synchronize()
        print("🔄 Monthly analysis counter reset")
    }
    
    /// Manually reset counter (for testing or admin purposes)
    func manuallyResetAnalysisCount() {
        resetMonthlyAnalysisCount()
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
                preferences.autoAnalyze = autoAnalyze
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

// MARK: - Calendar Extension
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}

