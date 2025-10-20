//
//  DataPersistenceService.swift
//  MixDoctor
//
//  Service for managing SwiftData persistence operations
//

import Foundation
import SwiftData

@MainActor
final class DataPersistenceService {
    static let shared = DataPersistenceService()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    private init() {
        setupContainer()
    }
    
    // MARK: - Setup
    
    private func setupContainer() {
        do {
            let schema = Schema([
                AudioFile.self,
                UserPreferences.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
    }
    
    var context: ModelContext? {
        modelContext
    }
    
    // MARK: - AudioFile Operations
    
    func saveAudioFile(_ audioFile: AudioFile) throws {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        context.insert(audioFile)
        try context.save()
    }
    
    func fetchAllAudioFiles() throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func fetchAudioFiles(matching predicate: Predicate<AudioFile>) throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func deleteAudioFile(_ audioFile: AudioFile) throws {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        context.delete(audioFile)
        try context.save()
    }
    
    func deleteAudioFiles(_ audioFiles: [AudioFile]) throws {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        for audioFile in audioFiles {
            context.delete(audioFile)
        }
        
        try context.save()
    }
    
    // MARK: - Search & Filter
    
    func searchAudioFiles(query: String) throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let predicate = #Predicate<AudioFile> { file in
            file.fileName.localizedStandardContains(query) ||
            file.notes!.localizedStandardContains(query) ||
            file.tags.contains(query)
        }
        
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func fetchAudioFiles(withTag tag: String) throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let predicate = #Predicate<AudioFile> { file in
            file.tags.contains(tag)
        }
        
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateImported, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func fetchAnalyzedFiles() throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let predicate = #Predicate<AudioFile> { file in
            file.dateAnalyzed != nil
        }
        
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateAnalyzed, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func fetchFilesWithIssues() throws -> [AudioFile] {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let allFiles = try fetchAnalyzedFiles()
        return allFiles.filter { file in
            guard let result = file.analysisResult else { return false }
            return result.hasAnyIssues
        }
    }
    
    // MARK: - Statistics
    
    func calculateStatistics() throws -> Statistics {
        let allFiles = try fetchAllAudioFiles()
        let analyzedFiles = allFiles.filter { $0.dateAnalyzed != nil }
        let filesWithIssues = try fetchFilesWithIssues()
        
        let totalSize = allFiles.reduce(0) { $0 + $1.fileSize }
        
        let averageScore = analyzedFiles.isEmpty ? 0 :
            analyzedFiles.compactMap { $0.analysisResult?.overallScore }
                .reduce(0, +) / Double(analyzedFiles.count)
        
        return Statistics(
            totalFiles: allFiles.count,
            analyzedFiles: analyzedFiles.count,
            filesWithIssues: filesWithIssues.count,
            totalStorageUsed: totalSize,
            averageScore: averageScore
        )
    }
    
    // MARK: - User Preferences
    
    func fetchUserPreferences() throws -> UserPreferences {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(descriptor)
        
        if let existing = preferences.first {
            return existing
        } else {
            // Create default preferences
            let newPreferences = UserPreferences()
            context.insert(newPreferences)
            try context.save()
            return newPreferences
        }
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) throws {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        preferences.lastModified = Date()
        try context.save()
    }
    
    // MARK: - Batch Operations
    
    func deleteAllData() throws {
        guard let context = modelContext else {
            throw PersistenceError.contextNotAvailable
        }
        
        let audioFiles = try fetchAllAudioFiles()
        for file in audioFiles {
            context.delete(file)
        }
        
        try context.save()
    }
}

// MARK: - Supporting Types

enum PersistenceError: LocalizedError {
    case contextNotAvailable
    case saveFailed
    case fetchFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "Database context is not available"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .deleteFailed:
            return "Failed to delete data"
        }
    }
}

struct Statistics {
    let totalFiles: Int
    let analyzedFiles: Int
    let filesWithIssues: Int
    let totalStorageUsed: Int64
    let averageScore: Double
    
    var pendingFiles: Int {
        totalFiles - analyzedFiles
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}
