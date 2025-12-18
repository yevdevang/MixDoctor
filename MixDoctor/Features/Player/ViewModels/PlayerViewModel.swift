//
//  PlayerViewModel.swift
//  MixDoctor
//
//  View model for audio playback with channel controls using AVAudioEngine
//

import Foundation
import AVFoundation
import Observation

@Observable
final class PlayerViewModel {
    let audioFile: AudioFile
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFile_av: AVAudioFile?
    private var timer: Timer?
    private var playbackStartTime: Date?
    private var pausedTime: TimeInterval = 0
    private var isRescheduling = false // Flag to prevent completion handler from running during manual reschedule
    
    // Playback state
    var isPlaying = false
    var isUserSeeking = false // Flag to prevent progress updates while user is dragging slider
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var loadError: String?
    var playbackRate: Double = 1.0 {
        didSet {
            applyPlaybackRate()
        }
    }
    var isLooping = false
    
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
        case mono
        case left
        case right
        case mid
        case side
    }
    
    init(audioFile: AudioFile) {
        self.audioFile = audioFile
        setupAudioEngine()
        generateWaveform()
    }
    
    deinit {
        timer?.invalidate()
        audioEngine?.stop()
        audioPlayerNode?.stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        
        do {
            // Check if file exists
            let fileManager = FileManager.default
            let fileExists = fileManager.fileExists(atPath: audioFile.fileURL.path)
            
            guard fileExists else {
                let errorMsg = "Audio file does not exist at path: \(audioFile.fileURL.path)"
                loadError = errorMsg
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
            
            // Load audio file
            audioFile_av = try AVAudioFile(forReading: audioFile.fileURL)
            guard let audioFile = audioFile_av else {
                loadError = "Failed to load audio file"
                return
            }
            
            // Get duration
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = audioFile.length
            duration = Double(frameCount) / sampleRate
            
            // Setup audio engine
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let playerNode = audioPlayerNode else {
                loadError = "Failed to create audio engine"
                return
            }
            
            // Attach player node
            engine.attach(playerNode)
            
            // Connect and apply initial channel mode
            applyChannelMode()
            
            // Prepare engine
            engine.prepare()
            
            loadError = nil
        } catch let error as NSError {
            let errorMsg = "Failed to load audio: \(error.localizedDescription)"
            loadError = errorMsg
            
        }
    }
    
    private func generateWaveform() {
        // Generate sample waveform data for visualization
        // In a real implementation, this would extract actual audio samples
        #if targetEnvironment(macCatalyst)
        // More segments on Mac for better detail
        waveformSamples = (0..<200).map { _ in Float.random(in: -1...1) }
        #else
        waveformSamples = (0..<100).map { _ in Float.random(in: -1...1) }
        #endif
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
        guard let engine = audioEngine, 
              let playerNode = audioPlayerNode,
              let audioFile = audioFile_av else {
            return
        }
        
        do {
            // Start engine if not running
            if !engine.isRunning {
                try engine.start()
            }
            
            // Save pausedTime before stopping (as stop might trigger completion handler)
            let resumeTime = pausedTime
            
            // Set flag to prevent completion handler from running during reschedule
            isRescheduling = true
            
            // Always stop and reschedule when resuming
            playerNode.stop()
            
            // Restore current time
            currentTime = resumeTime
            
            // Calculate start frame based on resume time
            let startFrame = AVAudioFramePosition(resumeTime * audioFile.processingFormat.sampleRate)
            let totalFrames = audioFile.length
            let remainingFrames = totalFrames - startFrame
            
            
            if remainingFrames > 0 {
                // Use scheduleFile for better handling of large audio files
                // This avoids UInt32 overflow issues with frameCount
                if startFrame == 0 {
                    // Playing from beginning - use scheduleFile
                    playerNode.scheduleFile(
                        audioFile,
                        at: nil
                    ) { [weak self] in
                        // Completion handler - handle looping or natural end
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            // Only handle completion if NOT rescheduling and actually playing
                            if !self.isRescheduling && self.isPlaying {
                                if self.isLooping {
                                    self.currentTime = 0
                                    self.pausedTime = 0
                                    self.play()
                                } else {
                                    self.stop()
                                }
                            }
                            // Reset rescheduling flag
                            self.isRescheduling = false
                        }
                    }
                } else {
                    // Playing from middle - use scheduleSegment
                    // Safe cast: if remainingFrames is too large, play what we can
                    let safeFrameCount = min(remainingFrames, AVAudioFramePosition(UInt32.max))
                    let frameCount = AVAudioFrameCount(safeFrameCount)
                    
                    playerNode.scheduleSegment(
                        audioFile,
                        startingFrame: startFrame,
                        frameCount: frameCount,
                        at: nil
                    ) { [weak self] in
                        // Completion handler - handle looping or natural end
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            // Only handle completion if NOT rescheduling and actually playing
                            if !self.isRescheduling && self.isPlaying {
                                if self.isLooping {
                                    self.currentTime = 0
                                    self.pausedTime = 0
                                    self.play()
                                } else {
                                    self.stop()
                                }
                            }
                            // Reset rescheduling flag
                            self.isRescheduling = false
                        }
                    }
                }
                
                playerNode.play()
                playbackStartTime = Date()
                isPlaying = true
                
                // Clear rescheduling flag after a brief delay to ensure it's set when completion might fire
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isRescheduling = false
                }
                
                startTimer()
            } else {
                isRescheduling = false
            }
        } catch {
            isRescheduling = false
            loadError = "Failed to start playback: \(error.localizedDescription)"
        }
    }
    
    func pause() {
        guard let playerNode = audioPlayerNode else { return }
        
        playerNode.pause()
        isPlaying = false
        pausedTime = currentTime
        playbackStartTime = nil
        stopTimer()
        
    }
    
    func stop() {
        audioPlayerNode?.stop()
        isPlaying = false
        currentTime = 0
        pausedTime = 0
        progress = 0
        playbackStartTime = nil
        stopTimer()
    }
    
    func seek(to progress: Double) {
        guard let playerNode = audioPlayerNode,
              let audioFile = audioFile_av else { return }
        
        let wasPlaying = isPlaying
        
        // Update time
        let time = duration * progress
        currentTime = time
        pausedTime = time
        self.progress = progress
        
        // If playing, reschedule from new position
        if wasPlaying {
            playerNode.stop()
            
            // Calculate start frame based on new time
            let startFrame = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
            let totalFrames = audioFile.length
            let remainingFrames = totalFrames - startFrame
            
            if remainingFrames > 0 {
                // Safe cast: if remainingFrames is too large, play what we can
                let safeFrameCount = min(remainingFrames, AVAudioFramePosition(UInt32.max))
                let frameCount = AVAudioFrameCount(safeFrameCount)
                
                // Schedule new segment
                playerNode.scheduleSegment(
                    audioFile,
                    startingFrame: startFrame,
                    frameCount: frameCount,
                    at: nil
                ) { [weak self] in
                    DispatchQueue.main.async {
                        if self?.isLooping == true {
                            self?.currentTime = 0
                            self?.pausedTime = 0
                            self?.play()
                        } else {
                            self?.stop()
                        }
                    }
                }
                
                // Continue playing from new position
                playerNode.play()
                playbackStartTime = Date()
                isPlaying = true
            }
        }
    }
    
    func skipForward() {
        let newTime = min(currentTime + 10, duration)
        let newProgress = newTime / duration
        seek(to: newProgress)
    }
    
    func skipBackward() {
        let newTime = max(currentTime - 10, 0)
        let newProgress = newTime / duration
        seek(to: newProgress)
    }
    
    func toggleLoop() {
        isLooping.toggle()
    }
    
    private func applyPlaybackRate() {
        // AVAudioPlayerNode doesn't support rate directly
        // Would need AVAudioUnitVarispeed for this
    }
    
    // MARK: - Channel Mode
    
    private func applyChannelMode() {
        guard let engine = audioEngine,
              let playerNode = audioPlayerNode,
              let audioFile = audioFile_av else { return }
        
        // Disconnect existing connections
        engine.disconnectNodeOutput(playerNode)
        
        let format = audioFile.processingFormat
        
        switch channelMode {
        case .stereo:
            // Normal stereo playback
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            
        case .mono:
            // Mix both channels to mono (L+R)/2
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            
            // Connect player to mixer
            engine.connect(playerNode, to: mixer, format: format)
            
            // Create mono format
            let monoFormat = AVAudioFormat(
                standardFormatWithSampleRate: format.sampleRate,
                channels: 1
            )
            
            // Connect mixer to output
            engine.connect(mixer, to: engine.mainMixerNode, format: monoFormat)
            
        case .left:
            // Play only left channel
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(playerNode, to: mixer, format: format)
            
            // Set input volumes: left=1.0, right=0.0
            if format.channelCount >= 2 {
                mixer.volume = 1.0
                // Extract left channel by panning full left
                mixer.pan = -1.0
            }
            
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            
        case .right:
            // Play only right channel
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(playerNode, to: mixer, format: format)
            
            // Set input volumes: left=0.0, right=1.0
            if format.channelCount >= 2 {
                mixer.volume = 1.0
                // Extract right channel by panning full right
                mixer.pan = 1.0
            }
            
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            
        case .mid:
            // Mid (sum): (L+R) - center/mono content
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            
            engine.connect(playerNode, to: mixer, format: format)
            
            // Mid is essentially mono - sum of L+R
            mixer.volume = 0.707 // Reduce volume to prevent clipping (1/sqrt(2))
            
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            
        case .side:
            // Side (difference): (L-R) - stereo width content
            // This is more complex and would require custom audio processing
            // For now, use a simplified version
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            
            engine.connect(playerNode, to: mixer, format: format)
            
            // Approximate side by reducing center content
            mixer.volume = 0.707
            
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
        }
        
        // Restart playback if currently playing
        if isPlaying {
            let currentProgress = progress
            pause()
            seek(to: currentProgress)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.play()
            }
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
        guard isPlaying, !isUserSeeking else { return }
        
        // Calculate elapsed time since playback started
        if let startTime = playbackStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            currentTime = pausedTime + elapsed
        }
        
        // Update progress
        if duration > 0 {
            progress = min(currentTime / duration, 1.0)
        }
        
        // Check if reached end
        if currentTime >= duration {
            if isLooping {
                currentTime = 0
                pausedTime = 0
                stop()
                play()
            } else {
                stop()
            }
        }
    }
}
