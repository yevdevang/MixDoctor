//
//  PAZFrequencyAnalyzer.swift
//  MixDoctor
//
//  PAZ Analyzer-style frequency analyzer component
//

import SwiftUI
import Charts

struct PAZFrequencyAnalyzer: View {
    let result: AnalysisResult
    
    // PAZ-style frequency bands with proper Hz ranges
    private var frequencyBands: [FrequencyBand] {
        [
            FrequencyBand(
                label: "Sub Bass",
                range: "20-80 Hz",
                value: result.lowEndBalance * 0.25, // Estimate sub-bass as portion of low end
                color: Color(red: 0.4, green: 0.2, blue: 0.8),
                isCritical: false
            ),
            FrequencyBand(
                label: "Bass",
                range: "80-250 Hz",
                value: result.lowEndBalance * 0.75, // Main bass portion
                color: Color(red: 0.5, green: 0.3, blue: 1.0),
                isCritical: true
            ),
            FrequencyBand(
                label: "Low Mid",
                range: "250-500 Hz",
                value: result.lowMidBalance,
                color: Color(red: 1.0, green: 0.6, blue: 0.2),
                isCritical: true
            ),
            FrequencyBand(
                label: "Mid",
                range: "500-2k Hz",
                value: result.midBalance,
                color: Color(red: 0.9, green: 0.8, blue: 0.2),
                isCritical: true
            ),
            FrequencyBand(
                label: "High Mid",
                range: "2-6 kHz",
                value: result.highMidBalance,
                color: Color(red: 0.5, green: 0.8, blue: 0.3),
                isCritical: true
            ),
            FrequencyBand(
                label: "Presence",
                range: "6-12 kHz",
                value: result.highBalance * 0.6, // Main presence portion
                color: Color(red: 0.2, green: 0.7, blue: 0.9),
                isCritical: true
            ),
            FrequencyBand(
                label: "Air",
                range: "12-20 kHz",
                value: result.highBalance * 0.4, // Air frequencies
                color: Color(red: 0.4, green: 0.5, blue: 1.0),
                isCritical: false
            )
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.blue)
                    .font(.title2)

                Text("Frequency Analyzer")
                    .font(.headline)

                Spacer()

                Image(systemName: result.hasFrequencyImbalance ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.hasFrequencyImbalance ? .orange : .green)
            }

            // Overall Score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.frequencyBalanceScore))
                    .font(.system(size: 28, weight: .bold))

                Text("%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(frequencyBalanceDescription(result.frequencyBalanceScore))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            AmplitudeSummary(
                peakLevel: result.peakLevel,
                rmsLevel: result.rmsLevel,
                loudnessLUFS: result.loudnessLUFS,
                hasClipping: result.hasClipping
            )

            Divider()
                .padding(.vertical, 4)

            // Chart-style spectrum analyzer with proper spacing
            VStack(spacing: 16) {
                // Chart visualization with fixed height to prevent overlap
                FrequencyChart(
                    bands: frequencyBands,
                    spectrum: result.frequencySpectrum,  // REAL FFT data from audio file
                    sampleRate: result.spectrumSampleRate
                )
                    .frame(height: 250) // Ensure chart doesn't expand
                    .clipped() // Prevent any content from overflowing
                
                // Clear divider between chart and frequency breakdown
                Divider()
                    .padding(.vertical, 8)
                
                // Frequency band details below chart
                VStack(spacing: 8) {
                    ForEach(frequencyBands, id: \.label) { band in
                        FrequencyBandDetail(band: band)
                    }
                }
            }
            
            // Analysis insights
            if result.hasFrequencyImbalance {
                PAZAnalysisInsights(bands: frequencyBands)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func frequencyBalanceDescription(_ score: Double) -> String {
        switch score {
        case 0..<50: return "Needs EQ work"
        case 50..<70: return "Moderate balance"
        case 70..<85: return "Good balance"
        default: return "Excellent balance"
        }
    }
}

// MARK: - Amplitude Summary

struct AmplitudeSummary: View {
    let peakLevel: Double
    let rmsLevel: Double
    let loudnessLUFS: Double
    let hasClipping: Bool
    
    private struct AmplitudeMetric: Identifiable {
        let id: String
        let value: String
        let unit: String
        let color: Color
        let icon: String
    }
    
    private var metrics: [AmplitudeMetric] {
        [
            AmplitudeMetric(
                id: "Peak",
                value: formatted(peakLevel),
                unit: "dB",
                color: peakColor,
                icon: hasClipping ? "exclamationmark.triangle.fill" : "waveform.path"
            ),
            AmplitudeMetric(
                id: "RMS",
                value: formatted(rmsLevel),
                unit: "dB",
                color: rmsColor,
                icon: "dot.radiowaves.left.and.right"
            ),
            AmplitudeMetric(
                id: "Loudness",
                value: formatted(loudnessLUFS),
                unit: "LUFS",
                color: .blue,
                icon: "gauge"
            )
        ]
    }
    
    private var peakColor: Color {
        if hasClipping { return .red }
        if peakLevel > -1.0 { return .orange }
        return .green
    }
    
    private var rmsColor: Color {
        if rmsLevel > -8.0 { return .orange }
        if rmsLevel < -20.0 { return .yellow }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Label(metric.id, systemImage: metric.icon)
                        .font(.caption.bold())
                        .foregroundStyle(metric.color)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(metric.value)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(metric.unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(metric.color.opacity(0.25), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatted(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Frequency Chart Component

struct FrequencyChart: View {
    let bands: [FrequencyBand]
    let spectrum: [Float]?      // REAL FFT data
    let sampleRate: Double?     // Actual sample rate
    
    var body: some View {
        // Chart area with spectrum analyzer
        ZStack {
            // Use Canvas-based spectrum generator for professional visualization
            if let fftData = spectrum, let sr = sampleRate, fftData.count > 0 {
                SpectrumCanvasView(dataPoints: prepareDataPoints(fftData: fftData, sampleRate: sr))
                    .frame(height: 230)
            } else {
                // Fallback: Dark background
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        Text("NO FFT DATA")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.7))
                    )
            }
        }
        .frame(height: 230)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Prepare data points for Canvas view
    private func prepareDataPoints(fftData: [Float], sampleRate: Double) -> [(frequency: Double, magnitude: Double)] {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(fftData.count)
        
        let minFreq = 20.0
        let maxFreq = 20000.0
        
        var dataPoints: [(frequency: Double, magnitude: Double)] = []
        
        // Debug: show ONLY the bins in audible range
        print("🔍 FFT DATA in AUDIBLE RANGE (20Hz - 20kHz):")
        print("📊 Sample rate: \(sampleRate)Hz, Nyquist: \(nyquist)Hz, Bin width: \(String(format: "%.2f", binWidth))Hz")
        print("📊 Total FFT bins: \(fftData.count)")
        
        var debugCount = 0
        for (index, mag) in fftData.enumerated() {
            let frequency = Double(index) * binWidth
            guard frequency >= minFreq && frequency <= maxFreq else { continue }
            
            // Debug first 50 audible bins
            if debugCount < 50 {
                let dB = 20.0 * log10(max(Double(mag), 1e-12))
                print("  Bin \(index): \(String(format: "%.1f", frequency))Hz = \(String(format: "%.4f", mag)) = \(String(format: "%.1f", dB))dB")
                debugCount += 1
            }
            
            let dB = 20.0 * log10(max(Double(mag), 1e-12))
            let clampedDB = max(dB, -100.0)
            
            dataPoints.append((frequency: frequency, magnitude: clampedDB))
        }
        
        print("📊 Created \(dataPoints.count) data points for visualization")
        print("📊 Magnitude variation: min=\(String(format: "%.1f", dataPoints.map { $0.magnitude }.min() ?? 0))dB, max=\(String(format: "%.1f", dataPoints.map { $0.magnitude }.max() ?? 0))dB")
        
        return dataPoints
    }
}


// MARK: - Spectrum Grid

struct SpectrumGrid: View {
    var body: some View {
        ZStack {
            // Professional spectrum analyzer grid like the image
            // Horizontal grid lines (dB levels) - aligned with dB scale
            VStack(spacing: 0) {
                ForEach(0..<11) { index in // 11 lines for dB values (0 to -60 in 6dB steps)
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 0.5)
                    
                    if index < 10 {
                        Spacer()
                    }
                }
            }
            
            // Vertical grid lines (frequency divisions) - match the image density
            HStack(spacing: 0) {
                ForEach(0..<20) { index in // Many more vertical lines
                    Rectangle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 0.5)
                    
                    if index < 19 {
                        Spacer()
                    }
                }
            }
            

        }
        .padding(10)
    }
}

// MARK: - Spectrum Curve

struct SpectrumCurve: View {
    let bands: [FrequencyBand]
    let size: CGSize
    let spectrum: [Float]?      // REAL FFT data from audio file
    let sampleRate: Double?     // Actual sample rate
    
    private let minFreq = 20.0
    private let maxFreq = 20000.0
    
    var body: some View {
        ZStack {
            if let fftData = spectrum, let sr = sampleRate, fftData.count > 0 {
                // REAL SPECTRUM from FFT using Charts
                realSpectrumChart(fftData: fftData, sampleRate: sr)
                
                // Debug label
                VStack {
                    HStack {
                        Text("FFT: \(fftData.count) bins @ \(Int(sr))Hz")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.7))
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(20)
            } else {
                // Fallback: Use band averages
                bandAveragesChart()
                
                // Debug label
                VStack {
                    HStack {
                        Text("NO FFT DATA - using band averages")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.7))
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
    }
    
    // Chart with REAL FFT data - professional analyzer style with spikes and peaks
    @ViewBuilder
    private func realSpectrumChart(fftData: [Float], sampleRate: Double) -> some View {
        let dataPoints = prepareFFTDataPoints(fftData: fftData, sampleRate: sampleRate)
        
        Chart(dataPoints) { point in
            // Ultra-thin line with NO smoothing - shows every FFT bin
            LineMark(
                x: .value("Frequency", log10(point.frequency)),
                y: .value("Magnitude", point.magnitude)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(Color.yellow)
            .lineStyle(StrokeStyle(lineWidth: 0.5)) // Very thin line
        }
        .chartXScale(domain: log10(minFreq)...log10(maxFreq))
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000].map { log10(Double($0)) }) { value in
                if let logFreq = value.as(Double.self) {
                    let freq = pow(10.0, logFreq)
                    AxisValueLabel {
                        Text(formatFrequency(freq))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) { value in
                if let val = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(-100 + val * 100))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // Chart with band averages (fallback)
    @ViewBuilder
    private func bandAveragesChart() -> some View {
        let dataPoints = prepareBandDataPoints()
        
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Frequency", point.logFrequency),
                    y: .value("Magnitude", point.magnitude)
                )
                .foregroundStyle(Color.cyan.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXScale(domain: log10(minFreq)...log10(maxFreq))
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]) { value in
                if let freq = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatFrequency(freq))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // Prepare FFT data for Chart - Professional spectrum analyzer style like Waves PAZ
    private func prepareFFTDataPoints(fftData: [Float], sampleRate: Double) -> [SpectrumDataPoint] {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(fftData.count)
        
        var dataPoints: [SpectrumDataPoint] = []
        
        print("📊 FFT Analysis: \(fftData.count) bins, sample rate: \(sampleRate)Hz, bin width: \(String(format: "%.2f", binWidth))Hz")
        
        // Debug: Print some raw FFT values to see if there's variation
        print("📊 RAW FFT magnitudes sample (first 20 bins):")
        for i in 0..<min(20, fftData.count) {
            let freq = Double(i) * binWidth
            print("   Bin \(i) (\(String(format: "%.1f", freq))Hz): \(fftData[i])")
        }
        
        // Professional spectrum analyzer processing like Waves PAZ
        // Use proper RMS magnitude calculation and dB scaling - NO artificial variation!
        for binIndex in 0..<fftData.count {
            let frequency = Double(binIndex) * binWidth
            
            // Only include audible frequencies (20Hz - 20kHz)
            guard frequency >= minFreq && frequency <= maxFreq else { continue }
            
            let magnitude = fftData[binIndex]
            
            // Professional dB conversion: 20*log10(magnitude)
            // Reference level: assume full scale is 0 dB (like professional analyzers)
            let dBValue = 20.0 * log10(max(Double(magnitude), 1e-12)) // Prevent log(0)
            
            // Professional analyzer range: -100 dB to 0 dB for better low-level detail
            let clampedDB = max(dBValue, -100.0)
            
            // Convert to 0-1 range for display (-100 dB = 0, 0 dB = 1)
            let normalizedMagnitude = (clampedDB + 100.0) / 100.0
            
            dataPoints.append(SpectrumDataPoint(
                id: binIndex,
                frequency: frequency,
                logFrequency: 0,  // Not used anymore
                magnitude: max(normalizedMagnitude, 0.0) // Ensure non-negative
            ))
        }
        
        print("📊 FFT Data Points: \(dataPoints.count) bins from \(String(format: "%.0f", dataPoints.first?.frequency ?? 0))Hz to \(String(format: "%.0f", dataPoints.last?.frequency ?? 0))Hz")
        print("📊 Magnitude range: \(String(format: "%.3f", dataPoints.map { $0.magnitude }.min() ?? 0)) to \(String(format: "%.3f", dataPoints.map { $0.magnitude }.max() ?? 0))")
        
        return dataPoints
    }
    
    // Prepare band average data for Chart
    private func prepareBandDataPoints() -> [SpectrumDataPoint] {
        let bandDefinitions: [(label: String, lower: Double, upper: Double)] = [
            ("Sub Bass", 20, 80),
            ("Bass", 80, 250),
            ("Low Mid", 250, 500),
            ("Mid", 500, 2000),
            ("High Mid", 2000, 6000),
            ("Presence", 6000, 12000),
            ("Air", 12000, 20000)
        ]
        
        var dataPoints: [SpectrumDataPoint] = []
        let numPoints = 200
        
        for i in 0..<numPoints {
            let t = Double(i) / Double(numPoints - 1)
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)
            let logFreq = logMin + t * (logMax - logMin)
            let frequency = pow(10.0, logFreq)
            
            // Find band and get value
            var bandValue = 0.0
            for bandDef in bandDefinitions {
                if frequency >= bandDef.lower && frequency < bandDef.upper {
                    bandValue = bands.first(where: { $0.label == bandDef.label })?.value ?? 0
                    break
                }
            }
            
            let energy = min(max(bandValue / 100.0, 0.0), 1.0)
            
            dataPoints.append(SpectrumDataPoint(
                id: i,
                frequency: frequency,
                logFrequency: logFreq,
                magnitude: energy
            ))
        }
        
        return dataPoints
    }
    
    private func formatFrequency(_ freq: Double) -> String {
        if freq >= 1000 {
            return "\(Int(freq / 1000))k"
        }
        return "\(Int(freq))"
    }
}

// Data point for Chart
struct SpectrumDataPoint: Identifiable {
    let id: Int
    let frequency: Double
    let logFrequency: Double
    let magnitude: Double
}

// MARK: - Frequency Markers

struct FrequencyMarkers: View {
    let size: CGSize
    
    var body: some View {
        HStack {
            Spacer()
            
            // Enhanced frequency markers with more detail
            ForEach([50, 100, 200, 500, 1000, 2000, 5000, 10000], id: \.self) { frequency in
                VStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 1, height: 15)
                    
                    Text(formatFrequency(frequency))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private func formatFrequency(_ frequency: Int) -> String {
        if frequency >= 1000 {
            return "\(frequency/1000)k"
        } else {
            return "\(frequency)"
        }
    }
}

// MARK: - Frequency Chart Bar

struct FrequencyChartBar: View {
    let band: FrequencyBand
    let maxHeight: CGFloat
    let width: CGFloat
    
    // Calculate bar height based on frequency value
    private var barHeight: CGFloat {
        let minHeight: CGFloat = 8
        let normalizedValue = min(max(band.value / 100, 0), 1)
        return minHeight + (maxHeight - minHeight) * normalizedValue
    }
    
    // Status color based on energy level
    private var barColor: Color {
        if !band.isCritical {
            return band.color.opacity(0.7)
        }
        
        switch band.value {
        case 0..<15: return .orange // Too low
        case 15..<55: return band.color // Good range
        case 55..<75: return band.color.opacity(0.9) // Slightly high
        default: return .purple // Too high
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            
            // Main frequency bar with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            barColor,
                            barColor.opacity(0.3)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: width, height: barHeight)
                .cornerRadius(2)
                .overlay(
                    // Peak indicator line
                    Rectangle()
                        .fill(barColor)
                        .frame(width: width, height: 2)
                        .cornerRadius(1)
                        .offset(y: -barHeight/2 + 1),
                    alignment: .top
                )
                .animation(.easeOut(duration: 0.6), value: band.value)
            
            // Band label
            Text(band.label.prefix(3))
                .font(.caption2)
                .foregroundStyle(barColor)
                .frame(width: width)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Frequency Band Detail

struct FrequencyBandDetail: View {
    let band: FrequencyBand
    
    private var statusColor: Color {
        if !band.isCritical {
            return band.color.opacity(0.7)
        }
        
        switch band.value {
        case 0..<15: return .orange
        case 15..<55: return band.color
        case 55..<75: return band.color.opacity(0.8)
        default: return .purple.opacity(0.8)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(band.color)
                .frame(width: 8, height: 8)
            
            // Band info
            VStack(alignment: .leading, spacing: 1) {
                Text(band.label)
                    .font(.caption.weight(.medium))
                
                Text(band.range)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Value with status
            HStack(spacing: 4) {
                Text(String(format: "%.1f%%", band.value))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                
                // Status indicator
                Image(systemName: statusIcon)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var statusIcon: String {
        guard band.isCritical else { return "checkmark.circle.fill" }
        
        switch band.value {
        case 0..<15: return "arrow.down.circle.fill"
        case 15..<55: return "checkmark.circle.fill"
        case 55..<75: return "exclamationmark.triangle.fill"
        default: return "xmark.circle.fill"
        }
    }
}

// MARK: - Analysis Insights

struct PAZAnalysisInsights: View {
    let bands: [FrequencyBand]
    
    private var insights: [String] {
        var messages: [String] = []
        
        // Check for common frequency issues
        for band in bands where band.isCritical {
            if band.value < 15 {
                messages.append("• \(band.label) (\(band.range)) is lacking - consider boosting")
            } else if band.value > 65 {
                messages.append("• \(band.label) (\(band.range)) is excessive - consider reducing")
            }
        }
        
        // Check for balance issues
        let bassTotal = bands.prefix(2).reduce(0) { $0 + $1.value }
        let midTotal = bands.dropFirst(2).dropLast(2).reduce(0) { $0 + $1.value }
        let highTotal = bands.suffix(2).reduce(0) { $0 + $1.value }
        
        if bassTotal > midTotal + highTotal {
            messages.append("• Mix is bass-heavy - consider high-pass filtering or reducing low end")
        } else if highTotal > bassTotal + midTotal {
            messages.append("• Mix is bright - consider de-essing or taming high frequencies")
        } else if midTotal < bassTotal * 0.6 {
            messages.append("• Midrange lacks presence - vocals and leads may be buried")
        }
        
        return Array(messages.prefix(3)) // Limit to top 3 insights
    }
    
    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    
                    Text("Analysis Insights")
                        .font(.subheadline.weight(.semibold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(insights, id: \.self) { insight in
                        Text(insight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.05))
                    .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Data Models

struct FrequencyBand {
    let label: String
    let range: String
    let value: Double
    let color: Color
    let isCritical: Bool // Whether this band is critical for mix balance
}
