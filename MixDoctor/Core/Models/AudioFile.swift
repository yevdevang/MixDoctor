import Foundation
import SwiftData

/// Audio file model that stores metadata and references to imported audio files.
/// 
/// **File Persistence Strategy:**
/// Files are copied to the app's Documents/AudioFiles directory during import.
/// Only the filename is stored in the database (storedFileName), not the full path.
/// The fileURL is computed dynamically to ensure it always points to the correct location,
/// even if the app container changes (common in iOS Simulator).
@Model
final class AudioFile {
    var id: UUID
    var fileName: String
    private var storedFileName: String  // Store only the filename, not full path
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
    
    // Computed property that always returns the correct URL based on current app container
    @Transient
    var fileURL: URL {
        get {
            // Use iCloud storage service to get the correct directory
            let audioDir = iCloudStorageService.shared.getAudioFilesDirectory()
            return audioDir.appendingPathComponent(storedFileName)
        }
        set {
            storedFileName = newValue.lastPathComponent
        }
    }

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
        self.storedFileName = fileURL.lastPathComponent
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
    var rmsLevel: Double                // RMS level in dBFS
    var truePeakLevel: Double           // True peak level in dBTP

    var hasPhaseIssues: Bool
    var hasStereoIssues: Bool
    var hasFrequencyImbalance: Bool
    var hasDynamicRangeIssues: Bool

    var recommendations: [String]
    
    // Frequency Balance Analysis
    var frequencyBalanceScore: Double  // 0-100, overall balance quality
    var frequencyBalanceStatus: String  // "balanced", "bass-heavy", "mid-heavy", "treble-heavy"
    var lowFrequencyPercent: Double     // % of total energy in low range (20-250 Hz)
    var midFrequencyPercent: Double     // % of total energy in mid range (250-4000 Hz)
    var highFrequencyPercent: Double    // % of total energy in high range (4000-16000 Hz)
    
    // Store frequency spectrum image ID (audio file UUID)
    var hasFrequencySpectrumImage: Bool
    
    // MARK: - Stem-Based Mix Analysis (optional, advanced feature)
    
    // Stem level balance
    var hasStemAnalysis: Bool            // Whether stem separation was performed
    var vocalsLevel: Double              // 0-1, relative level
    var drumsLevel: Double               // 0-1, relative level
    var bassLevel: Double                // 0-1, relative level
    var otherInstrumentsLevel: Double    // 0-1, relative level
    
    // Mix depth and spatial characteristics
    var mixDepthScore: Double            // 0-100, how much depth/dimension
    var foregroundClarityScore: Double   // 0-100, clarity of lead elements
    var elementSeparationScore: Double   // 0-100, how distinct elements are
    var backgroundAmbienceScore: Double  // 0-100, reverb/space amount
    
    // Stem-specific stereo width
    var vocalsStereoWidth: Double        // 0-100, % stereo width
    var drumsStereoWidth: Double         // 0-100, % stereo width
    var bassStereoWidth: Double          // 0-100, % stereo width
    
    // Spatial placement descriptions
    var vocalsPlacement: String          // e.g., "center", "wide", "center-left"
    var drumsPlacement: String
    var bassPlacement: String
    
    // Frequency masking and mix density
    var frequencyMaskingScore: Double    // 0-100, overlap between stems (lower is better)
    var mixDensityScore: Double          // 0-100, how "full" the mix is
    
    // MARK: - AI-Generated Analysis Text
    var stereoAnalysis: String?          // Detailed stereo width assessment
    var frequencyAnalysis: String?       // Detailed frequency balance assessment
    var dynamicsAnalysis: String?        // Detailed dynamics assessment
    var detailedSummary: String?         // Overall mix assessment
    
    // MARK: - Mix Cohesion Analysis
    var mixCohesionScore: Double         // 0-100, overall cohesion quality
    var spectralCoherence: Double        // 0-100, how well frequencies complement
    var phaseIntegrity: Double           // 0-100, phase relationship quality
    var dynamicConsistency: Double       // 0-100, processing uniformity
    var spatialBalance: Double           // 0-100, stereo field balance
    var mixDepth: Double                 // 0-100, front-to-back dimension

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
        self.rmsLevel = 0
        self.truePeakLevel = 0
        self.hasPhaseIssues = false
        self.hasStereoIssues = false
        self.hasFrequencyImbalance = false
        self.hasDynamicRangeIssues = false
        self.recommendations = []
        self.frequencyBalanceScore = 0
        self.frequencyBalanceStatus = "unknown"
        self.lowFrequencyPercent = 0
        self.midFrequencyPercent = 0
        self.highFrequencyPercent = 0
        self.hasFrequencySpectrumImage = false
        self.hasStemAnalysis = false
        self.vocalsLevel = 0
        self.drumsLevel = 0
        self.bassLevel = 0
        self.otherInstrumentsLevel = 0
        self.mixDepthScore = 0
        self.foregroundClarityScore = 0
        self.elementSeparationScore = 0
        self.backgroundAmbienceScore = 0
        self.vocalsStereoWidth = 0
        self.drumsStereoWidth = 0
        self.bassStereoWidth = 0
        self.vocalsPlacement = ""
        self.drumsPlacement = ""
        self.bassPlacement = ""
        self.frequencyMaskingScore = 0
        self.mixDensityScore = 0
        self.stereoAnalysis = nil
        self.frequencyAnalysis = nil
        self.dynamicsAnalysis = nil
        self.detailedSummary = nil
        self.mixCohesionScore = 0
        self.spectralCoherence = 0
        self.phaseIntegrity = 0
        self.dynamicConsistency = 0
        self.spatialBalance = 0
        self.mixDepth = 0
    }
}

extension AnalysisResult {
    var frequencyBalanceSummary: [Double] {
        [lowEndBalance, lowMidBalance, midBalance, highMidBalance, highBalance]
    }
    
    var hasAnyIssues: Bool {
        hasPhaseIssues || hasStereoIssues || hasFrequencyImbalance || hasDynamicRangeIssues
    }
}
