//
//  DatabaseCleanup.swift
//  MixDoctor
//
//  Utility to clean up orphaned database records
//

import Foundation
import SwiftData

@MainActor
class DatabaseCleanup {
    static let shared = DatabaseCleanup()
    
    private init() {}
    
    /// Remove all database records where the physical file no longer exists
    func cleanupOrphanedRecords(modelContext: ModelContext) async -> Int {
        let descriptor = FetchDescriptor<AudioFile>()
        guard let allFiles = try? modelContext.fetch(descriptor) else {
            return 0
        }
        
        var removedCount = 0
        
        for file in allFiles {
            let fileURL = file.fileURL
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            
            if !fileExists {
                print("🗑️ Removing orphaned record: \(file.fileName) - file not found at \(fileURL.path)")
                modelContext.delete(file)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            try? modelContext.save()
            print("✅ Cleaned up \(removedCount) orphaned record(s)")
        } else {
            print("✅ No orphaned records found")
        }
        
        return removedCount
    }
}
