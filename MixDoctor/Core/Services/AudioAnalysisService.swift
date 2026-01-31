//
//  AudioAnalysisService.swift
//  MixDoctor
//
//  Main service for audio analysis orchestration
//  
//  🔄 MIGRATION NOTE: Consider replacing with AudioKitService
//  This service uses basic AVFoundation analysis. AudioKit provides:
//  - More accurate FFT analysis
//  - Real-time spectrum analysis  
//  - Advanced pitch detection
//  - Better frequency analysis
//  - Professional audio processing capabilities
//

import Foundation
import Observation
import AVFoundation
import SwiftUI

@Observable
final class AudioAnalysisService {
    
    // Add shared singleton instance
    static let shared = AudioAnalysisService()
    
    // 🔄 REPLACE: Basic audio processing - AudioKit has better analysis
    // Temporarily commented out due to compilation issues
    // private let processor = AudioProcessor()
    // private let featureExtractor = AudioFeatureExtractor()
    
    // ✅ KEEP: UI state management
    var isAnalyzing: Bool = false
    var analysisProgress: Double = 0
    
    // Make init private for singleton pattern
    private init() {}
    
    // MARK: - Testing Support
    
    /// Reset service state - primarily for testing purposes
    /// Call this in test tearDown to ensure clean state between tests
    func reset() {
        isAnalyzing = false
        analysisProgress = 0
    }
    
    // MARK: - Main Analysis
    
    // URL-based analysis method for compatibility - Temporarily disabled
    /*
    func getDetailedAnalysis(for url: URL) async throws -> AnalysisResult {
        // Create AudioFile from URL
        let audioFile = AudioFile(url)
        return try await analyzeAudio(audioFile)
    }
    
    // 🔄 REPLACE: This entire analysis pipeline can be replaced with AudioKit's more sophisticated analysis
    // AudioKit provides: FFTTap, AmplitudeTracker, PitchTap, and real-time frequency analysis
    func analyzeAudio(_ audioFile: AudioFile) async throws -> AnalysisResult {
        // ✅ KEEP: Progress tracking and UI state
        isAnalyzing = true
        analysisProgress = 0
        
        defer {
            isAnalyzing = false
            analysisProgress = 0
        }

        // 🔄 REPLACE: File handling - AudioKit handles file loading better
        // Verify file exists before attempting analysis
        let fileURL = audioFile.fileURL        // Try both the original path and potential URL-decoded version
        var fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        var actualURL = fileURL
        
        // If not found, try looking for files in the directory that match the decoded name
        if !fileExists {
            let fileName = fileURL.lastPathComponent
            let directory = fileURL.deletingLastPathComponent()
            
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
                // Look for a file that matches when URL-decoded
                if let matchingFile = contents.first(where: { $0 == fileName.removingPercentEncoding }) {
                    actualURL = directory.appendingPathComponent(matchingFile)
                    fileExists = FileManager.default.fileExists(atPath: actualURL.path)
                    if fileExists {
                    }
                }
            }
        }
        
        
        // If file doesn't exist, list directory contents for debugging
        if !fileExists {
            let directory = fileURL.deletingLastPathComponent()
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
            }
        }
        
        guard fileExists else {
            throw NSError(domain: "AudioAnalysisService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Audio file not found at path: \(fileURL.path). Please delete and re-import this file."
            ])
        }
        
        // 🔄 REPLACE: Basic audio loading - AudioKit's AudioPlayer is more robust
        // Load and process audio using the actual URL that exists
        analysisProgress = 0.1
        let processedAudio = try processor.loadAudio(from: actualURL)
        
        // 🔄 REPLACE: Manual feature extraction - AudioKit provides built-in analysis
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
        
        // Calculate technical metrics
        let peakLevelDB = 20 * log10(loudnessFeatures.peakLevel + 0.0001)
        let rmsLevelDB = 20 * log10(loudnessFeatures.rmsLevel + 0.0001)
        
        // Extract frequency band energies (use correct band ranges)
        // Available bands: 20 (sub_bass), 60 (bass), 250 (low_mids), 500 (mids), 2000 (high_mids), 6000 (highs)
        let subBass: Float = frequencyFeatures.frequencyBands[20.0] ?? 0
        let bass: Float = frequencyFeatures.frequencyBands[60.0] ?? 0
        let lowMids: Float = frequencyFeatures.frequencyBands[250.0] ?? 0
        let mids: Float = frequencyFeatures.frequencyBands[500.0] ?? 0
        let highMids: Float = frequencyFeatures.frequencyBands[2000.0] ?? 0
        let highs: Float = frequencyFeatures.frequencyBands[6000.0] ?? 0
        
        // Combine for low/mid/high classification
        let lowEnergy: Float = (subBass + bass) / 2.0  // 20-250 Hz
        let midEnergy: Float = (lowMids + mids) / 2.0  // 250-2000 Hz
        let highEnergy: Float = (highMids + highs) / 2.0  // 2000-20000 Hz
        
        
        // ✅ KEEP: OpenAI integration for intelligent analysis
        // Analyze with OpenAI
        analysisProgress = 0.8
        
        // Check if user has Pro subscription
        let subscriptionService = await SubscriptionService.shared
        let isProUser = await subscriptionService.isProUser
        
        
        let aiResponse = try await OpenAIService.shared.analyzeAudioFeatures(
            peakLevel: peakLevelDB,
            rmsLevel: rmsLevelDB,
            dynamicRange: loudnessFeatures.dynamicRange,
            stereoWidth: stereoFeatures.stereoWidth,
            lowFrequencyEnergy: lowEnergy,
            midFrequencyEnergy: midEnergy,
            highFrequencyEnergy: highEnergy,
            spectralCentroid: frequencyFeatures.spectralCentroid,
            zeroCrossingRate: 0.5,  // Placeholder
            phaseCoherence: stereoFeatures.correlation,
            isProUser: isProUser
        )
        
        
        // 🔄 REPLACE: Manual scoring calculations - AudioKit + AI can provide better metrics
        // Calculate a technical score based on objective metrics as a sanity check
        var technicalScore: Double = 100.0
        
        // Stereo width check (30-75% is ideal)
        let stereoWidthPercent = Double(stereoFeatures.stereoWidth * 100)
        if stereoWidthPercent < 25 {
            technicalScore -= 20  // Very narrow stereo
        } else if stereoWidthPercent < 30 {
            technicalScore -= 10  // Narrow stereo
        } else if stereoWidthPercent > 80 {
            technicalScore -= 15  // Too wide (phase issues likely)
        }
        
        // Phase coherence check (>0.5 is acceptable, >0.6 is good)
        if stereoFeatures.correlation < 0.4 {
            technicalScore -= 25  // Severe phase issues
        } else if stereoFeatures.correlation < 0.5 {
            technicalScore -= 15  // Phase issues
        }
        // 0.5-1.0 is fine, no penalty
        
        // Dynamic range check (4-18 dB is acceptable)
        if loudnessFeatures.dynamicRange < 3 {
            technicalScore -= 20  // Severely over-compressed
        } else if loudnessFeatures.dynamicRange < 4 {
            technicalScore -= 10  // Over-compressed
        } else if loudnessFeatures.dynamicRange > 20 {
            technicalScore -= 15  // Overly dynamic
        } else if loudnessFeatures.dynamicRange > 18 {
            technicalScore -= 5   // Very dynamic
        }
        
        // Peak level check (should be reasonably loud)
        if loudnessFeatures.peakLevel > 1.0 {
            technicalScore -= 25  // Clipping
        } else if peakLevelDB < -12 {
            technicalScore -= 15  // Very quiet
        } else if peakLevelDB < -10 {
            technicalScore -= 5   // Quiet
        }
        
        // Frequency balance check - CRITICAL for mix quality
        // Calculate percentages of total energy
        let totalFreqEnergy = lowEnergy + midEnergy + highEnergy
        if totalFreqEnergy > 0 {
            let lowPercent = Double(lowEnergy / totalFreqEnergy * 100)
            let midPercent = Double(midEnergy / totalFreqEnergy * 100)
            let highPercent = Double(highEnergy / totalFreqEnergy * 100)
            
            
            // Ideal range: 25-45% per band (with some flexibility)
            // Severely imbalanced: >60% or <15% in any band
            if lowPercent > 60 {
                technicalScore -= 30  // Extremely bass-heavy
            } else if lowPercent > 50 {
                technicalScore -= 20  // Very bass-heavy
            } else if lowPercent < 15 {
                technicalScore -= 20  // Lacking bass
            }
            
            if midPercent < 20 {
                technicalScore -= 25  // Severely lacking mids (vocals, instruments)
            } else if midPercent < 25 {
                technicalScore -= 15  // Lacking mids
            } else if midPercent > 60 {
                technicalScore -= 20  // Too mid-heavy
            }
            
            if highPercent > 50 {
                technicalScore -= 25  // Extremely harsh/bright
            } else if highPercent > 45 {
                technicalScore -= 15  // Very bright
            } else if highPercent < 10 {
                technicalScore -= 20  // Dull/muddy
            }
        }
        
        
        // DISABLED: Use Claude's intelligent score instead of max()
        // let finalScore = max(technicalScore, aiResponse.overallQuality)
        let finalScore = aiResponse.overallQuality  // Use Claude's score directly
        
        // ✅ KEEP: Result creation and data mapping - this structure is good
        // Create analysis result
        analysisProgress = 0.9
        let result = AnalysisResult(audioFile: audioFile, analysisVersion: "OpenAI-1.0")
        
        // Populate technical metrics
        result.stereoWidthScore = Double(stereoFeatures.stereoWidth * 100)
        result.phaseCoherence = Double(stereoFeatures.correlation)
        result.dynamicRange = Double(loudnessFeatures.dynamicRange)
        result.loudnessLUFS = Double(loudnessFeatures.lufs)
        result.peakLevel = Double(peakLevelDB)
        result.spectralCentroid = Double(frequencyFeatures.spectralCentroid)
        result.hasClipping = loudnessFeatures.peakLevel >= 1.0
        
        // Normalize frequency bands to percentages (0-100)
        // Calculate total energy and convert each band to percentage of total
        let totalEnergy = lowEnergy + midEnergy + highEnergy
        if totalEnergy > 0 {
            result.lowEndBalance = Double((lowEnergy / totalEnergy) * 100)
            result.midBalance = Double((midEnergy / totalEnergy) * 100)
            result.highBalance = Double((highEnergy / totalEnergy) * 100)
        } else {
            // Fallback to equal distribution if no energy detected
            result.lowEndBalance = 33.3
            result.midBalance = 33.3
            result.highBalance = 33.3
        }
        
        
        // Apply OpenAI analysis (use our calculated final score instead of raw AI score)
        result.overallScore = finalScore
        
        // If mix is excellent (85+), no need for recommendations
        if finalScore >= 85 {
            result.recommendations = ["Your mix sounds excellent! No significant improvements needed."]
        } else if finalScore >= 75 {
            // Good mix - only keep critical recommendations (max 3)
            result.recommendations = Array(aiResponse.recommendations.prefix(3))
        } else {
            // Fair/poor mix - show all recommendations
            result.recommendations = aiResponse.recommendations
        }
        
        // Set issue flags based on REALISTIC professional thresholds
        // Phase coherence: <0.5 is problematic, 0.5-0.6 is acceptable, 0.6+ is good
        result.hasPhaseIssues = stereoFeatures.correlation < 0.5
        
        // Stereo width: <30% is narrow, 30-75% is good, >80% is too wide
        result.hasStereoIssues = stereoFeatures.stereoWidth < 0.3 || stereoFeatures.stereoWidth > 0.8
        
        // Frequency imbalance: Only flag if severely imbalanced (>60% in one band)
        result.hasFrequencyImbalance = (lowEnergy > 0.6 || highEnergy > 0.6)
        
        // Dynamic range: 4-18 dB is acceptable range
        result.hasDynamicRangeIssues = (loudnessFeatures.dynamicRange < 4.0 || 
                                       loudnessFeatures.dynamicRange > 18.0)
        
        
        analysisProgress = 1.0
        
        return result
    }
    */
}
