//
//  AnalysisResultPersistence.swift
//  MixDoctor
//
//  Service for persisting analysis results to iCloud Drive as JSON files
//

import Foundation
import SwiftData

/// Handles saving and loading analysis results as JSON files in iCloud Drive
final class AnalysisResultPersistence {
    static let shared = AnalysisResultPersistence()
    
    private init() {}
    
    // MARK: - Save Analysis Result
    
    /// Saves an analysis result as a JSON file alongside the audio file
    /// - Parameters:
    ///   - result: The analysis result to save
    ///   - audioFileName: The name of the audio file (without path)
    func saveAnalysisResult(_ result: AnalysisResult, forAudioFile audioFileName: String) throws {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        // Create JSON filename based on audio filename
        let jsonFileName = analysisFileName(for: audioFileName)
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        // Convert to dictionary
        let data: [String: Any] = [
            "id": result.id.uuidString,
            "dateAnalyzed": result.dateAnalyzed.timeIntervalSince1970,
            "analysisVersion": result.analysisVersion,
            "overallScore": result.overallScore,
            "stereoWidthScore": result.stereoWidthScore,
            "phaseCoherence": result.phaseCoherence,
            "spectralCentroid": result.spectralCentroid,
            "hasClipping": result.hasClipping,
            "lowEndBalance": result.lowEndBalance,
            "lowMidBalance": result.lowMidBalance,
            "midBalance": result.midBalance,
            "highMidBalance": result.highMidBalance,
            "highBalance": result.highBalance,
            "dynamicRange": result.dynamicRange,
            "loudnessLUFS": result.loudnessLUFS,
            "peakLevel": result.peakLevel,
            "hasPhaseIssues": result.hasPhaseIssues,
            "hasStereoIssues": result.hasStereoIssues,
            "hasFrequencyImbalance": result.hasFrequencyImbalance,
            "hasDynamicRangeIssues": result.hasDynamicRangeIssues,
            "recommendations": result.recommendations,
            // Claude AI fields
            "aiSummary": result.aiSummary as Any,
            "aiRecommendations": result.aiRecommendations,
            "claudeScore": result.claudeScore as Any,
            "isReadyForMastering": result.isReadyForMastering
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        
        // Write to file
        try jsonData.write(to: jsonURL, options: .atomic)
        
        print("✅ Saved analysis result to: \(jsonFileName)")
    }
    
    // MARK: - Load Analysis Result
    
    /// Loads an analysis result from JSON file if it exists
    /// - Parameter audioFileName: The name of the audio file
    /// - Returns: The loaded analysis result, or nil if no saved result exists
    func loadAnalysisResult(forAudioFile audioFileName: String) -> AnalysisResult? {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        let jsonFileName = analysisFileName(for: audioFileName)
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        print("🔍 Looking for analysis JSON: \(jsonFileName)")
        print("   Path: \(jsonURL.path)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            print("❌ No analysis JSON found for: \(audioFileName)")
            
            // List what files ARE in the directory
            if let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
                print("   Files in directory:")
                for file in files {
                    print("   - \(file.lastPathComponent)")
                }
            }
            return nil
        }
        
        do {
            // Read JSON data
            let jsonData = try Data(contentsOf: jsonURL)
            guard let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Invalid JSON format in analysis file")
                return nil
            }
            
            // Create AnalysisResult from data
            let result = AnalysisResult(audioFile: nil, analysisVersion: data["analysisVersion"] as? String ?? "1.0")
            
            if let idString = data["id"] as? String, let id = UUID(uuidString: idString) {
                result.id = id
            }
            
            if let timestamp = data["dateAnalyzed"] as? TimeInterval {
                result.dateAnalyzed = Date(timeIntervalSince1970: timestamp)
            }
            
            result.overallScore = data["overallScore"] as? Double ?? 0
            result.stereoWidthScore = data["stereoWidthScore"] as? Double ?? 0
            result.phaseCoherence = data["phaseCoherence"] as? Double ?? 0
            result.spectralCentroid = data["spectralCentroid"] as? Double ?? 0
            result.hasClipping = data["hasClipping"] as? Bool ?? false
            result.lowEndBalance = data["lowEndBalance"] as? Double ?? 0
            result.lowMidBalance = data["lowMidBalance"] as? Double ?? 0
            result.midBalance = data["midBalance"] as? Double ?? 0
            result.highMidBalance = data["highMidBalance"] as? Double ?? 0
            result.highBalance = data["highBalance"] as? Double ?? 0
            result.dynamicRange = data["dynamicRange"] as? Double ?? 0
            result.loudnessLUFS = data["loudnessLUFS"] as? Double ?? 0
            result.peakLevel = data["peakLevel"] as? Double ?? 0
            result.hasPhaseIssues = data["hasPhaseIssues"] as? Bool ?? false
            result.hasStereoIssues = data["hasStereoIssues"] as? Bool ?? false
            result.hasFrequencyImbalance = data["hasFrequencyImbalance"] as? Bool ?? false
            result.hasDynamicRangeIssues = data["hasDynamicRangeIssues"] as? Bool ?? false
            result.recommendations = data["recommendations"] as? [String] ?? []
            
            // Load Claude AI fields
            result.aiSummary = data["aiSummary"] as? String
            result.aiRecommendations = data["aiRecommendations"] as? [String] ?? []
            result.claudeScore = data["claudeScore"] as? Int
            result.isReadyForMastering = data["isReadyForMastering"] as? Bool ?? false
            
            print("✅ Loaded analysis result for: \(audioFileName)")
            return result
            
        } catch {
            print("❌ Failed to load analysis result: \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Analysis Result
    
    /// Deletes the analysis result file from iCloud Drive
    /// - Parameter audioFileName: The name of the audio file
    func deleteAnalysisResult(forAudioFile audioFileName: String) {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()
        
        let jsonFileName = analysisFileName(for: audioFileName)
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            do {
                try FileManager.default.removeItem(at: jsonURL)
                print("✅ Deleted analysis result: \(jsonFileName)")
            } catch {
                print("❌ Failed to delete analysis result: \(error)")
            }
        }
    }
    
    // MARK: - Helper
    
    /// Generates the JSON filename for an audio file
    /// Example: "song.mp3" -> "song.mp3.analysis.json"
    private func analysisFileName(for audioFileName: String) -> String {
        return "\(audioFileName).analysis.json"
    }
}
