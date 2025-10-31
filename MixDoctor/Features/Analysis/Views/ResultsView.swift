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
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    // MARK: - Mock Testing - Access shared instance directly
    private var mockService: MockSubscriptionService { MockSubscriptionService.shared }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let analysisService = AudioAnalysisService()

    var body: some View {
        ScrollView {
            if let result = analysisResult {
                resultContentView(result: result)
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isAnalyzing) {
            analysingView
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // If paywall was dismissed without purchase, return to dashboard
            if !mockService.isProUser {
                print("⚠️ Paywall dismissed without purchase, returning to dashboard")
                dismiss()
            }
        }) {
            MockPaywallView(onPurchaseComplete: {
                Task {
                    await performAnalysis()
                }
            })
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            print("📊 ResultsView appeared for: \(audioFile.fileName)")
            print("   File ID: \(audioFile.id)")
            print("   File URL: \(audioFile.fileURL)")
            print("   Has existing result: \(audioFile.analysisResult != nil)")
            print("   🔒 Subscription Status:")
            print("      Is Pro: \(mockService.isProUser)")
            print("      Remaining: \(mockService.remainingFreeAnalyses)")
            print("      Can perform: \(mockService.canPerformAnalysis())")
            
            // Check if analysis already exists (either in memory or on iCloud)
            if let existingResult = audioFile.analysisResult {
                // Use cached result from SwiftData
                print("   ✅ Using cached result from SwiftData (score: \(existingResult.overallScore))")
                analysisResult = existingResult
            } else {
                // Try to load from iCloud Drive JSON file
                if let savedResult = AnalysisResultPersistence.shared.loadAnalysisResult(forAudioFile: audioFile.fileName) {
                    print("   ☁️ Loaded analysis from iCloud Drive (score: \(savedResult.overallScore))")
                    audioFile.analysisResult = savedResult
                    savedResult.audioFile = audioFile
                    try? modelContext.save()
                    analysisResult = savedResult
                } else {
                    // No cached result found - need to analyze
                    print("   ➡️ No cached result found, starting analysis...")
                    await performAnalysis()
                }
            }
        }
    }

    // MARK: - Analysis Views

    private var analysingView: some View {
        AnimatedGradientLoader(fileName: audioFile.fileName)
    }

    // MARK: - Results Content

    private func resultContentView(result: AnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Overall Score Card
            overallScoreCard(result: result)
            
            // AI Analysis Overview (if available)
            if result.detailedSummary != nil || result.stereoAnalysis != nil {
                aiAnalysisOverviewCard(result: result)
            }

            // Individual Metrics
            VStack(spacing: 16) {
                // Mix Cohesion Card (for all users)
                mixCohesionCard(result: result)
                
                stereoWidthCard(result: result)
                phaseCoherenceCard(result: result)
                frequencyBalanceCard(result: result)
                dynamicRangeCard(result: result)
                loudnessCard(result: result)
                
                // Pro features
                if mockService.isProUser && result.hasStemAnalysis {
                    proFeaturesCard(result: result)
                }
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

    // MARK: - AI Analysis Overview

    private func aiAnalysisOverviewCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .foregroundStyle(.purple)
                
                Text("Analysis Overview")
                    .font(.headline)
            }
            
            if let summary = result.detailedSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            if let stereo = result.stereoAnalysis {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Stereo", systemImage: "waveform.path.ecg")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(stereo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            if let frequency = result.frequencyAnalysis {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Frequency", systemImage: "waveform")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(frequency)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            if let dynamics = result.dynamicsAnalysis {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Dynamics", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(dynamics)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
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
        let _ = print("🎨 Rendering Frequency Balance Card:")
        let _ = print("   Low: \(result.lowEndBalance)%")
        let _ = print("   Mid: \(result.midBalance)%")
        let _ = print("   High: \(result.highBalance)%")
        let _ = print("   Score: \(result.frequencyBalanceScore)%")
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)

                Text("Frequency Balance")
                    .font(.headline)

                Spacer()

                Image(systemName: result.hasFrequencyImbalance ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.hasFrequencyImbalance ? .orange : .green)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.frequencyBalanceScore))
                    .font(.system(size: 32, weight: .bold))

                Text("%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(frequencyBalanceDescription(result.frequencyBalanceScore))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            // Frequency bars
            VStack(spacing: 10) {
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

            // First row: LUFS and Peak
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
            
            // Second row: RMS and True Peak
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RMS")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f dBFS", result.rmsLevel))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("True Peak")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f dBTP", result.truePeakLevel))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(result.truePeakLevel > -1.0 ? .orange : .primary)
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
    
    // MARK: - Pro Features
    
    private func proFeaturesCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)

                Text("Pro Analysis")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }

            VStack(spacing: 16) {
                // Foreground Clarity
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Foreground Clarity", systemImage: "waveform.badge.magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Text(foregroundClarityDescription(result.foregroundClarityScore))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(result.foregroundClarityScore))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Divider()
                
                // Background Ambience
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Background Ambience", systemImage: "water.waves")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Text(backgroundAmbienceDescription(result.backgroundAmbienceScore))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(result.backgroundAmbienceScore))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppConstants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cornerRadius)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Mix Cohesion Card
    
    private func mixCohesionCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Mix Cohesion")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(result.mixCohesionScore))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(cohesionColor(score: result.mixCohesionScore))
            }
            
            Text(cohesionDescription(score: result.mixCohesionScore))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Individual cohesion factors
            VStack(spacing: 10) {
                cohesionFactorRow(
                    icon: "tuningfork",
                    title: "Spectral Coherence",
                    value: result.spectralCoherence,
                    description: "Frequencies complement"
                )
                
                cohesionFactorRow(
                    icon: "waveform.path.ecg",
                    title: "Phase Integrity",
                    value: result.phaseIntegrity,
                    description: "Channels work together"
                )
                
                cohesionFactorRow(
                    icon: "slider.horizontal.3",
                    title: "Dynamic Consistency",
                    value: result.dynamicConsistency,
                    description: "Uniform processing"
                )
                
                cohesionFactorRow(
                    icon: "aspectratio",
                    title: "Spatial Balance",
                    value: result.spatialBalance,
                    description: "Stereo field balanced"
                )
                
                cohesionFactorRow(
                    icon: "cube.fill",
                    title: "Mix Depth",
                    value: result.mixDepth,
                    description: "3D dimension"
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppConstants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cornerRadius)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func cohesionFactorRow(icon: String, title: String, value: Double, description: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple.opacity(0.7))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(value))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(cohesionColor(score: value))
        }
    }
    
    private func cohesionColor(score: Double) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func cohesionDescription(score: Double) -> String {
        if score >= 70 {
            return "Excellent cohesion - all elements sit well together in the mix"
        } else if score >= 50 {
            return "Good cohesion - most elements work together well"
        } else if score >= 30 {
            return "Fair cohesion - some elements may not sit well together"
        } else {
            return "Poor cohesion - channels appear to be fighting each other"
        }
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
            Button(role: .destructive, action: { 
                deleteFile()
            }) {
                Label("Delete File", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isAnalyzing)
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

    private func frequencyBalanceDescription(_ score: Double) -> String {
        switch score {
        case 0..<50: return "Significant frequency imbalance"
        case 50..<70: return "Moderate frequency balance"
        case 70..<85: return "Good frequency balance"
        default: return "Excellent frequency balance"
        }
    }

    private func dynamicRangeDescription(_ range: Double) -> String {
        switch range {
        case 0..<6: return "Over-compressed"
        case 6..<14: return "Good dynamics"
        default: return "Very dynamic - may need compression"
        }
    }
    
    private func foregroundClarityDescription(_ score: Double) -> String {
        switch score {
        case 0..<40: return "Lead elements lack clarity and definition"
        case 40..<60: return "Moderate clarity - could be improved"
        case 60..<80: return "Good clarity - vocals/leads are clear"
        default: return "Excellent clarity - perfect separation"
        }
    }
    
    private func backgroundAmbienceDescription(_ score: Double) -> String {
        switch score {
        case 0..<15: return "Very dry - minimal or no reverb/space"
        case 15..<30: return "Light ambience - subtle space"
        case 30..<50: return "Moderate ambience - good depth"
        case 50..<70: return "Rich ambience - spacious mix"
        default: return "Heavy ambience - very wet/spacious"
        }
    }

    private func performAnalysis() async {
        // Double-check that we don't already have a result
        if let existingResult = audioFile.analysisResult {
            print("   ✅ Analysis already exists (score: \(existingResult.overallScore)), skipping")
            analysisResult = existingResult
            return
        }
        
        // Check if user can perform analysis
        print("🔍 Checking analysis permission:")
        print("   Is Pro User: \(mockService.isProUser)")
        print("   Remaining analyses: \(mockService.remainingFreeAnalyses)")
        print("   Can perform: \(mockService.canPerformAnalysis())")
        
        guard mockService.canPerformAnalysis() else {
            print("⚠️ Free limit reached, showing paywall")
            showPaywall = true
            return
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            print("🔍 Starting analysis for: \(audioFile.fileName)")
            print("   File URL: \(audioFile.fileURL)")
            
            // Perform the analysis on the specific file
            let result = try await analysisService.analyzeAudio(audioFile)
            
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✅ Analysis complete!")
            print("   Final Overall Score: \(Int(result.overallScore))")
            print("   Score Description: \(scoreDescription(result.overallScore))")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            // Increment usage count for free users
            mockService.incrementAnalysisCount()
            
            // Update the local state
            analysisResult = result
            
            // Save to the persistent AudioFile model
            audioFile.analysisResult = result
            audioFile.dateAnalyzed = Date()
            
            // Save to SwiftData
            try modelContext.save()
            
            // Save to iCloud Drive as JSON for cross-device sync
            do {
                try AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: audioFile.fileName)
                print("☁️ Saved analysis to iCloud Drive")
            } catch {
                print("⚠️ Failed to save analysis to iCloud: \(error)")
            }
            
            print("✅ Analysis completed and saved for: \(audioFile.fileName)")
        } catch {
            print("❌ Analysis error for \(audioFile.fileName): \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteFile() {
        print("🗑️ Deleting audio file: \(audioFile.fileName)")
        
        // Delete the actual audio file from storage (iCloud or local)
        let fileURL = audioFile.fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Deleted audio file from storage: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Failed to delete audio file: \(error)")
            }
        }
        
        // Delete the analysis result JSON from iCloud Drive
        AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: audioFile.fileName)
        
        // Delete the SwiftData record
        modelContext.delete(audioFile)
        try? modelContext.save()
        dismiss()
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

// MARK: - Animated Gradient Loader

private struct AnimatedGradientLoader: View {
    let fileName: String
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.435, green: 0.173, blue: 0.871), // Purple
                    Color(red: 0.6, green: 0.3, blue: 0.95),      // Light purple
                    Color(red: 0.2, green: 0.8, blue: 0.6),       // Green/Teal
                    Color(red: 0.435, green: 0.173, blue: 0.871)  // Purple again
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(.degrees(animationOffset))
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
                ) {
                    animationOffset = 360
                }
            }
            
            // Content overlay
            VStack(spacing: 24) {
                // Pulsing circle with waveform icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animationOffset > 0 ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: animationOffset
                        )
                    
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 12) {
                    Text("Analyzing Audio")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Using advanced AI to analyze your mix...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Loading indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationOffset > 0 ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
