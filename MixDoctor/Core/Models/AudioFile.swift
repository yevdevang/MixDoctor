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
    
    // Mixing Status
    var isProfessionallyMixed: Bool  // True if mixed, False if unmixed recording

    // Full FFT Spectrum Data for professional analyzer visualization
    // FIXED: Use @Transient with Data backing to prevent SwiftData detachment crashes
    @Transient
    var frequencySpectrum: [Float]? {
        get {
            guard let data = frequencySpectrumData else { return nil }
            // Convert Data back to [Float]
            let floatCount = data.count / MemoryLayout<Float>.size
            return data.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self).prefix(floatCount))
            }
        }
        set {
            guard let floats = newValue else {
                frequencySpectrumData = nil
                return
            }
            // Convert [Float] to Data
            frequencySpectrumData = floats.withUnsafeBytes { buffer in
                Data(buffer)
            }
        }
    }
    var frequencySpectrumData: Data?  // Backing storage for spectrum data
    var spectrumSampleRate: Double?  // Sample rate used for FFT

    // Unmixed Detection Result (stored as JSON data)
    @Transient
    var unmixedDetection: UnmixedDetectionResult? {
        get {
            guard let data = unmixedDetectionData else { return nil }
            return try? JSONDecoder().decode(UnmixedDetectionResult.self, from: data)
        }
        set {
            unmixedDetectionData = try? JSONEncoder().encode(newValue)
        }
    }
    var unmixedDetectionData: Data?  // Backing storage

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
        self.isProfessionallyMixed = true  // Assume mixed until proven otherwise
        
        // Initialize spectrum data backing storage
        self.frequencySpectrumData = nil
        self.spectrumSampleRate = nil
    }
}

extension AnalysisResult {
    var frequencyBalanceSummary: [Double] {
        [lowEndBalance, lowMidBalance, midBalance, highMidBalance, highBalance]
    }
    
    /// Overall frequency balance score (0-100)
    /// Evaluates how well-balanced the frequency spectrum is
    /// Higher score = better balance across all bands
    var frequencyBalanceScore: Double {
        let bands = [lowEndBalance, lowMidBalance, midBalance, highMidBalance, highBalance]
        
        // If all bands are 0, data hasn't been analyzed yet
        let total = bands.reduce(0, +)
        if total < 0.1 {
            return 0.0
        }
        
        // IMPROVED: More lenient ideal ranges to accommodate different genres and mixing styles
        // Professional mixes can vary widely based on genre and creative intent
        // Low End: 10-40% (was 15-35%), Low Mid: 12-35% (was 15-30%), Mid: 18-45% (was 20-40%)
        // High Mid: 10-35% (was 15-30%), High: 5-30% (was 10-25%)
        let idealRanges: [(min: Double, max: Double, weight: Double)] = [
            (10, 40, 1.2),  // Low End - WIDENED range (was 15-35)
            (12, 35, 1.0),  // Low Mid - WIDENED range (was 15-30)
            (18, 45, 1.5),  // Mid - WIDENED range (was 20-40)
            (10, 35, 1.0),  // High Mid - WIDENED range (was 15-30)
            (5, 30, 0.8)    // High - WIDENED range (was 10-25)
        ]
        
        var totalScore = 0.0
        var totalWeight = 0.0
        
        for (index, value) in bands.enumerated() {
            let (minIdeal, maxIdeal, weight) = idealRanges[index]
            
            // Calculate how well this band fits the ideal range
            let bandScore: Double
            if value >= minIdeal && value <= maxIdeal {
                // Perfect - in ideal range
                bandScore = 100.0
            } else if value < minIdeal {
                // Too low - score based on how far below minimum
                let deficit = minIdeal - value
                bandScore = max(0, 100 - (deficit * 2)) // REDUCED penalty: 3→2 points per % below
            } else {
                // Too high - score based on how far above maximum
                let excess = value - maxIdeal
                bandScore = max(0, 100 - (excess * 1.5)) // REDUCED penalty: 2→1.5 points per % above
            }
            
            totalScore += bandScore * weight
            totalWeight += weight
        }
        
        // Calculate weighted average
        let balanceScore = totalScore / totalWeight
        
        // Apply penalty for extreme imbalances (one band dominating)
        let maxBand = bands.max() ?? 0
        let minBand = bands.min() ?? 0
        let imbalanceRatio = maxBand > 0 ? (maxBand - minBand) / maxBand : 0
        
        // IMPROVED: More lenient imbalance threshold (0.66→0.75)
        // If one band is more than 4x another, apply additional penalty
        if imbalanceRatio > 0.75 {
            let imbalancePenalty = (imbalanceRatio - 0.75) * 40 // Reduced penalty: 50→40
            return max(0, balanceScore - imbalancePenalty)
        }
        
        return balanceScore
    }
    
    var hasAnyIssues: Bool {
        hasPhaseIssues || hasStereoIssues || hasFrequencyImbalance || hasDynamicRangeIssues
    }
}
