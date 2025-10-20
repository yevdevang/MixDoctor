import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
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
    
    init() {}
    
    func resetAllData() {
        // This will be implemented to clear all SwiftData
        // For now, just a placeholder
    }
}

extension Notification.Name {
    static let iCloudSyncToggled = Notification.Name("iCloudSyncToggled")
}
