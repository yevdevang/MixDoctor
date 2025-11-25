//
//  AudioProcessor.swift
//  MixDoctor
//
//  Created on Phase 3: CoreML Audio Analysis Engine
//

import AVFoundation
import Accelerate

public final class AudioProcessor {
    
    struct ProcessedAudio {
        let leftChannel: [Float]
        let rightChannel: [Float]
        let sampleRate: Double
        let frameCount: Int
    }
    
    // MARK: - Audio Loading
    
    func loadAudio(from url: URL) throws -> ProcessedAudio {
        print("🎵 AudioProcessor loading file from: \(url)")
        print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        guard format.channelCount >= 1 else {
            throw AudioProcessingError.invalidChannelCount
        }
        
        let frameCount = Int(audioFile.length)
        print("   Frame count: \(frameCount), Sample rate: \(format.sampleRate)")
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Convert to float arrays
        let leftChannel = extractChannel(buffer: buffer, channel: 0)
        let rightChannel = format.channelCount > 1 ? extractChannel(buffer: buffer, channel: 1) : leftChannel
        
        // Log some sample values for debugging
        let leftAvg = leftChannel.prefix(1000).reduce(0, +) / Float(min(1000, leftChannel.count))
        let rightAvg = rightChannel.prefix(1000).reduce(0, +) / Float(min(1000, rightChannel.count))
        print("   Left channel avg (first 1000): \(leftAvg)")
        print("   Right channel avg (first 1000): \(rightAvg)")
        
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
        _ = channelArray.withUnsafeMutableBufferPointer { ptr in
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
