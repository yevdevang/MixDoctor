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
        
        // Verify file exists before attempting analysis
        let fileURL = audioFile.fileURL
        
        // Try both the original path and potential URL-decoded version
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
                        print("   ✅ Found file with decoded name: \(matchingFile)")
                    }
                }
            }
        }
        
        print("🔍 Pre-analysis file check:")
        print("   File URL: \(fileURL)")
        print("   File path: \(fileURL.path)")
        print("   Actual URL: \(actualURL)")
        print("   File exists: \(fileExists)")
        
        // If file doesn't exist, list directory contents for debugging
        if !fileExists {
            let directory = fileURL.deletingLastPathComponent()
            print("❌ File not found. Directory: \(directory.path)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
                print("   Files in directory: \(contents.count)")
                contents.prefix(10).forEach { print("   - \($0)") }
            }
        }
        
        guard fileExists else {
            throw NSError(domain: "AudioAnalysisService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Audio file not found at path: \(fileURL.path). Please delete and re-import this file."
            ])
        }
        
        // Load and process audio using the actual URL that exists
        analysisProgress = 0.1
        let processedAudio = try processor.loadAudio(from: actualURL)
        
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
        
        print("   📊 Extracted Features:")
        print("      Peak Level: \(peakLevelDB) dBFS")
        print("      RMS Level: \(rmsLevelDB) dBFS")
        print("      Dynamic Range: \(loudnessFeatures.dynamicRange) dB")
        print("      Stereo Width: \(stereoFeatures.stereoWidth)")
        print("      Phase Coherence: \(stereoFeatures.correlation)")
        print("      Frequency Bands:")
        print("        Sub Bass (20-60): \(subBass)")
        print("        Bass (60-250): \(bass)")
        print("        Low Mids (250-500): \(lowMids)")
        print("        Mids (500-2k): \(mids)")
        print("        High Mids (2k-6k): \(highMids)")
        print("        Highs (6k-20k): \(highs)")
        print("      Combined:")
        print("        Low: \(lowEnergy)")
        print("        Mid: \(midEnergy)")
        print("        High: \(highEnergy)")
        print("      Spectral Centroid: \(frequencyFeatures.spectralCentroid) Hz")
        
        // Analyze with OpenAI
        analysisProgress = 0.8
        print("   🤖 Analyzing with OpenAI GPT-5 Nano...")
        print("   📤 Sending to OpenAI:")
        print("      Peak Level: \(peakLevelDB) dBFS")
        print("      RMS Level: \(rmsLevelDB) dBFS")
        print("      Dynamic Range: \(loudnessFeatures.dynamicRange) dB")
        print("      Stereo Width: \(stereoFeatures.stereoWidth * 100)%")
        print("      Phase Coherence: \(stereoFeatures.correlation)")
        print("      Low Energy: \(lowEnergy)")
        print("      Mid Energy: \(midEnergy)")
        print("      High Energy: \(highEnergy)")
        
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
            phaseCoherence: stereoFeatures.correlation
        )
        
        print("   📥 OpenAI Response:")
        print("      Score: \(aiResponse.overallQuality)")
        print("      Stereo: \(aiResponse.stereoAnalysis)")
        print("      Frequency: \(aiResponse.frequencyAnalysis)")
        print("      Dynamics: \(aiResponse.dynamicsAnalysis)")
        
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
            
            print("   📊 Checking frequency balance:")
            print("      Low: \(String(format: "%.1f", lowPercent))%")
            print("      Mid: \(String(format: "%.1f", midPercent))%")
            print("      High: \(String(format: "%.1f", highPercent))%")
            
            // Ideal range: 25-45% per band (with some flexibility)
            // Severely imbalanced: >60% or <15% in any band
            if lowPercent > 60 {
                technicalScore -= 30  // Extremely bass-heavy
                print("      ❌ Extremely bass-heavy: -30 points")
            } else if lowPercent > 50 {
                technicalScore -= 20  // Very bass-heavy
                print("      ⚠️ Very bass-heavy: -20 points")
            } else if lowPercent < 15 {
                technicalScore -= 20  // Lacking bass
                print("      ⚠️ Lacking bass: -20 points")
            }
            
            if midPercent < 20 {
                technicalScore -= 25  // Severely lacking mids (vocals, instruments)
                print("      ❌ Severely lacking mids: -25 points")
            } else if midPercent < 25 {
                technicalScore -= 15  // Lacking mids
                print("      ⚠️ Lacking mids: -15 points")
            } else if midPercent > 60 {
                technicalScore -= 20  // Too mid-heavy
                print("      ⚠️ Too mid-heavy: -20 points")
            }
            
            if highPercent > 50 {
                technicalScore -= 25  // Extremely harsh/bright
                print("      ❌ Extremely harsh/bright: -25 points")
            } else if highPercent > 45 {
                technicalScore -= 15  // Very bright
                print("      ⚠️ Very bright: -15 points")
            } else if highPercent < 10 {
                technicalScore -= 20  // Dull/muddy
                print("      ⚠️ Dull/muddy mix: -20 points")
            }
        }
        
        print("   🔬 Technical Score (objective): \(Int(technicalScore))")
        print("   🤖 AI Score: \(Int(aiResponse.overallQuality))")
        
        // Use the HIGHER of technical score or AI score to avoid unfair penalization
        let finalScore = max(technicalScore, aiResponse.overallQuality)
        print("   ⭐ Final Score (max of both): \(Int(finalScore))")
        
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
        
        print("   📊 Frequency Balance (normalized):")
        print("      Low: \(result.lowEndBalance)%")
        print("      Mid: \(result.midBalance)%")
        print("      High: \(result.highBalance)%")
        
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
        
        print("   ✅ OpenAI Analysis Complete:")
        print("      Overall Quality: \(aiResponse.overallQuality)/100")
        print("      Stereo: \(aiResponse.stereoAnalysis)")
        print("      Frequency: \(aiResponse.frequencyAnalysis)")
        print("      Dynamics: \(aiResponse.dynamicsAnalysis)")
        print("      Summary: \(aiResponse.detailedSummary)")
        print("      Recommendations: \(aiResponse.recommendations.count)")
        
        analysisProgress = 1.0
        
        return result
    }
}
