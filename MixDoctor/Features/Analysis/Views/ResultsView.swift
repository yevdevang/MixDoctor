//
//  ResultsView.swift
//  MixDoctor
//
//  View for displaying detailed audio analysis results
//

import SwiftUI
import SwiftData

@MainActor
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
                FrequencyBar(label: "Low", value: result.lowEndBalance, color: .red)
                FrequencyBar(label: "Mid", value: result.midBalance, color: .green)
                FrequencyBar(label: "High", value: result.highBalance, color: .blue)
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
            Button(action: { exportReport(result) }) {
                Label("Export Report", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: { Task { await performAnalysis() } }) {
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
            audioFile.dateAnalyzed = Date()
            try? modelContext.save()
        } catch {
            print("Analysis error: \(error)")
        }
    }
    
    private func exportReport(_ result: AnalysisResult) {
        // TODO: Implement report export functionality
        print("Exporting report for \(audioFile.fileName)")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AudioFile.self, configurations: config)
    
    let audioFile = AudioFile(
        fileName: "Sample Track.wav",
        fileURL: URL(fileURLWithPath: "/tmp/sample.wav"),
        duration: 180.5,
        sampleRate: 44100,
        bitDepth: 24,
        numberOfChannels: 2,
        fileSize: 15_000_000
    )
    
    return NavigationStack {
        ResultsView(audioFile: audioFile)
            .modelContainer(container)
    }
}
