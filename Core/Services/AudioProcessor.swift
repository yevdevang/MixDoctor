//
//  AudioProcessor.swift
//  MixDoctor
//
//  Created on Phase 3: CoreML Audio Analysis Engine
//

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
