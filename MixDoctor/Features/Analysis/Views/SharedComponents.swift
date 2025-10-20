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
        .background(Color.backgroundPrimary)
        .cornerRadius(12)
    }
}

// MARK: - Audio File Row

struct AudioFileRow: View {
    let audioFile: AudioFile

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: audioFile.analysisResult != nil ? "checkmark.circle.fill" : "clock.fill")
                    .font(.title3)
                    .foregroundStyle(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(formatDuration(audioFile.duration), systemImage: "clock")
                    Label("\(Int(audioFile.sampleRate / 1000))kHz", systemImage: "waveform")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Score badge
            if let result = audioFile.analysisResult {
                VStack(spacing: 2) {
                    Text("\(Int(result.overallScore))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.scoreColor(for: result.overallScore))

                    Text("score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if let result = audioFile.analysisResult {
            return Color.scoreColor(for: result.overallScore)
        }
        return .gray
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
