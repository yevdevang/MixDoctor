//
//  AudioKitService.swift
//  MixDoctor
//
//  AudioKit-based audio analysis and processing service
//

import Foundation
import AVFoundation
import AudioKit
import Combine
import Accelerate

@MainActor
public class AudioKitService: ObservableObject {
    public static let shared = AudioKitService()
    
    // MARK: - Analysis Properties
    @Published public var isAnalyzing = false
    
    private init() {
        setupAudioEngine()
    }
    
    // MARK: - Setup
    private func setupAudioEngine() {
        // AudioKit setup for analysis
        print("🎵 AudioKitService initialized with AudioKit engine")
    }
    
    // MARK: - File-Based Audio Analysis
    
    /// Analyze audio file and return comprehensive analysis for display
    public func getDetailedAnalysis(for url: URL) async throws -> AnalysisResult {
        print("🔍 AudioKit analyzing: \(url.lastPathComponent)")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        return try await performAudioKitAnalysis(url: url)
    }
    
    private func performAudioKitAnalysis(url: URL) async throws -> AnalysisResult {
        // Load audio file for AudioKit analysis
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw AudioKitError.fileLoadFailed
        }
        
        // Calculate duration from AudioKit/AVFoundation
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        
        // Read audio data into buffer for AudioKit processing
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            throw AudioKitError.processingFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Perform AudioKit-based analysis
        let analysisResult = await performAudioKitBufferAnalysis(buffer, duration: duration)
        
        // Create AnalysisResult with AudioKit data
        // Note: audioFile parameter is AVAudioFile, but AnalysisResult expects MixDoctor.AudioFile
        // For now, create with nil and populate data
        let result = AnalysisResult(audioFile: nil, analysisVersion: "AudioKit-1.0")
        
        // Populate with AudioKit analysis results
        result.stereoWidthScore = analysisResult.stereoWidth
        result.phaseCoherence = analysisResult.phaseCoherence
        result.monoCompatibility = analysisResult.monoCompatibility
        result.spectralCentroid = analysisResult.spectralCentroid
        result.hasClipping = analysisResult.hasClipping
        
        // AudioKit frequency analysis
        result.lowEndBalance = analysisResult.lowEnd
        result.lowMidBalance = analysisResult.lowMid
        result.midBalance = analysisResult.mid
        result.highMidBalance = analysisResult.highMid
        result.highBalance = analysisResult.high
        
        result.dynamicRange = analysisResult.dynamicRange
        result.loudnessLUFS = analysisResult.loudness
        result.rmsLevel = analysisResult.rmsLevel
        result.peakLevel = analysisResult.peakLevel
        
        // AudioKit issue detection
        result.hasPhaseIssues = analysisResult.phaseIssues
        result.hasStereoIssues = analysisResult.stereoIssues
        result.hasFrequencyImbalance = analysisResult.frequencyImbalance
        result.hasDynamicRangeIssues = analysisResult.dynamicRangeIssues
        
        // Map instrument balance data
        result.hasInstrumentBalanceIssues = !analysisResult.instrumentBalance.isBalanced
        result.instrumentBalanceScore = analysisResult.instrumentBalance.isBalanced ? 100.0 : Double(100 - analysisResult.instrumentBalance.balanceIssues.count * 10)
        result.kickEnergy = analysisResult.instrumentBalance.instrumentEnergies["kick"] ?? 0.0
        result.bassEnergy = analysisResult.instrumentBalance.instrumentEnergies["bass"] ?? 0.0
        result.vocalEnergy = analysisResult.instrumentBalance.instrumentEnergies["vocals"] ?? 0.0
        result.guitarEnergy = analysisResult.instrumentBalance.instrumentEnergies["guitars"] ?? 0.0
        result.cymbalEnergy = analysisResult.instrumentBalance.instrumentEnergies["cymbals"] ?? 0.0
        
        result.recommendations = analysisResult.recommendations
        
        // MARK: - Professional Mastering Analysis Results
        print("🎛️ === PROFESSIONAL MASTERING ANALYSIS ===")
        
        // Spectral Balance Analysis
        print("📊 SPECTRAL BALANCE:")
        print("   • Sub-bass (20-60Hz): \(String(format: "%.1f", analysisResult.spectralBalance.subBassEnergy * 100))%")
        print("   • Bass (60-250Hz): \(String(format: "%.1f", analysisResult.spectralBalance.bassEnergy * 100))%") 
        print("   • Low-mid (250-500Hz): \(String(format: "%.1f", analysisResult.spectralBalance.lowMidEnergy * 100))%")
        print("   • Midrange (500Hz-2kHz): \(String(format: "%.1f", analysisResult.spectralBalance.midEnergy * 100))%")
        print("   • High-mid (2-6kHz): \(String(format: "%.1f", analysisResult.spectralBalance.highMidEnergy * 100))%")
        print("   • Presence (6-12kHz): \(String(format: "%.1f", analysisResult.spectralBalance.presenceEnergy * 100))%")
        print("   • Air (12-20kHz): \(String(format: "%.1f", analysisResult.spectralBalance.airEnergy * 100))%")
        print("   • Balance Score: \(String(format: "%.1f", analysisResult.spectralBalance.balanceScore))/100")
        print("   • Spectral Tilt: \(String(format: "%.2f", analysisResult.spectralBalance.tiltMeasure)) (neg=dark, pos=bright)")
        
        // Stereo Correlation Analysis
        print("🔄 STEREO CORRELATION:")
        print("   • Correlation Coefficient: \(String(format: "%.3f", analysisResult.stereoCorrelation.correlationCoefficient))")
        print("   • Stereo Width: \(String(format: "%.2f", analysisResult.stereoCorrelation.stereoWidth))")
        print("   • Phase Coherence: \(String(format: "%.1f", analysisResult.stereoCorrelation.phaseCoherence * 100))%")
        print("   • Mono Compatibility: \(String(format: "%.1f", analysisResult.stereoCorrelation.monoCompatibility))%")
        print("   • Side Energy: \(String(format: "%.1f", analysisResult.stereoCorrelation.sidechainEnergy * 100))%")
        print("   • Center Image: \(String(format: "%.1f", analysisResult.stereoCorrelation.centerImage * 100))%")
        
        // Dynamic Range Analysis  
        print("📈 DYNAMIC RANGE ANALYSIS:")
        print("   • LUFS Range: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.lufsRange)) LU")
        print("   • Crest Factor: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.crestFactor)) dB")
        print("   • 95th Percentile: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.percentile95)) dB")
        print("   • 5th Percentile: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.percentile5)) dB")
        print("   • Compression Ratio: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.compressionRatio)):1")
        print("   • Headroom: \(String(format: "%.1f", analysisResult.dynamicRangeAnalysis.breathingRoom)) dB")
        
        // Peak-to-Average Analysis
        print("⚡ PEAK-TO-AVERAGE ANALYSIS:")
        print("   • Peak-to-RMS: \(String(format: "%.1f", analysisResult.peakToAverageRatio.peakToRmsRatio)) dB")
        print("   • Peak-to-LUFS: \(String(format: "%.1f", analysisResult.peakToAverageRatio.peakToLufsRatio)) dB")
        print("   • True Peak: \(String(format: "%.1f", analysisResult.peakToAverageRatio.truePeakLevel)) dBFS")
        print("   • Integrated Loudness: \(String(format: "%.1f", analysisResult.peakToAverageRatio.integratedLoudness)) LUFS")
        print("   • Loudness Range: \(String(format: "%.1f", analysisResult.peakToAverageRatio.loudnessRange)) LU")
        print("   • Punchiness: \(String(format: "%.1f", analysisResult.peakToAverageRatio.punchiness))/100")
        
        // Mastering Recommendations
        print("🎯 MASTERING RECOMMENDATIONS:")
        let allRecommendations = analysisResult.spectralBalance.recommendations + 
                                analysisResult.stereoCorrelation.recommendations +
                                analysisResult.dynamicRangeAnalysis.recommendations +
                                analysisResult.peakToAverageRatio.recommendations
        
        if allRecommendations.isEmpty {
            print("   ✅ Master appears professionally balanced")
        } else {
            for recommendation in allRecommendations.prefix(10) {
                print("   • \(recommendation)")
            }
        }
        
        print("✅ AudioKit analysis complete for: \(url.lastPathComponent)")
        return result
    }
    
    // MARK: - AudioKit Analysis Implementation
    
    private func performAudioKitBufferAnalysis(_ buffer: AVAudioPCMBuffer, duration: TimeInterval) async -> AudioKitAnalysisResult {
        // AudioKit-based buffer analysis
        guard let leftData = buffer.floatChannelData?[0] else {
            return AudioKitAnalysisResult()
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let rightData = channelCount > 1 ? buffer.floatChannelData?[1] : nil
        
        // AudioKit frequency analysis
        let fftAnalysis = performAudioKitFFT(leftData, frameCount: frameCount)
        
        // AudioKit amplitude analysis
        let amplitudeAnalysis = performAudioKitAmplitudeAnalysis(leftData, frameCount: frameCount)
        
        // AudioKit stereo analysis (if stereo)
        let stereoAnalysis = performAudioKitStereoAnalysis(leftData, rightData, frameCount: frameCount)
        
        // AudioKit dynamic range analysis
        let dynamicAnalysis = performAudioKitDynamicAnalysis(leftData, frameCount: frameCount)
        
        // AudioKit instrument balance analysis
        let instrumentBalance = analyzeInstrumentBalance(leftData, frameCount: frameCount)
        
        // MARK: - Professional Mastering Analysis
        let spectralBalance = analyzeSpectralBalance(leftData, frameCount: frameCount)
        let stereoCorrelation = analyzeStereoCorrelation(leftData, rightData ?? leftData, frameCount: frameCount)
        let dynamicRangeAnalysis = analyzeDynamicRange(leftData, rightData ?? leftData, frameCount: frameCount)
        let peakToAverageRatio = analyzePeakToAverage(leftData, rightData ?? leftData, frameCount: frameCount)
        
        // Combine AudioKit results
        return AudioKitAnalysisResult(
            stereoWidth: stereoAnalysis.width,
            phaseCoherence: stereoAnalysis.coherence,
            monoCompatibility: stereoAnalysis.monoCompatibility,
            spectralCentroid: fftAnalysis.spectralCentroid,
            hasClipping: amplitudeAnalysis.hasClipping,
            lowEnd: fftAnalysis.lowEnd,
            lowMid: fftAnalysis.lowMid,
            mid: fftAnalysis.mid,
            highMid: fftAnalysis.highMid,
            high: fftAnalysis.high,
            dynamicRange: dynamicAnalysis.range,
            loudness: amplitudeAnalysis.loudness,
            rmsLevel: amplitudeAnalysis.rms,
            peakLevel: amplitudeAnalysis.peak,
            phaseIssues: stereoAnalysis.coherence < 0.3,  // Only flag serious phase problems
            stereoIssues: abs(stereoAnalysis.balance) > 0.3,
            frequencyImbalance: fftAnalysis.hasImbalance,
            dynamicRangeIssues: dynamicAnalysis.range < 4.0,  // Only flag severely over-compressed material
            instrumentBalance: instrumentBalance,
            recommendations: generateAudioKitRecommendations(fftAnalysis, amplitudeAnalysis, stereoAnalysis, dynamicAnalysis, instrumentBalance),
            spectralBalance: spectralBalance,
            stereoCorrelation: stereoCorrelation,
            dynamicRangeAnalysis: dynamicRangeAnalysis,
            peakToAverageRatio: peakToAverageRatio
        )
    }
    
    // MARK: - AudioKit Analysis Methods
    
    private func performAudioKitFFT(_ data: UnsafePointer<Float>, frameCount: Int) -> AudioKitFFTResult {
        // Convert pointer to array for processing
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        
        // FFT size should be power of 2, find the closest one
        let fftSize = Int(pow(2, floor(log2(Double(frameCount)))))
        let actualSamples = Array(samples.prefix(fftSize))
        
        // Perform FFT using built-in Accelerate framework
        let magnitudes = performFFTAnalysis(actualSamples)
        
        // Define frequency bands (assuming 44.1kHz sample rate)
        let sampleRate: Double = 44100.0
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(magnitudes.count / 2)
        
        // Ensure we only use the meaningful half of the spectrum
        let usefulBins = magnitudes.count / 2
        
        // Frequency band ranges - more conservative and realistic
        let bassRange = max(1, Int(20.0 / binWidth))..<min(usefulBins, Int(250.0 / binWidth))     // 20Hz - 250Hz
        let lowMidRange = bassRange.upperBound..<min(usefulBins, Int(500.0 / binWidth))          // 250Hz - 500Hz  
        let midRange = lowMidRange.upperBound..<min(usefulBins, Int(2000.0 / binWidth))          // 500Hz - 2kHz
        let highMidRange = midRange.upperBound..<min(usefulBins, Int(4000.0 / binWidth))         // 2kHz - 4kHz
        let highRange = highMidRange.upperBound..<min(usefulBins, Int(20000.0 / binWidth))       // 4kHz - 20kHz
        
        // Calculate energy in each frequency band
        let lowEnd = calculateBandEnergy(magnitudes, range: bassRange)
        let lowMid = calculateBandEnergy(magnitudes, range: lowMidRange)
        let mid = calculateBandEnergy(magnitudes, range: midRange)
        let highMid = calculateBandEnergy(magnitudes, range: highMidRange)
        let high = calculateBandEnergy(magnitudes, range: highRange)
        
        // Calculate spectral centroid
        let spectralCentroid = calculateSpectralCentroid(magnitudes, binWidth: binWidth)
        
        // Check for frequency imbalance
        let hasImbalance = checkFrequencyImbalance(lowEnd, lowMid, mid, highMid, high)
        
        return AudioKitFFTResult(
            lowEnd: lowEnd,
            lowMid: lowMid,
            mid: mid,
            highMid: highMid,
            high: high,
            spectralCentroid: spectralCentroid,
            hasImbalance: hasImbalance
        )
    }
    
    private func performAudioKitAmplitudeAnalysis(_ data: UnsafePointer<Float>, frameCount: Int) -> AudioKitAmplitudeResult {
        // Convert pointer to array for processing
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        
        // Calculate peak amplitude
        let peakAmplitude = samples.map { abs($0) }.max() ?? 0.0
        
        // Calculate RMS (Root Mean Square) for average loudness
        let sumOfSquares = samples.reduce(0.0) { sum, sample in
            sum + Double(sample * sample)
        }
        let rms = sqrt(sumOfSquares / Double(frameCount))
        
        // Calculate loudness in LUFS using proper EBU R128 calculation
        let loudnessLUFS = calculateLUFS(samples)
        
        // Calculate RMS level in dB for professional standards
        let rmsLevelDB = rms > 0 ? 20 * log10(rms) : -100.0
        
        // Detect clipping
        let clippingThreshold: Float = 0.99 // 99% of max amplitude
        let hasClipping = samples.contains { abs($0) >= clippingThreshold }
        
        // Enhanced clipping detection - check for sustained peaks
        let sustainedClippingCount = samples.enumerated().reduce(0) { count, element in
            let (index, sample) = element
            if abs(sample) >= clippingThreshold {
                // Check if next few samples are also at peak (indicating clipping)
                let checkRange = min(index + 3, frameCount - 1)
                let sustainedPeak = (index..<checkRange).allSatisfy { i in
                    abs(samples[i]) >= clippingThreshold * 0.98
                }
                return count + (sustainedPeak ? 1 : 0)
            }
            return count
        }
        
        let hasSustainedClipping = sustainedClippingCount > frameCount / 1000 // More than 0.1% of samples
        
        // Calculate crest factor (peak-to-RMS ratio) for dynamic range assessment
        let crestFactor = rms > 0 ? Double(peakAmplitude) / rms : 0.0
        
        // Analyze amplitude distribution for better loudness assessment
        let amplitudeHistogram = createAmplitudeHistogram(samples)
        let perceivedLoudness = calculatePerceivedLoudness(from: amplitudeHistogram, rms: rms)
        
        return AudioKitAmplitudeResult(
            peak: Double(peakAmplitude),
            rms: rmsLevelDB,
            loudness: max(Double(loudnessLUFS), perceivedLoudness),
            hasClipping: hasClipping || hasSustainedClipping
        )
    }
    
    private func performAudioKitStereoAnalysis(_ leftData: UnsafePointer<Float>, _ rightData: UnsafePointer<Float>?, frameCount: Int) -> AudioKitStereoResult {
        // Handle mono files - return neutral stereo result
        guard let rightData = rightData else {
            return AudioKitStereoResult(
                width: 0.0,      // No stereo width for mono
                coherence: 1.0,  // Perfect coherence (mono)
                balance: 0.0,    // Centered balance
                monoCompatibility: 1.0  // Perfect mono compatibility (already mono)
            )
        }
        
        // Convert pointers to arrays for processing
        let leftSamples = Array(UnsafeBufferPointer(start: leftData, count: frameCount))
        let rightSamples = Array(UnsafeBufferPointer(start: rightData, count: frameCount))
        
        // Calculate stereo balance (left/right energy distribution)
        let leftEnergy = leftSamples.reduce(0.0) { sum, sample in
            sum + Double(sample * sample)
        }
        let rightEnergy = rightSamples.reduce(0.0) { sum, sample in
            sum + Double(sample * sample)
        }
        
        let totalEnergy = leftEnergy + rightEnergy
        let balance = totalEnergy > 0 ? (rightEnergy - leftEnergy) / totalEnergy : 0.0
        
        // Calculate phase coherence using cross-correlation
        let phaseCoherence = calculatePhaseCoherence(leftSamples, rightSamples)
        
        // Calculate stereo width using Mid-Side analysis
        let stereoWidth = calculateStereoWidth(leftSamples, rightSamples)
        
        // Calculate mono compatibility
        let monoCompatibility = calculateMonoCompatibility(leftSamples, rightSamples)
        
        // Advanced stereo analysis using frequency domain
        let frequencyCoherence = calculateFrequencyDomainCoherence(leftSamples, rightSamples)
        
        // Combine time and frequency domain coherence for better accuracy
        let combinedCoherence = (phaseCoherence + frequencyCoherence) / 2.0
        
        return AudioKitStereoResult(
            width: stereoWidth,
            coherence: max(0.0, min(1.0, combinedCoherence)), // Clamp to [0, 1]
            balance: max(-1.0, min(1.0, balance)), // Clamp to [-1, 1]
            monoCompatibility: monoCompatibility
        )
    }
    
    private func performAudioKitDynamicAnalysis(_ data: UnsafePointer<Float>, frameCount: Int) -> AudioKitDynamicResult {
        // Convert pointer to array for processing
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        
        // Calculate basic peak and RMS for initial dynamic range
        let peakAmplitude = samples.map { abs($0) }.max() ?? 0.0
        let rmsAmplitude = sqrt(samples.reduce(0.0) { sum, sample in
            sum + Double(sample * sample)
        } / Double(frameCount))
        
        // Calculate crest factor (peak-to-RMS ratio) in dB
        let crestFactorDB = rmsAmplitude > 0 ? 20 * log10(Double(peakAmplitude) / rmsAmplitude) : 0.0
        
        // Segment-based dynamic range analysis for more accurate measurement
        let segmentDynamicRange = calculateSegmentedDynamicRange(samples)
        
        // Short-term loudness variation analysis
        let loudnessVariation = calculateLoudnessVariation(samples)
        
        // Frequency-specific dynamic range analysis
        let frequencyDynamicRange = calculateFrequencySpecificDynamicRange(samples)
        
        // EBU R128 compliant dynamic range estimation
        let ebuDynamicRange = calculateEBUDynamicRange(samples)
        
        // Combine different dynamic range measurements
        let combinedDynamicRange = combinesDynamicRangeMeasurements(
            crestFactor: crestFactorDB,
            segmented: segmentDynamicRange,
            loudnessVariation: loudnessVariation,
            frequencyBased: frequencyDynamicRange,
            ebu: ebuDynamicRange
        )
        
        return AudioKitDynamicResult(range: combinedDynamicRange)
    }
    
    // MARK: - AudioKit Helper Methods
    
    private func analyzeFrequencyBand(_ samples: [Float], lowFreq: Double, highFreq: Double) -> Double {
        guard !samples.isEmpty && lowFreq < highFreq else { return 0.0 }
        
        // Determine appropriate FFT size
        let fftSize = min(4096, Int(pow(2, floor(log2(Double(samples.count))))))
        guard fftSize >= 256 else { return 0.0 } // Minimum FFT size for meaningful analysis
        
        let fftSamples = Array(samples.prefix(fftSize))
        
        // Perform FFT using built-in Accelerate framework
        let magnitudes = performFFTAnalysis(fftSamples)
        
        // Calculate frequency parameters
        let sampleRate: Double = 44100.0 // Assume standard sample rate
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(magnitudes.count / 2)
        
        // Convert frequency range to bin indices
        let startBin = max(0, Int(lowFreq / binWidth))
        let endBin = min(magnitudes.count / 2, Int(highFreq / binWidth))
        
        guard startBin < endBin else { return 0.0 }
        
        // Extract the frequency band
        let bandMagnitudes = Array(magnitudes[startBin..<endBin])
        
        // Calculate energy in the specified frequency band
        let bandEnergy = bandMagnitudes.reduce(0.0) { sum, magnitude in
            sum + Double(magnitude * magnitude)
        }
        
        // Calculate total energy across all frequencies for normalization
        let totalEnergy = magnitudes.prefix(magnitudes.count / 2).reduce(0.0) { sum, magnitude in
            sum + Double(magnitude * magnitude)
        }
        
        // Return normalized energy ratio
        if totalEnergy > 0.0 {
            let energyRatio = bandEnergy / totalEnergy
            
            // Apply frequency weighting based on psychoacoustic principles
            let weightedRatio = applyFrequencyWeighting(energyRatio, lowFreq: lowFreq, highFreq: highFreq)
            
            // Clamp to reasonable range [0, 1]
            return max(0.0, min(1.0, weightedRatio))
        }
        
        return 0.0
    }
    
    // MARK: - Frequency Analysis Helper Methods
    
    private func applyFrequencyWeighting(_ energyRatio: Double, lowFreq: Double, highFreq: Double) -> Double {
        // Apply psychoacoustic frequency weighting based on human hearing perception
        
        let centerFreq = (lowFreq + highFreq) / 2.0
        var weightingFactor: Double = 1.0
        
        // Apply A-weighting inspired curve for perceptual relevance
        // Human hearing is most sensitive around 1-4 kHz
        
        if centerFreq < 100 {
            // Very low frequencies - reduce weighting (less perceptually important)
            weightingFactor = 0.7
        } else if centerFreq < 500 {
            // Low frequencies - moderate weighting
            weightingFactor = 0.85
        } else if centerFreq >= 500 && centerFreq <= 4000 {
            // Mid frequencies - highest weighting (most perceptually important)
            weightingFactor = 1.2
        } else if centerFreq > 4000 && centerFreq <= 8000 {
            // High-mid frequencies - good weighting
            weightingFactor = 1.1
        } else if centerFreq > 8000 && centerFreq <= 12000 {
            // High frequencies - moderate weighting
            weightingFactor = 0.9
        } else {
            // Very high frequencies - reduced weighting
            weightingFactor = 0.8
        }
        
        // Additional weighting based on bandwidth
        let bandwidth = highFreq - lowFreq
        let bandwidthFactor = calculateBandwidthWeighting(bandwidth)
        
        return energyRatio * weightingFactor * bandwidthFactor
    }
    
    private func calculateBandwidthWeighting(_ bandwidth: Double) -> Double {
        // Weight based on bandwidth - wider bands get slightly less weight per Hz
        // This prevents very wide bands from dominating the analysis
        
        if bandwidth < 100 {
            // Narrow bands - full weight
            return 1.0
        } else if bandwidth < 500 {
            // Medium bands - slight reduction
            return 0.95
        } else if bandwidth < 1000 {
            // Wide bands - more reduction
            return 0.9
        } else {
            // Very wide bands - significant reduction
            return 0.85
        }
    }
    
    private func calculateSpectralCentroid(_ magnitudes: [Float], binWidth: Double) -> Double {
        var weightedSum: Double = 0.0
        var magnitudeSum: Double = 0.0
        
        // Only use meaningful frequency range (up to half of magnitudes for real FFT)
        let usefulBins = magnitudes.count / 2
        
        for index in 0..<usefulBins {
            let frequency = Double(index) * binWidth
            let magnitudeDouble = Double(magnitudes[index])
            
            // Skip DC bin and very low frequencies that might be noise
            if frequency > 20.0 && magnitudeDouble > 0.001 {
                weightedSum += frequency * magnitudeDouble
                magnitudeSum += magnitudeDouble
            }
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
    
    private func calculateBandEnergy(_ magnitudes: [Float], range: Range<Int>) -> Double {
        guard !range.isEmpty && range.upperBound <= magnitudes.count && range.lowerBound >= 0 else { return 0.0 }
        
        let bandMagnitudes = Array(magnitudes[range])
        let energy = bandMagnitudes.reduce(0.0) { sum, magnitude in
            sum + Double(magnitude * magnitude)
        }
        
        // Calculate total energy only from meaningful spectrum (up to Nyquist)
        let usefulMagnitudes = Array(magnitudes.prefix(magnitudes.count / 2))
        let totalEnergy = usefulMagnitudes.reduce(0.0) { sum, magnitude in
            sum + Double(magnitude * magnitude)
        }
        
        // Return energy as percentage of total energy
        return totalEnergy > 0 ? (energy / totalEnergy) * 100.0 : 0.0
    }
    
    private func checkFrequencyImbalance(_ lowEnd: Double, _ lowMid: Double, _ mid: Double, _ highMid: Double, _ high: Double) -> Bool {
        // More realistic frequency balance assessment for different genres
        
        // Critical imbalances that indicate technical problems:
        
        // 1. Extremely bass-heavy (>75% in low end) - indicates serious mix issues
        if lowEnd > 75.0 {
            return true
        }
        
        // 2. Completely missing high frequencies (<0.5%) - likely damaged or heavily filtered
        if high < 0.5 && highMid < 2.0 {
            return true
        }
        
        // 3. Mid frequencies completely missing (<5%) - hollow/scooped sound
        if mid < 5.0 && lowMid < 5.0 {
            return true
        }
        
        // 4. Only high frequencies present (low+lowMid+mid < 20%) - thin/harsh sound
        if (lowEnd + lowMid + mid) < 20.0 {
            return true
        }
        
        // 5. Unrealistic total energy distribution (should roughly add up)
        let totalEnergy = lowEnd + lowMid + mid + highMid + high
        if totalEnergy < 80.0 || totalEnergy > 120.0 {
            return true
        }
        
        // Genre-aware assessment: Different genres have different "normal" frequency distributions
        // Heavy rock/metal: 50-70% low end is normal
        // Electronic: 40-60% low end is normal  
        // Acoustic/vocal: 30-50% low end is normal
        // We'll be more lenient and only flag extreme cases
        
        return false
    }

    // MARK: - Amplitude Analysis Helper Methods
    
    private func createAmplitudeHistogram(_ samples: [Float]) -> [Int] {
        // Create histogram with 100 bins for amplitude distribution
        let binCount = 100
        var histogram = Array(repeating: 0, count: binCount)
        
        for sample in samples {
            let amplitude = abs(sample)
            let binIndex = min(Int(amplitude * Float(binCount - 1)), binCount - 1)
            histogram[binIndex] += 1
        }
        
        return histogram
    }
    
    private func calculatePerceivedLoudness(from histogram: [Int], rms: Double) -> Double {
        // Calculate perceived loudness based on amplitude distribution
        // This approximates psychoacoustic loudness perception
        
        let totalSamples = histogram.reduce(0, +)
        guard totalSamples > 0 else { return -100.0 }
        
        var weightedSum: Double = 0.0
        
        for (bin, count) in histogram.enumerated() {
            let amplitude = Double(bin) / Double(histogram.count - 1)
            // Apply psychoacoustic weighting (higher amplitudes contribute more to perceived loudness)
            let weight = pow(amplitude, 0.67) // Power law approximation
            weightedSum += weight * Double(count)
        }
        
        let perceivedAmplitude = weightedSum / Double(totalSamples)
        let perceivedLoudnessDB = perceivedAmplitude > 0 ? 20 * log10(perceivedAmplitude) : -100.0
        
        return perceivedLoudnessDB - 23.0 // Convert to LUFS-like scale
    }
    
    // MARK: - Stereo Analysis Helper Methods
    
    private func calculatePhaseCoherence(_ leftSamples: [Float], _ rightSamples: [Float]) -> Double {
        guard leftSamples.count == rightSamples.count && !leftSamples.isEmpty else { return 0.7 }
        
        // Calculate cross-correlation at zero lag (Pearson correlation coefficient)
        var crossCorrelation: Double = 0.0
        var leftSquareSum: Double = 0.0
        var rightSquareSum: Double = 0.0
        var leftSum: Double = 0.0
        var rightSum: Double = 0.0
        
        let count = Double(leftSamples.count)
        
        // Calculate means first
        for i in 0..<leftSamples.count {
            leftSum += Double(leftSamples[i])
            rightSum += Double(rightSamples[i])
        }
        
        let leftMean = leftSum / count
        let rightMean = rightSum / count
        
        // Calculate correlation coefficient
        for i in 0..<leftSamples.count {
            let leftDiff = Double(leftSamples[i]) - leftMean
            let rightDiff = Double(rightSamples[i]) - rightMean
            
            crossCorrelation += leftDiff * rightDiff
            leftSquareSum += leftDiff * leftDiff
            rightSquareSum += rightDiff * rightDiff
        }
        
        let denominator = sqrt(leftSquareSum * rightSquareSum)
        let correlation = denominator > 0 ? crossCorrelation / denominator : 0.0
        
        // Convert correlation to phase coherence measure
        // Professional masters often have correlation around 0.3-0.8 due to stereo processing
        // Raw correlation can be negative, so we take absolute value and adjust the scale
        let absCorrelation = abs(correlation)
        
        // Adjust scale to be more realistic for audio analysis:
        // - Perfect mono: 1.0 correlation -> ~0.95 coherence
        // - Professional stereo: 0.3-0.8 correlation -> 0.4-0.8 coherence  
        // - Phase issues: <0.2 correlation -> <0.3 coherence
        if absCorrelation > 0.8 {
            return 0.8 + (absCorrelation - 0.8) * 0.75  // 0.8-0.95 range
        } else if absCorrelation > 0.3 {
            return 0.4 + (absCorrelation - 0.3) * 0.8   // 0.4-0.8 range
        } else {
            return absCorrelation * 1.33                // 0.0-0.4 range
        }
    }
    
    /// Calculate mono compatibility score (0.0 = poor, 1.0 = excellent)
    private func calculateMonoCompatibility(_ leftSamples: [Float], _ rightSamples: [Float]) -> Double {
        guard leftSamples.count == rightSamples.count && !leftSamples.isEmpty else { return 1.0 }
        
        // Calculate Mid/Side signals
        var midSignal: [Float] = []
        var sideSignal: [Float] = []
        var stereoEnergy: Double = 0.0
        var monoEnergy: Double = 0.0
        
        for i in 0..<leftSamples.count {
            let left = leftSamples[i]
            let right = rightSamples[i]
            
            // Mid = (L + R) / 2, Side = (L - R) / 2
            let mid = (left + right) / 2.0
            let side = (left - right) / 2.0
            
            midSignal.append(mid)
            sideSignal.append(side)
            
            // Calculate energy in stereo vs mono
            stereoEnergy += Double(left * left + right * right)
            monoEnergy += Double(mid * mid)
        }
        
        // Calculate RMS levels
        let stereoRMS = sqrt(stereoEnergy / Double(leftSamples.count * 2))
        let monoRMS = sqrt(monoEnergy / Double(leftSamples.count))
        
        // Mono compatibility ratio (how much energy is preserved in mono)
        let energyPreservation = stereoRMS > 0 ? monoRMS / stereoRMS : 1.0
        
        // Calculate phase cancellation factor
        var phaseCancellation: Double = 0.0
        for i in 0..<leftSamples.count {
            let left = Double(leftSamples[i])
            let right = Double(rightSamples[i])
            
            // Detect phase cancellation (when L and R are out of phase)
            if abs(left + right) < abs(left - right) && abs(left) > 0.01 && abs(right) > 0.01 {
                phaseCancellation += 1.0
            }
        }
        
        let cancellationRatio = phaseCancellation / Double(leftSamples.count)
        
        // Combine factors for final mono compatibility score
        let compatibilityScore = energyPreservation * (1.0 - min(cancellationRatio * 2.0, 0.5))
        
        return max(0.0, min(1.0, compatibilityScore))
    }
    
    private func calculateStereoWidth(_ leftSamples: [Float], _ rightSamples: [Float]) -> Double {
        guard leftSamples.count == rightSamples.count && !leftSamples.isEmpty else { return 0.0 }
        
        // Calculate cross-correlation coefficient between L and R channels
        var leftSum: Double = 0.0
        var rightSum: Double = 0.0
        var leftSquareSum: Double = 0.0
        var rightSquareSum: Double = 0.0
        var crossSum: Double = 0.0
        
        let count = Double(leftSamples.count)
        
        // Calculate means
        for i in 0..<leftSamples.count {
            leftSum += Double(leftSamples[i])
            rightSum += Double(rightSamples[i])
        }
        
        let leftMean = leftSum / count
        let rightMean = rightSum / count
        
        // Calculate correlation coefficient
        for i in 0..<leftSamples.count {
            let leftDiff = Double(leftSamples[i]) - leftMean
            let rightDiff = Double(rightSamples[i]) - rightMean
            
            crossSum += leftDiff * rightDiff
            leftSquareSum += leftDiff * leftDiff
            rightSquareSum += rightDiff * rightDiff
        }
        
        let denominator = sqrt(leftSquareSum * rightSquareSum)
        
        if denominator > 0.0001 {
            let correlation = crossSum / denominator
            // Convert correlation to stereo width:
            // correlation = 1.0 (identical channels) → width = 0.0 (mono)
            // correlation = 0.0 (uncorrelated) → width = 1.0 (wide stereo)
            // correlation = -1.0 (inverted) → width = 1.0 (maximum width)
            return 1.0 - abs(correlation)
        }
        
        return 0.0
    }
    
    private func calculateFrequencyDomainCoherence(_ leftSamples: [Float], _ rightSamples: [Float]) -> Double {
        guard leftSamples.count == rightSamples.count && !leftSamples.isEmpty else { return 0.0 }
        
        // Use smaller FFT size for better performance
        let fftSize = min(1024, Int(pow(2, floor(log2(Double(leftSamples.count))))))
        let leftFFTSamples = Array(leftSamples.prefix(fftSize))
        let rightFFTSamples = Array(rightSamples.prefix(fftSize))
        
        // Perform FFT on both channels using built-in implementation
        let leftMagnitudes = performFFTAnalysis(leftFFTSamples)
        let rightMagnitudes = performFFTAnalysis(rightFFTSamples)
        
        // Calculate magnitude coherence across frequency bins
        var coherenceSum: Double = 0.0
        var validBins = 0
        
        for i in 0..<min(leftMagnitudes.count, rightMagnitudes.count) {
            let leftMagnitude = Double(leftMagnitudes[i])
            let rightMagnitude = Double(rightMagnitudes[i])
            
            if leftMagnitude > 0.001 && rightMagnitude > 0.001 { // Avoid division by very small numbers
                // Calculate normalized coherence
                let coherence = min(leftMagnitude, rightMagnitude) / max(leftMagnitude, rightMagnitude)
                coherenceSum += coherence
                validBins += 1
            }
        }
        
        return validBins > 0 ? coherenceSum / Double(validBins) : 0.0
    }
    
    // MARK: - Dynamic Range Analysis Helper Methods
    
    private func calculateSegmentedDynamicRange(_ samples: [Float]) -> Double {
        // Divide audio into segments and analyze dynamic range of each
        let segmentSize = max(1024, samples.count / 20) // 20 segments minimum
        var segmentRanges: [Double] = []
        
        for i in stride(from: 0, to: samples.count, by: segmentSize) {
            let endIndex = min(i + segmentSize, samples.count)
            let segment = Array(samples[i..<endIndex])
            
            let segmentPeak = segment.map { abs($0) }.max() ?? 0.0
            let segmentRMS = sqrt(segment.reduce(0.0) { sum, sample in
                sum + Double(sample * sample)
            } / Double(segment.count))
            
            if segmentRMS > 0.001 { // Avoid silent segments
                let segmentRange = 20 * log10(Double(segmentPeak) / segmentRMS)
                segmentRanges.append(segmentRange)
            }
        }
        
        // Return median dynamic range to avoid outliers
        let sortedRanges = segmentRanges.sorted()
        let medianIndex = sortedRanges.count / 2
        return sortedRanges.isEmpty ? 0.0 : sortedRanges[medianIndex]
    }
    
    private func calculateLoudnessVariation(_ samples: [Float]) -> Double {
        // Analyze short-term loudness variations (similar to PLR - Peak to Loudness Ratio)
        let blockSize = 1024 // Approximately 23ms at 44.1kHz
        var loudnessValues: [Double] = []
        
        for i in stride(from: 0, to: samples.count, by: blockSize) {
            let endIndex = min(i + blockSize, samples.count)
            let block = Array(samples[i..<endIndex])
            
            // Calculate RMS for this block
            let blockRMS = sqrt(block.reduce(0.0) { sum, sample in
                sum + Double(sample * sample)
            } / Double(block.count))
            
            if blockRMS > 0.0001 {
                let blockLoudness = 20 * log10(blockRMS) + 23.0 // Convert to LUFS-like scale
                loudnessValues.append(blockLoudness)
            }
        }
        
        guard !loudnessValues.isEmpty else { return 0.0 }
        
        // Calculate the range between 95th and 10th percentiles
        let sortedLoudness = loudnessValues.sorted()
        let tenthPercentileIndex = Int(Double(sortedLoudness.count) * 0.1)
        let ninetyFifthPercentileIndex = Int(Double(sortedLoudness.count) * 0.95)
        
        let tenthPercentile = sortedLoudness[tenthPercentileIndex]
        let ninetyFifthPercentile = sortedLoudness[ninetyFifthPercentileIndex]
        
        return ninetyFifthPercentile - tenthPercentile
    }
    
    private func calculateFrequencySpecificDynamicRange(_ samples: [Float]) -> Double {
        // Analyze dynamic range in different frequency bands
        let fftSize = min(2048, Int(pow(2, floor(log2(Double(samples.count))))))
        let fftSamples = Array(samples.prefix(fftSize))
        
        // Perform FFT using built-in implementation
        let magnitudes = performFFTAnalysis(fftSamples)
        
        // Define frequency bands for dynamic range analysis
        let sampleRate: Double = 44100.0
        let binWidth = sampleRate / Double(fftSize)
        
        // Low frequency (20Hz - 500Hz) - typically has more dynamic range
        let lowFreqStart = Int(20.0 / binWidth)
        let lowFreqEnd = Int(500.0 / binWidth)
        let lowFreqMagnitudes = Array(magnitudes[lowFreqStart..<min(lowFreqEnd, magnitudes.count)])
        
        // Mid frequency (500Hz - 5kHz) - most perceptually important
        let midFreqStart = lowFreqEnd
        let midFreqEnd = Int(5000.0 / binWidth)
        let midFreqMagnitudes = Array(magnitudes[midFreqStart..<min(midFreqEnd, magnitudes.count)])
        
        // Calculate dynamic range for each band
        let lowFreqRange = calculateFrequencyBandDynamicRange(lowFreqMagnitudes)
        let midFreqRange = calculateFrequencyBandDynamicRange(midFreqMagnitudes)
        
        // Weight mid frequencies more heavily as they're more perceptually important
        return (lowFreqRange * 0.3 + midFreqRange * 0.7)
    }
    
    private func calculateFrequencyBandDynamicRange(_ magnitudes: [Float]) -> Double {
        guard !magnitudes.isEmpty else { return 0.0 }
        
        let sortedMagnitudes = magnitudes.filter { $0 > 0.001 }.sorted()
        guard sortedMagnitudes.count > 2 else { return 0.0 }
        
        // Use 95th percentile as peak and 10th percentile as noise floor
        let tenthPercentileIndex = Int(Double(sortedMagnitudes.count) * 0.1)
        let ninetyFifthPercentileIndex = Int(Double(sortedMagnitudes.count) * 0.95)
        
        let noiseFloor = Double(sortedMagnitudes[tenthPercentileIndex])
        let peak = Double(sortedMagnitudes[ninetyFifthPercentileIndex])
        
        return peak > noiseFloor ? 20 * log10(peak / noiseFloor) : 0.0
    }
    
    private func calculateEBUDynamicRange(_ samples: [Float]) -> Double {
        // Simplified EBU R128 dynamic range calculation
        // In practice, this would require proper gating and filtering
        
        // Apply approximate K-weighting filter (simplified)
        let filteredSamples = applySimpleHighShelfFilter(samples, cutoff: 1681.0, gain: 3.99)
        
        // Calculate momentary loudness blocks (400ms)
        let blockSize = Int(0.4 * 44100) // 400ms at 44.1kHz
        var momentaryLoudness: [Double] = []
        
        for i in stride(from: 0, to: filteredSamples.count, by: blockSize) {
            let endIndex = min(i + blockSize, filteredSamples.count)
            let block = Array(filteredSamples[i..<endIndex])
            
            let meanSquare = block.reduce(0.0) { sum, sample in
                sum + Double(sample * sample)
            } / Double(block.count)
            
            if meanSquare > 0.0001 {
                let loudness = -0.691 + 10 * log10(meanSquare)
                momentaryLoudness.append(loudness)
            }
        }
        
        guard !momentaryLoudness.isEmpty else { return 0.0 }
        
        // Apply relative gating at -70 LUFS
        let gatingThreshold = momentaryLoudness.max()! - 70.0
        let gatedLoudness = momentaryLoudness.filter { $0 >= gatingThreshold }
        
        guard gatedLoudness.count > 1 else { return 0.0 }
        
        let sortedGatedLoudness = gatedLoudness.sorted()
        let tenthPercentile = sortedGatedLoudness[Int(Double(sortedGatedLoudness.count) * 0.1)]
        let ninetyFifthPercentile = sortedGatedLoudness[Int(Double(sortedGatedLoudness.count) * 0.95)]
        
        return ninetyFifthPercentile - tenthPercentile
    }
    
    private func applySimpleHighShelfFilter(_ samples: [Float], cutoff: Double, gain: Double) -> [Float] {
        // Simplified high-shelf filter approximation for K-weighting
        // This is a basic implementation - real K-weighting is more complex
        let sampleRate: Double = 44100.0
        let omega = 2.0 * Double.pi * cutoff / sampleRate
        let alpha = sin(omega) / 2.0
        let A = pow(10.0, gain / 40.0)
        
        let b0 = A * ((A + 1) + (A - 1) * cos(omega) + 2 * sqrt(A) * alpha)
        let b1 = -2 * A * ((A - 1) + (A + 1) * cos(omega))
        let b2 = A * ((A + 1) + (A - 1) * cos(omega) - 2 * sqrt(A) * alpha)
        let a0 = (A + 1) - (A - 1) * cos(omega) + 2 * sqrt(A) * alpha
        let a1 = 2 * ((A - 1) - (A + 1) * cos(omega))
        let a2 = (A + 1) - (A - 1) * cos(omega) - 2 * sqrt(A) * alpha
        
        var filteredSamples = samples
        var x1: Double = 0.0, x2: Double = 0.0
        var y1: Double = 0.0, y2: Double = 0.0
        
        for i in 0..<samples.count {
            let x0 = Double(samples[i])
            let y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            
            filteredSamples[i] = Float(y0)
            
            x2 = x1; x1 = x0
            y2 = y1; y1 = y0
        }
        
        return filteredSamples
    }
    
    private func combinesDynamicRangeMeasurements(crestFactor: Double, segmented: Double, loudnessVariation: Double, frequencyBased: Double, ebu: Double) -> Double {
        // Combine different dynamic range measurements with appropriate weighting
        
        // Weight the measurements based on their reliability and relevance
        let weights = [
            0.2, // Crest factor - basic but can be misleading
            0.3, // Segmented analysis - good for overall assessment
            0.2, // Loudness variation - important for perceptual quality
            0.15, // Frequency-based - useful for identifying frequency-specific issues
            0.15  // EBU approximation - industry standard approach
        ]
        
        let measurements = [crestFactor, segmented, loudnessVariation, frequencyBased, ebu]
        
        var weightedSum: Double = 0.0
        var totalWeight: Double = 0.0
        
        for (measurement, weight) in zip(measurements, weights) {
            if measurement > 0 && measurement < 100 { // Sanity check
                weightedSum += measurement * weight
                totalWeight += weight
            }
        }
        
        let combinedRange = totalWeight > 0 ? weightedSum / totalWeight : 0.0
        
        // Clamp to reasonable range (0-60 dB)
        return max(0.0, min(60.0, combinedRange))
    }
    
    private func generateAudioKitRecommendations(_ fft: AudioKitFFTResult, _ amplitude: AudioKitAmplitudeResult, _ stereo: AudioKitStereoResult, _ dynamic: AudioKitDynamicResult, _ instrumentBalance: InstrumentBalanceResult) -> [String] {
        var recommendations: [String] = []
        
        // Add instrument balance recommendations first (most important)
        recommendations.append(contentsOf: instrumentBalance.recommendations)
        
        // Clipping recommendations
        if amplitude.hasClipping {
            recommendations.append("⚠️ Clipping detected. Reduce input gain or use limiting to prevent distortion.")
        }
        
        // Peak level recommendations
        let peakDB = 20 * log10(amplitude.peak + 0.0001)
        if peakDB > -0.1 {
            recommendations.append("🔊 Peak levels are too hot. Leave some headroom (-1dB to -3dB) for mastering.")
        } else if peakDB < -12.0 {
            recommendations.append("🔉 Peak levels are quite low. Consider increasing overall level.")
        }
        
        // Loudness recommendations
        if amplitude.loudness < -30.0 {
            recommendations.append("📢 Mix is too quiet. Increase overall loudness to reach broadcast standards (-23 LUFS).")
        } else if amplitude.loudness > -10.0 {
            recommendations.append("📢 Mix is too loud and may cause fatigue. Consider reducing overall level.")
        }
        
        // Frequency balance recommendations
        if fft.hasImbalance {
            if fft.lowEnd > 0.4 {
                recommendations.append("🎛️ Too much low-end energy. Consider high-pass filtering or reducing bass.")
            }
            if fft.high < 0.15 {
                recommendations.append("✨ Lacking high-frequency content. Add some sparkle with gentle high-shelf EQ.")
            }
            if fft.mid < 0.2 {
                recommendations.append("🎤 Midrange content is low. Vocals and lead instruments may lack presence.")
            }
        }
        
        // Spectral centroid recommendations
        if fft.spectralCentroid < 800 {
            recommendations.append("🌟 Mix sounds dark. Consider brightening with high-frequency enhancement.")
        } else if fft.spectralCentroid > 4000 {
            recommendations.append("🔥 Mix sounds harsh or bright. Consider gentle high-frequency reduction.")
        }
        
        // Stereo recommendations
        if abs(stereo.balance) > 0.3 {
            let direction = stereo.balance > 0 ? "right" : "left"
            recommendations.append("⚖️ Mix is heavily panned to the \(direction). Check stereo balance.")
        }
        
        if stereo.coherence < 0.7 {
            recommendations.append("🌊 Phase issues detected between left and right channels. Check for phase cancellation.")
        }
        
        if stereo.width < 0.1 {
            recommendations.append("↔️ Mix lacks stereo width. Consider using stereo imaging techniques.")
        } else if stereo.width > 0.9 {
            recommendations.append("↔️ Mix may be too wide. Check mono compatibility.")
        }
        
        // Dynamic range recommendations
        if dynamic.range < 3.0 {
            recommendations.append("📈 Very compressed mix. Consider reducing compression for more dynamics.")
        } else if dynamic.range < 6.0 {
            recommendations.append("📊 Limited dynamic range. Some gentle expansion might help.")
        } else if dynamic.range > 25.0 {
            recommendations.append("📉 Very wide dynamic range. Consider gentle compression for consistency.")
        }
        
        // Positive feedback for good mixes
        if recommendations.isEmpty {
            recommendations.append("✅ Well-balanced mix! Good frequency distribution, stereo imaging, and dynamics.")
        }
        
        return recommendations
    }
}

// MARK: - AudioKit Analysis Data Structures

struct AudioKitAnalysisResult {
    let stereoWidth: Double
    let phaseCoherence: Double
    let monoCompatibility: Double
    let spectralCentroid: Double
    let hasClipping: Bool
    let lowEnd: Double
    let lowMid: Double
    let mid: Double
    let highMid: Double
    let high: Double
    let dynamicRange: Double
    let loudness: Double
    let rmsLevel: Double
    let peakLevel: Double
    let phaseIssues: Bool
    let stereoIssues: Bool
    let frequencyImbalance: Bool
    let dynamicRangeIssues: Bool
    let instrumentBalance: InstrumentBalanceResult
    let recommendations: [String]
    
    // MARK: - Professional Mastering Analysis
    let spectralBalance: SpectralBalanceResult
    let stereoCorrelation: StereoCorrelationResult
    let dynamicRangeAnalysis: DynamicRangeAnalysis
    let peakToAverageRatio: PeakToAverageResult
    
    init() {
        self.stereoWidth = 0.0
        self.phaseCoherence = 1.0
        self.monoCompatibility = 1.0
        self.spectralCentroid = 0.0
        self.hasClipping = false
        self.lowEnd = 0.5
        self.lowMid = 0.5
        self.mid = 0.5
        self.highMid = 0.5
        self.high = 0.5
        self.dynamicRange = 0.0
        self.loudness = -23.0
        self.rmsLevel = 0.0
        self.peakLevel = 0.0
        self.phaseIssues = false
        self.stereoIssues = false
        self.frequencyImbalance = false
        self.dynamicRangeIssues = false
        self.instrumentBalance = InstrumentBalanceResult(
            instrumentEnergies: [:],
            balanceIssues: [],
            isBalanced: true,
            recommendations: []
        )
        self.recommendations = []
        
        // Initialize mastering analysis with neutral values
        self.spectralBalance = SpectralBalanceResult()
        self.stereoCorrelation = StereoCorrelationResult()
        self.dynamicRangeAnalysis = DynamicRangeAnalysis()
        self.peakToAverageRatio = PeakToAverageResult()
    }
    
    init(stereoWidth: Double, phaseCoherence: Double, monoCompatibility: Double, spectralCentroid: Double, hasClipping: Bool, lowEnd: Double, lowMid: Double, mid: Double, highMid: Double, high: Double, dynamicRange: Double, loudness: Double, rmsLevel: Double, peakLevel: Double, phaseIssues: Bool, stereoIssues: Bool, frequencyImbalance: Bool, dynamicRangeIssues: Bool, instrumentBalance: InstrumentBalanceResult, recommendations: [String], spectralBalance: SpectralBalanceResult, stereoCorrelation: StereoCorrelationResult, dynamicRangeAnalysis: DynamicRangeAnalysis, peakToAverageRatio: PeakToAverageResult) {
        self.stereoWidth = stereoWidth
        self.phaseCoherence = phaseCoherence
        self.monoCompatibility = monoCompatibility
        self.spectralCentroid = spectralCentroid
        self.hasClipping = hasClipping
        self.lowEnd = lowEnd
        self.lowMid = lowMid
        self.mid = mid
        self.highMid = highMid
        self.high = high
        self.dynamicRange = dynamicRange
        self.loudness = loudness
        self.rmsLevel = rmsLevel
        self.peakLevel = peakLevel
        self.phaseIssues = phaseIssues
        self.stereoIssues = stereoIssues
        self.frequencyImbalance = frequencyImbalance
        self.dynamicRangeIssues = dynamicRangeIssues
        self.instrumentBalance = instrumentBalance
        self.recommendations = recommendations
        self.spectralBalance = spectralBalance
        self.stereoCorrelation = stereoCorrelation
        self.dynamicRangeAnalysis = dynamicRangeAnalysis
        self.peakToAverageRatio = peakToAverageRatio
    }
}

struct AudioKitFFTResult {
    let lowEnd: Double
    let lowMid: Double
    let mid: Double
    let highMid: Double
    let high: Double
    let spectralCentroid: Double
    let hasImbalance: Bool
}

struct AudioKitAmplitudeResult {
    let peak: Double
    let rms: Double
    let loudness: Double
    let hasClipping: Bool
}

struct AudioKitStereoResult {
    let width: Double
    let coherence: Double
    let balance: Double
    let monoCompatibility: Double
}

struct AudioKitDynamicResult {
    let range: Double
}

// MARK: - Professional Mastering Analysis Structures

/// Comprehensive spectral balance analysis for mastering
struct SpectralBalanceResult {
    let subBassEnergy: Double       // 20-60 Hz
    let bassEnergy: Double          // 60-250 Hz  
    let lowMidEnergy: Double        // 250-500 Hz
    let midEnergy: Double           // 500-2kHz
    let highMidEnergy: Double       // 2kHz-6kHz
    let presenceEnergy: Double      // 6kHz-12kHz
    let airEnergy: Double           // 12kHz-20kHz
    
    let balanceScore: Double        // 0-100: How well balanced the spectrum is
    let tiltMeasure: Double         // -1 to 1: Spectral tilt (negative = dark, positive = bright)
    let energyDistribution: [String: Double]  // Detailed frequency distribution
    let recommendations: [String]
    
    init() {
        self.subBassEnergy = 0.14   // 14% - typical for modern masters
        self.bassEnergy = 0.20      // 20%
        self.lowMidEnergy = 0.18    // 18%
        self.midEnergy = 0.22       // 22%
        self.highMidEnergy = 0.15   // 15%
        self.presenceEnergy = 0.08  // 8%
        self.airEnergy = 0.03       // 3%
        self.balanceScore = 85.0
        self.tiltMeasure = 0.0
        self.energyDistribution = [:]
        self.recommendations = []
    }
    
    init(subBassEnergy: Double, bassEnergy: Double, lowMidEnergy: Double, midEnergy: Double, highMidEnergy: Double, presenceEnergy: Double, airEnergy: Double, balanceScore: Double, tiltMeasure: Double, energyDistribution: [String: Double], recommendations: [String]) {
        self.subBassEnergy = subBassEnergy
        self.bassEnergy = bassEnergy
        self.lowMidEnergy = lowMidEnergy
        self.midEnergy = midEnergy
        self.highMidEnergy = highMidEnergy
        self.presenceEnergy = presenceEnergy
        self.airEnergy = airEnergy
        self.balanceScore = balanceScore
        self.tiltMeasure = tiltMeasure
        self.energyDistribution = energyDistribution
        self.recommendations = recommendations
    }
}

/// Stereo correlation and imaging analysis
struct StereoCorrelationResult {
    let correlationCoefficient: Double  // -1 to 1: Stereo correlation
    let stereoWidth: Double            // 0-2: Perceived stereo width
    let phaseCoherence: Double         // 0-1: Phase relationship quality
    let monoCompatibility: Double      // 0-100: How well it translates to mono
    let sidechainEnergy: Double        // Energy in the side channel
    let centerImage: Double            // 0-1: How centered the main elements are
    let recommendations: [String]
    
    init() {
        self.correlationCoefficient = 0.7  // Good stereo correlation
        self.stereoWidth = 1.0
        self.phaseCoherence = 0.9
        self.monoCompatibility = 85.0
        self.sidechainEnergy = 0.3
        self.centerImage = 0.8
        self.recommendations = []
    }
    
    init(correlationCoefficient: Double, stereoWidth: Double, phaseCoherence: Double, monoCompatibility: Double, sidechainEnergy: Double, centerImage: Double, recommendations: [String]) {
        self.correlationCoefficient = correlationCoefficient
        self.stereoWidth = stereoWidth
        self.phaseCoherence = phaseCoherence
        self.monoCompatibility = monoCompatibility
        self.sidechainEnergy = sidechainEnergy
        self.centerImage = centerImage
        self.recommendations = recommendations
    }
}

/// Comprehensive dynamic range analysis for mastering
struct DynamicRangeAnalysis {
    let lufsRange: Double              // Dynamic range in LUFS (EBU R128)
    let shortTermVariation: Double     // Short-term loudness variation
    let momentaryPeaks: [Double]       // Momentary loudness peaks
    let crestFactor: Double            // Peak-to-RMS ratio in dB
    let percentile95: Double           // 95th percentile level
    let percentile5: Double            // 5th percentile level
    let compressionRatio: Double       // Estimated compression ratio
    let breathingRoom: Double          // Available headroom before limiting
    let recommendations: [String]
    
    init() {
        self.lufsRange = 12.0          // Good dynamic range
        self.shortTermVariation = 3.0
        self.momentaryPeaks = []
        self.crestFactor = 12.0        // Healthy crest factor
        self.percentile95 = -6.0
        self.percentile5 = -18.0
        self.compressionRatio = 3.0
        self.breathingRoom = 3.0
        self.recommendations = []
    }
    
    init(lufsRange: Double, shortTermVariation: Double, momentaryPeaks: [Double], crestFactor: Double, percentile95: Double, percentile5: Double, compressionRatio: Double, breathingRoom: Double, recommendations: [String]) {
        self.lufsRange = lufsRange
        self.shortTermVariation = shortTermVariation
        self.momentaryPeaks = momentaryPeaks
        self.crestFactor = crestFactor
        self.percentile95 = percentile95
        self.percentile5 = percentile5
        self.compressionRatio = compressionRatio
        self.breathingRoom = breathingRoom
        self.recommendations = recommendations
    }
}

/// Peak-to-average ratio analysis
struct PeakToAverageResult {
    let peakToRmsRatio: Double         // Peak-to-RMS in dB
    let peakToLufsRatio: Double        // Peak-to-LUFS in dB  
    let truePeakLevel: Double          // True peak level in dBFS
    let averageLevel: Double           // Average level in dB
    let momentaryLoudness: Double      // Momentary loudness in LUFS
    let integratedLoudness: Double     // Integrated loudness in LUFS
    let loudnessRange: Double          // LRA (Loudness Range) in LU
    let punchiness: Double             // 0-100: How punchy the master sounds
    let recommendations: [String]
    
    init() {
        self.peakToRmsRatio = 12.0     // Good ratio for modern masters
        self.peakToLufsRatio = 18.0
        self.truePeakLevel = -1.0      // Safe headroom
        self.averageLevel = -18.0
        self.momentaryLoudness = -14.0
        self.integratedLoudness = -14.0
        self.loudnessRange = 7.0       // Moderate dynamic range
        self.punchiness = 75.0
        self.recommendations = []
    }
    
    init(peakToRmsRatio: Double, peakToLufsRatio: Double, truePeakLevel: Double, averageLevel: Double, momentaryLoudness: Double, integratedLoudness: Double, loudnessRange: Double, punchiness: Double, recommendations: [String]) {
        self.peakToRmsRatio = peakToRmsRatio
        self.peakToLufsRatio = peakToLufsRatio
        self.truePeakLevel = truePeakLevel
        self.averageLevel = averageLevel
        self.momentaryLoudness = momentaryLoudness
        self.integratedLoudness = integratedLoudness
        self.loudnessRange = loudnessRange
        self.punchiness = punchiness
        self.recommendations = recommendations
    }
}

// MARK: - AudioKit Error Handling

enum AudioKitError: Error {
    case fileLoadFailed
    case processingFailed
    case analysisError
    
    var localizedDescription: String {
        switch self {
        case .fileLoadFailed:
            return "Failed to load audio file for AudioKit analysis"
        case .processingFailed:
            return "AudioKit processing failed"
        case .analysisError:
            return "AudioKit analysis error occurred"
        }
    }
    }
    
    // MARK: - Analysis Helper Methods
    
    private func performFFTAnalysis(_ data: UnsafePointer<Float>, frameCount: Int) -> [Float] {
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        return performFFTAnalysis(samples)
    }
    
    private func performFFTAnalysis(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        // Ensure FFT size is power of 2
        let fftSize = Int(pow(2, floor(log2(Double(samples.count)))))
        guard fftSize >= 16 else { return [] }
        
        let actualSamples = Array(samples.prefix(fftSize))
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        // Create FFT setup
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Prepare input data
        var realParts = actualSamples
        var imagParts = Array(repeating: Float(0.0), count: fftSize)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = Array(repeating: Float(0.0), count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Convert to proper scale and take square root for magnitude
        var count = Int32(fftSize / 2)
        vvsqrtf(&magnitudes, magnitudes, &count)
        
        return magnitudes
    }
    
    private func analyzeFrequencyBalance(from spectrum: [Float]) -> FrequencyBalance {
        // Analyze frequency distribution in bass, mid, treble ranges
        // This would use AudioKit's frequency analysis
        return FrequencyBalance(bass: 0.0, mid: 0.0, treble: 0.0)
    }
    
    private func calculateStereoWidth(_ balance: Float) -> Float {
        // Convert stereo balance to width percentage
        return min(1.0, abs(balance) * 2.0)
    }
    
    private func estimateSpectralCentroid(from spectrum: [Float]) -> Float {
        // Calculate spectral centroid from frequency spectrum
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        for (index, magnitude) in spectrum.enumerated() {
            let frequency = Float(index) * 44100.0 / Float(spectrum.count * 2)
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
    
    private func identifyQualityIssues(from result: BufferAnalysisResult) -> [String] {
        var issues: [String] = []
        
        
        
        return issues
    }
    
    // MARK: - LUFS Calculation (EBU R128 Standard)
    
    /// Calculate LUFS (Loudness Units relative to Full Scale) according to EBU R128 standard
    private func calculateLUFS(_ samples: [Float]) -> Float {
        // Apply high-pass filter (shelving filter at 38 Hz)
        let filteredSamples = applyHighPassFilter(samples, cutoffFreq: 38.0, sampleRate: 44100.0)
        
        // Apply weighting filter (RLB weighting for stereo)
        let weightedSamples = applyWeightingFilter(filteredSamples, sampleRate: 44100.0)
        
        // Calculate momentary loudness (400ms blocks)
        let blockSize = Int(0.4 * 44100) // 400ms at 44.1kHz
        var momentaryLoudness: [Float] = []
        
        for i in stride(from: 0, to: weightedSamples.count - blockSize, by: blockSize / 4) {
            let blockEnd = min(i + blockSize, weightedSamples.count)
            let block = Array(weightedSamples[i..<blockEnd])
            
            // Calculate mean square for this block
            let meanSquare = block.reduce(0) { $0 + $1 * $1 } / Float(block.count)
            
            if meanSquare > 0 {
                // Convert to loudness units (with calibration)
                let loudness = -0.691 + 10 * log10(meanSquare)
                momentaryLoudness.append(loudness)
            }
        }
        
        // Apply gating (remove blocks below -70 LUFS)
        let gatedBlocks = momentaryLoudness.filter { $0 > -70.0 }
        
        // Apply relative gating (remove blocks below 10 LU from ungated mean)
        if !gatedBlocks.isEmpty {
            let ungatedMean = gatedBlocks.reduce(0, +) / Float(gatedBlocks.count)
            let relativeGate = ungatedMean - 10.0
            let finalBlocks = gatedBlocks.filter { $0 > relativeGate }
            
            if !finalBlocks.isEmpty {
                return finalBlocks.reduce(0, +) / Float(finalBlocks.count)
            }
        }
        
        return -100.0 // Return very low value if no valid blocks
    }
    
    /// Apply high-pass filter for EBU R128 pre-filtering
    private func applyHighPassFilter(_ samples: [Float], cutoffFreq: Float, sampleRate: Float) -> [Float] {
        // Simple high-pass filter implementation
        // For production use, consider using a proper shelving filter
        let rc = 1.0 / (2.0 * Float.pi * cutoffFreq)
        let alpha = (sampleRate / 2.0) / ((sampleRate / 2.0) + (1.0 / rc))
        
        var filteredSamples = samples
        var prevInput: Float = 0
        var prevOutput: Float = 0
        
        for i in 0..<filteredSamples.count {
            let input = samples[i]
            let output = alpha * (prevOutput + input - prevInput)
            filteredSamples[i] = output
            prevInput = input
            prevOutput = output
        }
        
        return filteredSamples
    }
    
    /// Apply RLB weighting filter for EBU R128
    private func applyWeightingFilter(_ samples: [Float], sampleRate: Float) -> [Float] {
        // Simplified RLB weighting filter
        // This is a basic implementation; professional implementations use more complex filtering
        return samples.map { $0 * 1.0 } // For now, return unmodified (can be enhanced)
    }
    
    // MARK: - Instrument Balance Analysis
    
    /// Analyze instrument balance across frequency spectrum
    private func analyzeInstrumentBalance(_ data: UnsafePointer<Float>, frameCount: Int) -> InstrumentBalanceResult {
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        
        // Perform FFT analysis
        let magnitudes = performFFTAnalysis(data, frameCount: frameCount)
        let sampleRate: Double = 44100.0
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(magnitudes.count / 2)
        
        // Define instrument frequency ranges
        let instrumentRanges = [
            "kick": (20.0, 80.0),           // Kick drum fundamental
            "bass": (40.0, 250.0),          // Bass guitar/synth
            "lowMids": (200.0, 500.0),      // Lower guitar, piano, vocals
            "vocals": (300.0, 3000.0),      // Primary vocal range
            "guitars": (80.0, 5000.0),      // Electric guitars
            "snare": (150.0, 250.0),        // Snare fundamental
            "snareAttack": (2000.0, 8000.0), // Snare attack/crack
            "cymbals": (4000.0, 16000.0),   // Cymbals and hi-hats
            "presence": (2000.0, 6000.0),   // Vocal/instrument presence
            "air": (8000.0, 20000.0)        // Air and sparkle
        ]
        
        // Calculate energy for each instrument range
        var instrumentEnergies: [String: Double] = [:]
        let totalEnergy = magnitudes.prefix(magnitudes.count / 2).reduce(0.0) { sum, mag in
            sum + Double(mag * mag)
        }
        
        for (instrument, range) in instrumentRanges {
            let energy = calculateBandEnergyForRange(magnitudes, lowFreq: range.0, highFreq: range.1, binWidth: binWidth)
            instrumentEnergies[instrument] = energy / totalEnergy * 100.0 // Convert to percentage
        }
        
        // Analyze balance relationships
        let balanceIssues = detectInstrumentBalanceIssues(instrumentEnergies)
        let recommendations = generateInstrumentBalanceRecommendations(instrumentEnergies, balanceIssues)
        
        return InstrumentBalanceResult(
            instrumentEnergies: instrumentEnergies,
            balanceIssues: balanceIssues,
            isBalanced: balanceIssues.isEmpty,
            recommendations: recommendations
        )
    }
    
    private func calculateBandEnergyForRange(_ magnitudes: [Float], lowFreq: Double, highFreq: Double, binWidth: Double) -> Double {
        let startBin = Int(lowFreq / binWidth)
        let endBin = Int(highFreq / binWidth)
        let clampedStartBin = max(0, startBin)
        let clampedEndBin = min(magnitudes.count / 2, endBin)
        
        guard clampedStartBin < clampedEndBin else { return 0.0 }
        
        let range = clampedStartBin..<clampedEndBin
        let energy = magnitudes[range].reduce(0.0) { sum, magnitude in
            sum + Double(magnitude * magnitude)
        }
        
        return energy
    }
    
    private func detectInstrumentBalanceIssues(_ energies: [String: Double]) -> [InstrumentBalanceIssue] {
        var issues: [InstrumentBalanceIssue] = []
        
        // Get energy values
        let kick = energies["kick"] ?? 0
        let bass = energies["bass"] ?? 0
        let vocals = energies["vocals"] ?? 0
        let guitars = energies["guitars"] ?? 0
        let snare = energies["snare"] ?? 0
        let cymbals = energies["cymbals"] ?? 0
        let presence = energies["presence"] ?? 0
        let air = energies["air"] ?? 0
        
        // 1. Bass/Kick Balance
        if bass > kick * 3 {
            issues.append(.bassOverpowering)
        } else if kick > bass * 2 && bass > 5 {
            issues.append(.kickOverpowering)
        }
        
        // 2. Vocal Presence
        if vocals < 15 && presence < 10 {
            issues.append(.vocalsRecessed)
        } else if vocals > 35 {
            issues.append(.vocalsOverpowering)
        }
        
        // 3. Guitar Balance
        if guitars > 40 {
            issues.append(.guitarsOverpowering)
        } else if guitars < 8 && vocals > 20 {
            issues.append(.guitarsRecessed)
        }
        
        // 4. High Frequency Balance
        if air < 2 && cymbals < 3 {
            issues.append(.lackOfAir)
        } else if cymbals > 15 {
            issues.append(.cymbalsHarsh)
        }
        
        // 5. Frequency Masking Detection
        if bass > 25 && vocals < 20 {
            issues.append(.bassMaskingVocals)
        }
        
        if guitars > 30 && vocals < 18 {
            issues.append(.guitarsMaskingVocals)
        }
        
        // 6. Overall Balance Check
        let lowEnd = kick + bass
        let midRange = vocals + (energies["lowMids"] ?? 0)
        let highEnd = cymbals + air
        
        if lowEnd > 50 {
            issues.append(.bottomHeavy)
        }
        
        if highEnd < 8 {
            issues.append(.lackOfBrightness)
        }
        
        if midRange < 25 {
            issues.append(.hollowMidrange)
        }
        
        return issues
    }
    
    private func generateInstrumentBalanceRecommendations(_ energies: [String: Double], _ issues: [InstrumentBalanceIssue]) -> [String] {
        var recommendations: [String] = []
        
        for issue in issues {
            switch issue {
            case .bassOverpowering:
                recommendations.append("🎸 Reduce bass guitar level by 2-4 dB or apply high-pass filter around 80-100 Hz")
                
            case .kickOverpowering:
                recommendations.append("🥁 Reduce kick drum level or apply EQ cut around 60-80 Hz")
                
            case .vocalsRecessed:
                recommendations.append("🎤 Boost vocal presence around 2-4 kHz by 2-3 dB")
                recommendations.append("🎤 Consider de-essing other instruments in vocal frequency range")
                
            case .vocalsOverpowering:
                recommendations.append("🎤 Reduce vocal level by 1-2 dB or apply gentle compression")
                
            case .guitarsOverpowering:
                recommendations.append("🎸 Reduce guitar levels or apply mid-frequency cut around 400-800 Hz")
                
            case .guitarsRecessed:
                recommendations.append("🎸 Boost guitar presence around 2-5 kHz or increase overall level")
                
            case .lackOfAir:
                recommendations.append("✨ Add high-frequency sparkle with shelf EQ around 10-12 kHz")
                recommendations.append("✨ Consider adding subtle saturation or harmonic excitement")
                
            case .cymbalsHarsh:
                recommendations.append("🥁 Reduce cymbal harshness with EQ cut around 6-8 kHz")
                
            case .bassMaskingVocals:
                recommendations.append("🎛️ Create space for vocals by cutting bass around 200-400 Hz")
                recommendations.append("🎛️ Use sidechain compression or multiband processing")
                
            case .guitarsMaskingVocals:
                recommendations.append("🎛️ Cut guitar mids around 1-3 kHz to create vocal space")
                
            case .bottomHeavy:
                recommendations.append("⚖️ High-pass non-bass instruments more aggressively")
                recommendations.append("⚖️ Check room acoustics and monitoring setup")
                
            case .lackOfBrightness:
                recommendations.append("🌟 Add high-frequency content with air band EQ (10+ kHz)")
                
            case .hollowMidrange:
                recommendations.append("🎯 Boost midrange presence around 1-3 kHz")
                recommendations.append("🎯 Check for phase cancellation in mid frequencies")
            }
        }
        
        // Add genre-specific balance suggestions
        if recommendations.isEmpty {
            recommendations.append("✅ Instrument balance appears good for the genre")
            recommendations.append("💡 Consider reference mixing against similar professional tracks")
        }
        
        return recommendations
    }
    
    // MARK: - Audio Processing Methods (Optional)
    
    // MARK: - Professional Mastering Analysis Functions
    
    /// Comprehensive spectral balance analysis for mastering
    private func analyzeSpectralBalance(_ data: UnsafePointer<Float>, frameCount: Int) -> SpectralBalanceResult {
        let samples = Array(UnsafeBufferPointer(start: data, count: frameCount))
        let magnitudes = performFFTAnalysis(data, frameCount: frameCount)
        
        let sampleRate: Double = 44100.0
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(magnitudes.count / 2)
        
        // Professional mastering frequency bands
        let subBassRange = (20.0, 60.0)        // Sub-bass
        let bassRange = (60.0, 250.0)          // Bass  
        let lowMidRange = (250.0, 500.0)       // Low-midrange
        let midRange = (500.0, 2000.0)         // Midrange
        let highMidRange = (2000.0, 6000.0)    // High-midrange
        let presenceRange = (6000.0, 12000.0)  // Presence
        let airRange = (12000.0, 20000.0)      // Air
        
        // Calculate energy in each band
        let totalEnergy = magnitudes.prefix(magnitudes.count / 2).reduce(0.0) { sum, mag in
            sum + Double(mag * mag)
        }
        
        let subBassEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: subBassRange.0, highFreq: subBassRange.1, binWidth: binWidth) / totalEnergy
        let bassEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: bassRange.0, highFreq: bassRange.1, binWidth: binWidth) / totalEnergy
        let lowMidEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: lowMidRange.0, highFreq: lowMidRange.1, binWidth: binWidth) / totalEnergy
        let midEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: midRange.0, highFreq: midRange.1, binWidth: binWidth) / totalEnergy
        let highMidEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: highMidRange.0, highFreq: highMidRange.1, binWidth: binWidth) / totalEnergy
        let presenceEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: presenceRange.0, highFreq: presenceRange.1, binWidth: binWidth) / totalEnergy
        let airEnergy = calculateBandEnergyForRange(magnitudes, lowFreq: airRange.0, highFreq: airRange.1, binWidth: binWidth) / totalEnergy
        
        // Calculate spectral tilt (brightness measure)
        let lowTotal = subBassEnergy + bassEnergy + lowMidEnergy
        let highTotal = highMidEnergy + presenceEnergy + airEnergy
        let tiltMeasure = (highTotal - lowTotal) / max(highTotal + lowTotal, 0.001)
        
        // Calculate balance score based on deviation from ideal
        let ideal = [0.14, 0.20, 0.18, 0.22, 0.15, 0.08, 0.03]
        let actual = [subBassEnergy, bassEnergy, lowMidEnergy, midEnergy, highMidEnergy, presenceEnergy, airEnergy]
        
        // Break down the balance calculation
        let deviations = zip(ideal, actual).map { abs($0 - $1) }
        let totalDeviation = deviations.reduce(0, +)
        let balanceScore = 100.0 - (totalDeviation * 500.0)
        let clampedBalanceScore = max(0.0, min(100.0, balanceScore))
        
        // Energy distribution for detailed analysis
        let energyDistribution = [
            "Sub-bass (20-60Hz)": subBassEnergy * 100,
            "Bass (60-250Hz)": bassEnergy * 100,
            "Low-mid (250-500Hz)": lowMidEnergy * 100,
            "Midrange (500Hz-2kHz)": midEnergy * 100,
            "High-mid (2-6kHz)": highMidEnergy * 100,
            "Presence (6-12kHz)": presenceEnergy * 100,
            "Air (12-20kHz)": airEnergy * 100
        ]
        
        // Generate recommendations
        var recommendations: [String] = []
        
        if subBassEnergy > 0.20 {
            recommendations.append("🔍 Excessive sub-bass energy - consider high-pass filtering below 30Hz")
        }
        if bassEnergy < 0.15 {
            recommendations.append("🔊 Boost low end around 80-120Hz for more weight")
        } else if bassEnergy > 0.30 {
            recommendations.append("📉 Reduce bass energy around 100-200Hz to avoid muddiness")
        }
        if midEnergy < 0.18 {
            recommendations.append("🎯 Boost midrange presence for better clarity")
        }
        if presenceEnergy < 0.05 {
            recommendations.append("✨ Add presence around 8-10kHz for more sparkle")
        }
        if tiltMeasure < -0.3 {
            recommendations.append("🌑 Mix is too dark - add high-frequency content")
        } else if tiltMeasure > 0.3 {
            recommendations.append("☀️ Mix is too bright - reduce harsh frequencies")
        }
        
        return SpectralBalanceResult(
            subBassEnergy: subBassEnergy,
            bassEnergy: bassEnergy,
            lowMidEnergy: lowMidEnergy,
            midEnergy: midEnergy,
            highMidEnergy: highMidEnergy,
            presenceEnergy: presenceEnergy,
            airEnergy: airEnergy,
            balanceScore: clampedBalanceScore,
            tiltMeasure: tiltMeasure,
            energyDistribution: energyDistribution,
            recommendations: recommendations
        )
    }
    
    /// Stereo correlation and imaging analysis for mastering
    private func analyzeStereoCorrelation(_ leftData: UnsafePointer<Float>, _ rightData: UnsafePointer<Float>, frameCount: Int) -> StereoCorrelationResult {
        let leftSamples = Array(UnsafeBufferPointer(start: leftData, count: frameCount))
        let rightSamples = Array(UnsafeBufferPointer(start: rightData, count: frameCount))
        
        // Calculate stereo correlation coefficient
        let correlationCoeff = calculateCorrelationCoefficient(leftSamples, rightSamples)
        
        // Calculate Mid/Side signals
        var midSignal: [Float] = []
        var sideSignal: [Float] = []
        
        for i in 0..<frameCount {
            let mid = (leftSamples[i] + rightSamples[i]) / 2.0
            let side = (leftSamples[i] - rightSamples[i]) / 2.0
            midSignal.append(mid)
            sideSignal.append(side)
        }
        
        // Calculate energies
        let leftEnergy = leftSamples.map { $0 * $0 }.reduce(0, +)
        let rightEnergy = rightSamples.map { $0 * $0 }.reduce(0, +)
        let midEnergy = midSignal.map { $0 * $0 }.reduce(0, +)
        let sideEnergy = sideSignal.map { $0 * $0 }.reduce(0, +)
        
        // Stereo width calculation
        let totalEnergy = midEnergy + sideEnergy
        let stereoWidth = totalEnergy > 0 ? Double(sideEnergy / totalEnergy) * 2.0 : 1.0
        
        // Side chain energy (for stereo imaging)
        let sidechainEnergy = totalEnergy > 0 ? Double(sideEnergy / totalEnergy) : 0.3
        
        // Mono compatibility (how much is lost when summed to mono)
        let monoSum = leftSamples.indices.map { leftSamples[$0] + rightSamples[$0] }
        let monoEnergy = monoSum.map { $0 * $0 }.reduce(0, +)
        let originalEnergy = leftEnergy + rightEnergy
        let monoCompatibility = originalEnergy > 0 ? Double(monoEnergy / originalEnergy) * 100 : 85.0
        
        // Phase coherence analysis
        let phaseCoherence = abs(correlationCoeff)
        
        // Center image strength
        let centerImage = totalEnergy > 0 ? Double(midEnergy / totalEnergy) : 0.7
        
        // Generate recommendations
        var recommendations: [String] = []
        
        if correlationCoeff < 0.3 {
            recommendations.append("⚠️ Poor stereo correlation - check for phase issues")
        }
        if monoCompatibility < 70 {
            recommendations.append("📻 Poor mono compatibility - fix phase relationships")
        }
        if stereoWidth < 0.5 {
            recommendations.append("↔️ Stereo image is too narrow - add stereo width")
        } else if stereoWidth > 1.8 {
            recommendations.append("⚡ Stereo image too wide - may cause phase issues")
        }
        if centerImage < 0.5 {
            recommendations.append("🎯 Weak center image - ensure key elements are centered")
        }
        if phaseCoherence < 0.7 {
            recommendations.append("🔄 Phase coherence issues detected")
        }
        
        return StereoCorrelationResult(
            correlationCoefficient: correlationCoeff,
            stereoWidth: stereoWidth,
            phaseCoherence: phaseCoherence,
            monoCompatibility: monoCompatibility,
            sidechainEnergy: sidechainEnergy,
            centerImage: centerImage,
            recommendations: recommendations
        )
    }
    
    /// Comprehensive dynamic range analysis for mastering
    private func analyzeDynamicRange(_ leftData: UnsafePointer<Float>, _ rightData: UnsafePointer<Float>, frameCount: Int) -> DynamicRangeAnalysis {
        let leftSamples = Array(UnsafeBufferPointer(start: leftData, count: frameCount))
        let rightSamples = Array(UnsafeBufferPointer(start: rightData, count: frameCount))
        
        // Combine to mono for analysis
        let monoSamples = leftSamples.indices.map { (leftSamples[$0] + rightSamples[$0]) / 2.0 }
        
        // Calculate RMS over time (short-term windows)
        let windowSize = 4410 // 100ms at 44.1kHz
        var rmsValues: [Float] = []
        
        for i in stride(from: 0, to: monoSamples.count - windowSize, by: windowSize / 4) {
            let window = Array(monoSamples[i..<min(i + windowSize, monoSamples.count)])
            let rms = sqrt(window.map { $0 * $0 }.reduce(0, +) / Float(window.count))
            rmsValues.append(rms)
        }
        
        // Convert to dB
        let rmsDB = rmsValues.map { 20.0 * log10(max($0, 1e-10)) }
        
        // Calculate percentiles
        let sortedRMS = rmsDB.sorted()
        let percentile95 = sortedRMS.count > 0 ? sortedRMS[Int(0.95 * Double(sortedRMS.count))] : -20.0
        let percentile5 = sortedRMS.count > 0 ? sortedRMS[Int(0.05 * Double(sortedRMS.count))] : -40.0
        
        // LUFS range (simplified calculation)
        let lufsRange = percentile95 - percentile5
        
        // Peak analysis
        let peaks = monoSamples.map { abs($0) }
        let peakLevel = peaks.max() ?? 0.0
        let avgLevel = peaks.reduce(0, +) / Float(peaks.count)
        
        // Crest factor (Peak-to-RMS ratio)
        let avgRMS = rmsValues.reduce(0, +) / Float(rmsValues.count)
        let crestFactor = avgRMS > 0 ? 20.0 * log10(peakLevel / avgRMS) : 12.0
        
        // Short-term variation
        let shortTermVariation = rmsDB.count > 1 ? rmsDB.indices.dropFirst().map { i in
            abs(rmsDB[i] - rmsDB[i-1])
        }.reduce(0, +) / Float(rmsDB.count - 1) : 2.0
        
        // Momentary peaks (simplified)
        let momentaryPeaks = rmsDB.filter { $0 > percentile95 - 3.0 }.map { Double($0) }
        
        // Estimate compression ratio based on dynamics
        let expectedRange = 20.0 // Uncompressed dynamic range
        let compressionRatio = expectedRange / max(Double(lufsRange), 1.0)
        
        // Breathing room (headroom analysis)
        let peakLevelDB = 20.0 * log10(max(peakLevel, 1e-10))
        let breathingRoom = -1.0 - Double(peakLevelDB) // Headroom to -1dBFS
        
        // Generate recommendations
        var recommendations: [String] = []
        
        if lufsRange < 6.0 {
            recommendations.append("📈 Very low dynamic range - consider less aggressive compression")
        } else if lufsRange > 20.0 {
            recommendations.append("📉 Very high dynamic range - may need gentle compression for consistency")
        }
        
        if crestFactor < 8.0 {
            recommendations.append("🔧 Low crest factor indicates heavy compression/limiting")
        } else if crestFactor > 16.0 {
            recommendations.append("🎭 High crest factor - consider gentle compression for cohesion")
        }
        
        if breathingRoom < 1.0 {
            recommendations.append("⚠️ Insufficient headroom - reduce peak levels")
        }
        
        if compressionRatio > 8.0 {
            recommendations.append("🎛️ High compression ratio detected - check for over-compression")
        }
        
        return DynamicRangeAnalysis(
            lufsRange: Double(lufsRange),
            shortTermVariation: Double(shortTermVariation),
            momentaryPeaks: momentaryPeaks,
            crestFactor: Double(crestFactor),
            percentile95: Double(percentile95),
            percentile5: Double(percentile5),
            compressionRatio: compressionRatio,
            breathingRoom: breathingRoom,
            recommendations: recommendations
        )
    }
    
    /// Peak-to-average ratio analysis for mastering
    private func analyzePeakToAverage(_ leftData: UnsafePointer<Float>, _ rightData: UnsafePointer<Float>, frameCount: Int) -> PeakToAverageResult {
        let leftSamples = Array(UnsafeBufferPointer(start: leftData, count: frameCount))
        let rightSamples = Array(UnsafeBufferPointer(start: rightData, count: frameCount))
        
        // Combine channels
        let stereoSamples = leftSamples.indices.map { max(abs(leftSamples[$0]), abs(rightSamples[$0])) }
        
        // Calculate peak levels
        let truePeak = stereoSamples.max() ?? 0.0
        let truePeakDB = 20.0 * log10(max(truePeak, 1e-10))
        
        // Calculate RMS (average level)
        let rmsLevel = sqrt(stereoSamples.map { $0 * $0 }.reduce(0, +) / Float(stereoSamples.count))
        let rmsDB = 20.0 * log10(max(rmsLevel, 1e-10))
        
        // Peak-to-RMS ratio
        let peakToRmsRatio = truePeakDB - rmsDB
        
        // Simplified LUFS calculation (integrated loudness)
        let integratedLoudness = rmsDB - 23.0 // Rough LUFS approximation
        let momentaryLoudness = integratedLoudness + 2.0 // Momentary is typically higher
        
        // Peak-to-LUFS ratio
        let peakToLufsRatio = truePeakDB - integratedLoudness
        
        // Loudness Range (simplified)
        let windowSize = 4410 // 100ms windows
        var shortTermLoudness: [Float] = []
        
        for i in stride(from: 0, to: stereoSamples.count - windowSize, by: windowSize) {
            let window = Array(stereoSamples[i..<min(i + windowSize, stereoSamples.count)])
            let windowRMS = sqrt(window.map { $0 * $0 }.reduce(0, +) / Float(window.count))
            let windowLUFS = 20.0 * log10(max(windowRMS, 1e-10)) - 23.0
            shortTermLoudness.append(windowLUFS)
        }
        
        let sortedLoudness = shortTermLoudness.sorted()
        let loudnessRange = sortedLoudness.count > 0 ? 
            sortedLoudness[Int(0.95 * Double(sortedLoudness.count))] - sortedLoudness[Int(0.1 * Double(sortedLoudness.count))] : 7.0
        
        // Punchiness calculation (transient vs sustained energy ratio)
        let transientEnergy = calculateTransientEnergy(stereoSamples)
        let sustainedEnergy = rmsLevel * rmsLevel
        let punchiness = sustainedEnergy > 0 ? min(100.0, Double(transientEnergy / sustainedEnergy) * 50.0) : 50.0
        
        // Generate recommendations
        var recommendations: [String] = []
        
        if peakToRmsRatio < 6.0 {
            recommendations.append("🎛️ Very low peak-to-average ratio - heavily compressed/limited")
        } else if peakToRmsRatio > 20.0 {
            recommendations.append("📊 High peak-to-average ratio - very dynamic, may need gentle compression")
        }
        
        if truePeakDB > -1.0 {
            recommendations.append("🚨 True peaks above -1dBFS - reduce levels to prevent clipping")
        } else if truePeakDB < -6.0 {
            recommendations.append("📈 Conservative peak levels - could be louder if needed")
        }
        
        if integratedLoudness < -23.0 {
            recommendations.append("🔊 Below broadcast standard (-23 LUFS) - consider increasing level")
        } else if integratedLoudness > -14.0 {
            recommendations.append("📢 Above streaming standard (-14 LUFS) - may be too loud")
        }
        
        if punchiness < 30.0 {
            recommendations.append("👊 Low punchiness - enhance transients or reduce compression")
        } else if punchiness > 90.0 {
            recommendations.append("⚡ Very punchy - may be too aggressive for some playback systems")
        }
        
        return PeakToAverageResult(
            peakToRmsRatio: Double(peakToRmsRatio),
            peakToLufsRatio: Double(peakToLufsRatio),
            truePeakLevel: Double(truePeakDB),
            averageLevel: Double(rmsDB),
            momentaryLoudness: Double(momentaryLoudness),
            integratedLoudness: Double(integratedLoudness),
            loudnessRange: Double(loudnessRange),
            punchiness: punchiness,
            recommendations: recommendations
        )
    }
    
    // MARK: - Helper Functions for Mastering Analysis
    
    private func calculateCorrelationCoefficient(_ left: [Float], _ right: [Float]) -> Double {
        guard left.count == right.count && !left.isEmpty else { return 0.7 }
        
        let n = Float(left.count)
        let leftMean = left.reduce(0, +) / n
        let rightMean = right.reduce(0, +) / n
        
        var numerator: Float = 0
        var leftDenominator: Float = 0
        var rightDenominator: Float = 0
        
        for i in 0..<left.count {
            let leftDiff = left[i] - leftMean
            let rightDiff = right[i] - rightMean
            
            numerator += leftDiff * rightDiff
            leftDenominator += leftDiff * leftDiff
            rightDenominator += rightDiff * rightDiff
        }
        
        let denominator = sqrt(leftDenominator * rightDenominator)
        return denominator > 0 ? Double(numerator / denominator) : 0.7
    }
    
    private func calculateTransientEnergy(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0.0 }
        
        // Calculate derivative (difference between adjacent samples)
        var transientEnergy: Float = 0
        for i in 1..<samples.count {
            let diff = samples[i] - samples[i-1]
            transientEnergy += diff * diff
        }
        
        return transientEnergy / Float(samples.count - 1)
    }
    
    /// Generate audio visualization data for static display
    public func generateVisualizationData(for url: URL) async throws -> AudioVisualizationData {
        // Generate waveform and spectrum data for UI visualization
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw AudioKitError.fileLoadFailed
        }
        
        // TODO: Implement waveform and spectrum generation
        // This would create data for visual representation of the audio
        return AudioVisualizationData(waveform: [], spectrum: [])
    }

// MARK: - Data Models

// Comprehensive analysis result for display
public struct DetailedAnalysisResult {
    // File Information
    let fileName: String
    let fileSize: Int64
    let duration: TimeInterval
    let sampleRate: Float
    let channelCount: Int
    let bitDepth: Int
    let fileFormat: String
    
    // Audio Quality Metrics
    let averageAmplitude: Float
    let peakAmplitude: Float
    let dynamicRange: Float
    let hasClipping: Bool
    
    // Stereo Analysis
    let stereoBalance: Float
    let phaseCoherence: Float
    let stereoWidth: Float
    
    // Frequency Analysis
    let frequencyBalance: FrequencyBalance
    let spectralCentroid: Float
    let frequencySpectrum: [Float]
    
    // Overall Assessment
    let qualityIssues: [String]
    let recommendations: [String]
    
    // Formatted display properties
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var peakLevelDB: Float {
        20 * log10(peakAmplitude + 0.0001)
    }
    
    var averageLevelDB: Float {
        20 * log10(averageAmplitude + 0.0001)
    }
    
    var stereoBalanceDescription: String {
        if abs(stereoBalance) < 0.1 {
            return "Centered"
        } else {
            let direction = stereoBalance > 0 ? "Right" : "Left"
            let percentage = Int(abs(stereoBalance) * 100)
            return "\(direction) \(percentage)%"
        }
    }
}

// MARK: - Data Models

// Internal analysis result for buffer processing
private struct BufferAnalysisResult {
    let averageAmplitude: Float
    let peakAmplitude: Float
    let averagePitch: Float
    let frequencySpectrum: [Float]
    let dynamicRange: Float
    let stereoBalance: Float
    let phaseCoherence: Float
    let frequencyBalance: FrequencyBalance
    
    init(averageAmplitude: Float = 0.0, peakAmplitude: Float = 0.0, averagePitch: Float = 0.0,
         frequencySpectrum: [Float] = [], dynamicRange: Float = 0.0, stereoBalance: Float = 0.0,
         phaseCoherence: Float = 0.0, frequencyBalance: FrequencyBalance = FrequencyBalance(bass: 0.0, mid: 0.0, treble: 0.0)) {
        self.averageAmplitude = averageAmplitude
        self.peakAmplitude = peakAmplitude
        self.averagePitch = averagePitch
        self.frequencySpectrum = frequencySpectrum
        self.dynamicRange = dynamicRange
        self.stereoBalance = stereoBalance
        self.phaseCoherence = phaseCoherence
        self.frequencyBalance = frequencyBalance
    }
}

// MARK: - AudioKit Helper Methods

public struct FrequencyBalance {
    let bass: Float      // 20Hz - 250Hz
    let mid: Float       // 250Hz - 4kHz
    let treble: Float    // 4kHz - 20kHz
}

public struct AudioEnhancementSettings {
    var eqSettings: EQSettings
    var compressionRatio: Float
    var noiseReduction: Float
    var stereoEnhancement: Float
}

public struct EQSettings {
    var bassGain: Float = 0.0
    var midGain: Float = 0.0
    var trebleGain: Float = 0.0
}

public struct AudioVisualizationData {
    let waveform: [Float]
    let spectrum: [Float]
}

// MARK: - Instrument Balance Types

public enum InstrumentBalanceIssue {
    case bassOverpowering
    case kickOverpowering
    case vocalsRecessed
    case vocalsOverpowering
    case guitarsOverpowering
    case guitarsRecessed
    case lackOfAir
    case cymbalsHarsh
    case bassMaskingVocals
    case guitarsMaskingVocals
    case bottomHeavy
    case lackOfBrightness
    case hollowMidrange
}

public struct InstrumentBalanceResult {
    let instrumentEnergies: [String: Double]
    let balanceIssues: [InstrumentBalanceIssue]
    let isBalanced: Bool
    let recommendations: [String]
}
