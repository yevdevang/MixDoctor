//
//  SharedComponents.swift
//  MixDoctor
//
//  Reusable UI components for the app
//

import SwiftUI
import SwiftData

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let icon: String
    let value: Double
    let unit: String
    let status: Status
    let description: String

    enum Status {
        case good, warning, error

        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.headline)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 32, weight: .bold))

                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }
}

// MARK: - Frequency Bar

struct FrequencyBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 14)
                        .cornerRadius(7)

                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: max(geometry.size.width * (value / 100), 2), height: 14)
                        .cornerRadius(7)
                        .animation(.easeOut, value: value)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.0f%%", value))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 45, alignment: .trailing)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        #if canImport(UIKit)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color.gray.opacity(0.15))
        #endif
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color.secondary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .cornerRadius(12)
    }
}

// MARK: - Audio File Row

struct AudioFileRow: View {
    let audioFile: AudioFile
    var index: Int? = nil
    var onDelete: (() -> Void)? = nil
    var isAnalyzing: Bool = false
    
    @State private var fileExists: Bool = true
    @State private var isDownloading: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Waveform Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                // Mini waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(statusColor)
                            .frame(width: 2.5, height: waveformHeight(for: index))
                    }
                }
                
                // Download indicator for missing files (skip for demo files — they're bundled locally)
                if (!fileExists || isDownloading) && !audioFile.isDemoFile {
                    VStack {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(statusColor)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.caption2)
                                .foregroundStyle(statusColor)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.8))
                }
                
                // Checkmark overlay for analyzed files
                else if audioFile.analysisResult != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .background(
                                    Circle()
                                        .fill(statusColor)
                                        .frame(width: 14, height: 14)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 40, height: 40)
                    .padding(3)
                }

                // Index number badge at bottom-left
                if let index {
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(index)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(
                                    Circle()
                                        .fill(statusColor.opacity(0.85))
                                )
                            Spacer()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .offset(x: -4, y: 4)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(audioFile.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Row 1: Duration and sample rate
                HStack(spacing: 4) {
                    Label(formatDuration(audioFile.duration), systemImage: "clock")
                    Text("•")
                    Text("\(Int(audioFile.sampleRate / 1000))kHz")

                    // Show download status (skip for demo files)
                    if !fileExists && !audioFile.isDemoFile {
                        Text("•")
                        Text("Downloading...")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                // Row 2: Mix stage + DEMO badge
                HStack(spacing: 6) {
                    if let mixStage = audioFile.mixStage {
                        Text(formatMixStage(mixStage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(mixStageColor(mixStage))
                    }
                    if audioFile.isDemoFile {
                        Text("DEMO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primaryAccent))
                    }
                }
            }

            Spacer()

            // Analyzing indicator or Score badge
            if isAnalyzing {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 8)
            } else if let result = audioFile.analysisResult {
                if result.stageMismatch != nil {
                    // Stage mismatch indicator
                    let label = result.stageMismatch == "master" ? "Master" : "Mix"
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.title3)
                            .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))

                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.435, green: 0.173, blue: 0.871))
                    }
                } else if result.isProfessionallyMixed {
                    VStack(spacing: 2) {
                        Text("\(Int(result.overallScore))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.scoreColor(for: result.overallScore))

                        Text("score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Unmixed track indicator
                    VStack(spacing: 2) {
                        Image(systemName: "waveform.badge.exclamationmark")
                            .font(.title3)
                            .foregroundColor(.orange)

                        Text("Unmixed")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            #if targetEnvironment(macCatalyst)
            // Trash button on Mac (hidden for demo files)
            if let onDelete = onDelete, !audioFile.isDemoFile {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            #endif
            
            // Analyze icon button
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primaryAccent,
                                Color(red: 0.6, green: 0.3, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            checkFileStatus()
        }
    }

    private var statusColor: Color {
        if let result = audioFile.analysisResult {
            if result.stageMismatch != nil {
                return Color(red: 0.435, green: 0.173, blue: 0.871)
            }
            return Color.scoreColor(for: result.overallScore)
        }
        return .gray
    }
    
    private func checkFileStatus() {
        let fileURL = audioFile.fileURL
        fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        
        if !fileExists {
            // Check if file is in iCloud and needs downloading
            do {
                let values = try fileURL.resourceValues(forKeys: [
                    URLResourceKey.isUbiquitousItemKey,
                    URLResourceKey.ubiquitousItemDownloadingStatusKey
                ])
                
                if let isICloud = values.isUbiquitousItem, isICloud {
                    let downloadStatus = values.ubiquitousItemDownloadingStatus
                    isDownloading = (downloadStatus == .current || downloadStatus == .downloaded)
                    
                    // If not downloaded, trigger download
                    if downloadStatus == .notDownloaded {
                        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        isDownloading = true
                        
                        // Re-check status after a delay
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            await MainActor.run {
                                checkFileStatus()
                            }
                        }
                    }
                }
            } catch {
            }
        }
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        // Create a mini waveform pattern with varying heights
        let heights: [CGFloat] = [16, 24, 20, 28, 18]
        return heights[index % heights.count]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatMixStage(_ stage: String) -> String {
        switch stage.lowercased() {
        case "mix":
            return "Mix"
        case "master_streaming":
            return "Master (Streaming)"
        case "master_cd":
            return "Master (CD)"
        default:
            return stage.capitalized
        }
    }

    private func mixStageColor(_ stage: String) -> Color {
        switch stage.lowercased() {
        case "mix":
            return .blue
        case "master_streaming":
            return .green
        case "master_cd":
            return .orange
        default:
            return .secondary
        }
    }
}

// MARK: - Channel Button

struct ChannelButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let samples: [Float]
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Waveform bars
                HStack(spacing: 1) {
                    ForEach(0..<min(samples.count, 100), id: \.self) { index in
                        let sample = samples[index]
                        let barHeight = CGFloat(abs(sample)) * geometry.size.height

                        Rectangle()
                            .fill(colorForBar(index: index, totalBars: 100))
                            .frame(width: geometry.size.width / 100, height: barHeight)
                            .frame(height: geometry.size.height, alignment: .center)
                    }
                }

                // Progress indicator
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geometry.size.width * progress)
            }
        }
    }

    private func colorForBar(index: Int, totalBars: Int) -> Color {
        let position = Double(index) / Double(totalBars)
        return position < progress ? Color.blue : Color.gray.opacity(0.5)
    }
}
