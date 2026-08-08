import SwiftUI
import Foundation

enum AppConstants {
    // Audio settings
    static let supportedAudioFormats: Set<String> = ["wav", "mp3"]
    static let maxFileSizeMB: Int64 = 500
    static let minSampleRate: Double = 44_100.0
    static let fftSize = 8192  // FFT size for frequency analysis

    // Genre options
    static let availableGenres = [
        "Pop",
        "Rock/Indie",
        "Hip-Hop/R&B",
        "EDM/Electronic",
        "Jazz",
        "Classical/Orchestral",
        "Metal",
        "Acapella",
        "Live"
    ]

    // UI settings
    static let cornerRadius: CGFloat = 12
    static let defaultPadding: CGFloat = 16
    static let animationDuration: Double = 0.3
    
    // Versioning
    static let appVersion = "1.0.0"
    static let analysisVersion = "4.3"  // Generate + store spectrogram image (sent to Claude, shown in Results)
    
    // Storage
    static let maxStorageGB: Int64 = 10
    static let backupRetentionDays = 30
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioFileDeleted = Notification.Name("audioFileDeleted")
    static let iCloudSyncCompleted = Notification.Name("iCloudSyncCompleted")
    static let iCloudFilesChanged = Notification.Name("iCloudFilesChanged")
    static let iCloudSyncToggled = Notification.Name("iCloudSyncToggled")
    static let analysisCleared = Notification.Name("analysisCleared")
}
