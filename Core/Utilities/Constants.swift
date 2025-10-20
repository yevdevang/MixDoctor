//
//  Constants.swift
//  MixDoctor
//
//  Application-wide constants
//

import Foundation

enum Constants {
    // MARK: - Audio Analysis
    static let fftSize = 8192
    static let maxAudioFileSizeBytes: Int64 = 500_000_000 // 500 MB
    
    // MARK: - File Support
    static let supportedAudioFormats = ["wav", "aiff", "mp3", "m4a", "caf"]
    
    // MARK: - Analysis Thresholds
    enum Analysis {
        static let phaseCorrelationWarning: Float = 0.3
        static let phaseCorrelationError: Float = -0.3
        static let stereoWidthNarrow: Float = 0.3
        static let stereoWidthWide: Float = 0.7
        static let dynamicRangeMin: Float = 6.0
        static let dynamicRangeMax: Float = 20.0
        static let peakLevelWarning: Float = -0.1
        static let idealBassRatio: Float = 0.3
        static let idealMidsRatio: Float = 0.4
        static let idealHighsRatio: Float = 0.3
    }
    
    // MARK: - UI
    enum UI {
        static let animationDuration: Double = 0.3
        static let cornerRadius: CGFloat = 12
        static let standardPadding: CGFloat = 16
    }
}
