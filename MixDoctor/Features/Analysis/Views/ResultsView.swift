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
    @State private var showScoreGuide = false
    // MARK: - Production - Access shared instance directly
    private var subscriptionService: SubscriptionService { SubscriptionService.shared }

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
            
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

        }
        .fullScreenCover(isPresented: $isAnalyzing) {
            AnimatedGradientLoader(fileName: audioFile.fileName)
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // If paywall was dismissed without purchase, return to dashboard
            if !subscriptionService.isProUser {
                dismiss()
            } else {
                // Auto-analyze after successful purchase
                Task {
                    await performAnalysis()
                }
            }
        }) {
            PaywallView(
                onPurchaseComplete: {
                    showPaywall = false
                },
                onDismiss: {
                    showPaywall = false
                }
            )
            #if targetEnvironment(macCatalyst)
            .frame(width: 850, height: 1100)
            #endif
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showScoreGuide) {
            ScoreGuideView()
        }
        .task {
            // Load existing result immediately (already in memory, no I/O)
            if let existingResult = audioFile.analysisResult {
                analysisResult = existingResult
            } else {
                // Fallback: check if we can perform analysis
                if !subscriptionService.canPerformAnalysis() {
                    showPaywall = true
                } else {
                    // Run analysis on background thread
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
            .disabled(!subscriptionService.canPerformAnalysis() || isAnalyzing)
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

            // Genre and Mix Stage Selection
            analysisSettingsCard()

            // Overall Score Card - always show
            overallScoreCard(result: result)

            // Unmixed Track Warning Banner (if detected)
            if !result.isProfessionallyMixed {
                unmixedTrackWarningBanner(result: result)
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
            
            // Analysis Section - ALWAYS show for all tracks
            if let aiSummary = result.aiSummary, !aiSummary.isEmpty {
                modernAnalysisOnlySection(result: result)
            }

            // Recommendations Section - Show when there are AI recommendations OR detected issues
            let allRecommendations = generateAllRecommendations(result: result, detectedIssues: detectedIssues)
            if !allRecommendations.isEmpty && (!result.isProfessionallyMixed || result.overallScore < 85 || !detectedIssues.isEmpty) {
                modernRecommendationsOnlySectionWithIssues(result: result, recommendations: allRecommendations)
            }

            // Action Buttons
            actionButtons(result: result)
        }
        .padding()
    }

    // MARK: - Unmixed Detection Card
    
    private func unmixedDetectionCard(detection: UnmixedDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon - always show as unmixed/warning
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unmixed Audio Detected")
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
            
            // Detection criteria that failed - always show for unmixed audio
            if !detection.detectionCriteria.isEmpty {
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
    
    // Simple unmixed card for when detection data is missing
    private func simpleUnmixedCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                
                Text("Unmixed Audio Detected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("This audio appears to be unmixed or has significant technical issues. Apply professional mixing processing (compression, EQ, limiting) to improve quality.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }
    
    // MARK: - Analysis Settings Card
    
    private func analysisSettingsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.blue)
                
                Text("Analysis Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Genre Display (read-only)
                HStack {
                    Text("Genre:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(audioFile.genre ?? "Not set")
                        .foregroundStyle(audioFile.genre == nil ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
                
                // Mix Stage Display (read-only)
                HStack {
                    Text("Stage:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(mixStageDisplayName(audioFile.mixStage))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(AppConstants.cornerRadius)
    }
    
    private func mixStageDisplayName(_ stage: String?) -> String {
        switch stage {
        case "mix": return "Mix (Pre-Master)"
        case "master_streaming": return "Master (Streaming)"
        case "master_cd": return "Master (CD/Loud)"
        default: return "Mix (Pre-Master)"
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
                
                Button(action: {
                    showScoreGuide = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            
            // Score Circle with Modern Design
            if result.isProfessionallyMixed {
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
            } else {
                // Unmixed track - show indicator instead of score
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 12)
                        .frame(width: 160, height: 160)

                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)

                        Text("Unmixed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Score Description with Status
            VStack(spacing: 8) {
                Text(scoreDescription(result.overallScore, isProfessionallyMixed: result.isProfessionallyMixed, mixStage: audioFile.mixStage))
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
        
        // Phase issues - flag if phase coherence is below 50% (professional standard for "Problems")
        // Note: 50-70% is "Acceptable", 70%+ is "Excellent" per industry standards
        if result.phaseCoherence < 0.50 {
            issues.append("Poor phase coherence")
        }
        
        // Mono compatibility - flag if below 45% (poor mono compatibility range)
        if result.monoCompatibility < 0.45 {
            issues.append("Poor mono compatibility")
        }
        
        // Stereo width - only flag truly extreme issues
        // Metal with good mono compatibility can use 95-100% professionally
        if result.stereoWidthScore < 10 {
            issues.append("Mono or very narrow stereo")
        } else if result.stereoWidthScore > 100 {
            issues.append("Impossible stereo width value")
        }
        
        // Frequency balance - use FFT data if available, otherwise use old values
        // Capture spectrum data once to avoid SwiftData detachment errors
        let spectrum = result.frequencySpectrum
        let sampleRate = result.spectrumSampleRate
        let hasFFTData = spectrum != nil && !(spectrum?.isEmpty ?? true)
        
        if hasFFTData {
            // Use FFT-based calculation for accurate high frequency detection
            let highFreqEnergy = calculateHighFrequencyEnergy(spectrum: spectrum, sampleRate: sampleRate)
            
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
    private func calculateHighFrequencyEnergy(spectrum: [Float]?, sampleRate: Double?) -> Double {
        guard let spectrum = spectrum,
              let sampleRate = sampleRate,
              !spectrum.isEmpty else {
            return 0.0 // Return 0 if no spectrum data (will use fallback in calling function)
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

    // MARK: - Unmixed Track Warning Banner
    
    private func unmixedTrackWarningBanner(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unmixed/Raw Recording Detected")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("This track needs mixing and mastering")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("Why are all metrics showing green?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("**Technical checks passed** - no phase issues, clipping, or extreme distortion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.badge.exclamationmark")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("**Audio balance is problematic** - frequency spectrum is severely imbalanced (see Analysis below)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
            
            // What to do
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Next Steps:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text("This track needs professional mixing to balance frequencies, add compression, and optimize loudness. Check the **Recommendations** below for specific guidance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
        )
        .shadow(color: Color.orange.opacity(0.1), radius: 10, x: 0, y: 2)
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
                Text(cleanMarkdownText(aiSummary))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
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
                HStack(spacing: 4) {
                    Text("\(result.aiRecommendations.count)")
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
            if !result.aiRecommendations.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(result.aiRecommendations.enumerated()), id: \.offset) { index, recommendation in
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

    // MARK: - Generate All Recommendations (AI + Issue-based)

    private func generateAllRecommendations(result: AnalysisResult, detectedIssues: [String]) -> [String] {
        var recommendations: [String] = []

        // Start with AI recommendations - these are the primary source
        recommendations.append(contentsOf: result.aiRecommendations)

        // If AI generated recommendations, use them primarily
        // Only add fallback recommendations for issues NOT covered by AI
        let hasAIRecommendations = !result.aiRecommendations.isEmpty

        // Helper to check if an issue is already addressed by AI
        func isIssueCoveredByAI(_ keywords: [String]) -> Bool {
            guard hasAIRecommendations else { return false }
            return result.aiRecommendations.contains { rec in
                let lower = rec.lowercased()
                return keywords.contains { lower.contains($0) }
            }
        }

        // Generate fallback recommendations for detected issues
        // ONLY if AI didn't cover them
        // Written like top mix engineers (Dave Pensado, CLA, Tony Maserati, Manny Marroquin)
        for issue in detectedIssues {
            let recommendation: String?
            let keywords: [String]

            switch issue {
            case "Clipping detected":
                keywords = ["clip", "red", "limit", "headroom", "peak"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "You're hitting the reds - pull back that output gain and check your limiters. Leave some headroom for the mastering engineer to work with."

            case "Poor phase coherence":
                keywords = ["phase", "cancellation", "coherence", "flip"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "There's phase cancellation going on here. Check your stereo sources, parallel processing, and any mic placements. Flip the phase on your bass or kick and see what tightens up."

            case "Poor mono compatibility":
                keywords = ["mono", "collapse", "compatibility", "narrow"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "This mix is going to collapse on mono systems - club PAs, phones, portable speakers. Check your wide stereo elements and consider narrowing anything below 200Hz."

            case "Mono or very narrow stereo":
                keywords = ["stereo", "narrow", "width", "dimension", "panning"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "This mix is living in a shoebox. Open it up - use panning, stereo delays, or subtle widening on your elements to create some dimension."

            case "Excessive bass content":
                keywords = ["bass", "low end", "low-end", "sub", "kick"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "The low end is running the show here. Reign in that bass - high-pass some elements, tame the sub, and let the rest of the mix breathe. The kick and bass are fighting instead of working together."

            case "Severe mid deficiency":
                keywords = ["mid", "hollow", "scooped", "body", "500hz", "2khz"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "Where did the mids go? This mix is scooped out and hollow. Bring back some body in the 500Hz-2kHz range - that's where the soul of the mix lives."

            case "Severe high frequency loss":
                keywords = ["high", "bright", "air", "sparkle", "presence", "dark"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "This mix is dark and lifeless up top. Add some air and presence - open up those highs above 8kHz to give it some sparkle and life."

            case "Severely over-compressed":
                keywords = ["compress", "crush", "dynamic", "squash", "breath"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "You've crushed the life out of this mix. Back off the compression and limiting - let it breathe and have some dynamics. Music needs movement."

            case "Dangerously loud":
                keywords = ["loud", "hot", "fatigue", "pull back"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "This is way too hot. You're sacrificing dynamics and causing listener fatigue. Pull it back and let the mastering engineer handle the final loudness."

            case "Very quiet mix":
                keywords = ["quiet", "level", "gain"]
                recommendation = isIssueCoveredByAI(keywords) ? nil :
                    "This mix is too quiet to evaluate properly. Bring up the overall level while keeping your dynamics intact."

            default:
                recommendation = nil
                keywords = []
            }

            if let rec = recommendation {
                recommendations.append(rec)
            }
        }

        // Also check frequency bands directly for issues not in detectedIssues
        // Bass at 100% or close to it - only if not already covered
        if result.lowEndBalance > 60 && !detectedIssues.contains("Excessive bass content") {
            let bassKeywords = ["bass", "low end", "low-end", "sub"]
            if !isIssueCoveredByAI(bassKeywords) && !recommendations.contains(where: { $0.lowercased().contains("bass") || $0.lowercased().contains("low end") }) {
                let bassRec = "The bass is dominating at \(Int(result.lowEndBalance))% of the frequency spectrum. Let the other elements have some room - a mix is a team, not a solo act."
                recommendations.append(bassRec)
            }
        }

        // High frequencies too prominent
        if result.highBalance > 25 {
            let highRec = "The highs are sizzling at \(Int(result.highBalance))%. Tame that top end before it becomes fatiguing - think smooth and present, not harsh and brittle."
            if !recommendations.contains(where: { $0.lowercased().contains("high") || $0.lowercased().contains("bright") || $0.lowercased().contains("sizzle") }) {
                recommendations.append(highRec)
            }
        }

        return recommendations
    }

    // MARK: - Modern Recommendations Section with Issues

    private func modernRecommendationsOnlySectionWithIssues(result: AnalysisResult, recommendations: [String]) -> some View {
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
                HStack(spacing: 4) {
                    Text("\(recommendations.count)")
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
            if !recommendations.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
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

    private func scoreDescription(_ score: Double, isProfessionallyMixed: Bool, mixStage: String?) -> String {
        let isMaster = mixStage == "master_streaming" || mixStage == "master_cd"
        let qualityType = isMaster ? "Master" : "Mix"

        // If unmixed, don't show positive quality labels
        if !isProfessionallyMixed {
            switch score {
            case 70...100: return "Unmixed - Needs Processing"
            case 50..<70: return "Unmixed - Raw Recording"
            default: return "Unmixed - Needs Work"
            }
        }

        switch score {
        case 85...100: return "Excellent \(qualityType) Quality"
        case 70..<85: return "Good \(qualityType) Quality"
        case 50..<70: return "Fair \(qualityType) Quality"
        default: return "Needs Improvement"
        }
    }

    // MARK: - Metric Cards

    private func stereoWidthCard(result: AnalysisResult) -> some View {
        // Only hide issues for truly excellent scores (90+), not just good scores (85+)
        let hideIssues = (result.overallScore >= 90)
        
        // Get genre-aware description
        let genre = audioFile.genre
        let description = hideIssues ? "" : stereoWidthDescription(result.stereoWidthScore, genre: genre)
        
        return MetricCard(
            title: "Stereo Width",
            icon: "arrow.left.and.right",
            value: result.stereoWidthScore,
            unit: "%",
            status: hideIssues ? .good : (result.hasStereoIssues ? .warning : .good),
            description: description
        )
    }

    private func phaseCoherenceCard(result: AnalysisResult) -> some View {
        // Genre-aware phase coherence status (aligned with AudioKitService.swift logic)
        let minPhaseCoherenceForGenre: Double
        let genreLower = audioFile.genre?.lowercased() ?? ""
        
        // FIXED: Handle compound genres like "EDM/Electronic", "Rock/Indie", etc.
        if genreLower.contains("edm") || genreLower.contains("electronic") || genreLower.contains("hip") || genreLower.contains("rap") || genreLower.contains("trap") || genreLower.contains("dance") || genreLower.contains("techno") || genreLower.contains("dubstep") {
            minPhaseCoherenceForGenre = 0.50  // 50% - Tight, centered mix
        } else if genreLower.contains("pop") || genreLower.contains("r&b") || genreLower.contains("soul") {
            minPhaseCoherenceForGenre = 0.45  // 45% - Balanced commercial width
        } else if genreLower.contains("rock") || genreLower.contains("indie") || genreLower.contains("metal") || genreLower.contains("punk") || genreLower.contains("alternative") {
            minPhaseCoherenceForGenre = 0.40  // 40% - Moderate (wide guitars acceptable)
        } else if genreLower.contains("country") || genreLower.contains("folk") {
            minPhaseCoherenceForGenre = 0.40  // 40% - Moderate (natural acoustic spread)
        } else if genreLower.contains("jazz") || genreLower.contains("blues") {
            minPhaseCoherenceForGenre = 0.30  // 30% - Lower (natural room ambience, wide soundstage)
        } else if genreLower.contains("classical") || genreLower.contains("orchestral") {
            minPhaseCoherenceForGenre = 0.25  // 25% - Low (wide stereo imaging is essential)
        } else if genreLower.contains("ambient") || genreLower.contains("drone") || genreLower.contains("experimental") {
            minPhaseCoherenceForGenre = 0.20  // 20% - Very Low (artistic wide stereo)
        } else if genreLower.contains("acoustic") || genreLower.contains("singer") {
            minPhaseCoherenceForGenre = 0.35  // 35% - Moderate (intimate but natural)
        } else {
            minPhaseCoherenceForGenre = 0.35  // 35% - Conservative default
        }
        
        // Determine status based on genre-aware threshold
        // ALIGNED WITH DESCRIPTION LOGIC:
        // - Below minimum: Red error (severe issues)
        // - Minimum to (minimum + 0.15): Green good ("Good phase coherence")
        // - Above (minimum + 0.15): Green good ("Excellent phase coherence")
        let status: MetricCard.Status
        if result.phaseCoherence < minPhaseCoherenceForGenre {
            status = .error  // Below minimum = severe phase issues
        } else if result.phaseCoherence < (minPhaseCoherenceForGenre + 0.15) {
            status = .good  // ✅ FIXED: "Good" description should show green checkmark!
        } else {
            status = .good  // Excellent phase = green checkmark
        }
        
        return MetricCard(
            title: "Phase Coherence",
            icon: "waveform.path",
            value: result.phaseCoherence * 100,
            unit: "%",
            status: status,
            description: phaseDescription(result.phaseCoherence, genre: audioFile.genre)
        )
    }
    
    private func monoCompatibilityCard(result: AnalysisResult) -> some View {
        let compatibilityPercent = result.monoCompatibility * 100
        // Only hide issues for truly excellent scores (90+)
        let hideIssues = (result.overallScore >= 90)
        let status: MetricCard.Status = hideIssues ? .good : (compatibilityPercent >= 60 ? .good : .error)
        
        return MetricCard(
            title: "Mono Compatibility",
            icon: "speaker.wave.1",
            value: compatibilityPercent,
            unit: "%",
            status: status,
            description: hideIssues ? "" : monoCompatibilityDescription(result.monoCompatibility)
        )
    }

    private func frequencyBalanceCard(result: AnalysisResult) -> some View {
        
        // Use score-based logic: ≥80% = good (green), <80% = issue (red)
        let isBalanced = result.frequencyBalanceScore >= 80
        // Only hide issues for truly excellent scores (90+)
        let hideIssues = (result.overallScore >= 90)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)

                Text("Frequency Balance")
                    .font(.headline)

                Spacer()

                if !hideIssues {
                    Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isBalanced ? .green : .red)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.frequencyBalanceScore))
                    .font(.system(size: 32, weight: .bold))

                Text("%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if !hideIssues {
                Text(frequencyBalanceDescription(result.frequencyBalanceScore))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
        // Only hide issues for truly excellent scores (90+)
        let hideIssues = (result.overallScore >= 90)
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.purple)
                    .font(.title2)

                Text("Dynamic Range")
                    .font(.headline)

                Spacer()

                if !hideIssues {
                    Image(systemName: result.hasDynamicRangeIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(result.hasDynamicRangeIssues ? .red : .green)
                }
            }

            // Overall Score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.dynamicRange))
                    .font(.system(size: 28, weight: .bold))

                Text("dB")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !hideIssues {
                    Text(dynamicRangeDescription(result.dynamicRange))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Peak, RMS, Loudness Metrics
            HStack(spacing: 12) {
                // Peak
                VStack(alignment: .leading, spacing: 4) {
                    Label("Peak", systemImage: "waveform.path")
                        .font(.caption.bold())
                        .foregroundStyle(result.hasClipping ? .red : .green)
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
                        .stroke((result.hasClipping ? Color.red : Color.green).opacity(0.25), lineWidth: 1)
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
            Button(role: .destructive, action: { 
                deleteFile()
            }) {
                Label("Delete File", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isAnalyzing || audioFile.isDemoFile)
        }
    }

    // MARK: - Helper Functions

    private func stereoWidthDescription(_ width: Double, genre: String?) -> String {
        // Define genre-specific expectations (same as backend logic)
        let minExpected: Double
        let maxExpected: Double
        
        switch genre?.lowercased() {
        case "hip-hop", "hip hop", "rap", "trap", "edm", "dance", "techno":
            minExpected = 15  // 15% - Can be very mono-focused
            maxExpected = 60  // 60% - Avoid overly wide mixes
        case "pop", "r&b", "soul", "country", "folk":
            minExpected = 25  // 25% - Good balance
            maxExpected = 75  // 75% - Commercial width
        case "rock", "rock/indie", "indie", "metal", "punk", "alternative":
            minExpected = 15  // 15% - Modern rock can be narrow (bass-heavy)
            maxExpected = 100  // 100% - Extremely wide IS professional for metal (Korn masters use 99%+)
        case "jazz", "blues", "acoustic", "singer-songwriter":
            minExpected = 35  // 35% - Natural, spacious
            maxExpected = 90  // 90% - Live feel
        case "classical", "orchestral", "ambient", "drone", "experimental":
            minExpected = 40  // 40% - Wide, immersive soundstage
            maxExpected = 120 // 120% - Very wide, artistic
        default:
            minExpected = 20  // 20% - Default conservative
            maxExpected = 80  // 80% - Default conservative
        }
        
        // Generate description based on genre context
        if width < minExpected {
            return "Narrow for \(genre ?? "this genre") - consider widening"
        } else if width > maxExpected {
            return "Very wide for \(genre ?? "this genre") - check mono compatibility"
        } else if width < (minExpected + maxExpected) / 2 {
            return "Good stereo width for \(genre ?? "this genre")"
        } else {
            return "Wide stereo image - great for \(genre ?? "this genre")"
        }
    }

    private func phaseDescription(_ coherence: Double, genre: String?) -> String {
        // Genre-aware phase coherence descriptions
        let minExpected: Double
        let genreName = genre ?? "this genre"
        let genreLower = genre?.lowercased() ?? ""
        
        // FIXED: Handle compound genres like "EDM/Electronic", "Rock/Indie", etc.
        if genreLower.contains("edm") || genreLower.contains("electronic") || genreLower.contains("hip") || genreLower.contains("rap") || genreLower.contains("trap") || genreLower.contains("dance") || genreLower.contains("techno") || genreLower.contains("dubstep") {
            minExpected = 0.50  // 50% minimum
        } else if genreLower.contains("pop") || genreLower.contains("r&b") || genreLower.contains("soul") {
            minExpected = 0.45  // 45% minimum
        } else if genreLower.contains("rock") || genreLower.contains("indie") || genreLower.contains("metal") || genreLower.contains("punk") || genreLower.contains("alternative") {
            minExpected = 0.40  // 40% minimum
        } else if genreLower.contains("country") || genreLower.contains("folk") {
            minExpected = 0.40  // 40% minimum
        } else if genreLower.contains("jazz") || genreLower.contains("blues") {
            minExpected = 0.30  // 30% minimum - wide soundstage is normal
        } else if genreLower.contains("classical") || genreLower.contains("orchestral") {
            minExpected = 0.25  // 25% minimum - very wide is expected
        } else if genreLower.contains("ambient") || genreLower.contains("drone") || genreLower.contains("experimental") {
            minExpected = 0.20  // 20% minimum - artistic wide stereo
        } else if genreLower.contains("acoustic") || genreLower.contains("singer") {
            minExpected = 0.35  // 35% minimum
        } else {
            minExpected = 0.35  // 35% default
        }
        
        // Generate description based on genre-specific threshold
        if coherence < 0 {
            return "Severe phase cancellation"
        } else if coherence < minExpected {
            return "Poor phase coherence - mono cancellation risk"
        } else if coherence < (minExpected + 0.15) {
            return "Good phase coherence for \(genreName)"
        } else if coherence < 0.8 {
            return "Excellent phase coherence for \(genreName)"
        } else {
            return "Perfect phase alignment - very tight stereo"
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
        
        guard subscriptionService.canPerformAnalysis() else {
            showPaywall = true
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Log analysis started event
        AnalyticsService.log(.analysisStarted)

        do {
            
            // Store existing result in history before overwriting (if re-analyzing)
            if let existingResult = audioFile.analysisResult {
                audioFile.analysisHistory.append(existingResult)
            }
            
            // Perform the analysis completely off the main thread to prevent UI freezing
            let fileURL = audioFile.fileURL
            let genre = audioFile.genre
            let mixStage = audioFile.mixStage
            let result = try await Task.detached(priority: .userInitiated) {
                try await AudioKitService.shared.getDetailedAnalysis(for: fileURL, genre: genre, mixStage: mixStage)
            }.value
            
            
            // Increment usage count for free users (back on main thread)
            subscriptionService.incrementAnalysisCount()
            
            // Log free analysis count event
            let remainingFree = subscriptionService.remainingFreeAnalyses
            AnalyticsService.log(.freeAnalysisCount, parameters: [
                "remaining": String(remainingFree)
            ])
            
            // Update the local state
            analysisResult = result
            
            // Save to the persistent AudioFile model
            audioFile.analysisResult = result
            audioFile.dateAnalyzed = Date()
            
            // Log analysis completed event
            let usedCount = subscriptionService.isProUser ? 
                (50 - subscriptionService.remainingProAnalyses) : 
                (4 - subscriptionService.remainingFreeAnalyses)
            AnalyticsService.log(.analysisCompleted, parameters: [
                "score": String(format: "%.1f", result.overallScore),
                "analysis_count": String(usedCount)
            ])
            
            // Save to SwiftData and iCloud Drive on background thread to avoid freezing
            let fileName = audioFile.fileName
            let isDemo = audioFile.isDemoFile

            // Save to SwiftData first (synchronously on main actor)
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to save analysis result to SwiftData: \(error.localizedDescription)")
            }

            // Save to iCloud Drive as JSON for cross-device sync (background)
            Task.detached(priority: .utility) {
                do {
                    try AnalysisResultPersistence.shared.saveAnalysisResult(result, forAudioFile: fileName, isDemo: isDemo)
                    print("✅ Successfully saved analysis result to JSON for \(fileName)")
                } catch {
                    print("❌ Failed to save analysis result to JSON for \(fileName): \(error.localizedDescription)")
                }
            }
            
        } catch {
            AnalyticsService.log(.analysisFailed, parameters: [
                "error": error.localizedDescription
            ])
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteFile() {
        
        // Delete the actual audio file from storage (iCloud or local)
        // Using iCloudStorageService ensures proper eviction and cross-device sync
        let fileURL = audioFile.fileURL
        let fileName = audioFile.fileName
        let isDemo = audioFile.isDemoFile

        // Perform file deletion on background thread to avoid UI freezing
        Task.detached(priority: .utility) {
            do {
                try iCloudStorageService.shared.deleteAudioFile(at: fileURL)
                print("🗑️ Deleted file: \(fileName)")
            } catch {
                print("❌ Failed to delete file \(fileName): \(error.localizedDescription)")
            }

            // Delete the analysis result JSON from iCloud Drive
            AnalysisResultPersistence.shared.deleteAnalysisResult(forAudioFile: fileName, isDemo: isDemo)
        }
        
        // Delete the SwiftData record immediately (CloudKit will sync this deletion)
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

// Simple loader for MacCatalyst - no complex animations
struct SimpleAnalysisLoader: View {
    let fileName: String
    
    var body: some View {
        ZStack {
            // Solid background - no animations
            Color.primaryAccent
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // System progress indicator - native and lightweight
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(2.0)
                    .tint(.white)
                
                VStack(spacing: 12) {
                    Text("Analyzing Audio")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("Please wait while we analyze your mix...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(2)
                }
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnimatedGradientLoader: View {
    let fileName: String
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var dotScale: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var progressTracker = AnalysisProgressTracker.shared
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.primaryAccent, // Purple
                    Color(red: 0.6, green: 0.3, blue: 0.95),      // Light purple
                    Color(red: 0.2, green: 0.8, blue: 0.6),       // Green/Teal
                    Color.primaryAccent  // Purple again
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(.degrees(animationOffset))
            .ignoresSafeArea()
            .task {
                // Use task instead of onAppear for async animations
                await startAnimations()
            }
            
            // Content overlay
            VStack(spacing: 24) {
                // Pulsing circle with waveform icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                    
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    Text("Analyzing Audio")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    // Progress bar with percentage
                    VStack(spacing: 8) {
                        ProgressView(value: progressTracker.progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(maxWidth: 280)
                            .scaleEffect(x: 1.0, y: 2.0)  // Make it thicker
                        
                        HStack(spacing: 12) {
                            Text("\(Int(progressTracker.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.9))
                                .monospacedDigit()
                            
                            #if DEBUG
                            // Timer - Debug mode only
                            Text("⏱ \(progressTracker.formattedElapsedTime)")
                                .font(.caption.bold())
                                .foregroundColor(.yellow)
                                .monospacedDigit()
                            #endif
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Current step
                    Text(progressTracker.currentStep)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(height: 40)  // Fixed height to prevent jumping
                        .padding(.horizontal, 20)
                    
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(2)
                }
                
                // Loading indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScale[index])
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Prevent user interaction but allow animations
        .allowsHitTesting(false)
    }
    
    private func startAnimations() async {
        // Start gradient rotation
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: false)
        ) {
            animationOffset = 360
        }
        
        // Start pulse animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.2
        }
        
        // Start dot animations with delays
        for index in 0..<3 {
            try? await Task.sleep(nanoseconds: UInt64(index) * 200_000_000) // 0.2s delay per dot
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
            ) {
                dotScale[index] = 0.5
            }
        }
    }
}

// MARK: - Score Guide View
struct ScoreGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Understanding Your Score")
                            .font(.title2.bold())

                        Text("Scores depend on your selected Mix Stage. Masters and Mixes have different scoring ranges.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Tab Picker for Track Type
                    Picker("Track Type", selection: $selectedTab) {
                        Text("Master").tag(0)
                        Text("Mix").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Score Ranges based on selected tab
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0: // Master
                            masterScoreRanges
                        case 1: // Mix
                            mixScoreRanges
                        default:
                            masterScoreRanges
                        }
                    }

                    // Stage Explanation
                    stageExplanationCard

                    // Key Scoring Factors
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Scoring Factors")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            scoreFactorRow(icon: "speaker.wave.3.fill", title: "Loudness (LUFS)", description: "Streaming: -14 to -16 LUFS. CD/Loud: -6 to -9 LUFS")
                            scoreFactorRow(icon: "waveform.path.ecg", title: "Dynamic Range", description: "Streaming: 8-12 dB. CD/Loud: 4-6 dB. Mix: 8-15 dB")
                            scoreFactorRow(icon: "gauge.with.dots.needle.67percent", title: "Peak Levels", description: "Optimal: -1 to 0 dB. Clipping heavily penalized")
                            scoreFactorRow(icon: "waveform", title: "Frequency Balance", description: "Genre-appropriate distribution across spectrum")
                            scoreFactorRow(icon: "circle.lefthalf.filled", title: "Stereo Width", description: "25-85% typical. Metal/Rock can use 95%+ with good mono")
                            scoreFactorRow(icon: "waveform.path", title: "Phase Coherence", description: "EDM: 50%+, Pop: 45%+, Rock: 40%+, Jazz: 30%+")
                            scoreFactorRow(icon: "speaker.wave.1", title: "Mono Compatibility", description: "Good: 60%+. Metal/EDM: 45%+ acceptable")
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)

                    // Professional Standards
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Professional Standards")
                                .font(.subheadline.bold())
                        }

                        Text("Commercial masters (Korn, Metallica, etc.) typically score 96-100. They have optimized loudness, controlled dynamics, excellent stereo imaging, and genre-appropriate frequency balance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                    .padding(.horizontal)

                    // Genre-Aware Analysis
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .foregroundStyle(.purple)
                            Text("Genre-Aware Analysis")
                                .font(.subheadline.bold())
                        }

                        Text("Scoring adapts to your genre. Metal/Rock allows wide stereo and bass-heavy mixes. EDM/Hip-Hop expects heavy low end. Jazz/Classical preserves wide dynamics. Select your genre for accurate scoring.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.1))
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Master Score Ranges
    private var masterScoreRanges: some View {
        VStack(spacing: 16) {
            scoreRangeCard(
                range: "96-100",
                title: "Exceptional Commercial Master",
                description: "Commercial release quality (Korn, Metallica, Abbey Road). Optimal loudness, perfect dynamics, excellent stereo imaging.",
                color: .green,
                icon: "checkmark.seal.fill"
            )

            scoreRangeCard(
                range: "92-95",
                title: "Excellent Professional Master",
                description: "High-quality professional mastering. Ready for release with minor refinements possible.",
                color: Color(red: 0.3, green: 0.8, blue: 0.3),
                icon: "star.fill"
            )

            scoreRangeCard(
                range: "88-91",
                title: "Very Good Professional Master",
                description: "Professional quality with small imperfections. Suitable for release.",
                color: Color(red: 0.4, green: 0.7, blue: 0.4),
                icon: "star.leadinghalf.filled"
            )

            scoreRangeCard(
                range: "85-87",
                title: "Good Master",
                description: "Solid mastering work with some areas for improvement. Ready for release.",
                color: .orange,
                icon: "waveform.circle.fill"
            )

            scoreRangeCard(
                range: "75-84",
                title: "Amateur/Flawed Master",
                description: "Needs mastering polish. May have issues with loudness, dynamics, or balance.",
                color: Color(red: 1.0, green: 0.5, blue: 0.0),
                icon: "exclamationmark.triangle.fill"
            )

            scoreRangeCard(
                range: "Below 75",
                title: "Poor Mastering",
                description: "Significant problems requiring re-mastering or professional help.",
                color: .red,
                icon: "xmark.circle.fill"
            )
        }
    }

    // MARK: - Mix Score Ranges
    private var mixScoreRanges: some View {
        VStack(spacing: 16) {
            // Note about max score
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Mixes are capped at 90 points maximum")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)

            scoreRangeCard(
                range: "85-90",
                title: "Professional Mix",
                description: "Ready for mastering. Clean, balanced, and well-prepared. This is the best a pre-master mix can achieve.",
                color: .green,
                icon: "checkmark.seal.fill"
            )

            scoreRangeCard(
                range: "78-84",
                title: "Strong Amateur Mix",
                description: "Good quality but needs some polish before mastering. Minor balance or dynamics issues.",
                color: Color(red: 0.4, green: 0.8, blue: 0.4),
                icon: "star.fill"
            )

            scoreRangeCard(
                range: "68-77",
                title: "Decent Mix",
                description: "Needs significant work before mastering. Review recommendations for improvements.",
                color: .orange,
                icon: "waveform.circle.fill"
            )

            scoreRangeCard(
                range: "50-67",
                title: "Weak Mix",
                description: "Major issues requiring substantial mixing improvements. Not ready for mastering.",
                color: Color(red: 1.0, green: 0.5, blue: 0.0),
                icon: "exclamationmark.triangle.fill"
            )

            scoreRangeCard(
                range: "Below 50",
                title: "Critical Issues",
                description: "Severe problems. May need re-recording or major repair work.",
                color: .red,
                icon: "xmark.circle.fill"
            )
        }
    }

    // MARK: - Recording Score Ranges
    private var unmixedScoreRanges: some View {
        VStack(spacing: 16) {
            // Note about detection and max score
            HStack(spacing: 8) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Raw recordings are capped at 75 points maximum")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal)

            scoreRangeCard(
                range: "70-75",
                title: "Excellent Raw Recording",
                description: "Very clean recording, well-captured, ready for professional mixing. Best possible score for unmixed audio.",
                color: .green,
                icon: "checkmark.circle.fill"
            )

            scoreRangeCard(
                range: "65-69",
                title: "Good Recording",
                description: "Standard raw recording quality. Suitable for mixing with standard techniques.",
                color: Color(red: 0.4, green: 0.8, blue: 0.4),
                icon: "star.fill"
            )

            scoreRangeCard(
                range: "60-64",
                title: "Acceptable Recording",
                description: "Some issues but workable. Will require careful mixing to address problems.",
                color: .orange,
                icon: "waveform.circle.fill"
            )

            scoreRangeCard(
                range: "50-59",
                title: "Poor Recording",
                description: "Significant issues. Will require extensive work in mixing to salvage.",
                color: Color(red: 1.0, green: 0.5, blue: 0.0),
                icon: "exclamationmark.triangle.fill"
            )

            scoreRangeCard(
                range: "Below 50",
                title: "Very Poor Recording",
                description: "Major recording problems. Consider re-recording if possible.",
                color: .red,
                icon: "xmark.circle.fill"
            )

            // Detection explanation
            VStack(spacing: 8) {
                Text("How Raw Recordings Are Detected")
                    .font(.subheadline.bold())

                Text("Mix Doctor automatically detects raw recordings based on: very low loudness (<-16 LUFS), excessive dynamic range (>14 dB), poor frequency balance, and high crest factor (>12 dB).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Stage Explanation Card
    private var stageExplanationCard: some View {
        VStack(spacing: 12) {
            Text("Why Stage Matters")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 8) {
                stageRow(
                    stage: "Master (Streaming)",
                    target: "-14 to -16 LUFS",
                    maxScore: "100",
                    color: .green
                )
                stageRow(
                    stage: "Master (CD/Loud)",
                    target: "-6 to -9 LUFS",
                    maxScore: "100",
                    color: .green
                )
                stageRow(
                    stage: "Mix (Pre-Master)",
                    target: "-16 to -23 LUFS",
                    maxScore: "90",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private func stageRow(stage: String, target: String, maxScore: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(stage)
                .font(.caption.bold())
                .frame(width: 120, alignment: .leading)

            Text(target)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Max: \(maxScore)")
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
    
    private func scoreRangeCard(range: String, title: String, description: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(range)
                        .font(.headline)
                        .foregroundStyle(color)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.subheadline.bold())
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    private func scoreFactorRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}
