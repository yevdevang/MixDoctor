//
//  TestSpectrumGenerator.swift
//  MixDoctor
//
//  Generates test audio signals that produce jagged spectrum with clear peaks
//

import Foundation
import Accelerate

class TestSpectrumGenerator {
    
    /// Generate a multi-tone test signal that will show clear peaks in FFT
    /// This creates a signal with multiple harmonics that will produce a jagged spectrum
    static func generateMultiToneSignal(duration: Double = 1.0, sampleRate: Double = 44100.0) -> [Float] {
        let numSamples = Int(duration * sampleRate)
        var signal = [Float](repeating: 0, count: numSamples)
        
        // Define fundamental frequencies and harmonics (in Hz)
        // This simulates a musical chord with overtones
        let frequencies: [Double] = [
            100,    // Fundamental (bass)
            200,    // 2nd harmonic
            300,    // 3rd harmonic
            500,    // Presence
            800,    // Mid
            1200,   // High-mid
            2400,   // Presence
            4800,   // Brilliance
            9600    // Air
        ]
        
        // Amplitudes for each frequency (decreasing with higher frequencies)
        let amplitudes: [Float] = [1.0, 0.7, 0.5, 0.6, 0.4, 0.3, 0.25, 0.15, 0.08]
        
        // Generate the signal by adding all sine waves
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            
            var sample: Float = 0.0
            for (freq, amp) in zip(frequencies, amplitudes) {
                sample += amp * sin(2.0 * .pi * freq * t)
            }
            
            // Normalize to prevent clipping
            signal[i] = sample / Float(frequencies.count)
        }
        
        return signal
    }
    
    /// Perform FFT on the test signal and return frequency spectrum
    static func analyzeTestSignal() -> (frequencies: [Double], magnitudes: [Float]) {
        let signal = generateMultiToneSignal()
        let sampleRate = 44100.0
        
        // Use 4096-sample FFT window
        let fftSize = 4096
        let windowSamples = Array(signal.prefix(fftSize))
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Apply Hann window
        var windowedSamples = windowSamples
        vDSP_hann_window(&windowedSamples, vDSP_Length(fftSize), 0)
        
        var realParts = windowedSamples
        var imagParts = Array(repeating: Float(0.0), count: fftSize)
        
        var magnitudes = Array(repeating: Float(0.0), count: fftSize / 2)
        
        realParts.withUnsafeMutableBufferPointer { realPtr in
            imagParts.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                let nyquist = fftSize / 2
                for i in 0..<nyquist {
                    let real = realPtr[i]
                    let imag = imagPtr[i]
                    let magnitude = sqrt(real * real + imag * imag)
                    magnitudes[i] = magnitude / Float(fftSize)
                }
            }
        }
        
        // Calculate frequencies for each bin
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(magnitudes.count)
        let frequencies = (0..<magnitudes.count).map { Double($0) * binWidth }
        
        // Print results
        print("\n🎵 TEST SIGNAL FFT ANALYSIS:")
        print("Expected peaks at: 100Hz, 200Hz, 300Hz, 500Hz, 800Hz, 1200Hz, 2400Hz, 4800Hz, 9600Hz")
        print("\nFFT Results (showing bins with magnitude > 0.01):")
        
        for (i, mag) in magnitudes.enumerated() where mag > 0.01 {
            let freq = frequencies[i]
            let dB = 20.0 * log10(max(Double(mag), 1e-12))
            print(sprintf("  Bin %3d: %7.1f Hz = %.4f = %6.1f dB", i, freq, mag, dB))
        }
        
        return (frequencies, magnitudes)
    }
}

// Helper function for formatted printing
fileprivate func sprintf(_ format: String, _ args: CVarArg...) -> String {
    return String(format: format, arguments: args)
}
