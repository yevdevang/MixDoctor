import SwiftUI
import Foundation

enum AppConstants {
    // Audio settings
    static let supportedAudioFormats: Set<String> = ["wav", "mp3"]
    static let maxFileSizeMB: Int64 = 500
    static let minSampleRate: Double = 44_100.0
    static let fftSize = 8192  // FFT size for frequency analysis

    // UI settings
    static let cornerRadius: CGFloat = 12
    static let defaultPadding: CGFloat = 16
    static let animationDuration: Double = 0.3
    
    // Versioning
    static let appVersion = "1.0.0"
    static let analysisVersion = "3.4"  // Added critical mono override (<45%) + enhanced debug logging
    
    // Storage
    static let maxStorageGB: Int64 = 10
    static let backupRetentionDays = 30
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioFileDeleted = Notification.Name("audioFileDeleted")
}
