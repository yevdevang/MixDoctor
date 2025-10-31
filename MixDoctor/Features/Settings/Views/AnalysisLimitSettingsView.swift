//
//  AnalysisLimitSettingsView.swift
//  MixDoctor
//
//  Settings view for ChatGPT analysis limits
//

import SwiftUI

struct AnalysisLimitSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Current usage display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Usage")
                            .font(.headline)
                        HStack(spacing: 4) {
                            Text("\(viewModel.currentMonthAnalysisCount)")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(viewModel.canPerformAnalysis ? Color.primary : Color.red)
                            Text("/ \(viewModel.maxAnalysesPerMonth)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.remainingAnalyses)")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(viewModel.remainingAnalyses > 10 ? .green : .orange)
                    }
                }
                
                // Progress bar
                ProgressView(value: viewModel.analysisProgress) {
                    HStack {
                        Text("Usage")
                            .font(.caption)
                        Spacer()
                        Text("Resets in \(viewModel.daysUntilReset) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(viewModel.analysisProgress > 0.9 ? .red : .blue)
                
                Divider()
                
                // Cost information
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated Cost per Analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        // Token estimate
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(estimatedTokens) tokens")
                                .font(.caption2)
                        }
                        
                        // Cost estimate
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("~$\(String(format: "%.4f", estimatedCost))")
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                
                // Reset button (for testing)
                Button(role: .destructive) {
                    viewModel.manuallyResetAnalysisCount()
                } label: {
                    Label("Reset Counter", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        } header: {
            Label("Analysis Limit", systemImage: "chart.line.uptrend.xyaxis")
        } footer: {
            Text("You have 50 analyses per month (max 1 minute each) with ChatGPT audio analysis. Counter resets automatically at the start of each month.")
                .font(.caption)
        }
    }
    
    // MARK: - Helper Methods
    
    private var estimatedTokens: Int {
        Int(viewModel.maxAnalysisDuration * 150) // ~150 tokens per second
    }
    
    private var estimatedCost: Double {
        let tokens = Double(estimatedTokens)
        let costPer1M = 2.50 // GPT-4o pricing (adjust for user tier)
        return (tokens / 1_000_000) * costPer1M
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

#Preview {
    Form {
        AnalysisLimitSettingsView(viewModel: SettingsViewModel())
    }
}
