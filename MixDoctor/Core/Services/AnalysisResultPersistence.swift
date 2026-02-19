//
//  AnalysisResultPersistence.swift
//  MixDoctor
//
//  Service for persisting analysis results to iCloud Drive as JSON files
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Handles saving and loading analysis results as JSON files in iCloud Drive
final class AnalysisResultPersistence {
    static let shared = AnalysisResultPersistence()
    
    private init() {}
    
    // MARK: - Save Analysis Result
    
    /// Saves an analysis result as a JSON file alongside the audio file
    /// - Parameters:
    ///   - result: The analysis result to save
    ///   - audioFileName: The name of the audio file (without path)
    func saveAnalysisResult(_ result: AnalysisResult, forAudioFile audioFileName: String, isDemo: Bool = false) throws {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()

        // Create JSON filename based on audio filename
        let jsonFileName = analysisFileName(for: audioFileName, isDemo: isDemo)
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
            "isReadyForMastering": result.isReadyForMastering,
            // FFT spectrum data for visualization
            "frequencySpectrum": result.frequencySpectrum as Any,
            "spectrumSampleRate": result.spectrumSampleRate as Any,
            "rmsLevel": result.rmsLevel,
            // Unmixed detection fields
            "isProfessionallyMixed": result.isProfessionallyMixed,
            "monoCompatibility": result.monoCompatibility,
            "unmixedDetectionData": result.unmixedDetectionData?.base64EncodedString() as Any
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        
        // Check if we're saving to iCloud directory
        let isICloudDirectory = jsonURL.path.contains("Mobile Documents") || jsonURL.path.contains("iCloud~")
        
        print("💾 Saving analysis JSON for: \(audioFileName)")
        print("   Destination: \(jsonURL.path)")
        print("   Is iCloud directory: \(isICloudDirectory)")
        
        // Check if we're using iCloud
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let isActuallyICloud = isICloudDirectory && iCloudEnabled && service.iCloudContainerURL != nil
        
        if isActuallyICloud {
            print("   ✅ Using iCloud - will mark file as ubiquitous")
            let iCloudContainerURL = service.iCloudContainerURL!
            print("   iCloud container URL: \(iCloudContainerURL.path)")
            
            // Ensure destination directory exists
            let destinationDir = jsonURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                do {
                    try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
                    print("   ✅ Created directory: \(destinationDir.path)")
                } catch {
                    print("   ⚠️ Failed to create directory: \(error.localizedDescription)")
                    throw error
                }
            }
            
            // For iCloud: Write to temp first, then use setUbiquitous
            // This is REQUIRED for files to sync to iCloud Drive
            let tempDir = FileManager.default.temporaryDirectory
            let uniqueTempName = "\(UUID().uuidString)_\(jsonFileName)"
            let tempURL = tempDir.appendingPathComponent(uniqueTempName)
            
            do {
                // Step 1: Write to temporary location
                try jsonData.write(to: tempURL, options: .atomic)
                print("   ✅ Step 1: Wrote to temp: \(tempURL.path)")
                
                // Step 2: Remove existing file if it exists (setUbiquitous requires clean destination)
                if FileManager.default.fileExists(atPath: jsonURL.path) {
                    try FileManager.default.removeItem(at: jsonURL)
                    print("   ✅ Step 2: Removed existing file")
                }
                
                // Step 3: Use setUbiquitous to move to iCloud and mark as ubiquitous
                // This is CRITICAL - without this, files won't sync
                try FileManager.default.setUbiquitous(true, itemAt: tempURL, destinationURL: jsonURL)
                print("   ✅ Step 3: Called setUbiquitous - file should now sync to iCloud")
                
                // Step 4: Wait for file system to process
                Thread.sleep(forTimeInterval: 0.5)
                
                // Step 5: Verify file exists
                if FileManager.default.fileExists(atPath: jsonURL.path) {
                    print("   ✅ Step 4: File exists at destination: \(jsonURL.path)")
                    
                    // Step 6: Verify iCloud status
                    do {
                        let resourceValues = try jsonURL.resourceValues(forKeys: [
                            .isUbiquitousItemKey,
                            .ubiquitousItemIsUploadedKey
                        ])
                        
                        let isUbiquitous = resourceValues.isUbiquitousItem ?? false
                        let isUploaded = resourceValues.ubiquitousItemIsUploaded ?? false
                        
                        print("   📊 Final Status:")
                        print("      - File Path: \(jsonURL.path)")
                        print("      - Is Ubiquitous: \(isUbiquitous ? "✅ YES" : "❌ NO")")
                        print("      - Is Uploaded: \(isUploaded ? "✅ YES" : "⏳ PENDING")")
                        
                        if !isUbiquitous {
                            print("   ⚠️ CRITICAL: File is NOT marked as ubiquitous!")
                            print("   ⚠️ This means it will NOT sync to iCloud Drive")
                            print("   ⚠️ File exists locally but won't appear in iCloud")
                        }
                    } catch {
                        print("   ⚠️ Could not verify iCloud status: \(error.localizedDescription)")
                    }
                } else {
                    let errorMsg = "File does not exist after setUbiquitous at: \(jsonURL.path)"
                    print("   ❌ \(errorMsg)")
                    throw NSError(domain: "AnalysisResultPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
            } catch {
                // setUbiquitous failed - log detailed error
                print("   ❌ setUbiquitous FAILED: \(error.localizedDescription)")
                print("   📝 Error details: \(error)")
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                // Try direct write as fallback (won't sync but preserves data)
                print("   📝 Attempting direct write fallback...")
                try jsonData.write(to: jsonURL, options: .atomic)
                print("   ⚠️ Saved directly (file exists but WON'T sync to iCloud): \(jsonFileName)")
                print("   ⚠️ This is a fallback - file will not appear in iCloud Drive")
            }
        } else {
            // Local storage only
            print("   📁 Using local storage (iCloud not enabled or not available)")
            try jsonData.write(to: jsonURL, options: .atomic)
            print("   ✅ Saved to local directory: \(jsonURL.path)")
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw NSError(domain: "AnalysisResultPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "File was not created successfully"])
        }
        
        print("✅ Successfully saved analysis result: \(jsonFileName)")
    }
    
    // MARK: - Load Analysis Result
    
    /// Loads an analysis result from JSON file if it exists
    /// - Parameter audioFileName: The name of the audio file
    /// - Returns: The loaded analysis result, or nil if no saved result exists
    func loadAnalysisResult(forAudioFile audioFileName: String, isDemo: Bool = false) -> AnalysisResult? {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()

        let jsonFileName = analysisFileName(for: audioFileName, isDemo: isDemo)
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            
            // List what files ARE in the directory
            if let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
                for file in files {
                }
            }
            return nil
        }
        
        do {
            // Read JSON data
            let jsonData = try Data(contentsOf: jsonURL)
            guard let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
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
            let rawSummary = data["aiSummary"] as? String
            result.aiSummary = ClaudeAPIService.fixContradictoryAnalysis(analysis: rawSummary, score: result.overallScore)
            result.aiRecommendations = data["aiRecommendations"] as? [String] ?? []
            result.claudeScore = data["claudeScore"] as? Int
            result.isReadyForMastering = data["isReadyForMastering"] as? Bool ?? false
            
            // Load FFT spectrum data
            if let spectrumArray = data["frequencySpectrum"] as? [Double] {
                result.frequencySpectrum = spectrumArray.map { Float($0) }
            }
            result.spectrumSampleRate = data["spectrumSampleRate"] as? Double
            result.rmsLevel = data["rmsLevel"] as? Double ?? 0

            // Load unmixed detection fields
            result.isProfessionallyMixed = data["isProfessionallyMixed"] as? Bool ?? true
            result.monoCompatibility = data["monoCompatibility"] as? Double ?? 1.0
            if let base64String = data["unmixedDetectionData"] as? String,
               let decodedData = Data(base64Encoded: base64String) {
                result.unmixedDetectionData = decodedData
            }

            if result.frequencySpectrum != nil {
            }
            return result
            
        } catch {
            return nil
        }
    }
    
    // MARK: - Clear Date Tracking

    private static let lastAnalysisClearDateKey = "lastAnalysisClearDate"

    /// Records the current date as the last time all analysis was cleared.
    /// Used to prevent iCloud-synced JSON files from being re-loaded after a clear.
    func recordAnalysisClearDate() {
        UserDefaults.standard.set(Date(), forKey: Self.lastAnalysisClearDateKey)
        print("🧹 Recorded analysis clear date: \(Date())")
    }

    /// Checks whether a cached analysis result was created before the last clear.
    /// - Parameter result: The analysis result loaded from JSON
    /// - Returns: `true` if the result is stale (created before the last clear), `false` otherwise
    func isResultStale(_ result: AnalysisResult) -> Bool {
        guard let clearDate = UserDefaults.standard.object(forKey: Self.lastAnalysisClearDateKey) as? Date else {
            return false
        }
        return result.dateAnalyzed < clearDate
    }

    // MARK: - Delete Analysis Result

    /// Deletes the analysis result file from iCloud Drive
    /// - Parameter audioFileName: The name of the audio file
    func deleteAnalysisResult(forAudioFile audioFileName: String, isDemo: Bool = false) {
        let service = iCloudStorageService.shared
        let audioDir = service.getAudioFilesDirectory()

        let jsonFileName = analysisFileName(for: audioFileName, isDemo: isDemo)
        let jsonURL = audioDir.appendingPathComponent(jsonFileName)
        
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            do {
                try FileManager.default.removeItem(at: jsonURL)
            } catch {
            }
        }
    }
    
    // MARK: - Helper
    
    /// Generates the JSON filename for an audio file
    /// Example: "song.mp3" -> "song.mp3.analysis.json"
    /// Demo files: "Song 1 MIX" -> "MIX-demo-Song 1 MIX.analysis.json"
    func analysisFileName(for audioFileName: String, isDemo: Bool = false) -> String {
        if isDemo {
            return "MIX-demo-\(audioFileName).analysis.json"
        }
        return "\(audioFileName).analysis.json"
    }
}
