//
//  DashboardView.swift
//  MixDoctor
//
//  Main dashboard view for managing and viewing audio files
//

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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AudioFile.self, configurations: config)
    let context = container.mainContext
    
    // Create sample data
    for i in 1...5 {
        let audioFile = AudioFile(
            fileName: "Track \(i).wav",
            fileURL: URL(fileURLWithPath: "/tmp/track\(i).wav"),
            duration: Double.random(in: 120...300),
            sampleRate: 44100,
            bitDepth: 24,
            numberOfChannels: 2,
            fileSize: Int64.random(in: 10_000_000...50_000_000)
        )
        context.insert(audioFile)
    }
    
    return DashboardView()
        .modelContainer(container)
}
