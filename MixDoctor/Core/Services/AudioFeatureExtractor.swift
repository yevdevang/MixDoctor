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
        
        // Calculate stereo width using proper professional audio metrics
        let midSide = processor.convertToMidSide(left: left, right: right)
        let midEnergy = calculateRMS(midSide.mid)
        let sideEnergy = calculateRMS(midSide.side)
        
        // Professional stereo width calculation:
        // - Good professional mixes: 40-70% (balanced mono/stereo content)
        // - Mono: 0%
        // - Extreme wide stereo: 90-100%
        // Formula: Scale side energy ratio to percentage and apply perceptual curve
        let rawSideRatio = sideEnergy / (midEnergy + sideEnergy + 0.0001)
        
        // Apply perceptual scaling to match professional standards
        // A mix with 30% side energy should read as ~50-60% width (balanced)
        // A mix with 50% side energy should read as ~70-80% width (wide)
        let stereoWidth: Float
        if rawSideRatio < 0.25 {
            // Very mono (0-25% side energy -> 0-40% width)
            stereoWidth = rawSideRatio * 1.6
        } else if rawSideRatio < 0.40 {
            // Balanced (25-40% side energy -> 40-65% width)
            stereoWidth = 0.4 + (rawSideRatio - 0.25) * 1.67
        } else {
            // Wide stereo (40%+ side energy -> 65-100% width)
            stereoWidth = 0.65 + (rawSideRatio - 0.40) * 0.583
        }
        
        // Calculate balance
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        let totalRMS = leftRMS + rightRMS + 0.0001
        let leftRightBalance = (rightRMS - leftRMS) / totalRMS
        
        // Mid-side ratio
        let midSideRatio = midEnergy / (sideEnergy + 0.0001)
        
        print("   📊 Stereo Features:")
        print("      Correlation: \(correlation)")
        print("      Raw Side Ratio: \(rawSideRatio) (\(Int(rawSideRatio * 100))%)")
        print("      Stereo Width (Scaled): \(stereoWidth) (\(Int(stereoWidth * 100))%)")
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
        let frequencyBalance: FrequencyBalance // Balance across spectrum
    }
    
    struct FrequencyBalance {
        let isBalanced: Bool            // Overall balance status
        let lowEnergy: Float            // Normalized low frequency energy (0-1)
        let midEnergy: Float            // Normalized mid frequency energy (0-1)
        let highEnergy: Float           // Normalized high frequency energy (0-1)
        let imbalanceType: String?      // "bass-heavy", "mid-heavy", "treble-heavy", or nil if balanced
        let balanceScore: Float         // 0-1, where 1 is perfectly balanced
    }
    
    func extractFrequencyFeatures(audio: [Float], sampleRate: Double) throws -> FrequencyFeatures {
        let fftSize = 8192  // FFT size for analysis
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw NSError(domain: "AudioFeatureExtractor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to setup FFT"
            ])
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
        
        // Calculate frequency balance
        let balance = calculateFrequencyBalance(magnitudes: magnitudes, sampleRate: Float(sampleRate))
        
        return FrequencyFeatures(
            spectrum: magnitudes,
            frequencyBands: bands,
            spectralCentroid: centroid,
            spectralFlatness: flatness,
            frequencyBalance: balance
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
    
    private func calculateFrequencyBalance(magnitudes: [Float], sampleRate: Float) -> FrequencyBalance {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Float(magnitudes.count)
        
        // Define three broad frequency ranges for balance analysis
        // Low: 20-250 Hz (bass region)
        // Mid: 250-4000 Hz (midrange and presence)
        // High: 4000-16000 Hz (treble and air)
        let lowRange: ClosedRange<Float> = 20...250
        let midRange: ClosedRange<Float> = 250...4000
        let highRange: ClosedRange<Float> = 4000...16000
        
        // Calculate energy in each range
        func energyInRange(_ range: ClosedRange<Float>) -> Float {
            let startBin = max(0, Int(range.lowerBound / binWidth))
            let endBin = min(magnitudes.count - 1, Int(range.upperBound / binWidth))
            
            var energy: Float = 0
            for i in startBin...endBin {
                energy += magnitudes[i] * magnitudes[i]
            }
            return energy
        }
        
        let lowEnergy = energyInRange(lowRange)
        let midEnergy = energyInRange(midRange)
        let highEnergy = energyInRange(highRange)
        
        // Normalize energies to sum to 1.0
        let totalEnergy = lowEnergy + midEnergy + highEnergy
        guard totalEnergy > 0 else {
            return FrequencyBalance(
                isBalanced: false,
                lowEnergy: 0,
                midEnergy: 0,
                highEnergy: 0,
                imbalanceType: nil,
                balanceScore: 0
            )
        }
        
        let normalizedLow = lowEnergy / totalEnergy
        let normalizedMid = midEnergy / totalEnergy
        let normalizedHigh = highEnergy / totalEnergy
        
        // Calculate balance score (0-1)
        // Ideal balanced mix: ~0.33 for each range
        let ideal: Float = 1.0 / 3.0
        let lowDeviation = abs(normalizedLow - ideal)
        let midDeviation = abs(normalizedMid - ideal)
        let highDeviation = abs(normalizedHigh - ideal)
        
        // Average deviation from ideal (0 = perfect, ~0.33 = completely imbalanced)
        let averageDeviation = (lowDeviation + midDeviation + highDeviation) / 3.0
        let balanceScore = max(0, 1.0 - (averageDeviation * 3.0)) // Scale to 0-1
        
        // Determine if balanced (threshold: deviations < 0.15, meaning within ~15% of ideal)
        let balanceThreshold: Float = 0.15
        let isBalanced = lowDeviation < balanceThreshold && 
                        midDeviation < balanceThreshold && 
                        highDeviation < balanceThreshold
        
        // Determine imbalance type if not balanced
        var imbalanceType: String?
        if !isBalanced {
            let maxEnergy = max(normalizedLow, normalizedMid, normalizedHigh)
            if maxEnergy == normalizedLow {
                imbalanceType = "bass-heavy"
            } else if maxEnergy == normalizedMid {
                imbalanceType = "mid-heavy"
            } else {
                imbalanceType = "treble-heavy"
            }
        }
        
        print("   🎚️ Frequency Balance:")
        print("      Low (20-250 Hz): \(Int(normalizedLow * 100))%")
        print("      Mid (250-4000 Hz): \(Int(normalizedMid * 100))%")
        print("      High (4000-16000 Hz): \(Int(normalizedHigh * 100))%")
        print("      Balance Score: \(Int(balanceScore * 100))%")
        print("      Status: \(isBalanced ? "✅ Balanced" : "⚠️ Imbalanced (\(imbalanceType ?? "unknown"))")")
        
        return FrequencyBalance(
            isBalanced: isBalanced,
            lowEnergy: normalizedLow,
            midEnergy: normalizedMid,
            highEnergy: normalizedHigh,
            imbalanceType: imbalanceType,
            balanceScore: balanceScore
        )
    }
    
    // MARK: - Loudness and Dynamics
    
    struct LoudnessFeatures {
        let rmsLevel: Float          // RMS level
        let peakLevel: Float         // Sample peak level
        let truePeak: Float          // True peak (intersample peaks)
        let crestFactor: Float       // Peak to RMS ratio (indicates compression)
        let dynamicRange: Float      // Estimated dynamic range
        let loudnessRange: Float     // Loudness Range (LRA) in LU
        let lufs: Float             // Integrated loudness (LUFS)
    }
    
    func extractLoudnessFeatures(left: [Float], right: [Float]) -> LoudnessFeatures {
        // Calculate RMS for both channels
        let leftRMS = calculateRMS(left)
        let rightRMS = calculateRMS(right)
        let rmsLevel = (leftRMS + rightRMS) / 2.0
        
        // Calculate sample peak
        let leftPeak = left.max(by: { abs($0) < abs($1) }) ?? 0
        let rightPeak = right.max(by: { abs($0) < abs($1) }) ?? 0
        let peakLevel = max(abs(leftPeak), abs(rightPeak))
        
        // Calculate true peak (approximation: sample peak + 0.5 dB for intersample peaks)
        let truePeak = peakLevel * 1.122 // Roughly +1 dB headroom for intersample peaks
        
        // Crest factor (in dB) - indicates compression level
        let crestFactorDB = rmsLevel > 0 ? 20 * log10(peakLevel / rmsLevel) : 0
        
        // Dynamic range (simplified - difference between peak and average RMS)
        let dynamicRange = 20 * log10(peakLevel / (rmsLevel + 0.0001))
        
        // Calculate Loudness Range (LRA)
        let loudnessRange = calculateLoudnessRange(left: left, right: right)
        
        // LUFS (simplified ITU-R BS.1770 implementation)
        let lufs = calculateLUFS(left: left, right: right)
        
        return LoudnessFeatures(
            rmsLevel: rmsLevel,
            peakLevel: peakLevel,
            truePeak: truePeak,
            crestFactor: crestFactorDB,
            dynamicRange: dynamicRange,
            loudnessRange: loudnessRange,
            lufs: lufs
        )
    }
    
    // MARK: - Mixing Effects Detection
    
    struct MixingEffectsFeatures {
        let hasCompression: Bool        // Detected compression/limiting
        let hasReverb: Bool            // Detected reverb/spatial effects
        let hasStereoProcessing: Bool  // Detected stereo enhancement
        let hasEQ: Bool                // Detected EQ/frequency shaping
        let compressionAmount: Float   // 0-1 (none to heavy compression)
        let reverbAmount: Float        // 0-1 (dry to wet)
        let stereoEnhancement: Float   // 0-1 (mono to enhanced)
        let frequencyBalance: Float    // 0-1 (unbalanced to balanced)
    }
    
    // MARK: - Mix Cohesion Analysis
    
    struct MixCohesionFeatures {
        let cohesionScore: Float       // 0-1 (poor to excellent cohesion)
        let spectralCoherence: Float   // 0-1 (frequencies clash to complement)
        let phaseIntegrity: Float      // 0-1 (phase issues to solid phase)
        let dynamicConsistency: Float  // 0-1 (inconsistent to consistent)
        let spatialBalance: Float      // 0-1 (imbalanced to balanced)
        let overallDepth: Float        // 0-1 (flat/2D to deep/3D)
    }
    
    func analyzeMixCohesion(left: [Float], right: [Float], sampleRate: Double) throws -> MixCohesionFeatures {
        // 1. SPECTRAL COHERENCE - Do frequencies complement each other?
        let frequencyFeatures = try extractFrequencyFeatures(audio: left, sampleRate: sampleRate)
        let spectralFlatness = frequencyFeatures.spectralFlatness
        
        // VERY RELAXED for professional mixes: accept wide range (0.05-0.50)
        // Different genres have wildly different spectral characteristics:
        // - Rock/metal: 0.05-0.15 (very tonal, harmonic-rich)
        // - Pop/R&B: 0.15-0.30 (balanced)
        // - Electronic: 0.20-0.40 (synthetic, varied)
        let spectralCoherence: Float
        if spectralFlatness >= 0.05 && spectralFlatness <= 0.50 {
            // Give high scores across the entire professional range
            // Peak at 0.20, but stay high (70-100%) for 0.05-0.40
            let deviation = abs(spectralFlatness - 0.20)
            if spectralFlatness >= 0.05 && spectralFlatness <= 0.40 {
                spectralCoherence = max(0.70, 1.0 - (deviation / 0.30)) // 70-100% for pro range
            } else {
                spectralCoherence = 0.60 // Still acceptable up to 0.50
            }
        } else if spectralFlatness < 0.03 || spectralFlatness > 0.65 {
            spectralCoherence = 0.0 // Truly extreme/problematic
        } else {
            spectralCoherence = 0.4 // Borderline
        }
        
        // 2. PHASE INTEGRITY - Are channels working together?
        let stereoFeatures = extractStereoFeatures(left: left, right: right)
        let correlation = stereoFeatures.correlation
        
        // RELAXED: correlation 0.4-0.9 acceptable (professional mixes vary)
        // Poor mix: < 0.25 (severe phase issues) or > 0.97 (completely mono)
        let phaseIntegrity: Float
        if correlation >= 0.4 && correlation <= 0.9 {
            phaseIntegrity = 1.0
        } else if correlation < 0.25 || correlation > 0.97 {
            phaseIntegrity = 0.0
        } else {
            phaseIntegrity = 0.7 // Borderline acceptable
        }
        
        // 3. DYNAMIC CONSISTENCY - Is processing uniform across the mix?
        let loudnessFeatures = extractLoudnessFeatures(left: left, right: right)
        let crestFactor = loudnessFeatures.crestFactor
        let dynamicRange = loudnessFeatures.dynamicRange
        
        // RELAXED: Professional mixes range from 3-10 crest, 5-15 dB dynamic range
        let dynamicConsistency: Float
        if crestFactor >= 3 && crestFactor <= 10 && dynamicRange >= 5 && dynamicRange <= 15 {
            dynamicConsistency = 1.0
        } else if crestFactor > 15 || crestFactor < 2.5 || dynamicRange > 20 || dynamicRange < 3 {
            dynamicConsistency = 0.0 // Truly bad
        } else {
            dynamicConsistency = 0.6 // Acceptable
        }
        
        // 4. SPATIAL BALANCE - Is the stereo field balanced?
        let stereoWidth = stereoFeatures.stereoWidth
        let leftRightBalance = stereoFeatures.leftRightBalance
        
        // RELAXED: width 0.30-0.80, balance -0.20 to 0.20
        // Professional mixes have varied stereo imaging
        let spatialBalance: Float
        if stereoWidth >= 0.30 && stereoWidth <= 0.80 && abs(leftRightBalance) <= 0.20 {
            spatialBalance = 1.0
        } else if stereoWidth < 0.20 || abs(leftRightBalance) > 0.30 {
            spatialBalance = 0.0 // Truly bad
        } else {
            spatialBalance = 0.7 // Acceptable
        }
        
        // 5. OVERALL DEPTH - Does the mix have front-to-back dimension?
        // Combine multiple factors to assess depth
        let mixingEffects = try extractMixingEffects(left: left, right: right, sampleRate: sampleRate)
        
        // RELAXED: Professional mixes can have varying depth approaches
        // Some are upfront and dry (hip-hop), others are spacious (rock/pop)
        let hasDepthElements = mixingEffects.hasReverb || mixingEffects.hasStereoProcessing || mixingEffects.hasEQ
        let depthFactors = [
            mixingEffects.reverbAmount,
            mixingEffects.stereoEnhancement,
            mixingEffects.frequencyBalance
        ]
        let averageDepthFactor = depthFactors.reduce(0, +) / Float(depthFactors.count)
        
        let overallDepth: Float
        if hasDepthElements {
            // If mix has any depth elements, score based on average
            if averageDepthFactor > 0.5 {
                overallDepth = averageDepthFactor // Good depth
            } else if averageDepthFactor > 0.3 {
                overallDepth = 0.6 // Moderate depth (acceptable)
            } else {
                overallDepth = 0.4 // Minimal but present
            }
        } else if averageDepthFactor < 0.2 {
            overallDepth = 0.0 // Truly flat/unmixed
        } else {
            overallDepth = averageDepthFactor * 0.6 // Some natural depth
        }
        
        // COHESION SCORE - Weighted combination of all factors
        let cohesionScore = (
            spectralCoherence * 0.25 +
            phaseIntegrity * 0.25 +
            dynamicConsistency * 0.20 +
            spatialBalance * 0.15 +
            overallDepth * 0.15
        )
        
        return MixCohesionFeatures(
            cohesionScore: cohesionScore,
            spectralCoherence: spectralCoherence,
            phaseIntegrity: phaseIntegrity,
            dynamicConsistency: dynamicConsistency,
            spatialBalance: spatialBalance,
            overallDepth: overallDepth
        )
    }
    
    func extractMixingEffects(left: [Float], right: [Float], sampleRate: Double) throws -> MixingEffectsFeatures {
        // 1. COMPRESSION DETECTION (STRICTER THRESHOLDS)
        // Compressed audio has: low crest factor, consistent RMS, limited dynamic range
        let loudnessFeatures = extractLoudnessFeatures(left: left, right: right)
        
        // Crest factor analysis: compressed mixes typically 4-12 dB, unmixed 15-25+ dB
        // Professional rock/pop mixes: often 8-12 dB (punchy but not over-compressed)
        // BALANCED: Accept 9-10 dB as moderate compression (common in pro mixes)
        let crestFactor = loudnessFeatures.crestFactor
        let compressionAmount: Float
        if crestFactor < 6 {
            compressionAmount = 1.0 // Heavy compression (mastered)
        } else if crestFactor < 8 {
            compressionAmount = 0.9 // Strong compression (typical pro mix)
        } else if crestFactor < 10 {
            compressionAmount = 0.7 // Moderate compression (professional - GREEN DAY RANGE)
        } else if crestFactor < 12 {
            compressionAmount = 0.5 // Light compression (still acceptable)
        } else if crestFactor < 15 {
            compressionAmount = 0.2 // Minimal compression (likely unmixed)
        } else {
            compressionAmount = 0.0 // No compression (unmixed)
        }
        let hasCompression = compressionAmount >= 0.6 // Need 60%+ to count as compressed
        
        // 2. REVERB/DELAY DETECTION (STRICTER THRESHOLDS)
        // Reverb creates: autocorrelation tail, energy decay over time
        let reverbAmount = detectReverb(left: left, right: right)
        let hasReverb = reverbAmount > 0.25 // STRICTER: was 0.15, now 0.25
        
        // 3. STEREO PROCESSING DETECTION
        let stereoFeatures = extractStereoFeatures(left: left, right: right)
        
        // Professional stereo processing shows deliberate width + correlation management
        // BALANCED: 35-40% width is acceptable for professional mixes (not all genres are super wide)
        // Unmixed tracks: typically < 30% width with > 0.88 correlation (essentially mono)
        let stereoEnhancement: Float
        if stereoFeatures.stereoWidth > 0.40 && stereoFeatures.stereoWidth < 0.75 && 
           stereoFeatures.correlation > 0.35 && stereoFeatures.correlation < 0.85 {
            // Clear professional stereo range
            stereoEnhancement = 1.0
        } else if stereoFeatures.stereoWidth > 0.33 && stereoFeatures.stereoWidth < 0.85 &&
                  stereoFeatures.correlation > 0.30 && stereoFeatures.correlation < 0.88 {
            // Acceptable professional range (not all genres use wide stereo)
            stereoEnhancement = 0.7
        } else if stereoFeatures.stereoWidth < 0.30 || stereoFeatures.correlation > 0.90 {
            // Too narrow OR too correlated = no real stereo processing (unmixed)
            stereoEnhancement = 0.0
        } else {
            stereoEnhancement = 0.4
        }
        let hasStereoProcessing = stereoEnhancement >= 0.6 // Need 60%+ to count
        
        // 4. EQ/FREQUENCY SHAPING DETECTION
        let frequencyFeatures = try extractFrequencyFeatures(audio: left, sampleRate: sampleRate)
        
        // Professional EQ shows controlled frequency balance
        // Spectral flatness varies widely by genre:
        // - Rock/metal: 0.05-0.20 (very tonal, lots of distortion and harmonics)
        // - Pop/EDM: 0.15-0.30 (more balanced)
        // - Jazz/acoustic: 0.20-0.40 (natural, less processing)
        let flatness = frequencyFeatures.spectralFlatness
        
        // RELAXED: Accept wider range of professional flatness values
        let frequencyBalance: Float
        if flatness >= 0.05 && flatness <= 0.40 {
            // Professional range - calculate balance based on how close to ideal
            // Ideal varies by genre, but 0.20 is a good middle ground
            let deviation = abs(flatness - 0.20)
            frequencyBalance = max(0.50, 1.0 - (deviation / 0.20)) // At least 50% for pro range
        } else if flatness < 0.03 || flatness > 0.60 {
            frequencyBalance = 0.0 // Extreme values = unmixed/problematic
        } else {
            frequencyBalance = 0.4 // Borderline
        }
        let hasEQ = frequencyBalance > 0.50 // Need > 50% to count (so 51%+ passes)
        
        return MixingEffectsFeatures(
            hasCompression: hasCompression,
            hasReverb: hasReverb,
            hasStereoProcessing: hasStereoProcessing,
            hasEQ: hasEQ,
            compressionAmount: compressionAmount,
            reverbAmount: reverbAmount,
            stereoEnhancement: stereoEnhancement,
            frequencyBalance: frequencyBalance
        )
    }
    
    private func detectReverb(left: [Float], right: [Float]) -> Float {
        // Detect reverb by analyzing autocorrelation decay
        // Reverb creates a distinctive tail in the autocorrelation function
        
        let windowSize = 4096
        guard left.count > windowSize else { return 0.0 }
        
        // Take a middle section of the audio
        let startIndex = left.count / 2
        let endIndex = min(startIndex + windowSize, left.count)
        let segment = Array(left[startIndex..<endIndex])
        
        // Calculate autocorrelation at different lags
        var earlyEnergy: Float = 0.0 // 0-50ms
        var lateEnergy: Float = 0.0  // 50-200ms
        
        let sampleRate: Float = 44100.0
        let earlyLag = Int(0.05 * sampleRate) // 50ms
        let lateLag = Int(0.2 * sampleRate)   // 200ms
        
        // Energy in early reflections
        for i in 0..<min(earlyLag, segment.count) {
            earlyEnergy += segment[i] * segment[i]
        }
        
        // Energy in late reflections (reverb tail)
        for i in earlyLag..<min(lateLag, segment.count) {
            lateEnergy += segment[i] * segment[i]
        }
        
        // Reverb ratio: more energy in late reflections = more reverb
        let totalEnergy = earlyEnergy + lateEnergy + 0.0001
        let reverbRatio = lateEnergy / totalEnergy
        
        // Dry signal: < 0.1, Moderate reverb: 0.15-0.3, Heavy reverb: > 0.4
        return min(reverbRatio * 2.0, 1.0) // Scale to 0-1
    }
    
    // MARK: - Loudness Range Calculation
    
    private func calculateLoudnessRange(left: [Float], right: [Float]) -> Float {
        // Simplified Loudness Range (LRA) calculation using percentile method
        // LRA measures the variation in loudness over time
        // Standard: EBU R128 - difference between 10th and 95th percentile
        
        let windowSize = 4410 // 100ms at 44.1kHz (adjust based on actual sample rate)
        let hopSize = windowSize / 2
        var loudnessValues: [Float] = []
        
        // Calculate short-term loudness for overlapping windows
        let count = min(left.count, right.count)
        var index = 0
        
        while index + windowSize < count {
            let leftSegment = Array(left[index..<(index + windowSize)])
            let rightSegment = Array(right[index..<(index + windowSize)])
            
            // Calculate RMS for this window
            let leftRMS = calculateRMS(leftSegment)
            let rightRMS = calculateRMS(rightSegment)
            let avgRMS = (leftRMS + rightRMS) / 2.0
            
            // Convert to dB (LUFS approximation)
            if avgRMS > 0.0001 {
                let loudnessDB = 20 * log10(avgRMS) - 0.691
                loudnessValues.append(loudnessDB)
            }
            
            index += hopSize
        }
        
        // Sort values to calculate percentiles
        guard loudnessValues.count > 10 else { return 0 }
        loudnessValues.sort()
        
        // Calculate 10th and 95th percentiles
        let p10Index = Int(Double(loudnessValues.count) * 0.10)
        let p95Index = Int(Double(loudnessValues.count) * 0.95)
        
        let lra = loudnessValues[p95Index] - loudnessValues[p10Index]
        
        // LRA typically ranges from 2-20 LU
        // Low LRA (< 5 LU) = heavily compressed
        // Medium LRA (5-12 LU) = typical modern mix
        // High LRA (> 15 LU) = dynamic/classical music
        
        return max(0, lra)
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
    
    // MARK: - Stem-Based Analysis
    
    /// Enhanced mix balance analysis using stem separation
    struct StemBasedMixAnalysis {
        // Stem level balance (relative levels)
        let vocalsToInstrumentsRatio: Float  // dB difference
        let drumsToMixRatio: Float           // How prominent drums are
        let bassToMixRatio: Float            // How prominent bass is
        
        // Mix depth characteristics
        let depthScore: Float                // 0-1, how much depth/dimension
        let foregroundClarity: Float         // 0-1, clarity of lead elements
        let backgroundAmbience: Float        // 0-1, amount of space/reverb
        
        // Frequency distribution per stem
        let vocalsFrequencyRange: (low: Float, mid: Float, high: Float)
        let drumsFrequencyRange: (low: Float, mid: Float, high: Float)
        let bassFrequencyRange: (low: Float, mid: Float, high: Float)
        
        // Spatial characteristics
        let vocalsPlacement: String          // "center", "wide", "left", "right"
        let drumsPlacement: String
        let bassPlacement: String
        
        // Overall mix quality indicators
        let elementSeparationQuality: Float  // 0-1, how distinct elements are
        let frequencyMasking: Float          // 0-1, how much overlap (lower is better)
        let mixDensity: Float                // 0-1, how "full" the mix sounds
    }
    
    /// Analyze mix using separated stems for detailed insights
    func analyzeMixFromStems(
        vocals: (left: [Float], right: [Float])?,
        drums: (left: [Float], right: [Float])?,
        bass: (left: [Float], right: [Float])?,
        other: (left: [Float], right: [Float])?,
        sampleRate: Double
    ) throws -> StemBasedMixAnalysis {
        
        print("   🎚️ Analyzing Mix from Stems...")
        
        // Calculate RMS levels for each stem
        let vocalsRMS = vocals.map { (calculateRMS($0.left) + calculateRMS($0.right)) / 2.0 } ?? 0.0
        let drumsRMS = drums.map { (calculateRMS($0.left) + calculateRMS($0.right)) / 2.0 } ?? 0.0
        let bassRMS = bass.map { (calculateRMS($0.left) + calculateRMS($0.right)) / 2.0 } ?? 0.0
        let otherRMS = other.map { (calculateRMS($0.left) + calculateRMS($0.right)) / 2.0 } ?? 0.0
        
        let totalInstruments = drumsRMS + bassRMS + otherRMS + 0.0001
        
        // Calculate level ratios in dB
        let vocalsToInstrumentsRatio = 20 * log10((vocalsRMS + 0.0001) / totalInstruments)
        let drumsToMixRatio = drumsRMS / (vocalsRMS + totalInstruments)
        let bassToMixRatio = bassRMS / (vocalsRMS + totalInstruments)
        
        print("      Vocals to Instruments: \(String(format: "%.1f", vocalsToInstrumentsRatio)) dB")
        print("      Drums Ratio: \(String(format: "%.1f", drumsToMixRatio * 100))%")
        print("      Bass Ratio: \(String(format: "%.1f", bassToMixRatio * 100))%")
        
        // Analyze stereo width per stem for spatial placement
        let vocalsStereoFeatures = vocals.map { extractStereoFeatures(left: $0.left, right: $0.right) }
        let drumsStereoFeatures = drums.map { extractStereoFeatures(left: $0.left, right: $0.right) }
        let bassStereoFeatures = bass.map { extractStereoFeatures(left: $0.left, right: $0.right) }
        
        // Determine spatial placement
        let vocalsPlacement = determinePlacement(
            stereoWidth: vocalsStereoFeatures?.stereoWidth ?? 0,
            balance: vocalsStereoFeatures?.leftRightBalance ?? 0
        )
        let drumsPlacement = determinePlacement(
            stereoWidth: drumsStereoFeatures?.stereoWidth ?? 0,
            balance: drumsStereoFeatures?.leftRightBalance ?? 0
        )
        let bassPlacement = determinePlacement(
            stereoWidth: bassStereoFeatures?.stereoWidth ?? 0,
            balance: bassStereoFeatures?.leftRightBalance ?? 0
        )
        
        print("      Spatial Placement:")
        print("      - Vocals: \(vocalsPlacement)")
        print("      - Drums: \(drumsPlacement)")
        print("      - Bass: \(bassPlacement)")
        
        // Analyze frequency distribution per stem
        let vocalsFreq: (low: Float, mid: Float, high: Float)
        if let v = vocals, let freq = try? analyzeFrequencyDistribution(left: v.left, sampleRate: sampleRate) {
            vocalsFreq = freq
        } else {
            vocalsFreq = (low: 0, mid: 0, high: 0)
        }
        
        let drumsFreq: (low: Float, mid: Float, high: Float)
        if let d = drums, let freq = try? analyzeFrequencyDistribution(left: d.left, sampleRate: sampleRate) {
            drumsFreq = freq
        } else {
            drumsFreq = (low: 0, mid: 0, high: 0)
        }
        
        let bassFreq: (low: Float, mid: Float, high: Float)
        if let b = bass, let freq = try? analyzeFrequencyDistribution(left: b.left, sampleRate: sampleRate) {
            bassFreq = freq
        } else {
            bassFreq = (low: 0, mid: 0, high: 0)
        }
        
        // Calculate mix depth based on stem dynamics and stereo width variation
        let stereoWidthVariance = calculateVariance([
            vocalsStereoFeatures?.stereoWidth ?? 0,
            drumsStereoFeatures?.stereoWidth ?? 0,
            bassStereoFeatures?.stereoWidth ?? 0
        ])
        let depthScore = min(1.0, stereoWidthVariance * 3.0)
        
        // Foreground clarity: How much vocals stand out
        let foregroundClarity = min(1.0, vocalsRMS / (totalInstruments + 0.0001))
        
        // Background ambience: Estimate from wide stereo content
        let wideContent = [
            vocalsStereoFeatures?.stereoWidth ?? 0,
            drumsStereoFeatures?.stereoWidth ?? 0
        ].filter { $0 > 0.6 }.count
        let backgroundAmbience = Float(wideContent) / 2.0
        
        // Element separation quality: Variance in levels = better separation
        let levelVariance = calculateVariance([vocalsRMS, drumsRMS, bassRMS, otherRMS])
        let elementSeparationQuality = min(1.0, levelVariance * 4.0)
        
        // Frequency masking: Overlap in frequency ranges (lower is better)
        let frequencyOverlap = calculateFrequencyOverlap(
            vocalsFreq: vocalsFreq,
            drumsFreq: drumsFreq,
            bassFreq: bassFreq
        )
        let frequencyMasking = max(0, min(1.0, frequencyOverlap))
        
        // Mix density: How full the spectrum is
        let totalEnergy = vocalsRMS + drumsRMS + bassRMS + otherRMS
        let mixDensity = min(1.0, totalEnergy * 2.0)
        
        print("      Mix Characteristics:")
        print("      - Depth Score: \(String(format: "%.1f", depthScore * 100))%")
        print("      - Foreground Clarity: \(String(format: "%.1f", foregroundClarity * 100))%")
        print("      - Background Ambience: \(String(format: "%.1f", backgroundAmbience * 100))%")
        print("      - Element Separation: \(String(format: "%.1f", elementSeparationQuality * 100))%")
        print("      - Frequency Masking: \(String(format: "%.1f", frequencyMasking * 100))%")
        print("      - Mix Density: \(String(format: "%.1f", mixDensity * 100))%")
        
        return StemBasedMixAnalysis(
            vocalsToInstrumentsRatio: vocalsToInstrumentsRatio,
            drumsToMixRatio: drumsToMixRatio,
            bassToMixRatio: bassToMixRatio,
            depthScore: depthScore,
            foregroundClarity: foregroundClarity,
            backgroundAmbience: backgroundAmbience,
            vocalsFrequencyRange: vocalsFreq,
            drumsFrequencyRange: drumsFreq,
            bassFrequencyRange: bassFreq,
            vocalsPlacement: vocalsPlacement,
            drumsPlacement: drumsPlacement,
            bassPlacement: bassPlacement,
            elementSeparationQuality: elementSeparationQuality,
            frequencyMasking: frequencyMasking,
            mixDensity: mixDensity
        )
    }
    
    private func determinePlacement(stereoWidth: Float, balance: Float) -> String {
        if stereoWidth < 0.3 {
            // Narrow/mono
            if abs(balance) < 0.2 {
                return "center"
            } else if balance < 0 {
                return "center-left"
            } else {
                return "center-right"
            }
        } else if stereoWidth < 0.7 {
            return "moderate-wide"
        } else {
            return "very-wide"
        }
    }
    
    private func analyzeFrequencyDistribution(
        left: [Float],
        sampleRate: Double
    ) throws -> (low: Float, mid: Float, high: Float) {
        
        // Extract frequency features
        let freqFeatures = try extractFrequencyFeatures(audio: left, sampleRate: sampleRate)
        
        // Combine bands into low/mid/high
        let subBass = freqFeatures.frequencyBands[20.0] ?? 0
        let bass = freqFeatures.frequencyBands[60.0] ?? 0
        let lowMids = freqFeatures.frequencyBands[250.0] ?? 0
        let mids = freqFeatures.frequencyBands[500.0] ?? 0
        let highMids = freqFeatures.frequencyBands[2000.0] ?? 0
        let highs = freqFeatures.frequencyBands[6000.0] ?? 0
        
        let low = (subBass + bass) / 2.0
        let mid = (lowMids + mids) / 2.0
        let high = (highMids + highs) / 2.0
        
        return (low: low, mid: mid, high: high)
    }
    
    private func calculateFrequencyOverlap(
        vocalsFreq: (low: Float, mid: Float, high: Float),
        drumsFreq: (low: Float, mid: Float, high: Float),
        bassFreq: (low: Float, mid: Float, high: Float)
    ) -> Float {
        
        // Calculate overlap in each band
        let lowOverlap = min(vocalsFreq.low, drumsFreq.low, bassFreq.low)
        let midOverlap = min(vocalsFreq.mid, drumsFreq.mid, bassFreq.mid)
        let highOverlap = min(vocalsFreq.high, drumsFreq.high, bassFreq.high)
        
        // Average overlap across bands
        return (lowOverlap + midOverlap + highOverlap) / 3.0
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }
}
