# Phase 4: UI Implementation

**Duration**: Week 4-6
**Goal**: Create beautiful, intuitive interfaces for all app features

## Objectives

- Implement Import View with drag-and-drop
- Build comprehensive Results View with visualizations
- Create Dashboard with track management
- Develop feature-rich Audio Player
- Design Settings View
- Ensure consistent design language across all views
- Optimize for accessibility and dark mode

## Design Principles

- **Clarity**: Information should be easy to understand at a glance
- **Visual Hierarchy**: Important information stands out
- **Consistency**: Uniform design patterns throughout
- **Feedback**: Clear indication of app state and user actions
- **Accessibility**: Support VoiceOver, Dynamic Type, and high contrast

## Color System

### Score-based Colors
```swift
extension Color {
    static func scoreColor(for score: Double) -> Color {
        switch score {
        case 85...100: return .scoreExcellent  // Green
        case 70..<85: return .scoreGood        // Yellow-green
        case 50..<70: return .scoreFair        // Orange
        default: return .scorePoor             // Red
        }
    }
}
```

## View Implementations

### 1. Results View

```swift
import SwiftUI
import Charts

struct ResultsView: View {
    let audioFile: AudioFile
    @State private var analysisResult: AnalysisResult?
    @State private var isAnalyzing = false

    @Environment(\.modelContext) private var modelContext
    private let analysisService = AudioAnalysisService()

    var body: some View {
        ScrollView {
            if isAnalyzing {
                analysingView
            } else if let result = analysisResult {
                resultContentView(result: result)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await performAnalysis()
        }
    }

    // MARK: - Analysis Views

    private var analysingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing audio...")
                .font(.headline)

            Text(audioFile.fileName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No analysis available")
                .font(.headline)

            Button("Analyze Now") {
                Task {
                    await performAnalysis()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results Content

    private func resultContentView(result: AnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Overall Score Card
            overallScoreCard(result: result)

            // Individual Metrics
            VStack(spacing: 16) {
                stereoWidthCard(result: result)
                phaseCoherenceCard(result: result)
                frequencyBalanceCard(result: result)
                dynamicRangeCard(result: result)
                loudnessCard(result: result)
            }

            // Recommendations
            if !result.recommendations.isEmpty {
                recommendationsCard(result: result)
            }

            // Action Buttons
            actionButtons(result: result)
        }
        .padding()
    }

    // MARK: - Score Card

    private func overallScoreCard(result: AnalysisResult) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: result.overallScore / 100)
                    .stroke(
                        Color.scoreColor(for: result.overallScore),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1), value: result.overallScore)

                VStack(spacing: 4) {
                    Text("\(Int(result.overallScore))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color.scoreColor(for: result.overallScore))

                    Text("Overall Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(scoreDescription(result.overallScore))
                .font(.headline)
                .multilineTextAlignment(.center)

            issuesSummary(result: result)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    private func issuesSummary(result: AnalysisResult) -> some View {
        let issueCount = [
            result.hasPhaseIssues,
            result.hasStereoIssues,
            result.hasFrequencyImbalance,
            result.hasDynamicRangeIssues
        ].filter { $0 }.count

        return HStack(spacing: 8) {
            Image(systemName: issueCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(issueCount == 0 ? .green : .orange)

            Text(issueCount == 0 ? "No issues detected" : "\(issueCount) issue\(issueCount == 1 ? "" : "s") detected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.backgroundPrimary)
        .cornerRadius(8)
    }

    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 85...100: return "Excellent Mix Quality"
        case 70..<85: return "Good Mix Quality"
        case 50..<70: return "Fair Mix Quality"
        default: return "Needs Improvement"
        }
    }

    // MARK: - Metric Cards

    private func stereoWidthCard(result: AnalysisResult) -> some View {
        MetricCard(
            title: "Stereo Width",
            icon: "arrow.left.and.right",
            value: result.stereoWidthScore,
            unit: "%",
            status: result.hasStereoIssues ? .warning : .good,
            description: stereoWidthDescription(result.stereoWidthScore)
        )
    }

    private func phaseCoherenceCard(result: AnalysisResult) -> some View {
        MetricCard(
            title: "Phase Coherence",
            icon: "waveform.path",
            value: result.phaseCoherence * 100,
            unit: "%",
            status: result.hasPhaseIssues ? .error : .good,
            description: phaseDescription(result.phaseCoherence)
        )
    }

    private func frequencyBalanceCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)

                Text("Frequency Balance")
                    .font(.headline)

                Spacer()

                if result.hasFrequencyImbalance {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            // Frequency bars
            VStack(spacing: 8) {
                FrequencyBar(label: "Low", value: result.frequencyBalance.lowEnd, color: .red)
                FrequencyBar(label: "Mid", value: result.frequencyBalance.mids, color: .green)
                FrequencyBar(label: "High", value: result.frequencyBalance.highs, color: .blue)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    private func dynamicRangeCard(result: AnalysisResult) -> some View {
        MetricCard(
            title: "Dynamic Range",
            icon: "waveform",
            value: result.dynamicRange,
            unit: "dB",
            status: result.hasDynamicRangeIssues ? .warning : .good,
            description: dynamicRangeDescription(result.dynamicRange)
        )
    }

    private func loudnessCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.purple)

                Text("Loudness")
                    .font(.headline)

                Spacer()
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Integrated")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f LUFS", result.loudnessLUFS))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f dBFS", result.peakLevel))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(result.peakLevel > -0.1 ? .red : .primary)
                }
            }

            if result.peakLevel > -0.1 {
                Label("Potential clipping detected", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    // MARK: - Recommendations

    private func recommendationsCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)

                Text("Recommendations")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(recommendation)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    // MARK: - Action Buttons

    private func actionButtons(result: AnalysisResult) -> some View {
        VStack(spacing: 12) {
            Button(action: { /* Export report */ }) {
                Label("Export Report", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: { /* Re-analyze */ }) {
                Label("Re-analyze", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helper Functions

    private func stereoWidthDescription(_ width: Double) -> String {
        switch width {
        case 0..<30: return "Very narrow stereo image"
        case 30..<60: return "Good stereo width"
        case 60..<80: return "Wide stereo image"
        default: return "Very wide - mono compatibility risk"
        }
    }

    private func phaseDescription(_ coherence: Double) -> String {
        switch coherence {
        case -1..<(-0.3): return "Severe phase cancellation"
        case (-0.3)..<0.3: return "Possible phase issues"
        case 0.3..<0.7: return "Good phase relationship"
        default: return "Excellent phase coherence"
        }
    }

    private func dynamicRangeDescription(_ range: Double) -> String {
        switch range {
        case 0..<6: return "Over-compressed"
        case 6..<14: return "Good dynamics"
        default: return "Very dynamic - may need compression"
        }
    }

    private func performAnalysis() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await analysisService.analyzeAudio(audioFile)
            analysisResult = result
            audioFile.analysisResult = result
            try? modelContext.save()
        } catch {
            print("Analysis error: \(error)")
        }
    }
}

// MARK: - Supporting Views

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

struct FrequencyBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * (value / 100), height: 8)
                        .cornerRadius(4)
                        .animation(.easeOut, value: value)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", value))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
```

### 2. Dashboard View

```swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioFile.dateImported, order: .reverse) private var audioFiles: [AudioFile]

    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var selectedFile: AudioFile?

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case analyzed = "Analyzed"
        case pending = "Pending"
        case issues = "Has Issues"
    }

    var filteredFiles: [AudioFile] {
        var files = audioFiles

        // Apply search filter
        if !searchText.isEmpty {
            files = files.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply status filter
        switch filterOption {
        case .all:
            break
        case .analyzed:
            files = files.filter { $0.analysisResult != nil }
        case .pending:
            files = files.filter { $0.analysisResult == nil }
        case .issues:
            files = files.filter {
                guard let result = $0.analysisResult else { return false }
                return result.hasPhaseIssues || result.hasStereoIssues ||
                       result.hasFrequencyImbalance || result.hasDynamicRangeIssues
            }
        }

        return files
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if audioFiles.isEmpty {
                    emptyStateView
                } else {
                    // Statistics cards
                    statisticsView

                    // Filter picker
                    filterPicker

                    // Files list
                    filesList
                }
            }
            .navigationTitle("Dashboard")
            .searchable(text: $searchText, prompt: "Search audio files")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { /* Sort options */ }) {
                            Label("Sort by Date", systemImage: "calendar")
                        }
                        Button(action: { /* Sort by name */ }) {
                            Label("Sort by Name", systemImage: "textformat")
                        }
                        Button(action: { /* Sort by score */ }) {
                            Label("Sort by Score", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Files",
                    value: "\(audioFiles.count)",
                    icon: "music.note.list",
                    color: .blue
                )

                StatCard(
                    title: "Analyzed",
                    value: "\(analyzedCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "Issues Found",
                    value: "\(issuesCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )

                StatCard(
                    title: "Avg Score",
                    value: String(format: "%.0f", averageScore),
                    icon: "star.fill",
                    color: .purple
                )
            }
            .padding()
        }
        .background(Color.backgroundSecondary)
    }

    private var analyzedCount: Int {
        audioFiles.filter { $0.analysisResult != nil }.count
    }

    private var issuesCount: Int {
        audioFiles.compactMap { $0.analysisResult }.filter {
            $0.hasPhaseIssues || $0.hasStereoIssues ||
            $0.hasFrequencyImbalance || $0.hasDynamicRangeIssues
        }.count
    }

    private var averageScore: Double {
        let scores = audioFiles.compactMap { $0.analysisResult?.overallScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $filterOption) {
            ForEach(FilterOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Files List

    private var filesList: some View {
        List {
            ForEach(filteredFiles) { file in
                NavigationLink(value: file) {
                    AudioFileRow(audioFile: file)
                }
            }
            .onDelete(perform: deleteFiles)
        }
        .navigationDestination(for: AudioFile.self) { file in
            ResultsView(audioFile: file)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Audio Files",
            systemImage: "music.note",
            description: Text("Import audio files to get started")
        )
    }

    // MARK: - Actions

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = filteredFiles[index]
            modelContext.delete(file)
        }
        try? modelContext.save()
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
        .frame(width: 120)
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
```

### 3. Audio Player View

```swift
import SwiftUI
import AVFoundation

struct PlayerView: View {
    let audioFile: AudioFile

    @StateObject private var viewModel: PlayerViewModel

    init(audioFile: AudioFile) {
        self.audioFile = audioFile
        _viewModel = StateObject(wrappedValue: PlayerViewModel(audioFile: audioFile))
    }

    var body: some View {
        VStack(spacing: 20) {
            // Waveform
            waveformView

            // Playback controls
            playbackControls

            // Timeline
            timelineView

            // Channel controls
            channelControls

            // Additional controls
            additionalControls
        }
        .padding()
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Waveform

    private var waveformView: some View {
        WaveformView(
            samples: viewModel.waveformSamples,
            progress: viewModel.progress
        )
        .frame(height: 120)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            Button(action: { viewModel.skipBackward() }) {
                Image(systemName: "gobackward.10")
                    .font(.title2)
            }

            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }

            Button(action: { viewModel.skipForward() }) {
                Image(systemName: "goforward.10")
                    .font(.title2)
            }
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        VStack(spacing: 8) {
            Slider(value: $viewModel.progress, in: 0...1) { editing in
                if !editing {
                    viewModel.seek(to: viewModel.progress)
                }
            }

            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .monospacedDigit()

                Spacer()

                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Channel Controls

    private var channelControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channels")
                .font(.headline)

            HStack(spacing: 12) {
                ChannelButton(
                    title: "Stereo",
                    icon: "speaker.wave.2",
                    isSelected: viewModel.channelMode == .stereo
                ) {
                    viewModel.channelMode = .stereo
                }

                ChannelButton(
                    title: "Left",
                    icon: "l.square",
                    isSelected: viewModel.channelMode == .left
                ) {
                    viewModel.channelMode = .left
                }

                ChannelButton(
                    title: "Right",
                    icon: "r.square",
                    isSelected: viewModel.channelMode == .right
                ) {
                    viewModel.channelMode = .right
                }

                ChannelButton(
                    title: "Mid",
                    icon: "m.square",
                    isSelected: viewModel.channelMode == .mid
                ) {
                    viewModel.channelMode = .mid
                }

                ChannelButton(
                    title: "Side",
                    icon: "s.square",
                    isSelected: viewModel.channelMode == .side
                ) {
                    viewModel.channelMode = .side
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Additional Controls

    private var additionalControls: some View {
        HStack(spacing: 20) {
            Button(action: { viewModel.toggleLoop() }) {
                Label("Loop", systemImage: viewModel.isLooping ? "repeat.circle.fill" : "repeat.circle")
            }

            Spacer()

            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { rate in
                    Button("\(rate, specifier: "%.2f")x") {
                        viewModel.playbackRate = rate
                    }
                }
            } label: {
                Label("\(viewModel.playbackRate, specifier: "%.2f")x", systemImage: "gauge")
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Helper

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
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
```

## Deliverables

- [ ] Results View with all analysis metrics
- [ ] Dashboard with file management
- [ ] Audio Player with channel controls
- [ ] Settings View
- [ ] Consistent design system
- [ ] Dark mode support
- [ ] Accessibility features
- [ ] UI animations and transitions

## Next Phase

Proceed to [Phase 5: Data Management](05-phase-data-management.md)

## Estimated Time

- Results View: 8 hours
- Dashboard: 6 hours
- Player: 8 hours
- Settings: 4 hours
- Polish and animations: 4 hours

**Total: ~30 hours (4-5 days)**
