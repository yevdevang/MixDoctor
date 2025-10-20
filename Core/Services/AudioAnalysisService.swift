//
//  AudioAnalysisService.swift
//  MixDoctor
//
//  Main service for audio analysis orchestration
//

import Foundation
import Observation

@Observable
final class AudioAnalysisService {
    
    private let processor = AudioProcessor()
    private let featureExtractor = AudioFeatureExtractor()
    private let stereoClassifier = StereoWidthClassifier()
    private let phaseDetector = PhaseProblemDetector()
    private let frequencyAnalyzer = FrequencyBalanceAnalyzer()
    
    var isAnalyzing: Bool = false
    var analysisProgress: Double = 0
    
    // MARK: - Main Analysis
    
    func analyzeAudio(_ audioFile: AudioFile) async throws -> AnalysisResult {
        isAnalyzing = true
        analysisProgress = 0
        
        defer {
            isAnalyzing = false
            analysisProgress = 0
        }
        
        // Load and process audio
        analysisProgress = 0.1
        let processedAudio = try processor.loadAudio(from: audioFile.fileURL)
        
        // Extract features
        analysisProgress = 0.3
        let stereoFeatures = featureExtractor.extractStereoFeatures(
            left: processedAudio.leftChannel,
            right: processedAudio.rightChannel
        )
        
        analysisProgress = 0.5
        let frequencyFeatures = try featureExtractor.extractFrequencyFeatures(
            audio: processedAudio.leftChannel,
            sampleRate: processedAudio.sampleRate
        )
        
        analysisProgress = 0.7
        let loudnessFeatures = featureExtractor.extractLoudnessFeatures(
            left: processedAudio.leftChannel,
            right: processedAudio.rightChannel
        )
        
        // Run analyzers
        analysisProgress = 0.8
        let stereoResult = stereoClassifier.classify(features: stereoFeatures)
        let phaseResult = phaseDetector.detect(stereoFeatures: stereoFeatures)
        let frequencyResult = frequencyAnalyzer.analyze(frequencyFeatures: frequencyFeatures)
        
        // Create analysis result
        analysisProgress = 0.9
        let result = AnalysisResult(audioFile: audioFile)
        
        // Populate metrics
        result.stereoWidthScore = Double(stereoFeatures.stereoWidth * 100)
        result.phaseCoherence = Double(stereoFeatures.correlation)
        
        result.frequencyBalance = FrequencyBalance(
            lowEnd: Double(frequencyResult.bassRatio * 100),
            lowMids: 0, // Simplified for now
            mids: Double(frequencyResult.midsRatio * 100),
            highMids: 0, // Simplified for now
            highs: Double(frequencyResult.highsRatio * 100)
        )
        
        result.dynamicRange = Double(loudnessFeatures.dynamicRange)
        result.loudnessLUFS = Double(loudnessFeatures.lufs)
        result.peakLevel = Double(20 * log10(loudnessFeatures.peakLevel + 0.0001))
        
        // Set issue flags
        result.hasPhaseIssues = phaseResult.hasIssue
        result.hasStereoIssues = stereoResult.classification != .good
        result.hasFrequencyImbalance = !frequencyResult.issues.isEmpty
        result.hasDynamicRangeIssues = loudnessFeatures.dynamicRange < Constants.Analysis.dynamicRangeMin || 
                                       loudnessFeatures.dynamicRange > Constants.Analysis.dynamicRangeMax
        
        // Aggregate recommendations
        var recommendations: [String] = []
        recommendations.append(stereoResult.recommendation)
        recommendations.append(phaseResult.recommendation)
        recommendations.append(contentsOf: frequencyResult.recommendations)
        
        if result.hasDynamicRangeIssues {
            if loudnessFeatures.dynamicRange < Constants.Analysis.dynamicRangeMin {
                recommendations.append("Dynamic range is too compressed. Consider reducing compression or using parallel compression.")
            } else {
                recommendations.append("Dynamic range is very wide. Consider light compression for consistency across playback systems.")
            }
        }
        
        if result.peakLevel > Constants.Analysis.peakLevelWarning {
            recommendations.append("Peak level is very close to 0 dBFS. Risk of clipping. Leave more headroom.")
        }
        
        result.recommendations = recommendations
        
        // Calculate overall score
        result.overallScore = calculateOverallScore(result: result)
        
        analysisProgress = 1.0
        
        return result
    }
    
    private func calculateOverallScore(result: AnalysisResult) -> Double {
        var score: Double = 100
        
        // Deduct points for issues
        if result.hasPhaseIssues {
            score -= result.phaseCoherence < Double(Constants.Analysis.phaseCorrelationError) ? 30 : 15
        }
        
        if result.hasStereoIssues {
            score -= 15
        }
        
        if result.hasFrequencyImbalance {
            score -= 20
        }
        
        if result.hasDynamicRangeIssues {
            score -= 10
        }
        
        // Peak level penalty
        if result.peakLevel > Double(Constants.Analysis.peakLevelWarning) {
            score -= 10 // Potential clipping
        }
        
        return max(0, score)
    }
}
