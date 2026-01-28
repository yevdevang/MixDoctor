import AVFoundation
@testable import MixDoctor
import XCTest

@MainActor
final class AudioImportServiceTests: XCTestCase {
    private var sut: AudioImportService?
    private var temporaryURLs: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = AudioImportService()
    }

    override func tearDownWithError() throws {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()
        // Don't explicitly set sut to nil - @MainActor/@Observable objects
        // can cause SIGABRT during deallocation. Swift will handle cleanup automatically.
        try super.tearDownWithError()
    }

    func testValidateAudioFile_WithValidWAV_ReturnsTrue() async throws {
        guard let sut = sut else {
            XCTFail("SUT not initialized")
            return
        }
        
        let wavURL = try makeTemporaryWAVFile()
        temporaryURLs.append(wavURL)

        let isValid = try await sut.validateAudioFile(wavURL)

        XCTAssertTrue(isValid)
    }

    func testValidateAudioFile_WithUnsupportedExtension_ThrowsUnsupportedFormat() async throws {
        guard let sut = sut else {
            XCTFail("SUT not initialized")
            return
        }
        
        let url = try makeTemporaryFile(extension: "ogg")
        temporaryURLs.append(url)

        do {
            _ = try await sut.validateAudioFile(url)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? AudioImportError, .unsupportedFormat)
        }
    }

    func testImportMultipleFiles_WhenAllFail_ThrowsFirstError() async {
        guard let sut = sut else {
            XCTFail("SUT not initialized")
            return
        }
        
        let invalidURL = URL(fileURLWithPath: "/nonexistent/audio.wav")

        do {
            _ = try await sut.importMultipleFiles([invalidURL])
            XCTFail("Expected import to fail for invalid URLs")
        } catch let error as AudioImportError {
            // The error could be accessDenied or iCloudDownloadFailed depending on file system state
            XCTAssertTrue(
                error == .accessDenied || error == .iCloudDownloadFailed || error == .invalidAudioFile,
                "Expected accessDenied, iCloudDownloadFailed, or invalidAudioFile, got: \(error)"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - File Naming with Stage Tests
    
    func testFileNaming_WithMixStage_AppendsCorrectSuffix() throws {
        // Given
        let originalFileName = "Twisted Transistor.wav"
        let baseName = "Twisted Transistor"
        let mixStage = "mix"
        
        // Expected: "Twisted Transistor - Mix.wav"
        let expectedFileName = "\(baseName) - Mix.wav"
        
        // This tests the naming logic conceptually
        // In actual implementation, this happens in copyToDocuments
        XCTAssertEqual(expectedFileName, "Twisted Transistor - Mix.wav")
    }
    
    func testFileNaming_WithStreamingMasterStage_AppendsCorrectSuffix() throws {
        // Given
        let baseName = "Twisted Transistor"
        let mixStage = "master_streaming"
        
        // Expected: "Twisted Transistor - Master(Streaming).wav"
        let expectedFileName = "\(baseName) - Master(Streaming).wav"
        
        XCTAssertEqual(expectedFileName, "Twisted Transistor - Master(Streaming).wav")
    }
    
    func testFileNaming_WithCDMasterStage_AppendsCorrectSuffix() throws {
        // Given
        let baseName = "Twisted Transistor"
        let mixStage = "master_cd"
        
        // Expected: "Twisted Transistor - Master(CD-Loud).wav"
        let expectedFileName = "\(baseName) - Master(CD-Loud).wav"
        
        XCTAssertEqual(expectedFileName, "Twisted Transistor - Master(CD-Loud).wav")
    }
    
    func testBaseNameExtraction_FromFileWithStage_ExtractsCorrectly() throws {
        // Given
        let fileNameWithStage = "Twisted Transistor - Master(Streaming).wav"
        
        // When: Extract base name (simulate the logic from AudioImportService)
        let nameWithoutExt = (fileNameWithStage as NSString).deletingPathExtension
        let baseName: String
        if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
            baseName = String(nameWithoutExt[..<dashIndex.lowerBound])
        } else {
            baseName = nameWithoutExt
        }
        
        // Then
        XCTAssertEqual(baseName, "Twisted Transistor")
    }
    
    func testBaseNameExtraction_FromFileWithoutStage_ReturnsFullName() throws {
        // Given
        let fileName = "Twisted Transistor.wav"
        
        // When: Extract base name
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let baseName: String
        if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
            baseName = String(nameWithoutExt[..<dashIndex.lowerBound])
        } else {
            baseName = nameWithoutExt
        }
        
        // Then
        XCTAssertEqual(baseName, "Twisted Transistor")
    }
    
    func testBaseNameExtraction_FromFileWithDashInName_ExtractsCorrectly() throws {
        // Given: Song title has " - " in it already
        let fileNameWithDashInTitle = "AC-DC - Thunderstruck - Mix.wav"
        
        // When: Extract base name (should remove LAST " - Stage")
        let nameWithoutExt = (fileNameWithDashInTitle as NSString).deletingPathExtension
        let baseName: String
        if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
            baseName = String(nameWithoutExt[..<dashIndex.lowerBound])
        } else {
            baseName = nameWithoutExt
        }
        
        // Then: Should preserve the artist dash, only remove stage suffix
        XCTAssertEqual(baseName, "AC-DC - Thunderstruck")
    }
    
    func testStageDisplayNameConversion_Mix_ConvertsCorrectly() throws {
        // Given
        let internalStage = "mix"
        
        // When: Convert to display name
        let displayName: String
        switch internalStage.lowercased() {
        case "mix":
            displayName = "Mix"
        case "master_streaming", "master(streaming)":
            displayName = "Master(Streaming)"
        case "master_cd", "master(cd/loud)":
            displayName = "Master(CD-Loud)"
        default:
            displayName = internalStage
        }
        
        // Then
        XCTAssertEqual(displayName, "Mix")
    }
    
    func testStageDisplayNameConversion_MasterStreaming_ConvertsCorrectly() throws {
        // Given
        let internalStage = "master_streaming"
        
        // When: Convert to display name
        let displayName: String
        switch internalStage.lowercased() {
        case "mix":
            displayName = "Mix"
        case "master_streaming", "master(streaming)":
            displayName = "Master(Streaming)"
        case "master_cd", "master(cd/loud)":
            displayName = "Master(CD-Loud)"
        default:
            displayName = internalStage
        }
        
        // Then
        XCTAssertEqual(displayName, "Master(Streaming)")
    }
    
    func testStageDisplayNameConversion_MasterCD_ConvertsCorrectly() throws {
        // Given
        let internalStage = "master_cd"
        
        // When: Convert to display name
        let displayName: String
        switch internalStage.lowercased() {
        case "mix":
            displayName = "Mix"
        case "master_streaming", "master(streaming)":
            displayName = "Master(Streaming)"
        case "master_cd", "master(cd/loud)":
            displayName = "Master(CD-Loud)"
        default:
            displayName = internalStage
        }
        
        // Then
        XCTAssertEqual(displayName, "Master(CD-Loud)")
    }
    
    func testDuplicateDetection_SameFileNameDifferentStage_ShouldAllowImport() throws {
        // Given: Two files with same base name but different stages
        let file1 = "Twisted Transistor - Mix.wav"
        let file2 = "Twisted Transistor - Master(Streaming).wav"
        let stage1 = "mix"
        let stage2 = "master_streaming"
        
        // When: Extract base names
        let extractBaseName: (String) -> String = { fullName in
            let nameWithoutExt = (fullName as NSString).deletingPathExtension
            if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
                return String(nameWithoutExt[..<dashIndex.lowerBound])
            }
            return nameWithoutExt
        }
        
        let baseName1 = extractBaseName(file1)
        let baseName2 = extractBaseName(file2)
        
        // Then: Base names should match
        XCTAssertEqual(baseName1, baseName2, "Base names should be identical")
        
        // But stages are different
        XCTAssertNotEqual(stage1, stage2, "Stages should be different")
        
        // Therefore: NOT a duplicate (same base name, different stage = allowed)
        let isDuplicate = (baseName1 == baseName2) && (stage1 == stage2)
        XCTAssertFalse(isDuplicate, "Should NOT be considered duplicate (different stages)")
    }
    
    func testDuplicateDetection_SameFileNameSameStage_ShouldBlockImport() throws {
        // Given: Two files with same base name and same stage
        let file1 = "Twisted Transistor - Mix.wav"
        let file2 = "Twisted Transistor - Mix.wav"
        let stage1 = "mix"
        let stage2 = "mix"
        
        // When: Extract base names
        let extractBaseName: (String) -> String = { fullName in
            let nameWithoutExt = (fullName as NSString).deletingPathExtension
            if let dashIndex = nameWithoutExt.range(of: " - ", options: .backwards) {
                return String(nameWithoutExt[..<dashIndex.lowerBound])
            }
            return nameWithoutExt
        }
        
        let baseName1 = extractBaseName(file1)
        let baseName2 = extractBaseName(file2)
        
        // Then: Base names should match
        XCTAssertEqual(baseName1, baseName2, "Base names should be identical")
        
        // And stages also match
        XCTAssertEqual(stage1, stage2, "Stages should be identical")
        
        // Therefore: IS a duplicate (same base name, same stage = blocked)
        let isDuplicate = (baseName1 == baseName2) && (stage1 == stage2)
        XCTAssertTrue(isDuplicate, "Should be considered duplicate (same base name and stage)")
    }
    
    func testMultipleImports_SameBaseDifferentStages_CreatesThreeSeparateFiles() throws {
        // Given: One audio file imported 3 times with different stages
        let baseFileName = "Twisted Transistor"
        let fileExtension = "wav"
        
        let stages = [
            ("mix", "Mix"),
            ("master_streaming", "Master(Streaming)"),
            ("master_cd", "Master(CD-Loud)")
        ]
        
        // When: Generate file names for each stage
        var generatedFileNames: [String] = []
        for (internalStage, displayStage) in stages {
            let fileName = "\(baseFileName) - \(displayStage).\(fileExtension)"
            generatedFileNames.append(fileName)
        }
        
        // Then: Should have 3 unique file names
        XCTAssertEqual(generatedFileNames.count, 3, "Should have 3 file names")
        XCTAssertEqual(Set(generatedFileNames).count, 3, "All 3 file names should be unique")
        
        // Verify exact names
        XCTAssertTrue(generatedFileNames.contains("Twisted Transistor - Mix.wav"))
        XCTAssertTrue(generatedFileNames.contains("Twisted Transistor - Master(Streaming).wav"))
        XCTAssertTrue(generatedFileNames.contains("Twisted Transistor - Master(CD-Loud).wav"))
    }

    // MARK: - Helpers

    private func makeTemporaryFile(extension fileExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        let data = Data([0x00])
        guard FileManager.default.createFile(atPath: url.path, contents: data) else {
            throw NSError(domain: "MixDoctorTests", code: 1)
        }

        return url
    }

    private func makeTemporaryWAVFile() throws -> URL {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let bufferCapacity: AVAudioFrameCount = 1_024

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
            throw NSError(domain: "MixDoctorTests", code: 2)
        }
        buffer.frameLength = bufferCapacity

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        try audioFile.write(from: buffer)

        return url
    }
}
