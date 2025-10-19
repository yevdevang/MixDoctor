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

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?

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
    }
}

@Model
final class AnalysisResult {
    var id: UUID
    var audioFile: AudioFile?
    var dateAnalyzed: Date
    var overallScore: Double

    var stereoWidthScore: Double
    var phaseCoherence: Double
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

    init(audioFile: AudioFile?) {
        self.id = UUID()
        self.audioFile = audioFile
        self.dateAnalyzed = Date()
        self.overallScore = 0
        self.stereoWidthScore = 0
        self.phaseCoherence = 0
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
}
