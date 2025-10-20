import AVFoundation
@testable import MixDoctor
import XCTest

@MainActor
final class AudioImportServiceTests: XCTestCase {
    private var sut: AudioImportService!
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
        sut = nil
        try super.tearDownWithError()
    }

    func testValidateAudioFile_WithValidWAV_ReturnsTrue() throws {
        let wavURL = try makeTemporaryWAVFile()
        temporaryURLs.append(wavURL)

        let isValid = try sut.validateAudioFile(wavURL)

        XCTAssertTrue(isValid)
    }

    func testValidateAudioFile_WithUnsupportedExtension_ThrowsUnsupportedFormat() throws {
        let url = try makeTemporaryFile(extension: "ogg")
        temporaryURLs.append(url)

        XCTAssertThrowsError(try sut.validateAudioFile(url)) { error in
            XCTAssertEqual(error as? AudioImportError, .unsupportedFormat)
        }
    }

    func testImportMultipleFiles_WhenAllFail_ThrowsFirstError() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/audio.wav")

        do {
            _ = try await sut.importMultipleFiles([invalidURL])
            XCTFail("Expected import to fail for invalid URLs")
        } catch let error as AudioImportError {
            XCTAssertEqual(error, .accessDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
