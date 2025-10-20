# Phase 3: CoreML Audio Analysis Engine

**Duration**: Week 2-4
**Goal**: Build comprehensive audio analysis system using CoreML and DSP

## Objectives

- Implement audio preprocessing pipeline
- Extract audio features for analysis
- Create/train CoreML models for mix quality detection
- Analyze stereo imaging and width
- Detect phase issues
- Evaluate frequency balance
- Measure dynamic range and loudness
- Generate actionable recommendations

## Architecture Overview

```
Audio File (AVAudioFile)
    ↓
Audio Buffer (AVAudioPCMBuffer)
    ↓
Feature Extraction Layer
    ├── Time Domain Features
    ├── Frequency Domain Features (FFT)
    ├── Stereo Features
    └── Loudness Features
    ↓
CoreML Models
    ├── Stereo Width Classifier
    ├── Phase Problem Detector
    ├── Frequency Balance Analyzer
    └── Mix Quality Scorer
    ↓
Results Aggregation
    ↓
AnalysisResult Object
```

## Implementation

### 1. Audio Preprocessing

```swift
import AVFoundation
import Accelerate

final class AudioProcessor {

    struct ProcessedAudio {
        let leftChannel: [Float]
        let rightChannel: [Float]
        let sampleRate: Double
        let frameCount: Int
    }

    // MARK: - Audio Loading

    func loadAudio(from url: URL) throws -> ProcessedAudio {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat

        guard format.channelCount >= 1 else {
            throw AudioProcessingError.invalidChannelCount
        }

        let frameCount = Int(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw AudioProcessingError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)

        // Convert to float arrays
        let leftChannel = extractChannel(buffer: buffer, channel: 0)
        let rightChannel = format.channelCount > 1 ? extractChannel(buffer: buffer, channel: 1) : leftChannel

        return ProcessedAudio(
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            sampleRate: format.sampleRate,
            frameCount: frameCount
        )
    }

    private func extractChannel(buffer: AVAudioPCMBuffer, channel: Int) -> [Float] {
        guard let channelData = buffer.floatChannelData?[channel] else {
            return []
        }

        let frameCount = Int(buffer.frameLength)
        var channelArray = [Float](repeating: 0, count: frameCount)
        channelArray.withUnsafeMutableBufferPointer { ptr in
            memcpy(ptr.baseAddress!, channelData, frameCount * MemoryLayout<Float>.size)
        }

        return channelArray
    }

    // MARK: - Mid-Side Processing

    struct MidSideAudio {
        let mid: [Float]  // (L + R) / 2
        let side: [Float] // (L - R) / 2
    }

    func convertToMidSide(left: [Float], right: [Float]) -> MidSideAudio {
        var mid = [Float](repeating: 0, count: left.count)
        var side = [Float](repeating: 0, count: left.count)

        for i in 0..<left.count {
            mid[i] = (left[i] + right[i]) / 2.0
            side[i] = (left[i] - right[i]) / 2.0
        }

        return MidSideAudio(mid: mid, side: side)
    }
}

enum AudioProcessingError: LocalizedError {
    case invalidChannelCount
    case bufferCreationFailed
    case fftSetupFailed

    var errorDescription: String? {
        switch self {
        case .invalidChannelCount:
            return "Audio file has invalid channel count"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .fftSetupFailed:
            return "Failed to setup FFT"
        }
    }
}
```

### 2. Feature Extraction

```swift
import Accelerate

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
        let fftSize = AppConstants.fftSize
        let log2n = vDSP_Length(log2(Float(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw AudioProcessingError.fftSetupFailed
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Prepare buffers
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)

        // Window function (Hann window)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Apply window and convert to split complex
        var windowedAudio = [Float](repeating: 0, count: fftSize)
        let audioChunk = Array(audio.prefix(fftSize))
        vDSP_vmul(audioChunk, 1, window, 1, &windowedAudio, 1, vDSP_Length(fftSize))

        windowedAudio.withUnsafeBytes { audioBytes in
            audioBytes.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { audioComplex in
                vDSP_ctoz(audioComplex, 2, &output, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Perform FFT
        vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&output, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

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
```

### 3. CoreML Models

#### Model 1: Stereo Width Classifier

```swift
// This is a placeholder - actual model needs to be trained
// Model input: stereo features (width, correlation, mid-side ratio)
// Model output: classification (too_narrow, good, too_wide)

import CoreML

final class StereoWidthClassifier {

    private var model: MLModel?

    init() {
        // Load trained model
        // self.model = try? StereoWidthModel(configuration: MLModelConfiguration())
    }

    func classify(features: AudioFeatureExtractor.StereoFeatures) -> StereoWidthResult {
        // Placeholder implementation until model is trained
        let width = features.stereoWidth

        if width < 0.3 {
            return StereoWidthResult(classification: .tooNarrow, confidence: 0.8, recommendation: "Stereo image is too narrow. Consider widening with stereo enhancer.")
        } else if width > 0.7 {
            return StereoWidthResult(classification: .tooWide, confidence: 0.8, recommendation: "Stereo image is too wide. May have mono compatibility issues.")
        } else {
            return StereoWidthResult(classification: .good, confidence: 0.9, recommendation: "Stereo width is well balanced.")
        }
    }

    struct StereoWidthResult {
        enum Classification {
            case tooNarrow
            case good
            case tooWide
        }

        let classification: Classification
        let confidence: Float
        let recommendation: String
    }
}
```

#### Model 2: Phase Problem Detector

```swift
final class PhaseProblemDetector {

    func detect(stereoFeatures: AudioFeatureExtractor.StereoFeatures) -> PhaseResult {
        let correlation = stereoFeatures.correlation

        // Negative correlation indicates phase problems
        if correlation < -0.3 {
            return PhaseResult(
                hasIssue: true,
                severity: .severe,
                confidence: 0.9,
                recommendation: "Severe phase cancellation detected. Check for inverted polarity or phase issues."
            )
        } else if correlation < 0.3 {
            return PhaseResult(
                hasIssue: true,
                severity: .moderate,
                confidence: 0.7,
                recommendation: "Possible phase issues detected. Review stereo processing."
            )
        } else {
            return PhaseResult(
                hasIssue: false,
                severity: .none,
                confidence: 0.95,
                recommendation: "Phase relationship is healthy."
            )
        }
    }

    struct PhaseResult {
        enum Severity {
            case none, moderate, severe
        }

        let hasIssue: Bool
        let severity: Severity
        let confidence: Float
        let recommendation: String
    }
}
```

#### Model 3: Frequency Balance Analyzer

```swift
final class FrequencyBalanceAnalyzer {

    func analyze(frequencyFeatures: AudioFeatureExtractor.FrequencyFeatures) -> FrequencyBalanceResult {
        let bands = frequencyFeatures.frequencyBands

        // Extract band energies
        let bass = bands[60] ?? 0
        let mids = bands[500] ?? 0
        let highs = bands[6000] ?? 0

        // Normalize
        let total = bass + mids + highs + 0.0001
        let bassRatio = bass / total
        let midsRatio = mids / total
        let highsRatio = highs / total

        var issues: [String] = []
        var recommendations: [String] = []

        // Check for imbalances (ideal ratios are roughly 0.3, 0.4, 0.3)
        if bassRatio < 0.2 {
            issues.append("Bass deficiency")
            recommendations.append("Boost low end frequencies (60-250 Hz)")
        } else if bassRatio > 0.5 {
            issues.append("Bass excess")
            recommendations.append("Reduce low end frequencies or add high-pass filter")
        }

        if midsRatio < 0.25 {
            issues.append("Midrange deficiency")
            recommendations.append("Boost midrange frequencies (500-2000 Hz)")
        } else if midsRatio > 0.55 {
            issues.append("Midrange excess")
            recommendations.append("Reduce midrange frequencies for clarity")
        }

        if highsRatio < 0.15 {
            issues.append("High frequency deficiency")
            recommendations.append("Add brightness with high shelf or air band boost")
        } else if highsRatio > 0.4 {
            issues.append("High frequency excess")
            recommendations.append("Reduce harsh high frequencies")
        }

        let score = calculateBalanceScore(bassRatio: bassRatio, midsRatio: midsRatio, highsRatio: highsRatio)

        return FrequencyBalanceResult(
            score: score,
            bassRatio: bassRatio,
            midsRatio: midsRatio,
            highsRatio: highsRatio,
            issues: issues,
            recommendations: recommendations
        )
    }

    private func calculateBalanceScore(bassRatio: Float, midsRatio: Float, highsRatio: Float) -> Float {
        // Ideal ratios
        let idealBass: Float = 0.3
        let idealMids: Float = 0.4
        let idealHighs: Float = 0.3

        // Calculate deviation from ideal
        let bassDeviation = abs(bassRatio - idealBass)
        let midsDeviation = abs(midsRatio - idealMids)
        let highsDeviation = abs(highsRatio - idealHighs)

        let totalDeviation = bassDeviation + midsDeviation + highsDeviation
        let score = max(0, 100 - (totalDeviation * 200)) // Scale to 0-100

        return score
    }

    struct FrequencyBalanceResult {
        let score: Float
        let bassRatio: Float
        let midsRatio: Float
        let highsRatio: Float
        let issues: [String]
        let recommendations: [String]
    }
}
```

### 4. Audio Analysis Service

```swift
import Foundation
import Observation

@Observable
final class AudioAnalysisService {

    private let processor = AudioProcessor()
    private let featureExtractor = AudioFeatureExtractor()
    private let stereoClassifier = StereoWidthClassifier()
    private let phaseDetector = PhaseProblemDetector()
    private let frequencyAnalyzer = FrequencyBalanceAnalyzer()

    // MARK: - Main Analysis

    func analyzeAudio(_ audioFile: AudioFile) async throws -> AnalysisResult {
        // Load and process audio
        let processedAudio = try processor.loadAudio(from: audioFile.fileURL)

        // Extract features
        let stereoFeatures = featureExtractor.extractStereoFeatures(
            left: processedAudio.leftChannel,
            right: processedAudio.rightChannel
        )

        let frequencyFeatures = try featureExtractor.extractFrequencyFeatures(
            audio: processedAudio.leftChannel,
            sampleRate: processedAudio.sampleRate
        )

        let loudnessFeatures = featureExtractor.extractLoudnessFeatures(
            left: processedAudio.leftChannel,
            right: processedAudio.rightChannel
        )

        // Run analyzers
        let stereoResult = stereoClassifier.classify(features: stereoFeatures)
        let phaseResult = phaseDetector.detect(stereoFeatures: stereoFeatures)
        let frequencyResult = frequencyAnalyzer.analyze(frequencyFeatures: frequencyFeatures)

        // Create analysis result
        let result = AnalysisResult(audioFile: audioFile)

        // Populate metrics
        result.stereoWidthScore = Double(stereoFeatures.stereoWidth * 100)
        result.phaseCoherence = Double(stereoFeatures.correlation)

        result.frequencyBalance = FrequencyBalance(
            lowEnd: Double(frequencyResult.bassRatio * 100),
            lowMids: 0, // Simplified
            mids: Double(frequencyResult.midsRatio * 100),
            highMids: 0, // Simplified
            highs: Double(frequencyResult.highsRatio * 100)
        )

        result.dynamicRange = Double(loudnessFeatures.dynamicRange)
        result.loudnessLUFS = Double(loudnessFeatures.lufs)
        result.peakLevel = Double(20 * log10(loudnessFeatures.peakLevel))

        // Set issue flags
        result.hasPhaseIssues = phaseResult.hasIssue
        result.hasStereoIssues = stereoResult.classification != .good
        result.hasFrequencyImbalance = !frequencyResult.issues.isEmpty
        result.hasDynamicRangeIssues = loudnessFeatures.dynamicRange < 6 || loudnessFeatures.dynamicRange > 20

        // Aggregate recommendations
        var recommendations: [String] = []
        recommendations.append(stereoResult.recommendation)
        recommendations.append(phaseResult.recommendation)
        recommendations.append(contentsOf: frequencyResult.recommendations)

        if result.hasDynamicRangeIssues {
            if loudnessFeatures.dynamicRange < 6 {
                recommendations.append("Dynamic range is too compressed. Consider reducing compression.")
            } else {
                recommendations.append("Dynamic range is very wide. Consider light compression for consistency.")
            }
        }

        result.recommendations = recommendations

        // Calculate overall score
        result.overallScore = calculateOverallScore(result: result)

        return result
    }

    private func calculateOverallScore(result: AnalysisResult) -> Double {
        var score: Double = 100

        // Deduct points for issues
        if result.hasPhaseIssues {
            score -= result.phaseCoherence < -0.3 ? 30 : 15
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
        if result.peakLevel > -0.1 {
            score -= 10 // Potential clipping
        }

        return max(0, score)
    }
}
```

## CoreML Model Training (Future Implementation)

### Training Data Requirements

1. **Dataset Size**: 1000+ audio files
2. **Categories**:
   - Professional mixes (reference quality)
   - Amateur mixes with labeled issues
   - Synthetic test tones

3. **Labels Needed**:
   - Stereo width classification
   - Phase problem severity
   - Frequency balance scores
   - Overall mix quality rating

### Training Tools
- **Create ML**: For simple classifiers
- **TensorFlow/PyTorch**: For complex models, then convert to CoreML
- **Turi Create**: For audio analysis models

### Model Training Process
```python
# Pseudo-code for training
# 1. Extract features from audio files
# 2. Label dataset
# 3. Train model
# 4. Convert to CoreML
# 5. Integrate into app
```

## Testing

### Unit Tests

```swift
final class AudioFeatureExtractorTests: XCTestCase {

    func testStereoFeatureExtraction() {
        // Test stereo feature extraction
        let left = [Float](repeating: 1.0, count: 1000)
        let right = [Float](repeating: 0.5, count: 1000)

        let extractor = AudioFeatureExtractor()
        let features = extractor.extractStereoFeatures(left: left, right: right)

        XCTAssertGreaterThan(features.stereoWidth, 0)
        XCTAssertLessThanOrEqual(features.stereoWidth, 1)
    }
}
```

## Deliverables

- [ ] Audio preprocessing pipeline
- [ ] Feature extraction (stereo, frequency, loudness)
- [ ] CoreML model implementations (placeholder + real)
- [ ] Analysis service with complete workflow
- [ ] Unit tests for all analysis components
- [ ] Performance optimization
- [ ] Documentation for each analyzer

## Performance Targets

- Analysis time: < 10 seconds for 5-minute audio file
- Memory usage: < 200 MB during analysis
- CPU usage: < 80% on average

## Next Phase

Proceed to [Phase 4: UI Implementation](04-phase-ui-implementation.md) to build the user interface.

## Estimated Time

- Audio preprocessing: 6 hours
- Feature extraction: 8 hours
- Analyzer implementations: 10 hours
- Analysis service integration: 4 hours
- Testing: 6 hours
- Optimization: 4 hours

**Total: ~38 hours (5-7 days)**
