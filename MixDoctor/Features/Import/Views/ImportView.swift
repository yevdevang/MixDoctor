import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var importedItems: [ImportedAudioItem] = ImportedAudioItem.mock
    @State private var isImporterPresented = false
    @State private var isShowingError = false
    @State private var errorMessage: String?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    dropZoneSection
                    metricsSection
                    guidelinesSection
                    recentImportsSection
                }
                .padding(.horizontal, AppConstants.defaultPadding)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                appendImportedItem(for: url)
            case let .failure(error):
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
        .alert("Import Failed", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong while importing the file.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add New Audio")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Select or drop files to analyze balance, loudness, and stereo performance before you mix.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var dropZoneSection: some View {
        Button {
            isImporterPresented = true
        } label: {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: AppConstants.cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                    .foregroundStyle(Color.primaryAccent.opacity(0.35))
                    .frame(height: 160)
                    .overlay(dropZoneContent)

                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(Color.primaryAccent)
                    Text("Browse files or drag & drop")
                        .font(.headline)
                        .foregroundStyle(Color.primaryAccent)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var dropZoneContent: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.primaryAccent.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(Color.primaryAccent)
                )

            VStack(spacing: 4) {
                Text("Drop audio here")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Supports WAV, AIFF, FLAC, MP3, and M4A")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.horizontal, 24)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Overview")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(MetricCard.sampleMetrics) { metric in
                    MetricCardView(metric: metric)
                }
            }
        }
    }

    private var guidelinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Guidelines")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(GuidelineItem.allGuidelines) { guideline in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: guideline.iconName)
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Color.primaryAccent)
                            .padding(8)
                            .background(Color.primaryAccent.opacity(0.1), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(guideline.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(guideline.subtitle)
                                .font(.footnote)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppConstants.cornerRadius))
        }
    }

    private var recentImportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Imports")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Button("View All") {}
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primaryAccent)
            }

            if importedItems.isEmpty {
                EmptyRecentState()
            } else {
                VStack(spacing: 12) {
                    ForEach(importedItems) { item in
                        RecentImportRow(item: item)
                    }
                }
            }
        }
    }

    private func appendImportedItem(for url: URL) {
        let newItem = ImportedAudioItem(
            name: url.lastPathComponent,
            subtitle: "Queued for analysis",
            status: .pending
        )
        importedItems.insert(newItem, at: 0)
    }
}

private struct MetricCard: Identifiable {
    enum MetricTrend {
        case up
        case down
        case steady

        var iconName: String {
            switch self {
            case .up:
                "arrow.up.right"
            case .down:
                "arrow.down.right"
            case .steady:
                "minus"
            }
        }

        var tint: Color {
            switch self {
            case .up:
                Color.green
            case .down:
                Color.red
            case .steady:
                Color.secondaryText
            }
        }
    }

    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let trend: MetricTrend

    static let sampleMetrics: [MetricCard] = [
        MetricCard(title: "Average Loudness", value: "-14.2 LUFS", caption: "Compared to last import", trend: .steady),
        MetricCard(title: "Stereo Width", value: "72%", caption: "Showing optimal balance", trend: .up),
        MetricCard(title: "Peak Level", value: "-1.1 dB", caption: "Safe headroom detected", trend: .steady),
        MetricCard(title: "Dynamic Range", value: "11 dB", caption: "Needs review", trend: .down)
    ]
}

private struct MetricCardView: View {
    let metric: MetricCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Image(systemName: metric.trend.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(metric.trend.tint)
            }

            Text(metric.value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(metric.caption)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppConstants.cornerRadius))
    }
}

private struct GuidelineItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let subtitle: String

    static let allGuidelines: [GuidelineItem] = [
        GuidelineItem(iconName: "clock", title: "Recommended duration", subtitle: "Keep mixes under 15 minutes to speed up analysis."),
        GuidelineItem(iconName: "waveform.path.ecg", title: "Optimal sample rate", subtitle: "Use 44.1kHz or 48kHz with 24-bit depth for best results."),
        GuidelineItem(iconName: "music.quarternote.3", title: "Channel balance", subtitle: "Ensure stereo tracks are bounced without mastering to avoid clipping."),
        GuidelineItem(iconName: "lock.fill", title: "Secure storage", subtitle: "Files are saved locally in the ImportedAudio folder and never shared.")
    ]
}

private struct ImportedAudioItem: Identifiable {
    enum Status {
        case pending
        case completed
        case failed

        var label: String {
            switch self {
            case .pending:
                "Pending"
            case .completed:
                "Analyzed"
            case .failed:
                "Failed"
            }
        }

        var color: Color {
            switch self {
            case .pending:
                Color.primaryAccent
            case .completed:
                Color.green
            case .failed:
                Color.red
            }
        }

        var iconName: String {
            switch self {
            case .pending:
                "clock"
            case .completed:
                "checkmark.circle.fill"
            case .failed:
                "exclamationmark.triangle"
            }
        }
    }

    let id: UUID
    let name: String
    let subtitle: String
    let status: Status
    let timestamp: Date

    init(id: UUID = UUID(), name: String, subtitle: String, status: Status, timestamp: Date = .now) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.status = status
        self.timestamp = timestamp
    }

    static let mock: [ImportedAudioItem] = [
        ImportedAudioItem(name: "LeadVox_Final.wav", subtitle: "Analyzed 5 minutes ago", status: .completed),
        ImportedAudioItem(name: "Acoustic_Guitar_02.aiff", subtitle: "Pending analysis", status: .pending),
        ImportedAudioItem(name: "DrumBus_Print.flac", subtitle: "Import failed - unsupported bit depth", status: .failed)
    ]
}

private struct RecentImportRow: View {
    let item: ImportedAudioItem

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.primaryAccent.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.headline)
                        .foregroundStyle(Color.primaryAccent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Label(item.status.label, systemImage: item.status.iconName)
                .font(.footnote.weight(.semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .foregroundStyle(item.status == .failed ? Color.red : .white)
                .background(
                    Capsule(style: .continuous)
                        .fill(item.status == .failed ? Color.red.opacity(0.12) : item.status.color.opacity(0.9))
                )
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppConstants.cornerRadius))
    }
}

private struct EmptyRecentState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Color.secondaryText)
            Text("No imports yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Start by uploading a mix to see analysis summaries and recent activity here.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppConstants.cornerRadius))
    }
}

#Preview {
    ImportView()
}
