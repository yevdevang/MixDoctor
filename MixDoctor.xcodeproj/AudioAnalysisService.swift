//
//  AudioAnalysisService.swift
//  MixDoctor
//
//  Service for analyzing audio files and generating mix quality reports
//

import Foundation
import AVFoundation
import CoreMedia
import Accelerate

@MainActor
final class AudioAnalysisService {
    
    // MARK: - Analysis Errors
    
    enum AnalysisError: LocalizedError {
        case fileNotFound
        case unsupportedFormat
        case analysisFailure(String)
        case insufficientData
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Audio file not found"
            case .unsupportedFormat:
                return "Audio format not supported for analysis"
            case .analysisFailure(let reason):
                return "Analysis failed: \(reason)"
            case .insufficientData:
                return "Insufficient audio data for analysis"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func analyzeAudio(_ audioFile: AudioFile) async throws -> AnalysisResult {
        // Simulate analysis delay for demo purposes
        try await Task.sleep(for: .seconds(2))
        
        guard FileManager.default.fileExists(atPath: audioFile.fileURL.path) else {
            throw AnalysisError.fileNotFound
        }
        
        // Load audio data
        let audioData = try await loadAudioData(from: audioFile.fileURL)
        
        // Perform analysis
        let analysisResult = try await performDetailedAnalysis(
            audioData: audioData,
            audioFile: audioFile
        )
        
        return analysisResult
    }
    
    // MARK: - Private Analysis Methods
    
    private func loadAudioData(from url: URL) async throws -> AudioData {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioData = try self.extractAudioData(from: url)
                    continuation.resume(returning: audioData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func extractAudioData(from url: URL) throws -> AudioData {
        let asset = AVAsset(url: url)
        let track = asset.tracks(withMediaType: .audio).first
        
        guard let audioTrack = track else {
            throw AnalysisError.unsupportedFormat
        }
        
        // For demo purposes, generate synthetic audio data
        // In a real implementation, you would extract actual PCM data
        let sampleRate = 44100.0
        let duration = CMTimeGetSeconds(asset.duration)
        let sampleCount = Int(sampleRate * duration)
        
        // Generate synthetic stereo audio data for analysis
        var leftChannel = [Float](repeating: 0.0, count: sampleCount)
        var rightChannel = [Float](repeating: 0.0, count: sampleCount)
        
        // Add some synthetic content for realistic analysis
        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleRate)
            leftChannel[i] = sin(2.0 * .pi * 440.0 * t) * 0.5 + Float.random(in: -0.1...0.1)
            rightChannel[i] = sin(2.0 * .pi * 440.0 * t) * 0.3 + Float.random(in: -0.1...0.1)
        }
        
        return AudioData(
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            sampleRate: sampleRate,
            duration: duration
        )
    }
    
    private func performDetailedAnalysis(
        audioData: AudioData,
        audioFile: AudioFile
    ) async throws -> AnalysisResult {
        
        let result = AnalysisResult(audioFile: audioFile)
        
        // Perform various analyses
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.analyzeStereoWidth(audioData: audioData, result: result)
            }
            
            group.addTask {
                await self.analyzePhaseCoherence(audioData: audioData, result: result)
            }
            
            group.addTask {
                await self.analyzeFrequencyBalance(audioData: audioData, result: result)
            }
            
            group.addTask {
                await self.analyzeDynamicRange(audioData: audioData, result: result)
            }
            
            group.addTask {
                await self.analyzeLoudness(audioData: audioData, result: result)
            }
        }
        
        // Calculate overall score and generate recommendations
        await calculateOverallScore(result: result)
        await generateRecommendations(result: result)
        
        return result
    }
    
    // MARK: - Analysis Components
    
    private func analyzeStereoWidth(audioData: AudioData, result: AnalysisResult) async {
        // Calculate stereo width using correlation between L and R channels
        let correlation = calculateCorrelation(audioData.leftChannel, audioData.rightChannel)
        let stereoWidth = max(0, (1.0 - abs(correlation)) * 100)
        
        result.stereoWidthScore = stereoWidth
        result.hasStereoIssues = stereoWidth < 20 || stereoWidth > 90
    }
    
    private func analyzePhaseCoherence(audioData: AudioData, result: AnalysisResult) async {
        // Calculate phase coherence using cross-correlation
        let coherence = calculatePhaseCoherence(audioData.leftChannel, audioData.rightChannel)
        
        result.phaseCoherence = coherence
        result.hasPhaseIssues = coherence < 0.5
    }
    
    private func analyzeFrequencyBalance(audioData: AudioData, result: AnalysisResult) async {
        // Perform FFT analysis to check frequency balance
        let leftSpectrum = performFFT(audioData.leftChannel)
        let rightSpectrum = performFFT(audioData.rightChannel)
        
        // Calculate frequency band energies
        let nyquist = audioData.sampleRate / 2
        let lowEnd = calculateBandEnergy(leftSpectrum, rightSpectrum, 20, 250, nyquist)
        let lowMid = calculateBandEnergy(leftSpectrum, rightSpectrum, 250, 500, nyquist)
        let mid = calculateBandEnergy(leftSpectrum, rightSpectrum, 500, 2000, nyquist)
        let highMid = calculateBandEnergy(leftSpectrum, rightSpectrum, 2000, 8000, nyquist)
        let high = calculateBandEnergy(leftSpectrum, rightSpectrum, 8000, 20000, nyquist)
        
        result.lowEndBalance = lowEnd
        result.lowMidBalance = lowMid
        result.midBalance = mid
        result.highMidBalance = highMid
        result.highBalance = high
        
        // Check for significant imbalances
        let totalEnergy = lowEnd + lowMid + mid + highMid + high
        let idealBalance = totalEnergy / 5
        let tolerance = idealBalance * 0.5
        
        result.hasFrequencyImbalance = abs(lowEnd - idealBalance) > tolerance ||
                                     abs(mid - idealBalance) > tolerance ||
                                     abs(high - idealBalance) > tolerance
    }
    
    private func analyzeDynamicRange(audioData: AudioData, result: AnalysisResult) async {
        // Calculate dynamic range using RMS and peak values
        let leftRMS = calculateRMS(audioData.leftChannel)
        let rightRMS = calculateRMS(audioData.rightChannel)
        let avgRMS = (leftRMS + rightRMS) / 2.0
        
        let leftPeak = audioData.leftChannel.max() ?? 0
        let rightPeak = audioData.rightChannel.max() ?? 0
        let maxPeak = max(abs(leftPeak), abs(rightPeak))
        
        let dynamicRange = 20 * log10(maxPeak / avgRMS)
        
        result.dynamicRange = min(max(dynamicRange, 0), 50) // Clamp to reasonable range
        result.hasDynamicRangeIssues = dynamicRange < 8 || dynamicRange > 30
    }
    
    private func analyzeLoudness(audioData: AudioData, result: AnalysisResult) async {
        // Calculate integrated loudness (LUFS approximation) and peak level
        let leftRMS = calculateRMS(audioData.leftChannel)
        let rightRMS = calculateRMS(audioData.rightChannel)
        let avgRMS = (leftRMS + rightRMS) / 2.0
        
        // Convert to LUFS approximation
        let lufs = -23 + 20 * log10(avgRMS / 0.1)
        
        // Calculate peak level
        let leftPeak = audioData.leftChannel.max() ?? 0
        let rightPeak = audioData.rightChannel.max() ?? 0
        let maxPeak = max(abs(leftPeak), abs(rightPeak))
        let peakdBFS = 20 * log10(maxPeak)
        
        result.loudnessLUFS = lufs
        result.peakLevel = peakdBFS
    }
    
    private func calculateOverallScore(result: AnalysisResult) async {
        var score = 100.0
        
        // Deduct points for various issues
        if result.hasPhaseIssues {
            score -= 25
        }
        
        if result.hasStereoIssues {
            score -= 15
        }
        
        if result.hasFrequencyImbalance {
            score -= 20
        }
        
        if result.hasDynamicRangeIssues {
            score -= 15
        }
        
        if result.peakLevel > -0.1 {
            score -= 10 // Clipping penalty
        }
        
        // Loudness penalty
        if result.loudnessLUFS > -14 || result.loudnessLUFS < -30 {
            score -= 10
        }
        
        result.overallScore = max(0, score)
    }
    
    private func generateRecommendations(result: AnalysisResult) async {
        var recommendations: [String] = []
        
        if result.hasPhaseIssues {
            recommendations.append("Check for phase cancellation between channels. Consider using a phase correlation meter.")
        }
        
        if result.hasStereoIssues {
            if result.stereoWidthScore < 20 {
                recommendations.append("Stereo image is too narrow. Try widening stereo effects or panning instruments.")
            } else {
                recommendations.append("Stereo image may be too wide for mono compatibility. Check mono fold-down.")
            }
        }
        
        if result.hasFrequencyImbalance {
            if result.lowEndBalance > result.midBalance * 1.5 {
                recommendations.append("Low end appears dominant. Consider high-pass filtering or reducing bass.")
            }
            if result.highBalance < result.midBalance * 0.5 {
                recommendations.append("High frequencies appear lacking. Consider brightening the mix.")
            }
        }
        
        if result.hasDynamicRangeIssues {
            if result.dynamicRange < 8 {
                recommendations.append("Mix appears over-compressed. Consider reducing compression or limiting.")
            } else {
                recommendations.append("Mix may benefit from gentle compression to control dynamics.")
            }
        }
        
        if result.peakLevel > -0.1 {
            recommendations.append("Potential clipping detected. Reduce overall levels to prevent distortion.")
        }
        
        if result.loudnessLUFS > -14 {
            recommendations.append("Mix is quite loud. Consider reducing levels for streaming platform optimization.")
        } else if result.loudnessLUFS < -30 {
            recommendations.append("Mix appears quiet. Consider increasing overall levels or using gentle limiting.")
        }
        
        result.recommendations = recommendations
    }
    
    // MARK: - Audio Processing Utilities
    
    private func calculateCorrelation(_ left: [Float], _ right: [Float]) -> Float {
        guard left.count == right.count, !left.isEmpty else { return 0 }
        
        let count = left.count
        var correlation: Float = 0
        
        vDSP_dotpr(left, 1, right, 1, &correlation, vDSP_Length(count))
        
        var leftSum: Float = 0, rightSum: Float = 0
        vDSP_sve(left, 1, &leftSum, vDSP_Length(count))
        vDSP_sve(right, 1, &rightSum, vDSP_Length(count))
        
        return correlation / sqrt(leftSum * rightSum)
    }
    
    private func calculatePhaseCoherence(_ left: [Float], _ right: [Float]) -> Double {
        // Simplified phase coherence calculation
        let correlation = calculateCorrelation(left, right)
        return Double(abs(correlation))
    }
    
    private func performFFT(_ signal: [Float]) -> [Float] {
        let count = signal.count
        let log2n = vDSP_Length(log2(Float(count)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            return []
        }
        
        var realParts = signal
        var imagParts = [Float](repeating: 0.0, count: count)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, Int32(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: count / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(count / 2))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        return magnitudes
    }
    
    private func calculateBandEnergy(
        _ leftSpectrum: [Float],
        _ rightSpectrum: [Float],
        _ lowFreq: Double,
        _ highFreq: Double,
        _ nyquist: Double
    ) -> Double {
        let binSize = nyquist / Double(leftSpectrum.count)
        let startBin = Int(lowFreq / binSize)
        let endBin = min(Int(highFreq / binSize), leftSpectrum.count - 1)
        
        var energy: Double = 0
        for i in startBin...endBin {
            energy += Double(leftSpectrum[i] + rightSpectrum[i])
        }
        
        return energy / Double(endBin - startBin + 1) * 100 // Normalize to percentage
    }
    
    private func calculateRMS(_ signal: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(signal, 1, &rms, vDSP_Length(signal.count))
        return rms
    }
}

// MARK: - Supporting Types

struct AudioData {
    let leftChannel: [Float]
    let rightChannel: [Float]
    let sampleRate: Double
    let duration: Double
}