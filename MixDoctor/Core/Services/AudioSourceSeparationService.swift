//
//  AudioSourceSeparationService.swift
//  MixDoctor
//
//  Service for separating audio into individual stems (vocals, drums, bass, other)
//  to enable detailed mix balance and depth analysis
//

import Foundation
import AVFoundation
import Accelerate

/// Represents separated audio stems
struct SeparatedStems {
    let vocals: StemBuffer?
    let drums: StemBuffer?
    let bass: StemBuffer?
    let other: StemBuffer?  // Melodic instruments, synths, etc.
    
    let sampleRate: Double
    let originalDuration: TimeInterval
    
    /// Quality indicator for separation (0-1)
    let separationQuality: Float
    
    struct StemBuffer {
        let left: [Float]
        let right: [Float]
        let rmsLevel: Float
        let peakLevel: Float
    }
}

/// Mix balance metrics derived from stem analysis
struct MixBalanceMetrics {
    // Stem level balance (0-1, where 1 is highest)
    let vocalsLevel: Float
    let drumsLevel: Float
    let bassLevel: Float
    let otherLevel: Float
    
    // Mix depth indicators
    let frontElements: [String]  // Elements in the front (typically vocals)
    let middleElements: [String]  // Elements in the middle
    let backElements: [String]   // Elements in the back (typically reverb/ambience)
    
    // Stereo placement per stem
    let vocalsStereoWidth: Float
    let drumsStereoWidth: Float
    let bassStereoWidth: Float
    let otherStereoWidth: Float
    
    // Frequency separation quality
    let frequencySeparation: Float  // How well stems occupy different frequency ranges
    
    // Mix density
    let mixDensity: Float  // 0-1, how "full" the mix is
    
    // Element clarity
    let elementSeparation: Float  // 0-1, how distinct each element is
}

final class AudioSourceSeparationService {
    
    enum SeparationMode {
        case twoStem  // Vocals + Accompaniment (faster, lower quality)
        case fourStem // Vocals, Drums, Bass, Other (slower, higher quality)
        case fiveStem // Vocals, Drums, Bass, Piano, Other (most detailed)
    }
    
    enum SeparationError: Error, LocalizedError {
        case modelNotAvailable
        case processingFailed(String)
        case invalidAudioFormat
        case insufficientMemory
        
        var errorDescription: String? {
            switch self {
            case .modelNotAvailable:
                return "Source separation model is not available. This feature requires additional setup."
            case .processingFailed(let message):
                return "Separation processing failed: \(message)"
            case .invalidAudioFormat:
                return "Audio format is not supported for source separation."
            case .insufficientMemory:
                return "Not enough memory to process this audio file. Try a shorter file."
            }
        }
    }
    
    private let processor = AudioProcessor()
    private let featureExtractor = AudioFeatureExtractor()
    
    // Cache for separated stems to avoid reprocessing
    private var stemCache: [URL: SeparatedStems] = [:]
    
    // MARK: - Main Separation
    
    /// Separate audio into individual stems
    /// NOTE: Currently implements frequency-based estimation.
    /// For production, integrate CoreML model (Demucs, Spleeter) or cloud-based API.
    func separateAudio(
        from url: URL,
        mode: SeparationMode = .fourStem,
        useCache: Bool = true
    ) async throws -> SeparatedStems {
        
        print("🎸 Source Separation Starting...")
        print("   Mode: \(mode)")
        print("   File: \(url.lastPathComponent)")
        
        // Check cache
        if useCache, let cached = stemCache[url] {
            print("   ✅ Using cached stems")
            return cached
        }
        
        // Load audio
        let processedAudio = try processor.loadAudio(from: url)
        
        // For now, use frequency-based estimation
        // TODO: Replace with actual ML-based source separation
        let stems = try await estimateStemsFromFrequencyAnalysis(
            left: processedAudio.leftChannel,
            right: processedAudio.rightChannel,
            sampleRate: processedAudio.sampleRate,
            mode: mode
        )
        
        // Cache result
        if useCache {
            stemCache[url] = stems
        }
        
        print("   ✅ Separation complete (quality: \(Int(stems.separationQuality * 100))%)")
        
        return stems
    }
    
    // MARK: - Mix Balance Analysis
    
    /// Analyze mix balance from separated stems
    func analyzeMixBalance(stems: SeparatedStems) -> MixBalanceMetrics {
        
        print("📊 Analyzing Mix Balance from Stems...")
        
        // Calculate RMS levels for each stem
        let vocalsRMS = stems.vocals?.rmsLevel ?? 0
        let drumsRMS = stems.drums?.rmsLevel ?? 0
        let bassRMS = stems.bass?.rmsLevel ?? 0
        let otherRMS = stems.other?.rmsLevel ?? 0
        
        let totalRMS = vocalsRMS + drumsRMS + bassRMS + otherRMS + 0.0001
        
        // Normalize to 0-1
        let vocalsLevel = vocalsRMS / totalRMS
        let drumsLevel = drumsRMS / totalRMS
        let bassLevel = bassRMS / totalRMS
        let otherLevel = otherRMS / totalRMS
        
        print("   Stem Levels:")
        print("   - Vocals: \(Int(vocalsLevel * 100))%")
        print("   - Drums: \(Int(drumsLevel * 100))%")
        print("   - Bass: \(Int(bassLevel * 100))%")
        print("   - Other: \(Int(otherLevel * 100))%")
        
        // Analyze stereo width for each stem
        let vocalsStereoWidth = stems.vocals.map { calculateStereoWidth($0) } ?? 0
        let drumsStereoWidth = stems.drums.map { calculateStereoWidth($0) } ?? 0
        let bassStereoWidth = stems.bass.map { calculateStereoWidth($0) } ?? 0
        let otherStereoWidth = stems.other.map { calculateStereoWidth($0) } ?? 0
        
        print("   Stereo Width:")
        print("   - Vocals: \(Int(vocalsStereoWidth * 100))%")
        print("   - Drums: \(Int(drumsStereoWidth * 100))%")
        print("   - Bass: \(Int(bassStereoWidth * 100))%")
        print("   - Other: \(Int(otherStereoWidth * 100))%")
        
        // Determine mix depth (front/middle/back)
        var frontElements: [String] = []
        var middleElements: [String] = []
        var backElements: [String] = []
        
        // Front: High level, narrow stereo (0-40% width)
        if vocalsLevel > 0.2 && vocalsStereoWidth < 0.4 {
            frontElements.append("Vocals")
        }
        
        // Middle: Medium level, moderate stereo (40-70% width)
        if drumsLevel > 0.15 && drumsStereoWidth > 0.4 && drumsStereoWidth < 0.7 {
            middleElements.append("Drums")
        }
        if otherLevel > 0.15 && otherStereoWidth > 0.4 && otherStereoWidth < 0.7 {
            middleElements.append("Instruments")
        }
        
        // Back: Lower level, wide stereo (70%+ width)
        if otherStereoWidth > 0.7 {
            backElements.append("Ambience")
        }
        
        // Bass is typically center/mono
        if bassLevel > 0.15 && bassStereoWidth < 0.3 {
            middleElements.append("Bass")
        }
        
        // Calculate frequency separation quality
        let frequencySeparation = calculateFrequencySeparation(stems: stems)
        
        // Calculate mix density (how full the frequency spectrum is)
        let mixDensity = min(1.0, (vocalsLevel + drumsLevel + bassLevel + otherLevel) * 1.2)
        
        // Calculate element separation (how distinct each element is)
        let levelVariance = calculateVariance([vocalsLevel, drumsLevel, bassLevel, otherLevel])
        let elementSeparation = min(1.0, levelVariance * 2.0)
        
        print("   Mix Depth:")
        print("   - Front: \(frontElements.joined(separator: ", "))")
        print("   - Middle: \(middleElements.joined(separator: ", "))")
        print("   - Back: \(backElements.joined(separator: ", "))")
        print("   Frequency Separation: \(Int(frequencySeparation * 100))%")
        print("   Mix Density: \(Int(mixDensity * 100))%")
        print("   Element Separation: \(Int(elementSeparation * 100))%")
        
        return MixBalanceMetrics(
            vocalsLevel: vocalsLevel,
            drumsLevel: drumsLevel,
            bassLevel: bassLevel,
            otherLevel: otherLevel,
            frontElements: frontElements,
            middleElements: middleElements,
            backElements: backElements,
            vocalsStereoWidth: vocalsStereoWidth,
            drumsStereoWidth: drumsStereoWidth,
            bassStereoWidth: bassStereoWidth,
            otherStereoWidth: otherStereoWidth,
            frequencySeparation: frequencySeparation,
            mixDensity: mixDensity,
            elementSeparation: elementSeparation
        )
    }
    
    // MARK: - Private Helpers
    
    /// Estimate stems using frequency band analysis (temporary solution)
    /// TODO: Replace with actual ML-based separation (Demucs CoreML model)
    private func estimateStemsFromFrequencyAnalysis(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        mode: SeparationMode
    ) async throws -> SeparatedStems {
        
        print("   🔬 Estimating stems from frequency analysis...")
        
        // Apply bandpass filters to isolate frequency ranges
        
        // Vocals: 200 Hz - 3 kHz (fundamental + harmonics)
        let vocalsLeft = try applyBandpassFilter(left, sampleRate: sampleRate, lowCut: 200, highCut: 3000)
        let vocalsRight = try applyBandpassFilter(right, sampleRate: sampleRate, lowCut: 200, highCut: 3000)
        
        // Bass: 20 Hz - 250 Hz
        let bassLeft = try applyBandpassFilter(left, sampleRate: sampleRate, lowCut: 20, highCut: 250)
        let bassRight = try applyBandpassFilter(right, sampleRate: sampleRate, lowCut: 20, highCut: 250)
        
        // Drums: 60 Hz - 10 kHz (kick, snare, hi-hats)
        // Use transient detection to isolate percussive content
        let drumsLeft = try extractPercussiveContent(left, sampleRate: sampleRate)
        let drumsRight = try extractPercussiveContent(right, sampleRate: sampleRate)
        
        // Other: Everything else (3 kHz+, melodic content)
        let otherLeft = try applyHighpassFilter(left, sampleRate: sampleRate, cutoff: 3000)
        let otherRight = try applyHighpassFilter(right, sampleRate: sampleRate, cutoff: 3000)
        
        // Calculate RMS and peak for each stem
        let vocals = SeparatedStems.StemBuffer(
            left: vocalsLeft,
            right: vocalsRight,
            rmsLevel: calculateRMS(vocalsLeft),
            peakLevel: calculatePeak(vocalsLeft)
        )
        
        let bass = SeparatedStems.StemBuffer(
            left: bassLeft,
            right: bassRight,
            rmsLevel: calculateRMS(bassLeft),
            peakLevel: calculatePeak(bassLeft)
        )
        
        let drums = SeparatedStems.StemBuffer(
            left: drumsLeft,
            right: drumsRight,
            rmsLevel: calculateRMS(drumsLeft),
            peakLevel: calculatePeak(drumsLeft)
        )
        
        let other = SeparatedStems.StemBuffer(
            left: otherLeft,
            right: otherRight,
            rmsLevel: calculateRMS(otherLeft),
            peakLevel: calculatePeak(otherLeft)
        )
        
        // Separation quality is lower for frequency-based estimation (0.4-0.6)
        // Will be higher (0.8-0.95) when using actual ML models
        let separationQuality: Float = 0.5
        
        let duration = Double(left.count) / sampleRate
        
        return SeparatedStems(
            vocals: vocals,
            drums: drums,
            bass: bass,
            other: other,
            sampleRate: sampleRate,
            originalDuration: duration,
            separationQuality: separationQuality
        )
    }
    
    /// Apply bandpass filter (simple FFT-based)
    private func applyBandpassFilter(
        _ audio: [Float],
        sampleRate: Double,
        lowCut: Float,
        highCut: Float
    ) throws -> [Float] {
        
        let fftSize = 2048
        let hopSize = fftSize / 4
        var output = [Float](repeating: 0, count: audio.count)
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw SeparationError.processingFailed("FFT setup failed")
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        
        // Process in overlapping windows
        let numFrames = (audio.count - fftSize) / hopSize + 1
        
        for frame in 0..<numFrames {
            let startIndex = frame * hopSize
            let endIndex = min(startIndex + fftSize, audio.count)
            
            guard endIndex - startIndex == fftSize else { continue }
            
            var window = Array(audio[startIndex..<endIndex])
            
            // Apply Hann window
            var hannWindow = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(window, 1, hannWindow, 1, &window, 1, vDSP_Length(fftSize))
            
            // Use withUnsafeMutableBufferPointer for proper memory management
            realp.withUnsafeMutableBufferPointer { realpPtr in
                imagp.withUnsafeMutableBufferPointer { imagpPtr in
                    var splitComplex = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)
                    
                    // FFT
                    window.withUnsafeBytes { ptr in
                        ptr.baseAddress?.assumingMemoryBound(to: DSPComplex.self).withMemoryRebound(to: Float.self, capacity: fftSize) { p in
                            vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(p)), 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                        }
                    }
                    
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Apply bandpass filter
                    let binWidth = Float(sampleRate) / Float(fftSize)
                    for i in 0..<(fftSize / 2) {
                        let freq = Float(i) * binWidth
                        if freq < lowCut || freq > highCut {
                            splitComplex.realp[i] = 0
                            splitComplex.imagp[i] = 0
                        }
                    }
                    
                    // Inverse FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))
                    
                    var result = [Float](repeating: 0, count: fftSize)
                    result.withUnsafeMutableBytes { resultPtr in
                        if let baseAddress = resultPtr.baseAddress {
                            vDSP_ztoc(&splitComplex, 1, baseAddress.assumingMemoryBound(to: DSPComplex.self), 2, vDSP_Length(fftSize / 2))
                        }
                    }
                    
                    // Normalize and overlap-add
                    var scale = Float(1.0 / Float(fftSize))
                    vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(fftSize))
                    
                    for i in 0..<fftSize where (startIndex + i) < output.count {
                        output[startIndex + i] += result[i]
                    }
                }
            }
        }
        
        return output
    }
    
    /// Apply highpass filter
    private func applyHighpassFilter(
        _ audio: [Float],
        sampleRate: Double,
        cutoff: Float
    ) throws -> [Float] {
        return try applyBandpassFilter(audio, sampleRate: sampleRate, lowCut: cutoff, highCut: Float(sampleRate / 2))
    }
    
    /// Extract percussive content using transient detection
    private func extractPercussiveContent(
        _ audio: [Float],
        sampleRate: Double
    ) throws -> [Float] {
        
        var output = [Float](repeating: 0, count: audio.count)
        
        // Calculate envelope
        let windowSize = Int(sampleRate * 0.01)  // 10ms windows
        
        for i in 0..<audio.count {
            let start = max(0, i - windowSize / 2)
            let end = min(audio.count, i + windowSize / 2)
            
            var sumSq: Float = 0
            vDSP_measqv(Array(audio[start..<end]), 1, &sumSq, vDSP_Length(end - start))
            output[i] = sqrt(sumSq / Float(end - start))
        }
        
        // Enhance transients
        for i in 1..<(audio.count - 1) {
            let diff = output[i] - output[i - 1]
            if diff > 0 {
                output[i] = audio[i] * (1.0 + diff * 10.0)
            } else {
                output[i] = audio[i] * 0.3
            }
        }
        
        return output
    }
    
    /// Calculate stereo width for a stem
    private func calculateStereoWidth(_ buffer: SeparatedStems.StemBuffer) -> Float {
        let midSideResult = processor.convertToMidSide(left: buffer.left, right: buffer.right)
        let midChannelEnergy = calculateRMS(midSideResult.mid)
        let sideChannelEnergy = calculateRMS(midSideResult.side)
        let totalChannelEnergy = midChannelEnergy + sideChannelEnergy + 0.0001
        return sideChannelEnergy / totalChannelEnergy
    }
    
    /// Calculate frequency separation quality between stems
    private func calculateFrequencySeparation(stems: SeparatedStems) -> Float {
        // Good separation means stems occupy different frequency ranges
        // Simplified metric: variance in stem levels
        let levels: [Float] = [
            stems.vocals?.rmsLevel ?? 0,
            stems.drums?.rmsLevel ?? 0,
            stems.bass?.rmsLevel ?? 0,
            stems.other?.rmsLevel ?? 0
        ]
        
        return min(1.0, calculateVariance(levels) * 3.0)
    }
    
    // MARK: - Utility Functions
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }
    
    private func calculatePeak(_ samples: [Float]) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        return peak
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        stemCache.removeAll()
        print("🗑️ Stem cache cleared")
    }
    
    func getCacheSize() -> Int {
        return stemCache.count
    }
}
