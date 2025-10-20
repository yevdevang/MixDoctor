//
//  PlayerViewModel.swift
//  MixDoctor
//
//  View model for audio playback with channel controls
//

import Foundation
import AVFoundation
import Observation

@Observable
final class PlayerViewModel {
    let audioFile: AudioFile
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    // Playback state
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var loadError: String?
    var playbackRate: Double = 1.0 {
        didSet {
            audioPlayer?.rate = Float(playbackRate)
        }
    }
    var isLooping = false {
        didSet {
            audioPlayer?.numberOfLoops = isLooping ? -1 : 0
        }
    }
    
    // Channel mode
    var channelMode: ChannelMode = .stereo {
        didSet {
            applyChannelMode()
        }
    }
    
    // Waveform data
    var waveformSamples: [Float] = []
    
    enum ChannelMode {
        case stereo
        case left
        case right
        case mid
        case side
    }
    
    init(audioFile: AudioFile) {
        self.audioFile = audioFile
        setupAudioPlayer()
        generateWaveform()
    }
    
    deinit {
        timer?.invalidate()
        audioPlayer?.stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioPlayer() {
        do {
            // Check if file exists
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: audioFile.fileURL.path) else {
                print("Audio file does not exist at path: \(audioFile.fileURL.path)")
                return
            }
            
            #if os(iOS)
            // Configure audio session for iOS
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            #endif
            
            // Try to access security-scoped resource if needed
            let shouldStopAccessing = audioFile.fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    audioFile.fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Create audio player
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile.fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true
            duration = audioPlayer?.duration ?? 0
            
            loadError = nil
            print("✅ Successfully loaded audio file: \(audioFile.fileName)")
            print("   Duration: \(duration) seconds")
            print("   File path: \(audioFile.fileURL.path)")
        } catch let error as NSError {
            let errorMsg = "Failed to load audio: \(error.localizedDescription)"
            loadError = errorMsg
            
            print("❌ Failed to setup audio player: \(error)")
            print("   Error code: \(error.code)")
            print("   Error domain: \(error.domain)")
            print("   File URL: \(audioFile.fileURL)")
            print("   File path: \(audioFile.fileURL.path)")
            
            // Try to get more details about the error
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying error: \(underlyingError)")
            }
        }
    }
    
    private func generateWaveform() {
        // Generate sample waveform data for visualization
        // In a real implementation, this would extract actual audio samples
        waveformSamples = (0..<100).map { _ in Float.random(in: -1...1) }
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        progress = 0
        stopTimer()
    }
    
    func seek(to progress: Double) {
        let time = duration * progress
        audioPlayer?.currentTime = time
        currentTime = time
        self.progress = progress
    }
    
    func skipForward() {
        let newTime = min(currentTime + 10, duration)
        audioPlayer?.currentTime = newTime
        currentTime = newTime
        progress = currentTime / duration
    }
    
    func skipBackward() {
        let newTime = max(currentTime - 10, 0)
        audioPlayer?.currentTime = newTime
        currentTime = newTime
        progress = currentTime / duration
    }
    
    func toggleLoop() {
        isLooping.toggle()
    }
    
    // MARK: - Channel Mode
    
    private func applyChannelMode() {
        // TODO: Implement actual channel processing
        // This would require AVAudioEngine for real-time processing
        // For now, this is a placeholder
        switch channelMode {
        case .stereo:
            audioPlayer?.pan = 0
        case .left:
            audioPlayer?.pan = -1
        case .right:
            audioPlayer?.pan = 1
        case .mid, .side:
            // Mid/Side processing requires more complex implementation
            audioPlayer?.pan = 0
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        progress = duration > 0 ? currentTime / duration : 0
        
        // Check if playback finished
        if !player.isPlaying && currentTime >= duration && !isLooping {
            stop()
        }
    }
}
