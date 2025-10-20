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
        
        // Apply OpenAI analysis
        result.overallScore = aiResponse.overallQuality
        result.recommendations = aiResponse.recommendations
        
        // Set issue flags based on thresholds
        result.hasPhaseIssues = stereoFeatures.correlation < 0.7
        result.hasStereoIssues = stereoFeatures.stereoWidth < 0.3 || stereoFeatures.stereoWidth > 0.8
        result.hasFrequencyImbalance = (lowEnergy > 0.5 || highEnergy > 0.5)
        result.hasDynamicRangeIssues = (loudnessFeatures.dynamicRange < 6.0 || 
                                       loudnessFeatures.dynamicRange > 16.0)
        
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
