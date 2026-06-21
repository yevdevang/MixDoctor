//
//  AnalysisHistoryView.swift
//  MixDoctor
//

import SwiftUI
import Charts

// MARK: - History Section (embedded in ResultsView)

struct AnalysisHistorySectionView: View {
    let audioFile: AudioFile
    @State private var selectedHistoryResult: AnalysisResult?

    private var sortedHistory: [AnalysisResult] {
        // Hide non-versions: failed analyses (API error) and stage mismatches are
        // saved with overallScore == 0 and must not appear as timeline entries.
        // This also cleans up any 0-score entries archived before the fix.
        let valid: [AnalysisResult] = audioFile.analysisHistory.filter { result in
            result.overallScore > 0 && result.stageMismatch == nil
        }
        return valid.sorted { $0.dateAnalyzed < $1.dateAnalyzed }
    }

    var body: some View {
        if !sortedHistory.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.primaryAccent)
                        .font(.title2)
                    Text("Version History")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    let count = sortedHistory.count
                    Text("\(count) \(count == 1 ? "version" : "versions")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if sortedHistory.count >= 2 {
                    scoreTimelineChart(history: sortedHistory)
                }

                VStack(spacing: 8) {
                    ForEach(sortedHistory.reversed(), id: \.id) { result in
                        historyRow(result: result)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
            .sheet(item: $selectedHistoryResult) { result in
                AnalysisHistoryDetailSheet(result: result)
            }
        }
    }

    // MARK: - Score Timeline Chart

    @ViewBuilder
    private func scoreTimelineChart(history: [AnalysisResult]) -> some View {
        Chart {
            ForEach(Array(history.enumerated()), id: \.offset) { index, result in
                LineMark(
                    x: .value("Version", index + 1),
                    y: .value("Score", result.overallScore)
                )
                .foregroundStyle(Color.primaryAccent)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Version", index + 1),
                    y: .value("Score", result.overallScore)
                )
                .foregroundStyle(Color.scoreColor(for: result.overallScore))
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(values: Array(1...history.count)) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("v\(v)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .frame(height: 120)
    }

    // MARK: - History Row

    private func historyRow(result: AnalysisResult) -> some View {
        Button(action: { selectedHistoryResult = result }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.scoreColor(for: result.overallScore).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("\(Int(result.overallScore))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.scoreColor(for: result.overallScore))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.dateAnalyzed.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(String(format: "%.1f LUFS · %.1f dB DR · %d%% width",
                                result.loudnessLUFS, result.dynamicRange, Int(result.stereoWidthScore)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.backgroundPrimary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Detail Sheet

struct AnalysisHistoryDetailSheet: View {
    let result: AnalysisResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCircle
                    metricsGrid
                    if let summary = result.aiSummary, !summary.isEmpty {
                        aiSummaryCard(summary: summary)
                    }
                }
                .padding()
            }
            .navigationTitle(result.dateAnalyzed.formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Score Circle

    private var scoreCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: result.overallScore / 100)
                .stroke(
                    Color.scoreColor(for: result.overallScore),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(result.overallScore))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.scoreColor(for: result.overallScore))
                Text("Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCell(label: "Loudness", value: String(format: "%.1f LUFS", result.loudnessLUFS))
            metricCell(label: "Peak", value: String(format: "%.1f dBFS", result.peakLevel))
            metricCell(label: "Dynamic Range", value: String(format: "%.1f dB", result.dynamicRange))
            metricCell(label: "Stereo Width", value: "\(Int(result.stereoWidthScore))%")
            metricCell(label: "Phase Coherence", value: "\(Int(result.phaseCoherence * 100))%")
            metricCell(label: "Mono Compat.", value: "\(Int(result.monoCompatibility * 100))%")
        }
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.backgroundSecondary)
        )
    }

    // MARK: - AI Summary

    private func aiSummaryCard(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Analysis", systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
        )
    }
}
