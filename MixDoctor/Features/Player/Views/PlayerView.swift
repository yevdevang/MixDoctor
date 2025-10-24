//
//  PlayerView.swift
//  MixDoctor
//
//  Audio player view with playback controls
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    @State private var viewModel: PlayerViewModel?
    let audioFile: AudioFile?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    playerContent(viewModel: viewModel)
                } else if audioFile != nil {
                    ProgressView("Loading player...")
                        .task {
                            if let file = audioFile {
                                let newViewModel = PlayerViewModel(audioFile: file)
                                viewModel = newViewModel
                                // Auto-play when file is loaded
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                                newViewModel.play()
                            }
                        }
                } else {
                    emptyPlayerState
                }
            }
            .navigationTitle("Player")
        }
        .onChange(of: audioFile) { oldValue, newValue in
            if let newFile = newValue {
                // Stop current playback if any
                viewModel?.stop()
                // Create new view model with selected audio file
                let newViewModel = PlayerViewModel(audioFile: newFile)
                viewModel = newViewModel
                // Auto-play the new file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    newViewModel.play()
                }
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private func playerContent(viewModel: PlayerViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        if let errorMessage = viewModel.loadError {
            // Show error state
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                
                Text("Unable to Load Audio")
                    .font(.title2.weight(.semibold))
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("File: \(viewModel.audioFile.fileName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 24) {
                // File info
                fileInfoSection(viewModel: viewModel)
                
                // Waveform visualization
                waveformSection(viewModel: viewModel)
                
                Spacer()
                
                // Playback progress
                playbackProgressSection(viewModel: viewModel)
                
                // Main controls
                playbackControlsSection(viewModel: viewModel)
                
                // Additional controls
                additionalControlsSection(viewModel: viewModel)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func fileInfoSection(viewModel: PlayerViewModel) -> some View {
        VStack(spacing: 8) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.9))
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
            
            Text(viewModel.audioFile.fileName)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 4) {
                Text("\(viewModel.audioFile.sampleRate / 1000, specifier: "%.1f") kHz")
                Text("•")
                Text("\(viewModel.audioFile.bitDepth)-bit")
                Text("•")
                Text(channelLabel(for: viewModel.audioFile.numberOfChannels))
            }
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.top)
    }
    
    private func waveformSection(viewModel: PlayerViewModel) -> some View {
        VStack(spacing: 8) {
            Text("Waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(viewModel.waveformSamples.indices, id: \.self) { index in
                        let sample = viewModel.waveformSamples[index]
                        let normalizedHeight = CGFloat(abs(sample))
                        let isPlayed = Double(index) / Double(viewModel.waveformSamples.count) <= viewModel.progress
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isPlayed ? .blue : Color.gray.opacity(0.4))
                            .frame(height: max(normalizedHeight * geometry.size.height, 2))
                    }
                }
                .frame(height: geometry.size.height)
            }
            .frame(height: 60)
        }
        .padding(.horizontal)
    }
    
    private func playbackProgressSection(viewModel: PlayerViewModel) -> some View {
        @Bindable var viewModel = viewModel
        
        return VStack(spacing: 8) {
            Slider(value: $viewModel.progress, in: 0...1) { editing in
                if !editing {
                    viewModel.seek(to: viewModel.progress)
                }
            }
            .tint(.blue)
            
            HStack {
                Text(timeString(from: viewModel.currentTime))
                    .font(.caption.monospacedDigit())
                Spacer()
                Text(timeString(from: viewModel.duration))
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.horizontal)
    }
    
    private func playbackControlsSection(viewModel: PlayerViewModel) -> some View {
        HStack(spacing: 32) {
            // Skip back
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
            }
            .foregroundStyle(.blue)
            
            // Previous (placeholder)
            Button {} label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .foregroundStyle(.secondary)
            .disabled(true)
            
            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
            }
            .foregroundStyle(.blue)
            
            // Next (placeholder)
            Button {} label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .foregroundStyle(.secondary)
            .disabled(true)
            
            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.10")
                .font(.title)
            }
            .foregroundStyle(.blue)
        }
    }
    
    private func additionalControlsSection(viewModel: PlayerViewModel) -> some View {
        HStack(spacing: 40) {
            // Loop toggle
            Button {
                viewModel.toggleLoop()
            } label: {
                Image(systemName: viewModel.isLooping ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(viewModel.isLooping ? .blue : .secondary)
            }
            
            // Playback rate
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button {
                        viewModel.playbackRate = rate
                    } label: {
                        HStack {
                            Text("\(rate, specifier: "%.2f")×")
                            if abs(viewModel.playbackRate - rate) < 0.01 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    Text("\(viewModel.playbackRate, specifier: "%.2f")×")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            
            // Channel mode
            Menu {
                ForEach([
                    PlayerViewModel.ChannelMode.stereo,
                    .left,
                    .right,
                    .mid,
                    .side
                ], id: \.self) { mode in
                    Button {
                        viewModel.channelMode = mode
                    } label: {
                        HStack {
                            Text(channelModeLabel(mode))
                            if viewModel.channelMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                    Text(channelModeLabel(viewModel.channelMode))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyPlayerState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No audio selected")
                .font(.title2.weight(.semibold))
            
            Text("Import audio files and tap the play button to start listening")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func channelLabel(for count: Int) -> String {
        switch count {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(count) ch"
        }
    }
    
    private func channelModeLabel(_ mode: PlayerViewModel.ChannelMode) -> String {
        switch mode {
        case .stereo: return "Stereo"
        case .left: return "Left"
        case .right: return "Right"
        case .mid: return "Mid"
        case .side: return "Side"
        }
    }
}

#Preview {
    PlayerView(audioFile: nil)
        .modelContainer(for: [AudioFile.self])
}
