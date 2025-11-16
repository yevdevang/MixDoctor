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
    private let analysisService = AudioKitService.shared

    var body: some View {
        ZStack {
            ScrollView {
                if let result = analysisResult {
                    resultContentView(result: result)
                } else {
                    // Show empty state if no analysis result
                    emptyStateView
                }
            }
            
            // Show loading overlay during analysis
            if isAnalyzing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.white)
                    
                    Text("Re-analyzing...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.435, green: 0.173, blue: 0.871))
                )
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await performAnalysis()
                    }
                } label: {
                    if isAnalyzing {
                        ProgressView()
                            .tint(Color(red: 0.435, green: 0.173, blue: 0.871))
                    } else {
                        Label("Re-analyze", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isAnalyzing)
            }
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
            
            // Simply load the existing result since analysis should be done before navigation
            if let existingResult = audioFile.analysisResult {
                print("   ✅ Loading existing result (score: \(existingResult.overallScore))")
                analysisResult = existingResult
            } else {
                print("   ⚠️ No analysis result found - this shouldn't happen with new flow")
                // Fallback: check if we can perform analysis
                if !mockService.canPerformAnalysis() {
                    print("   🔒 Free limit reached, showing paywall")
                    showPaywall = true
                } else {
                    print("   🚀 Performing fallback analysis...")
                    await performAnalysis()
                }
            }
        }
    }
    
    // MARK: - Empty State
    
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
            // Song title (displayed above overall score)
            VStack(alignment: .center, spacing: 4) {
                Text(audioFile.fileName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Song name")

                // Optional subtitle: display analysis date if available
                if let analyzedDate = result.dateAnalyzed as Date? {
                    Text(analyzedDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Overall Score Card - ONLY show for professionally mixed audio
            if result.isProfessionallyMixed {
                overallScoreCard(result: result)
            }
            
            // Unmixed Detection Warning - ONLY show for unmixed audio
            if !result.isProfessionallyMixed, let unmixedDetection = result.unmixedDetection {
                unmixedDetectionCard(detection: unmixedDetection)
            }

            // Individual Metrics
            VStack(spacing: 16) {
                stereoWidthCard(result: result)
                phaseCoherenceCard(result: result)
                monoCompatibilityCard(result: result)
                // PAZ-style frequency analyzer
                PAZFrequencyAnalyzer(result: result)
                dynamicRangeCard(result: result)
            }
            
            // Issues Section
            let detectedIssues = calculateActualIssues(result: result)
            if !detectedIssues.isEmpty {
                modernIssuesSection(issues: detectedIssues)
            }
            
            // Analysis Section
            if let aiSummary = result.aiSummary {
                let analysisText = extractAnalysisText(from: aiSummary)
                if !analysisText.isEmpty {
                    modernAnalysisOnlySection(result: result)
                }
            }
            
            // Recommendations Section
            if !result.aiRecommendations.isEmpty || hasRecommendationsInSummary(result.aiSummary) {
                let summaryRecs = extractRecommendationsFromSummary(result.aiSummary)
                let allRecs = summaryRecs + result.aiRecommendations
                if !allRecs.isEmpty {
                    modernRecommendationsOnlySection(result: result)
                }
            }
            
            // Strengths Section
            if hasStrengthsInSummary(result.aiSummary) {
                let strengthTexts = extractStrengthsFromSummary(result.aiSummary)
                if !strengthTexts.isEmpty {
                    modernStrengthsSection(result: result)
                }
            }

            // Action Buttons
            actionButtons(result: result)
        }
        .padding()
    }

    // MARK: - Unmixed Detection Card
    
    private func unmixedDetectionCard(detection: UnmixedDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon based on detection result
            HStack {
                Image(systemName: detection.isLikelyUnmixed ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .foregroundStyle(detection.isLikelyUnmixed ? .orange : .green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(detection.isLikelyUnmixed ? "Unmixed Audio Detected" : "Professional Mix")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Mixing Quality: \(Int(detection.mixingQualityScore))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Quality bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Fill based on quality
                    RoundedRectangle(cornerRadius: 4)
                        .fill(qualityColor(detection.mixingQualityScore))
                        .frame(width: geometry.size.width * CGFloat(detection.mixingQualityScore / 100.0), height: 8)
                }
            }
            .frame(height: 8)
            
            // Detection criteria that failed
            if detection.isLikelyUnmixed && !detection.detectionCriteria.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(detection.detectionCriteria.filter { $0.value }.keys.sorted()), id: \.self) { criterion in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.orange)
                            
                            Text(criterion)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            
            // Main recommendation
            if !detection.recommendations.isEmpty {
                Text(detection.recommendations.first ?? "")
                    .font(.callout)
                    .foregroundStyle(detection.isLikelyUnmixed ? .orange : .green)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((detection.isLikelyUnmixed ? Color.orange : Color.green).opacity(0.1))
                    )
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }
    
    private func qualityColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .yellow
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - Modern Score Card

    private func overallScoreCard(result: AnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
                
                Text("Overall Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Score Circle with Modern Design
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                // Progress Circle
                Circle()
                    .trim(from: 0, to: result.overallScore / 100)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.scoreColor(for: result.overallScore).opacity(0.7), Color.scoreColor(for: result.overallScore)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.5), value: result.overallScore)

                // Score Content
                VStack(spacing: 4) {
                    Text("\(Int(result.overallScore))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(Color.scoreColor(for: result.overallScore))

                    Text("Score")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Score Description with Status
            VStack(spacing: 8) {
                Text(scoreDescription(result.overallScore))
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                modernIssuesSummary(result: result)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    private func modernIssuesSummary(result: AnalysisResult) -> some View {
        // Calculate issues based on actual metrics and score instead of boolean flags
        let issues = calculateActualIssues(result: result)
        let issueCount = issues.count
        
        // If score is below 70, show quality message instead of "no issues"
        let showQualityMessage = result.overallScore > 0 && result.overallScore < 70 && issueCount == 0

        return HStack(spacing: 8) {
            Image(systemName: showQualityMessage ? "info.circle.fill" : (issueCount == 0 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"))
                .foregroundColor(showQualityMessage ? .orange : (issueCount == 0 ? .green : .orange))
                .font(.title3)

            Text(showQualityMessage ? "Could be improved - check recommendations" : (issueCount == 0 ? "No critical issues detected" : "\(issueCount) issue\(issueCount == 1 ? "" : "s") detected"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(showQualityMessage ? .orange : (issueCount == 0 ? .green : .orange))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill((showQualityMessage || issueCount > 0 ? Color.orange : Color.green).opacity(0.1))
        )
    }
    
    // Calculate issues based on actual metrics and score thresholds
    private func calculateActualIssues(result: AnalysisResult) -> [String] {
        var issues: [String] = []
        
        // Always check for critical issues regardless of score
        if result.hasClipping {
            issues.append("Clipping detected")
        }
        
        // Only flag serious issues - be very conservative
        // Peak levels - only flag if actually clipping or dangerously close
        // Modern masters typically go to -0.1 dB, so only flag if > 0
        if result.peakLevel > 0.0 {
            issues.append("Clipping detected")
        }
        
        // Phase issues - only flag poor phase coherence
        if result.phaseCoherence < 0.25 {
            issues.append("Poor phase coherence")
        }
        
        // Stereo width - only flag extreme issues
        if result.stereoWidthScore < 10 {
            issues.append("Mono or very narrow stereo")
        } else if result.stereoWidthScore > 98 {
            issues.append("Excessive stereo width")
        }
        
        // Frequency balance - use FFT data if available, otherwise use old values
        let hasFFTData = result.frequencySpectrum != nil && !(result.frequencySpectrum?.isEmpty ?? true)
        
        if hasFFTData {
            // Use FFT-based calculation for accurate high frequency detection
            let highFreqEnergy = calculateHighFrequencyEnergy(result: result)
            
            // Only flag if truly no high frequencies (both presence and air < 0.5%)
            if highFreqEnergy < 0.5 {
                issues.append("Severe high frequency loss")
            }
        } else {
            // Fallback to old values
            let lowBalance = result.lowEndBalance
            let midBalance = result.midBalance  
            let highBalance = result.highBalance
            
            if lowBalance > 75 {
                issues.append("Excessive bass content")
            }
            
            if midBalance < 8 {
                issues.append("Severe mid deficiency")
            }
            
            if highBalance < 0.5 {
                issues.append("Severe high frequency loss")
            }
        }
        
        // Dynamic range - only flag severely compressed
        if result.dynamicRange < 2 {
            issues.append("Severely over-compressed")
        }
        
        // Loudness - only flag dangerous levels
        if result.loudnessLUFS > -5 {
            issues.append("Dangerously loud")
        } else if result.loudnessLUFS < -40 {
            issues.append("Very quiet mix")
        }
        
        return issues
    }
    
    // Helper to calculate high frequency energy from FFT spectrum
    private func calculateHighFrequencyEnergy(result: AnalysisResult) -> Double {
        guard let spectrum = result.frequencySpectrum,
              let sampleRate = result.spectrumSampleRate,
              !spectrum.isEmpty else {
            return result.highBalance
        }
        
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Double(spectrum.count)
        
        // Calculate presence (6-12 kHz) + air (12-20 kHz)
        let presenceStart = Int(6000.0 / binWidth)
        let presenceEnd = Int(12000.0 / binWidth)
        let airStart = Int(12000.0 / binWidth)
        let airEnd = min(spectrum.count - 1, Int(20000.0 / binWidth))
        
        var presenceEnergy: Double = 0
        var airEnergy: Double = 0
        
        // Calculate presence energy
        if presenceStart < presenceEnd {
            var sum: Double = 0
            for i in presenceStart...presenceEnd {
                let val = Double(spectrum[i])
                sum += val * val
            }
            presenceEnergy = sqrt(sum / Double(presenceEnd - presenceStart + 1)) * 1000
        }
        
        // Calculate air energy
        if airStart < airEnd {
            var sum: Double = 0
            for i in airStart...airEnd {
                let val = Double(spectrum[i])
                sum += val * val
            }
            airEnergy = sqrt(sum / Double(airEnd - airStart + 1)) * 1000
        }
        
        // Return average of presence and air
        return (presenceEnergy + airEnergy) / 2.0
    }

    // MARK: - Modern Issues Section

    private func modernIssuesSection(issues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.red, .orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("Issues")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Issues count badge
                HStack(spacing: 4) {
                    Text("\(issues.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.red, .orange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }

            // Issues Content
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .frame(width: 16, height: 16)

                        Text("\(index + 1). \(issue)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Modern Analysis Section (AI Summary)

    private func modernAnalysisSection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("AI Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Mastering status badge
                if result.isReadyForMastering {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                        Text("Ready")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.green, .mint]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
            }

            // AI Summary
            if let aiSummary = result.aiSummary, !aiSummary.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Summary", systemImage: "doc.text")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text(cleanMarkdownText(aiSummary))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            
            // AI Recommendations
            if !result.aiRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("AI Recommendations", systemImage: "sparkles")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(result.aiRecommendations.enumerated()), id: \.offset) { index, recommendation in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                    .font(.caption)
                                    .frame(width: 16, height: 16)

                                Text(cleanMarkdownText(recommendation))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Modern Analysis Only Section

    private func modernAnalysisOnlySection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Analysis badge
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                    Text("AI")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }

            // Analysis Content
            if let aiSummary = result.aiSummary, !aiSummary.isEmpty {
                let analysisText = extractAnalysisText(from: aiSummary)
                if !analysisText.isEmpty {
                    let analysisPoints = extractAnalysisPoints(from: analysisText)
                    if !analysisPoints.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(analysisPoints.enumerated()), id: \.offset) { index, point in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                        .frame(width: 16, height: 16)

                                    Text("\(index + 1). \(cleanMarkdownText(point))")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Modern Recommendations Only Section

    private func modernRecommendationsOnlySection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .red]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("Recommendations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Recommendations count badge
                let recommendationTexts = extractRecommendationsFromSummary(result.aiSummary) + result.aiRecommendations
                HStack(spacing: 4) {
                    Text("\(recommendationTexts.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.orange, .red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }

            // Recommendations Content
            let allRecommendations = extractRecommendationsFromSummary(result.aiSummary) + result.aiRecommendations
            if !allRecommendations.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(allRecommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .frame(width: 16, height: 16)

                            Text(cleanMarkdownText(recommendation))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Modern Strengths Section

    private func modernStrengthsSection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("Strengths")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Strengths badge
                let strengthTexts = extractStrengthsFromSummary(result.aiSummary)
                HStack(spacing: 4) {
                    Text("\(strengthTexts.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Image(systemName: "star.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }

            // Strengths Content
            let strengthTexts = extractStrengthsFromSummary(result.aiSummary)
            if !strengthTexts.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(strengthTexts.enumerated()), id: \.offset) { index, strength in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                                .frame(width: 16, height: 16)

                            Text(cleanMarkdownText(strength))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Helper Functions
    
    // Clean all markdown formatting and unwanted symbols from text
    private func cleanMarkdownText(_ text: String) -> String {
        var cleanedText = text
            // Remove all emojis and special unicode symbols (charts, icons, etc.)
            .replacingOccurrences(of: "📊|📈|📉|🎵|🎶|🎚️|🎛️|✅|❌|⚠️|🔧|💡|📌|🔍|⭐|🌟|✨|🎯|📝|🎤|🎸|🥁|🎹", with: "", options: .regularExpression)
            // Remove pipe symbols used for formatting
            .replacingOccurrences(of: "\\s*\\|\\s*", with: " ", options: .regularExpression)
            // Remove markdown headers (##, ###, ####, etc.) - applies per line
            .replacingOccurrences(of: "#{1,6}\\s*", with: "", options: .regularExpression)
            // Remove bold formatting (**text**)
            .replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression)
            // Remove italic formatting (*text*)
            .replacingOccurrences(of: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", with: "$1", options: .regularExpression)
            // Remove horizontal rules (---, ***, ___)
            .replacingOccurrences(of: "^\\s*[-*_]{3,}\\s*$", with: "", options: [.regularExpression, .anchored])
            // Remove numbered list format at start of lines (1. 2. 3. etc.)
            .replacingOccurrences(of: "^\\s*\\d+\\.\\s+", with: "", options: .regularExpression)
            // Remove leading asterisks, dashes, bullets
            .replacingOccurrences(of: "^\\s*[•\\-*]+\\s+", with: "", options: .regularExpression)
            // Remove "ANALYSIS:" prefix
            .replacingOccurrences(of: "ANALYSIS:\\s*", with: "", options: .regularExpression)
            // Remove multiple consecutive spaces
            .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
            // Remove multiple consecutive newlines
            .replacingOccurrences(of: "\\n\\s*\\n\\s*\\n+", with: "\n\n", options: .regularExpression)
            // Clean up bonus/penalty format: "| Bonus | value |" -> "Bonus: value"
            .replacingOccurrences(of: "(\\w+)\\s+(Bonus|Penalty)\\s+([-+]?\\d+)", with: "$1 $2: $3", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
    
    // MARK: - Content Parsing Functions
    
    // Check if AI summary has recommendations
    private func hasRecommendationsInSummary(_ aiSummary: String?) -> Bool {
        guard let summary = aiSummary else { return false }
        let lowercased = summary.lowercased()
        return lowercased.contains("recommendation") || lowercased.contains("should") || 
               lowercased.contains("consider") || lowercased.contains("boost") || 
               lowercased.contains("reduce") || lowercased.contains("apply")
    }
    
    // Check if AI summary has strengths
    private func hasStrengthsInSummary(_ aiSummary: String?) -> Bool {
        guard let summary = aiSummary else { return false }
        let lowercased = summary.lowercased()
        return lowercased.contains("strength") || lowercased.contains("excellent") || 
               lowercased.contains("good") || lowercased.contains("perfect") || 
               lowercased.contains("conservative") || lowercased.contains("✅")
    }
    
    // Extract analysis text (technical details, not recommendations or strengths)
    private func extractAnalysisText(from aiSummary: String) -> String {
        let lines = aiSummary.components(separatedBy: .newlines)
        var analysisLines: [String] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleanLine.lowercased()
            
            // Skip empty lines
            if cleanLine.isEmpty { continue }
            
            // Skip lines that are clearly recommendations
            if lowercased.contains("recommendation") || lowercased.contains("should") || 
               lowercased.contains("consider") || lowercased.contains("boost") || 
               lowercased.contains("reduce") || lowercased.contains("apply") ||
               lowercased.hasPrefix("- ") { continue }
            
            // Skip strength indicators
            if lowercased.contains("✅") || lowercased.contains("strength") { continue }
            
            // Include technical analysis lines
            if lowercased.contains("technically") || lowercased.contains("master") || 
               lowercased.contains("peak") || lowercased.contains("dynamic") || 
               lowercased.contains("frequency") || lowercased.contains("balance") ||
               lowercased.contains("analysis") || lowercased.contains("LUFS") ||
               lowercased.contains("professional") || lowercased.contains("standard") {
                analysisLines.append(cleanLine)
            }
        }
        
        return analysisLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Extract analysis text as individual points for structured display
    private func extractAnalysisPoints(from analysisText: String) -> [String] {
        // Split by sentences and periods to create individual points
        let sentences = analysisText.components(separatedBy: ". ")
        var points: [String] = []
        
        for sentence in sentences {
            let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanSentence.isEmpty && cleanSentence.count > 20 { // Only include substantial points
                // Add period back if it was removed during split
                let finalSentence = cleanSentence.hasSuffix(".") ? cleanSentence : cleanSentence + "."
                points.append(finalSentence)
            }
        }
        
        // If we have few points, try splitting by other delimiters
        if points.count < 2 {
            let alternativeSplit = analysisText.components(separatedBy: CharacterSet(charactersIn: ".;!"))
            points = alternativeSplit.compactMap { sentence in
                let clean = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                return clean.count > 20 ? clean + "." : nil
            }
        }
        
        // If still too few points, return the original text as a single point
        if points.count < 2 && !analysisText.isEmpty {
            return [analysisText]
        }
        
        return points
    }
    
    // Extract recommendations from AI summary
    private func extractRecommendationsFromSummary(_ aiSummary: String?) -> [String] {
        guard let summary = aiSummary else { return [] }
        
        let lines = summary.components(separatedBy: .newlines)
        var recommendations: [String] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleanLine.lowercased()
            
            // Skip empty lines
            if cleanLine.isEmpty { continue }
            
            // Look for recommendation indicators
            if lowercased.contains("boost") && lowercased.contains("khz") {
                recommendations.append(cleanLine)
            } else if lowercased.contains("apply") && lowercased.contains("gentle") {
                recommendations.append(cleanLine)
            } else if lowercased.contains("consider") {
                recommendations.append(cleanLine)
            } else if lowercased.hasPrefix("- ") && (lowercased.contains("boost") || lowercased.contains("reduce")) {
                recommendations.append(cleanLine.replacingOccurrences(of: "^- ", with: "", options: .regularExpression))
            }
        }
        
        return recommendations
    }
    
    // Extract strengths from AI summary
    private func extractStrengthsFromSummary(_ aiSummary: String?) -> [String] {
        guard let summary = aiSummary else { return [] }
        
        let lines = summary.components(separatedBy: .newlines)
        var strengths: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            let cleanedLine = cleanMarkdownText(trimmedLine)
            if cleanedLine.isEmpty { continue }
            
            let lowercased = cleanedLine.lowercased()
            
            // Look for strength indicators
            if lowercased.contains("excellent") || lowercased.contains("perfect") ||
               lowercased.contains("good") || lowercased.contains("healthy") ||
               lowercased.contains("professional") || lowercased.contains("conservative") ||
               lowercased.contains("bonus") || lowercased.contains("no clipping") {
                strengths.append(cleanedLine)
            }
        }
        
        return strengths
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
    
    private func monoCompatibilityCard(result: AnalysisResult) -> some View {
        let compatibilityPercent = result.monoCompatibility * 100
        let status: MetricCard.Status = compatibilityPercent >= 80 ? .good : compatibilityPercent >= 60 ? .warning : .error
        
        return MetricCard(
            title: "Mono Compatibility",
            icon: "speaker.wave.1",
            value: compatibilityPercent,
            unit: "%",
            status: status,
            description: monoCompatibilityDescription(result.monoCompatibility)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.purple)
                    .font(.title2)

                Text("Dynamic Range")
                    .font(.headline)

                Spacer()

                Image(systemName: result.hasDynamicRangeIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.hasDynamicRangeIssues ? .orange : .green)
            }

            // Overall Score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.dynamicRange))
                    .font(.system(size: 28, weight: .bold))

                Text("dB")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(dynamicRangeDescription(result.dynamicRange))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Peak, RMS, Loudness Metrics
            HStack(spacing: 12) {
                // Peak
                VStack(alignment: .leading, spacing: 4) {
                    Label("Peak", systemImage: "waveform.path")
                        .font(.caption.bold())
                        .foregroundStyle(result.hasClipping ? .red : result.peakLevel > -1.0 ? .orange : .green)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", result.peakLevel))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("dB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke((result.hasClipping ? Color.red : result.peakLevel > -1.0 ? Color.orange : Color.green).opacity(0.25), lineWidth: 1)
                )
                
                // RMS
                VStack(alignment: .leading, spacing: 4) {
                    Label("RMS", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.bold())
                        .foregroundStyle(result.rmsLevel > -8.0 ? .orange : result.rmsLevel < -20.0 ? .yellow : .green)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", result.rmsLevel))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("dB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke((result.rmsLevel > -8.0 ? Color.orange : result.rmsLevel < -20.0 ? Color.yellow : Color.green).opacity(0.25), lineWidth: 1)
                )
                
                // Loudness
                VStack(alignment: .leading, spacing: 4) {
                    Label("Loudness", systemImage: "gauge")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", result.loudnessLUFS))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("LUFS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
                ForEach(Array(result.recommendations.enumerated()), id: \.0) { index, recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(cleanMarkdownText(recommendation))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    // MARK: - Claude AI Insights

    private func claudeAIInsightsCard(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)

                Text("AI Analysis")
                    .font(.headline)
                
                Spacer()
                
                if result.isReadyForMastering {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            // AI Summary
            if let aiSummary = result.aiSummary, !aiSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text(cleanMarkdownText(aiSummary))
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // AI Recommendations
            if !result.aiRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Recommendations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(result.aiRecommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(cleanMarkdownText(recommendation))
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            // Mastering Status
            if result.isReadyForMastering {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text("Ready for Mastering")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }

    // MARK: - Action Buttons

    private func actionButtons(result: AnalysisResult) -> some View {
        VStack(spacing: 12) {
            Button(action: { 
                print("🔄 Re-analyze button tapped")
                print("   Current remaining: \(mockService.remainingFreeAnalyses)")
                print("   Can perform: \(mockService.canPerformAnalysis())")
                
                // Check immediately before starting task
                if !mockService.canPerformAnalysis() {
                    print("   ⚠️ Cannot perform analysis, showing paywall")
                    showPaywall = true
                    return
                }
                
                Task { await performAnalysis() } 
            }) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Label("Re-analyze", systemImage: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAnalyzing)
            
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
    
    private func monoCompatibilityDescription(_ compatibility: Double) -> String {
        switch compatibility {
        case 0.9...1.0:
            return "Excellent - Perfect mono translation"
        case 0.8..<0.9:
            return "Very Good - Minimal loss in mono"
        case 0.6..<0.8:
            return "Good - Acceptable mono playback"
        case 0.4..<0.6:
            return "Fair - Some elements may cancel"
        default:
            return "Poor - Significant phase cancellation"
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

    private func performAnalysis() async {
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
            
            // Store existing result in history before overwriting (if re-analyzing)
            if let existingResult = audioFile.analysisResult {
                print("   Found existing result, adding to history")
                audioFile.analysisHistory.append(existingResult)
            }
            
            // Perform the analysis on the specific file
            let result = try await analysisService.getDetailedAnalysis(for: audioFile.fileURL)
            
            print("   Analysis complete. Score: \(result.overallScore)")
            
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

struct AnimatedGradientLoader: View {
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
