//
//  PAZFrequencyAnalyzer.swift
//  MixDoctor
//
//  PAZ Analyzer-style frequency analyzer component
//

import SwiftUI

struct PAZFrequencyAnalyzer: View {
    let result: AnalysisResult
    
    // PAZ-style frequency bands with proper Hz ranges
    private var frequencyBands: [FrequencyBand] {
        [
            FrequencyBand(
                label: "Sub Bass",
                range: "20-60 Hz",
                value: result.lowEndBalance * 0.3, // Estimate sub-bass as portion of low end
                color: Color(red: 0.8, green: 0.2, blue: 0.2),
                isCritical: false
            ),
            FrequencyBand(
                label: "Bass",
                range: "60-250 Hz",
                value: result.lowEndBalance * 0.7, // Main bass portion
                color: Color(red: 1.0, green: 0.3, blue: 0.3),
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

            Divider()
                .padding(.vertical, 4)

            // Chart-style spectrum analyzer
            VStack(spacing: 12) {
                // Chart visualization
                FrequencyChart(bands: frequencyBands)
                
                // Frequency band details below chart
                VStack(spacing: 6) {
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
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
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

// MARK: - Frequency Chart Component

struct FrequencyChart: View {
    let bands: [FrequencyBand]
    
    var body: some View {
        VStack(spacing: 12) {
            // Chart area with spectrum analyzer
            GeometryReader { geometry in
                ZStack {
                    // Dark background like professional analyzers
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                    
                    // Grid
                    SpectrumGrid()
                    
                    // Frequency response curve
                    SpectrumCurve(bands: bands, size: geometry.size)
                    
                    // Frequency labels inside the chart at the bottom
                    VStack {
                        Spacer()
                        
                        HStack {
                            Text("20")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("30")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("50")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("100")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("200")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("500")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("1k")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("2k")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("5k")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("10k")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("20k")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: 250)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}


// MARK: - Spectrum Grid

struct SpectrumGrid: View {
    var body: some View {
        ZStack {
            // Professional spectrum analyzer grid like the image
            // Horizontal grid lines (dB levels) - more like the reference
            VStack(spacing: 0) {
                ForEach(0..<13) { index in // More grid lines like in image
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 0.5)
                    
                    if index < 12 {
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
            
            // Major grid lines for key frequencies
            GeometryReader { geometry in
                let width = geometry.size.width
                let majorFreqs: [Double] = [100, 1000, 10000] // Major frequency markers
                
                ForEach(majorFreqs.indices, id: \.self) { index in
                    let freq = majorFreqs[index]
                    let logFreq = log10(freq)
                    let logMin = log10(20.0)
                    let logMax = log10(20000.0)
                    let normalizedX = (logFreq - logMin) / (logMax - logMin)
                    let x = normalizedX * width
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: 1)
                        .offset(x: x - width/2)
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
    
    private func createPath() -> Path {
        var path = Path()
        let width = size.width - 40 // Padding
        let height = size.height - 40
        let baselineY = height * 0.7 // Position baseline like in the image
        
        // Create detailed frequency points for realistic spectrum analyzer look
        // Generate many frequency points with random variations like real spectrum data
        var frequencyPoints: [Double] = []
        
        let minFreq = 20.0
        let maxFreq = 20000.0
        let numPoints = 200 // High resolution for detailed spectrum
        
        for i in 0..<numPoints {
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)
            let logStep = (logMax - logMin) / Double(numPoints - 1)
            let logFreq = logMin + Double(i) * logStep
            let frequency = pow(10, logFreq)
            frequencyPoints.append(frequency)
        }
        
        var points: [CGPoint] = []
        
        for (_, frequency) in frequencyPoints.enumerated() {
            // Calculate x position using logarithmic scale
            let logFreq = log10(frequency)
            let logMin = log10(20.0)
            let logMax = log10(20000.0)
            let normalizedX = (logFreq - logMin) / (logMax - logMin)
            let x = 20 + normalizedX * width
            
            // Calculate y position with realistic spectrum analyzer variations
            let baseEnergy = getEnergyForFrequency(frequency)
            
            // Add realistic spectrum analyzer noise and variations
            let randomVariation = Double.random(in: -8...12) // Random spectrum variations
            let harmonicContent = getHarmonicContent(frequency) // Harmonic peaks
            let noiseFloor = getNoiseFloor(frequency) // Noise floor characteristics
            
            let totalEnergy = baseEnergy + randomVariation + harmonicContent + noiseFloor
            let clampedEnergy = max(0, min(100, totalEnergy))
            
            // Convert to Y position (inverted, 0 dB at top)
            let normalizedY = clampedEnergy / 100.0
            let y = baselineY - (normalizedY * height * 0.6) // Scale to visible range
            
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create jagged, realistic spectrum analyzer path
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        // Connect points with straight lines for jagged spectrum appearance
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        return path
    }
    
    private func getHarmonicContent(_ frequency: Double) -> Double {
        // Simulate harmonic peaks at musical intervals
        let fundamentalFreqs: [Double] = [110, 220, 440, 880, 1760, 3520] // Musical harmonics
        
        for fundamental in fundamentalFreqs {
            let harmonicDistance = abs(frequency - fundamental) / fundamental
            if harmonicDistance < 0.1 { // Within 10% of harmonic
                return Double.random(in: 5...15) // Harmonic peak
            }
        }
        return 0
    }
    
    private func getNoiseFloor(_ frequency: Double) -> Double {
        // Simulate realistic noise floor characteristics
        if frequency < 100 {
            return Double.random(in: (-15)...(-5)) // Low frequency noise
        } else if frequency > 15000 {
            return Double.random(in: (-20)...(-8)) // High frequency noise
        } else {
            return Double.random(in: (-12)...(-3)) // Mid frequency noise
        }
    }
    
    private func getEnergyForFrequency(_ frequency: Double) -> Double {
        // Enhanced frequency mapping with smooth interpolation between bands
        // This creates wave-like transitions between frequency bands
        
        // Define band boundaries and their corresponding energy values
        let bandData: [(range: ClosedRange<Double>, energy: Double, label: String)] = [
            (20...60, bands.first(where: { $0.label == "Sub Bass" })?.value ?? 0, "Sub Bass"),
            (60...250, bands.first(where: { $0.label == "Bass" })?.value ?? 0, "Bass"),
            (250...500, bands.first(where: { $0.label == "Low Mid" })?.value ?? 0, "Low Mid"),
            (500...2000, bands.first(where: { $0.label == "Mid" })?.value ?? 0, "Mid"),
            (2000...6000, bands.first(where: { $0.label == "High Mid" })?.value ?? 0, "High Mid"),
            (6000...12000, bands.first(where: { $0.label == "Presence" })?.value ?? 0, "Presence"),
            (12000...20000, bands.first(where: { $0.label == "Air" })?.value ?? 0, "Air")
        ]
        
        // Find the appropriate band and create smooth interpolation
        for i in 0..<bandData.count {
            let band = bandData[i]
            if band.range.contains(frequency) {
                // Add smooth transitions at band boundaries
                var energy = band.energy
                
                // Smooth transition to next band
                if i < bandData.count - 1 {
                    let nextBand = bandData[i + 1]
                    let bandWidth = band.range.upperBound - band.range.lowerBound
                    let positionInBand = frequency - band.range.lowerBound
                    let transitionZone = bandWidth * 0.3 // 30% of band for transition
                    
                    if positionInBand > bandWidth - transitionZone {
                        // We're in transition zone to next band
                        let transitionRatio = (positionInBand - (bandWidth - transitionZone)) / transitionZone
                        energy = band.energy + (nextBand.energy - band.energy) * transitionRatio * 0.5
                    }
                }
                
                // Add natural frequency response curve characteristics
                let naturalCurve = getNaturalFrequencyResponse(frequency)
                return energy + naturalCurve
            }
        }
        
        return 0 // Fallback
    }
    
    private func getNaturalFrequencyResponse(_ frequency: Double) -> Double {
        // Simulate natural frequency response characteristics for wave-like appearance
        let logFreq = log10(frequency)
        let logMid = log10(1000.0) // 1kHz reference
        
        // Create gentle frequency response curve
        let distance = abs(logFreq - logMid)
        let curve = cos(distance * .pi / 2) * 5.0 // Gentle curve ±5%
        
        return curve
    }
    
    var body: some View {
        ZStack {
            // Main spectrum waveform - jagged like real analyzer
            createPath()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.pink.opacity(0.9),
                            Color.red.opacity(0.8),
                            Color.orange.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineJoin: .miter)
                )
                .animation(.easeInOut(duration: 0.3), value: bands.map { $0.value })
            
            // Secondary spectrum line for depth (like dual channel)
            createPath()
                .stroke(
                    Color.cyan.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.0, lineJoin: .miter)
                )
                .offset(y: Double.random(in: -2...2)) // Slight offset for realism
                .animation(.easeInOut(duration: 0.25), value: bands.map { $0.value })
            
            // No fill area - keep it clean like real spectrum analyzer
        }
    }
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
        default: return .red // Too high
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
        default: return .red.opacity(0.8)
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
