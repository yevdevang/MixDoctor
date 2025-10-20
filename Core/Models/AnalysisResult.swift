//
//  AnalysisResult.swift
//  MixDoctor
//
//  Data model for audio analysis results
//

import Foundation

@Observable
final class AnalysisResult: Identifiable {
    let id = UUID()
    let audioFile: AudioFile
    let analysisDate: Date
    
    // Stereo Analysis
    var stereoWidthScore: Double = 0
    var phaseCoherence: Double = 0
    
    // Frequency Analysis
    var frequencyBalance: FrequencyBalance = FrequencyBalance()
    
    // Dynamics & Loudness
    var dynamicRange: Double = 0
    var loudnessLUFS: Double = 0
    var peakLevel: Double = 0
    
    // Overall Assessment
    var overallScore: Double = 0
    var recommendations: [String] = []
    
    // Issue Flags
    var hasPhaseIssues: Bool = false
    var hasStereoIssues: Bool = false
    var hasFrequencyImbalance: Bool = false
    var hasDynamicRangeIssues: Bool = false
    
    init(audioFile: AudioFile) {
        self.audioFile = audioFile
        self.analysisDate = Date()
    }
    
    var hasAnyIssues: Bool {
        hasPhaseIssues || hasStereoIssues || hasFrequencyImbalance || hasDynamicRangeIssues
    }
    
    var scoreColor: String {
        switch overallScore {
        case 80...100:
            return "green"
        case 60..<80:
            return "yellow"
        default:
            return "red"
        }
    }
    
    var scoreDescription: String {
        switch overallScore {
        case 90...100:
            return "Excellent"
        case 80..<90:
            return "Very Good"
        case 70..<80:
            return "Good"
        case 60..<70:
            return "Fair"
        case 50..<60:
            return "Poor"
        default:
            return "Needs Work"
        }
    }
}

struct FrequencyBalance: Codable {
    var lowEnd: Double = 0      // 20-250 Hz
    var lowMids: Double = 0     // 250-500 Hz
    var mids: Double = 0        // 500-2000 Hz
    var highMids: Double = 0    // 2000-6000 Hz
    var highs: Double = 0       // 6000-20000 Hz
}
