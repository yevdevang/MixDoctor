import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ImportViewModel {
    private let importService: AudioImportService
    private let modelContext: ModelContext

    var isImporting = false
    var importProgress: Double = 0
    var importedFiles: [AudioFile] = []
    var errorMessage: String?
    var showError = false

    init(modelContext: ModelContext, importService: AudioImportService = AudioImportService()) {
        self.modelContext = modelContext
        self.importService = importService
    }

    func loadImports() {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        if let storedFiles = try? modelContext.fetch(descriptor) {
            importedFiles = storedFiles
        } else {
            importedFiles = []
        }
    }

    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        isImporting = true
        importProgress = 0
        errorMessage = nil
        showError = false
        defer { isImporting = false }

        do {
            let files = try await importService.importMultipleFiles(urls)

            for file in files {
                modelContext.insert(file)
            }

            try modelContext.save()
            loadImports()
            importProgress = 1.0
        } catch {
            if let importError = error as? AudioImportError {
                errorMessage = importError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
            importProgress = 0
        }
    }

    func removeImportedFile(_ file: AudioFile) {
        modelContext.delete(file)
        try? modelContext.save()
        importedFiles.removeAll { $0.id == file.id }
    }
}
