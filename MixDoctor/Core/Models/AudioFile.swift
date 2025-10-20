import Foundation
import SwiftData

@Model
final class AudioFile {
    var id: UUID
    var fileName: String
    var fileURL: URL
    var duration: TimeInterval
    var sampleRate: Double
    var bitDepth: Int
    var numberOfChannels: Int
    var fileSize: Int64
    var dateImported: Date
    var dateAnalyzed: Date?
    var tags: [String]
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?
    
    @Relationship(deleteRule: .cascade)
    var analysisHistory: [AnalysisResult]

    init(
        fileName: String,
        fileURL: URL,
        duration: TimeInterval,
        sampleRate: Double,
        bitDepth: Int,
        numberOfChannels: Int,
        fileSize: Int64
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.numberOfChannels = numberOfChannels
        self.fileSize = fileSize
        self.dateImported = Date()
        self.tags = []
        self.notes = ""
        self.analysisHistory = []
    }
}

@Model
final class AnalysisResult {
    var id: UUID
    var audioFile: AudioFile?
    var dateAnalyzed: Date
    var analysisVersion: String  // Track which analysis method was used
    var overallScore: Double

    var stereoWidthScore: Double
    var phaseCoherence: Double
    var spectralCentroid: Double
    var hasClipping: Bool
    var lowEndBalance: Double
    var lowMidBalance: Double
    var midBalance: Double
    var highMidBalance: Double
    var highBalance: Double
    var dynamicRange: Double
    var loudnessLUFS: Double
    var peakLevel: Double

    var hasPhaseIssues: Bool
    var hasStereoIssues: Bool
    var hasFrequencyImbalance: Bool
    var hasDynamicRangeIssues: Bool

    var recommendations: [String]

    init(audioFile: AudioFile?, analysisVersion: String = "1.0") {
        self.id = UUID()
        self.audioFile = audioFile
        self.dateAnalyzed = Date()
        self.analysisVersion = analysisVersion
        self.overallScore = 0
        self.stereoWidthScore = 0
        self.phaseCoherence = 0
        self.spectralCentroid = 0
        self.hasClipping = false
    self.lowEndBalance = 0
    self.lowMidBalance = 0
    self.midBalance = 0
    self.highMidBalance = 0
    self.highBalance = 0
        self.dynamicRange = 0
        self.loudnessLUFS = 0
        self.peakLevel = 0
        self.hasPhaseIssues = false
        self.hasStereoIssues = false
        self.hasFrequencyImbalance = false
        self.hasDynamicRangeIssues = false
        self.recommendations = []
    }
}

extension AnalysisResult {
    var frequencyBalanceSummary: [Double] {
        [lowEndBalance, lowMidBalance, midBalance, highMidBalance, highBalance]
    }
    
    /// Overall frequency balance score (0-100)
    /// Calculated as average of all frequency bands
    var frequencyBalanceScore: Double {
        let bands = [lowEndBalance, midBalance, highBalance]
        let average = bands.reduce(0, +) / Double(bands.count)
        return average
    }
    
    var hasAnyIssues: Bool {
        hasPhaseIssues || hasStereoIssues || hasFrequencyImbalance || hasDynamicRangeIssues
    }
}
