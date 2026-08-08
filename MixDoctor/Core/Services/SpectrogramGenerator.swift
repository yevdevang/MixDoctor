//
//  SpectrogramGenerator.swift
//  MixDoctor
//
//  Renders a true time x frequency spectrogram image from raw PCM samples,
//  for both on-screen display and upload to Claude's vision API.
//

import Foundation
import Accelerate
import CoreGraphics
import UIKit

enum SpectrogramGenerator {

    /// Pixel dimensions used both for on-screen display and for the image sent to Claude.
    /// 1024px keeps the PNG well under Anthropic's recommended image size while still
    /// showing fine time/frequency detail.
    static let imageWidth = 1024
    static let imageHeight = 512

    /// FFT window applied at each time step. 2048 gives ~46ms resolution at 44.1kHz,
    /// a reasonable trade-off between frequency and time resolution for a mix overview.
    private static let fftSize = 2048
    static let minFrequency: Double = 20

    /// How far below the loudest bin colors still render. Internal (not private) so the
    /// Results UI can draw a matching dB legend alongside the image.
    static let dynamicRangeDb: Float = 80

    /// Bundles the rendered heatmap with the time-averaged per-bin magnitude spectrum
    /// computed from the exact same STFT columns, so the frequency-band breakdown and
    /// curve shown in the Results UI always match what the heatmap displays.
    struct Result {
        let image: UIImage
        /// Linear magnitude, averaged across all time columns, one value per FFT bin
        /// (index 0...fftSize/2 - 1, linearly spaced from 0Hz to Nyquist).
        let averageSpectrum: [Float]
    }

    /// Generates a PNG-encoded spectrogram image from a single (mono/left) channel of audio.
    nonisolated static func generatePNG(samples data: UnsafePointer<Float>, frameCount: Int, sampleRate: Double) -> Data? {
        generate(samples: data, frameCount: frameCount, sampleRate: sampleRate)?.image.pngData()
    }

    nonisolated static func generateImage(samples data: UnsafePointer<Float>, frameCount: Int, sampleRate: Double) -> UIImage? {
        generate(samples: data, frameCount: frameCount, sampleRate: sampleRate)?.image
    }

    /// Computes the STFT once and returns both the rendered spectrogram image and the
    /// time-averaged per-bin spectrum derived from it.
    nonisolated static func generate(samples data: UnsafePointer<Float>, frameCount: Int, sampleRate: Double) -> Result? {
        guard frameCount >= fftSize else {
            print("⚠️ SpectrogramGenerator: not enough samples (\(frameCount)) for fftSize \(fftSize)")
            return nil
        }

        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            print("⚠️ SpectrogramGenerator: vDSP_create_fftsetup failed")
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let halfSize = fftSize / 2
        let lastValidStart = frameCount - fftSize
        // Spread `imageWidth` analysis windows evenly across the whole file so a
        // 3-minute track and a 3-hour file both render at the same image size.
        let step = imageWidth > 1 ? Double(lastValidStart) / Double(imageWidth - 1) : 0

        // magnitudesDb[column][bin], collected first so we can normalize against
        // the loudest bin in the whole track before mapping to color.
        var magnitudesDb = [[Float]](repeating: [Float](repeating: -.infinity, count: halfSize), count: imageWidth)
        var globalMaxDb: Float = -.infinity

        for column in 0..<imageWidth {
            let start = min(Int(Double(column) * step), lastValidStart)

            var windowed = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                windowed[i] = data[start + i] * window[i]
            }

            var realp = [Float](repeating: 0, count: halfSize)
            var imagp = [Float](repeating: 0, count: halfSize)
            var columnDb = [Float](repeating: -.infinity, count: halfSize)

            windowed.withUnsafeBufferPointer { windowedPtr in
                windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                    realp.withUnsafeMutableBufferPointer { realPtr in
                        imagp.withUnsafeMutableBufferPointer { imagPtr in
                            var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                            // vDSP_fft_zrip's real-FFT trick requires samples pre-packed into interleaved
                            // even/odd pairs via vDSP_ctoz first — without this, it silently transforms
                            // only the first half of the window (real part only) instead of the real signal,
                            // producing a fabricated noise floor that rises sharply near Nyquist.
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                            for bin in 0..<halfSize {
                                let real = realPtr[bin]
                                // imagp[0] packs the Nyquist bin's value, not bin 0's imaginary part — bin 0 (DC) has none.
                                let imag = bin == 0 ? 0 : imagPtr[bin]
                                let magnitude = sqrt(real * real + imag * imag) / Float(fftSize) * 2
                                let db = 20 * log10(max(magnitude, 1e-9))
                                columnDb[bin] = db
                                if db > globalMaxDb { globalMaxDb = db }
                            }
                        }
                    }
                }
            }
            magnitudesDb[column] = columnDb
        }

        guard globalMaxDb.isFinite else {
            print("⚠️ SpectrogramGenerator: no finite magnitudes produced")
            return nil
        }

        // Average spectrum: mean linear magnitude per bin across every time column —
        // the exact same numbers that were color-mapped into the heatmap above, just
        // collapsed along the time axis instead of the frequency axis.
        var averageSpectrum = [Float](repeating: 0, count: halfSize)
        for bin in 0..<halfSize {
            var sum: Float = 0
            for column in 0..<imageWidth {
                let db = magnitudesDb[column][bin]
                sum += db.isFinite ? pow(10, db / 20) : 0
            }
            averageSpectrum[bin] = sum / Float(imageWidth)
        }

        let minDb = globalMaxDb - dynamicRangeDb
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(halfSize)
        let logMin = log10(minFrequency)
        let logMax = log10(nyquist)

        var pixels = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)

        for row in 0..<imageHeight {
            // row 0 = top of image = highest frequency, matching how engineers read a spectrogram
            let t = 1.0 - Double(row) / Double(imageHeight - 1)
            let frequency = pow(10, logMin + t * (logMax - logMin))
            let bin = min(halfSize - 1, max(0, Int(frequency / binWidth)))

            for column in 0..<imageWidth {
                let db = magnitudesDb[column][bin]
                let normalized = max(0, min(1, (db - minDb) / (globalMaxDb - minDb)))
                let color = SpectrogramColorMap.color(for: normalized)

                let offset = (row * imageWidth + column) * 4
                pixels[offset] = color.r
                pixels[offset + 1] = color.g
                pixels[offset + 2] = color.b
                pixels[offset + 3] = 255
            }
        }

        guard let image = pixels.withUnsafeMutableBytes({ rawPtr -> UIImage? in
            guard let context = CGContext(
                data: rawPtr.baseAddress,
                width: imageWidth,
                height: imageHeight,
                bitsPerComponent: 8,
                bytesPerRow: imageWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cgImage = context.makeImage() else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }) else {
            return nil
        }

        return Result(image: image, averageSpectrum: averageSpectrum)
    }
}

/// Dark-to-bright false-color map (black -> blue -> magenta -> orange -> yellow),
/// the convention audio engineers expect from spectrogram tools: quiet is dark, loud is hot.
/// Not private: the Results UI reuses `color(for:)` to draw a dB legend that matches the image exactly.
enum SpectrogramColorMap {
    private static let stops: [(position: Float, r: UInt8, g: UInt8, b: UInt8)] = [
        (0.00, 5, 5, 20),
        (0.25, 30, 20, 110),
        (0.50, 130, 30, 130),
        (0.75, 230, 90, 40),
        (1.00, 255, 240, 90)
    ]

    static func color(for value: Float) -> (r: UInt8, g: UInt8, b: UInt8) {
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) {
            if value >= stops[i].position && value <= stops[i + 1].position {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        let range = upper.position - lower.position
        let t = range > 0 ? (value - lower.position) / range : 0
        func lerp(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(Float(a) + (Float(b) - Float(a)) * t)
        }
        return (lerp(lower.r, upper.r), lerp(lower.g, upper.g), lerp(lower.b, upper.b))
    }
}
