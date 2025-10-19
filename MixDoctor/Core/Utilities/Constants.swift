import SwiftUI

enum AppConstants {
    // Audio settings
    static let supportedAudioFormats: Set<String> = ["wav", "aiff", "aif", "mp3", "m4a", "flac"]
    static let maxFileSizeMB: Int64 = 500
    static let minSampleRate: Double = 44_100.0

    // UI settings
    static let cornerRadius: CGFloat = 12
    static let defaultPadding: CGFloat = 16
    static let animationDuration: Double = 0.3
}
