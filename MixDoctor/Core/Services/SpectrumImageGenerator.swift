//
//  SpectrumImageGenerator.swift
//  MixDoctor
//
//  Service to generate professional spectrum analyzer visualizations using SwiftUI Canvas
//

import Foundation
import SwiftUI

class SpectrumImageGenerator {
    
    /// Generate a professional spectrum analyzer view from FFT data
    static func createSpectrumView(fftData: [Float], sampleRate: Double) -> some View {
        
        // Prepare data
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(fftData.count)
        
        var dataPoints: [(frequency: Double, magnitude: Double)] = []
        
        // Convert FFT to frequency/magnitude pairs (20Hz - 20kHz, in dB)
        for (index, mag) in fftData.enumerated() {
            let frequency = Double(index) * binWidth
            guard frequency >= 20 && frequency <= 20000 else { continue }
            
            let dB = 20.0 * log10(max(Double(mag), 1e-12))
            let clampedDB = max(dB, -100.0)
            
            dataPoints.append((frequency: frequency, magnitude: clampedDB))
        }
        
        return SpectrumCanvasView(dataPoints: dataPoints)
    }
}

// Canvas view to draw professional spectrum analyzer
struct SpectrumCanvasView: View {
    let dataPoints: [(frequency: Double, magnitude: Double)]
    
    var body: some View {
        Canvas { context, size in
            // Black background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black)
            )
            
            let leftPadding: CGFloat = 10  // Minimal left padding to shift wave further left
            let rightPadding: CGFloat = 60  // More space on right for dB labels
            let padding: CGFloat = 40  // Top/bottom padding
            let graphWidth = size.width - leftPadding - rightPadding
            let graphHeight = size.height - padding * 2
            
            // Draw grid
            drawGrid(context: &context, size: size, leftPadding: leftPadding, rightPadding: rightPadding, padding: padding, graphWidth: graphWidth, graphHeight: graphHeight)
            
            // Draw spectrum curve - shows ALL frequency bins with peaks and valleys
            drawSpectrum(context: &context, size: size, leftPadding: leftPadding, padding: padding, graphWidth: graphWidth, graphHeight: graphHeight)
            
            // Draw labels
            drawLabels(context: &context, size: size, leftPadding: leftPadding, rightPadding: rightPadding, padding: padding, graphWidth: graphWidth, graphHeight: graphHeight)
        }
        .background(Color.black)
    }
    
    private func drawGrid(context: inout GraphicsContext, size: CGSize, leftPadding: CGFloat, rightPadding: CGFloat, padding: CGFloat, graphWidth: CGFloat, graphHeight: CGFloat) {
        var path = Path()
        
        // Horizontal grid lines (dB levels: 0, -20, -40, -60, -80, -100)
        for i in 0...5 {
            let y = padding + (graphHeight / 5.0) * CGFloat(i)
            path.move(to: CGPoint(x: leftPadding, y: y))
            path.addLine(to: CGPoint(x: size.width - rightPadding, y: y))
        }
        
        // Vertical grid lines (frequency markers)
        let freqMarkers: [Double] = [20, 49, 100, 200, 499, 1000, 2000, 4000, 10000, 20000]
        for freq in freqMarkers {
            let x = leftPadding + xPosition(for: freq, width: graphWidth)
            path.move(to: CGPoint(x: x, y: padding))
            path.addLine(to: CGPoint(x: x, y: size.height - padding))
        }
        
        context.stroke(path, with: .color(.blue.opacity(0.2)), lineWidth: 0.5)
    }
    
    private func drawSpectrum(context: inout GraphicsContext, size: CGSize, leftPadding: CGFloat, padding: CGFloat, graphWidth: CGFloat, graphHeight: CGFloat) {
        guard !dataPoints.isEmpty, let firstPoint = dataPoints.first else { return }
        
        var path = Path()
        
        // Start path
        let startX = leftPadding + xPosition(for: firstPoint.frequency, width: graphWidth)
        let startY = padding + yPosition(for: firstPoint.magnitude, height: graphHeight)
        
        path.move(to: CGPoint(x: startX, y: startY))
        
        // Draw line through ALL points - this will show natural peaks and valleys!
        for point in dataPoints.dropFirst() {
            let x = leftPadding + xPosition(for: point.frequency, width: graphWidth)
            let y = padding + yPosition(for: point.magnitude, height: graphHeight)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Stroke the spectrum line with blue color
        context.stroke(path, with: .color(.blue), lineWidth: 1.5)
    }
    
    private func drawLabels(context: inout GraphicsContext, size: CGSize, leftPadding: CGFloat, rightPadding: CGFloat, padding: CGFloat, graphWidth: CGFloat, graphHeight: CGFloat) {
        // Frequency labels (X-axis)
        let freqLabels: [(freq: Double, label: String)] = [
            (20, "20"), (49, "49"), (100, "100"), (200, "200"),
            (499, "499"), (1000, "1k"), (2000, "2k"), (4000, "4k"), (10000, "10k")
        ]
        
        for item in freqLabels {
            let x = leftPadding + xPosition(for: item.freq, width: graphWidth)
            let text = Text(item.label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
            
            context.draw(text, at: CGPoint(x: x, y: size.height - padding + 15))
        }
        
        // dB labels (Y-axis)
        let dbLabels = [0, -20, -40, -60, -80, -100]
        for (i, db) in dbLabels.enumerated() {
            let y = padding + (graphHeight / 5.0) * CGFloat(i)
            let text = Text("\(db)")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
            
            context.draw(text, at: CGPoint(x: size.width - rightPadding + 25, y: y))
        }
    }
    
    // Logarithmic X position for frequency (professional analyzer style)
    private func xPosition(for frequency: Double, width: CGFloat) -> CGFloat {
        let minFreq = 15.0  // Start from 15Hz instead of 20Hz to shift wave left
        let maxFreq = 20000.0
        
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = log10(max(frequency, minFreq))
        
        let normalizedPosition = (logFreq - logMin) / (logMax - logMin)
        return CGFloat(normalizedPosition) * width
    }
    
    // Linear Y position for dB (-100 to 0)
    private func yPosition(for dB: Double, height: CGFloat) -> CGFloat {
        let minDB = -100.0
        let maxDB = 0.0
        
        let normalizedPosition = (dB - minDB) / (maxDB - minDB)
        return height - (CGFloat(normalizedPosition) * height) // Flip Y-axis (0 dB at top)
    }
}
