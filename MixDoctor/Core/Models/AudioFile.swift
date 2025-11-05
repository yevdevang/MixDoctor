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
public final class AudioFile {
    public var id: UUID
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
    
    // MARK: - Simplified Mix Quality Computed Properties
    
    /// Boolean indicator for overall mix quality
    /// Returns true if the mix has good balance and minimal technical issues
    var isWellMixed: Bool {
        guard let result = analysisResult else { return false }
        
        // More realistic criteria for "well mixed":
        // 1. No critical technical issues (severe phase problems, extreme compression)
        let hasNoMajorIssues = !result.hasPhaseIssues && !result.hasDynamicRangeIssues
        
        // 2. No severe frequency imbalance (only flag extreme cases)
        let hasReasonableFrequencyBalance = !result.hasFrequencyImbalance
        
        // 3. No clipping
        let hasCleanAudio = !result.hasClipping
        
        // A mix can be "well mixed" even with genre-specific characteristics
        // We only flag technical problems, not aesthetic choices
        return hasNoMajorIssues && hasReasonableFrequencyBalance && hasCleanAudio
    }
    
    /// Boolean indicator if the mix needs improvement
    /// Returns true if there are technical issues to address
    var needsMixImprovement: Bool {
        guard let result = analysisResult else { return true }
        
        // Flag mixes that have technical problems requiring attention
        return result.hasPhaseIssues || result.hasFrequencyImbalance || 
               result.hasDynamicRangeIssues || result.hasClipping
    }
    
    /// Boolean indicator if the mix is ready for mastering
    /// Returns true if the mix quality is technically sound for mastering
    var isReadyForMastering: Bool {
        guard let result = analysisResult else { return false }
        
        // Ready for mastering if there are no critical technical issues
        // Genre-specific frequency balance is acceptable
        let hasSoundTechnicals = !result.hasPhaseIssues && !result.hasClipping && !result.hasDynamicRangeIssues
        
        // Allow for some frequency imbalance as it might be intentional genre characteristics
        // Only block mastering for severe technical frequency problems
        return hasSoundTechnicals
    }
}

@Model
public final class AnalysisResult {
    public var id: UUID
    var audioFile: AudioFile?
    var dateAnalyzed: Date
    var analysisVersion: String  // Track which analysis method was used
    var overallScore: Double

    var stereoWidthScore: Double
    var phaseCoherence: Double
    var monoCompatibility: Double
    var spectralCentroid: Double
    var hasClipping: Bool
    var lowEndBalance: Double
    var lowMidBalance: Double
    var midBalance: Double
    var highMidBalance: Double
    var highBalance: Double
    var dynamicRange: Double
    var loudnessLUFS: Double
    var rmsLevel: Double
    var peakLevel: Double

    var hasPhaseIssues: Bool
    var hasStereoIssues: Bool
    var hasFrequencyImbalance: Bool
    var hasDynamicRangeIssues: Bool
    
    // Instrument Balance Properties
    var instrumentBalanceScore: Double  // Overall balance score 0-100
    var hasInstrumentBalanceIssues: Bool
    var kickEnergy: Double
    var bassEnergy: Double
    var vocalEnergy: Double
    var guitarEnergy: Double
    var cymbalEnergy: Double

    var recommendations: [String]
    
    // AI Analysis Fields
    var stereoAnalysis: String
    var frequencyAnalysis: String
    var dynamicsAnalysis: String
    var effectsAnalysis: String
    var detailedSummary: String
    
    // Claude AI Analysis Fields
    var aiSummary: String?
    var aiRecommendations: [String]
    var claudeScore: Int?
    var isReadyForMastering: Bool

    init(audioFile: AudioFile?, analysisVersion: String = "1.0") {
        self.id = UUID()
        self.audioFile = audioFile
        self.dateAnalyzed = Date()
        self.analysisVersion = analysisVersion
        self.overallScore = 0
        self.stereoWidthScore = 0
        self.phaseCoherence = 0
        self.monoCompatibility = 1.0
        self.spectralCentroid = 0
        self.hasClipping = false
        self.lowEndBalance = 0
        self.lowMidBalance = 0
        self.midBalance = 0
         self.highMidBalance = 0
        self.highBalance = 0
        self.dynamicRange = 0
        self.loudnessLUFS = 0
        self.rmsLevel = 0
        self.peakLevel = 0
        self.hasPhaseIssues = false
        self.hasStereoIssues = false
        self.hasFrequencyImbalance = false
        self.hasDynamicRangeIssues = false
        
        // Initialize instrument balance properties
        self.instrumentBalanceScore = 0
        self.hasInstrumentBalanceIssues = false
        self.kickEnergy = 0
        self.bassEnergy = 0
        self.vocalEnergy = 0
        self.guitarEnergy = 0
        self.cymbalEnergy = 0
        
        self.recommendations = []
        
        // Initialize AI analysis fields
        self.stereoAnalysis = ""
        self.frequencyAnalysis = ""
        self.dynamicsAnalysis = ""
        self.effectsAnalysis = ""
        self.detailedSummary = ""
        
        // Initialize Claude AI analysis fields
        self.aiSummary = nil
        self.aiRecommendations = []
        self.claudeScore = nil
        self.isReadyForMastering = false
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
