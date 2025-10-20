//
//  AudioFeatureExtractor.swift
//  MixDoctor
//
//  Created on Phase 3: CoreML Audio Analysis Engine
//

import Accelerate
import Foundation

final class AudioFeatureExtractor {
    
    private let processor = AudioProcessor()
    
    // MARK: - Stereo Features
    
    struct StereoFeatures {
        let stereoWidth: Float        // 0-1 (narrow to wide)
        let correlation: Float        // -1 to 1 (out of phase to in phase)
        let leftRightBalance: Float   // -1 to 1 (left heavy to right heavy)
        let midSideRatio: Float       // Ratio of mid to side energy
    }
    
    func extractStereoFeatures(left: [Float], right: [Float]) -> StereoFeatures {
        // Calculate correlation
        let correlation = calculateCorrelation(left: left, right: right)
        
        // Calculate stereo width (based on side channel energy)
        let midSide = processor.convertToMidSide(left: left, right: right)
        let midEnergy = calculateRMS(midSide.mid)
        let sideEnergy = calculateRMS(midSide.side)
        let stereoWidth = sideEnergy / (midEnergy + sideEnergy + 0.0001)
        
        // Calculate balance
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        let totalRMS = leftRMS + rightRMS + 0.0001
        let leftRightBalance = (rightRMS - leftRMS) / totalRMS
        
        // Mid-side ratio
        let midSideRatio = midEnergy / (sideEnergy + 0.0001)
        
        print("   📊 Stereo Features:")
        print("      Correlation: \(correlation)")
        print("      Stereo Width: \(stereoWidth)")
        print("      L/R Balance: \(leftRightBalance)")
        print("      Mid/Side Ratio: \(midSideRatio)")
        
        return StereoFeatures(
            stereoWidth: stereoWidth,
            correlation: correlation,
            leftRightBalance: leftRightBalance,
            midSideRatio: midSideRatio
        )
    }
    
    // MARK: - Frequency Analysis
    
    struct FrequencyFeatures {
        let spectrum: [Float]           // Magnitude spectrum
        let frequencyBands: [Float: Float] // Energy per band
        let spectralCentroid: Float     // Brightness measure
        let spectralFlatness: Float     // Tonality measure
    }
    
    func extractFrequencyFeatures(audio: [Float], sampleRate: Double) throws -> FrequencyFeatures {
        let fftSize = 8192  // FFT size for analysis
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw AudioProcessingError.fftSetupFailed
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Prepare buffers
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        
        // Window function (Hann window)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // Apply window and convert to split complex
        var windowedAudio = [Float](repeating: 0, count: fftSize)
        let audioChunk = Array(audio.prefix(fftSize))
        vDSP_vmul(audioChunk, 1, window, 1, &windowedAudio, 1, vDSP_Length(fftSize))
        
        // Calculate magnitude spectrum
        var magnitudes = realp.withUnsafeMutableBufferPointer { realpPtr in
            imagp.withUnsafeMutableBufferPointer { imagpPtr in
                var output = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)
                
                windowedAudio.withUnsafeBytes { audioBytes in
                    audioBytes.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { audioComplex in
                        vDSP_ctoz(audioComplex, 2, &output, 1, vDSP_Length(fftSize / 2))
                    }
                }
                
                // Perform FFT
                vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitude
                var mags = [Float](repeating: 0, count: fftSize / 2)
                vDSP_zvabs(&output, 1, &mags, 1, vDSP_Length(fftSize / 2))
                
                return mags
            }
        }
        
        // Normalize
        var normFactor = Float(1.0 / Float(fftSize))
        vDSP_vsmul(magnitudes, 1, &normFactor, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Calculate frequency bands
        let bands = calculateFrequencyBands(magnitudes: magnitudes, sampleRate: Float(sampleRate))
        
        // Calculate spectral centroid
        let centroid = calculateSpectralCentroid(magnitudes: magnitudes, sampleRate: Float(sampleRate))
        
        // Calculate spectral flatness
        let flatness = calculateSpectralFlatness(magnitudes: magnitudes)
        
        return FrequencyFeatures(
            spectrum: magnitudes,
            frequencyBands: bands,
            spectralCentroid: centroid,
            spectralFlatness: flatness
        )
    }
    
    private func calculateFrequencyBands(magnitudes: [Float], sampleRate: Float) -> [Float: Float] {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Float(magnitudes.count)
        
        // Define frequency bands (Hz)
        let bandRanges: [(String, ClosedRange<Float>)] = [
            ("sub_bass", 20...60),
            ("bass", 60...250),
            ("low_mids", 250...500),
            ("mids", 500...2000),
            ("high_mids", 2000...6000),
            ("highs", 6000...20000)
        ]
        
        var bands: [Float: Float] = [:]
        
        for (_, range) in bandRanges {
            let startBin = Int(range.lowerBound / binWidth)
            let endBin = Int(range.upperBound / binWidth)
            let validEndBin = min(endBin, magnitudes.count - 1)
            
            var bandEnergy: Float = 0
            for i in startBin...validEndBin {
                bandEnergy += magnitudes[i] * magnitudes[i]
            }
            bands[range.lowerBound] = sqrt(bandEnergy / Float(validEndBin - startBin + 1))
        }
        
        return bands
    }
    
    private func calculateSpectralCentroid(magnitudes: [Float], sampleRate: Float) -> Float {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Float(magnitudes.count)
        
        var numerator: Float = 0
        var denominator: Float = 0
        
        for (i, magnitude) in magnitudes.enumerated() {
            let frequency = Float(i) * binWidth
            numerator += frequency * magnitude
            denominator += magnitude
        }
        
        return denominator > 0 ? numerator / denominator : 0
    }
    
    private func calculateSpectralFlatness(magnitudes: [Float]) -> Float {
        let nonZeroMagnitudes = magnitudes.filter { $0 > 0.0001 }
        guard !nonZeroMagnitudes.isEmpty else { return 0 }
        
        // Geometric mean
        let logSum = nonZeroMagnitudes.reduce(0) { $0 + log($1) }
        let geometricMean = exp(logSum / Float(nonZeroMagnitudes.count))
        
        // Arithmetic mean
        let arithmeticMean = nonZeroMagnitudes.reduce(0, +) / Float(nonZeroMagnitudes.count)
        
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }
    
    // MARK: - Loudness and Dynamics
    
    struct LoudnessFeatures {
        let rmsLevel: Float          // RMS level
        let peakLevel: Float         // Peak level
        let crestFactor: Float       // Peak to RMS ratio
        let dynamicRange: Float      // Estimated dynamic range
        let lufs: Float             // Integrated loudness (LUFS)
    }
    
    func extractLoudnessFeatures(left: [Float], right: [Float]) -> LoudnessFeatures {
        // Calculate RMS for both channels
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        let rmsLevel = (leftRMS + rightRMS) / 2.0
        
        // Calculate peak
        let leftPeak = left.max() ?? 0
        let rightPeak = right.max() ?? 0
        let peakLevel = max(leftPeak, rightPeak)
        
        // Crest factor
        let crestFactor = rmsLevel > 0 ? peakLevel / rmsLevel : 0
        
        // Dynamic range (simplified - difference between peak and average RMS)
        let dynamicRange = 20 * log10(peakLevel / (rmsLevel + 0.0001))
        
        // LUFS (simplified ITU-R BS.1770 implementation)
        let lufs = calculateLUFS(left: left, right: right)
        
        return LoudnessFeatures(
            rmsLevel: rmsLevel,
            peakLevel: peakLevel,
            crestFactor: crestFactor,
            dynamicRange: dynamicRange,
            lufs: lufs
        )
    }
    
    // MARK: - Helper Functions
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        return sqrt(sumSquares / Float(samples.count))
    }
    
    private func calculateCorrelation(left: [Float], right: [Float]) -> Float {
        let count = min(left.count, right.count)
        var correlation: Float = 0
        
        vDSP_dotpr(left, 1, right, 1, &correlation, vDSP_Length(count))
        
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        
        return (leftRMS * rightRMS) > 0 ? correlation / (leftRMS * rightRMS * Float(count)) : 0
    }
    
    private func calculateLUFS(left: [Float], right: [Float]) -> Float {
        // Simplified LUFS calculation
        // Real implementation would include K-weighting filter
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        let averageRMS = (leftRMS + rightRMS) / 2.0
        
        // Convert to dB scale (LUFS reference: 0 LUFS = -0.691 dBFS for digital full scale)
        let dbfs = 20 * log10(averageRMS + 0.0001)
        return dbfs + 0.691
    }
}
