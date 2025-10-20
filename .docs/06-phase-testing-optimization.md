# Phase 6: Testing & Optimization

**Duration**: Week 7-8
**Goal**: Ensure app quality, performance, and reliability through comprehensive testing

## Objectives

- Implement unit tests for all services and logic
- Create UI tests for critical user flows
- Performance testing and optimization
- Memory leak detection and fixes
- Accessibility testing
- Localization preparation
- Error handling improvements
- Code review and refactoring

## Testing Strategy

### Testing Pyramid

```
        /\
       /  \      E2E Tests (10%)
      /____\     UI Tests (20%)
     /      \    Integration Tests (30%)
    /________\   Unit Tests (40%)
```

## Unit Testing

### 1. Audio Import Service Tests

```swift
import XCTest
import AVFoundation
@testable import MixDoctor

final class AudioImportServiceTests: XCTestCase {

    var sut: AudioImportService!
    var testBundle: Bundle!

    override func setUp() {
        super.setUp()
        sut = AudioImportService()
        testBundle = Bundle(for: type(of: self))
    }

    override func tearDown() {
        sut = nil
        testBundle = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    func testValidateAudioFile_ValidWAV_ReturnsTrue() throws {
        // Given
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_44100", withExtension: "wav"))

        // When
        let result = try sut.validateAudioFile(url)

        // Then
        XCTAssertTrue(result)
    }

    func testValidateAudioFile_UnsupportedFormat_ThrowsError() {
        // Given
        let url = URL(fileURLWithPath: "/test/file.ogg")

        // When/Then
        XCTAssertThrowsError(try sut.validateAudioFile(url)) { error in
            XCTAssertEqual(error as? AudioImportError, .unsupportedFormat)
        }
    }

    func testValidateAudioFile_LowSampleRate_ThrowsError() throws {
        // Given
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_22050", withExtension: "wav"))

        // When/Then
        XCTAssertThrowsError(try sut.validateAudioFile(url)) { error in
            XCTAssertEqual(error as? AudioImportError, .sampleRateTooLow)
        }
    }

    // MARK: - Import Tests

    func testImportAudioFile_ValidFile_CreatesAudioFile() async throws {
        // Given
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_44100", withExtension: "wav"))

        // When
        let audioFile = try await sut.importAudioFile(from: url)

        // Then
        XCTAssertEqual(audioFile.fileName, "test_audio_44100.wav")
        XCTAssertGreaterThan(audioFile.duration, 0)
        XCTAssertEqual(audioFile.sampleRate, 44100)
        XCTAssertEqual(audioFile.numberOfChannels, 2)
    }

    func testImportMultipleFiles_ValidFiles_ImportsAll() async throws {
        // Given
        let urls = [
            try XCTUnwrap(testBundle.url(forResource: "test_audio_1", withExtension: "wav")),
            try XCTUnwrap(testBundle.url(forResource: "test_audio_2", withExtension: "wav"))
        ]

        // When
        let audioFiles = try await sut.importMultipleFiles(urls)

        // Then
        XCTAssertEqual(audioFiles.count, 2)
    }

    // MARK: - Performance Tests

    func testImportPerformance() throws {
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_large", withExtension: "wav"))

        measure {
            Task {
                _ = try? await sut.importAudioFile(from: url)
            }
        }
    }
}
```

### 2. Audio Analysis Tests

```swift
import XCTest
@testable import MixDoctor

final class AudioFeatureExtractorTests: XCTestCase {

    var sut: AudioFeatureExtractor!

    override func setUp() {
        super.setUp()
        sut = AudioFeatureExtractor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Stereo Features

    func testExtractStereoFeatures_IdenticalChannels_ReturnsHighCorrelation() {
        // Given
        let left = [Float](repeating: 0.5, count: 1000)
        let right = left

        // When
        let features = sut.extractStereoFeatures(left: left, right: right)

        // Then
        XCTAssertGreaterThan(features.correlation, 0.99)
        XCTAssertLessThan(features.stereoWidth, 0.1)
    }

    func testExtractStereoFeatures_InvertedChannels_ReturnsNegativeCorrelation() {
        // Given
        let left = [Float](repeating: 0.5, count: 1000)
        let right = [Float](repeating: -0.5, count: 1000)

        // When
        let features = sut.extractStereoFeatures(left: left, right: right)

        // Then
        XCTAssertLessThan(features.correlation, -0.9)
    }

    func testExtractStereoFeatures_UncorrelatedChannels_ReturnsWideWidth() {
        // Given
        let left = [Float](repeating: 0.8, count: 1000)
        let right = [Float](repeating: 0.2, count: 1000)

        // When
        let features = sut.extractStereoFeatures(left: left, right: right)

        // Then
        XCTAssertGreaterThan(features.stereoWidth, 0.3)
    }

    // MARK: - Frequency Analysis

    func testExtractFrequencyFeatures_ValidAudio_ReturnsSpectrum() throws {
        // Given
        let sampleRate = 44100.0
        let frequency: Float = 1000.0 // 1kHz tone
        let samples = generateSineTone(frequency: frequency, sampleRate: Float(sampleRate), duration: 1.0)

        // When
        let features = try sut.extractFrequencyFeatures(audio: samples, sampleRate: sampleRate)

        // Then
        XCTAssertFalse(features.spectrum.isEmpty)
        XCTAssertGreaterThan(features.spectralCentroid, 0)
        XCTAssertGreaterThan(features.spectralFlatness, 0)
    }

    // MARK: - Loudness Features

    func testExtractLoudnessFeatures_SilentAudio_ReturnsZero() {
        // Given
        let left = [Float](repeating: 0, count: 1000)
        let right = [Float](repeating: 0, count: 1000)

        // When
        let features = sut.extractLoudnessFeatures(left: left, right: right)

        // Then
        XCTAssertEqual(features.rmsLevel, 0, accuracy: 0.001)
        XCTAssertEqual(features.peakLevel, 0, accuracy: 0.001)
    }

    func testExtractLoudnessFeatures_FullScaleAudio_ReturnsMax() {
        // Given
        let left = [Float](repeating: 1.0, count: 1000)
        let right = [Float](repeating: 1.0, count: 1000)

        // When
        let features = sut.extractLoudnessFeatures(left: left, right: right)

        // Then
        XCTAssertEqual(features.peakLevel, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(features.crestFactor, 0)
    }

    // MARK: - Helper

    private func generateSineTone(frequency: Float, sampleRate: Float, duration: Float) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let time = Float(i) / sampleRate
            samples[i] = sin(2.0 * .pi * frequency * time)
        }

        return samples
    }
}
```

### 3. Analysis Service Tests

```swift
import XCTest
import SwiftData
@testable import MixDoctor

final class AudioAnalysisServiceTests: XCTestCase {

    var sut: AudioAnalysisService!
    var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        sut = AudioAnalysisService()

        // Setup in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AudioFile.self, configurations: config)
        modelContext = ModelContext(container)
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        super.tearDown()
    }

    func testAnalyzeAudio_ValidFile_ReturnsResult() async throws {
        // Given
        let testBundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio", withExtension: "wav"))

        let audioFile = AudioFile(
            fileName: "test_audio.wav",
            fileURL: url,
            duration: 10.0,
            sampleRate: 44100,
            bitDepth: 16,
            numberOfChannels: 2,
            fileSize: 1000000
        )

        // When
        let result = try await sut.analyzeAudio(audioFile)

        // Then
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.overallScore, 0)
        XCTAssertGreaterThan(result.stereoWidthScore, 0)
    }

    func testAnalyzeAudio_PhaseIssue_DetectsIssue() async throws {
        // Given: Audio file with known phase issue
        let testBundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_phase_issue", withExtension: "wav"))

        let audioFile = AudioFile(
            fileName: "test_audio_phase_issue.wav",
            fileURL: url,
            duration: 10.0,
            sampleRate: 44100,
            bitDepth: 16,
            numberOfChannels: 2,
            fileSize: 1000000
        )

        // When
        let result = try await sut.analyzeAudio(audioFile)

        // Then
        XCTAssertTrue(result.hasPhaseIssues)
        XCTAssertLessThan(result.phaseCoherence, 0)
    }
}
```

## UI Testing

### 1. Import Flow Tests

```swift
import XCTest

final class ImportFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testImportFlow_TapBrowseFiles_ShowsFilePicker() {
        // Given: App is on Import tab
        let importTab = app.tabBars.buttons["Import"]
        importTab.tap()

        // When: Tap browse files button
        let browseButton = app.buttons["Browse Files"]
        XCTAssertTrue(browseButton.exists)
        browseButton.tap()

        // Then: File picker should appear
        // Note: Can't fully test file picker in UI tests, but can verify button tap
        XCTAssertTrue(browseButton.exists)
    }

    func testImportFlow_AfterImport_ShowsImportedFile() {
        // This test would require setting up test files
        // and simulating file selection, which is complex in UI tests
    }
}
```

### 2. Dashboard Flow Tests

```swift
import XCTest

final class DashboardFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    func testDashboard_WithFiles_DisplaysList() {
        // Given: Dashboard tab is selected
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        dashboardTab.tap()

        // When: Files exist (seeded in test configuration)
        let filesList = app.tables.firstMatch

        // Then: List should be visible
        XCTAssertTrue(filesList.exists)
    }

    func testDashboard_TapFile_NavigatesToResults() {
        // Given: Dashboard with files
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        dashboardTab.tap()

        // When: Tap first file
        let firstFile = app.tables.cells.firstMatch
        if firstFile.exists {
            firstFile.tap()

            // Then: Results view should appear
            let resultsView = app.navigationBars["Analysis Results"]
            XCTAssertTrue(resultsView.waitForExistence(timeout: 2))
        }
    }

    func testDashboard_SearchFiles_FiltersResults() {
        // Given: Dashboard with multiple files
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        dashboardTab.tap()

        // When: Enter search text
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("test")

        // Then: List should filter
        // Verification depends on test data
    }
}
```

### 3. Analysis Results Tests

```swift
import XCTest

final class AnalysisResultsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    func testResultsView_ShowsOverallScore() {
        // Navigate to results view (assuming test data exists)
        app.tabBars.buttons["Dashboard"].tap()

        let firstFile = app.tables.cells.firstMatch
        if firstFile.waitForExistence(timeout: 2) {
            firstFile.tap()

            // Check for score display
            let scoreText = app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'")).firstMatch
            XCTAssertTrue(scoreText.waitForExistence(timeout: 2))
        }
    }

    func testResultsView_ShowsRecommendations() {
        // Navigate to results view
        app.tabBars.buttons["Dashboard"].tap()

        let firstFile = app.tables.cells.firstMatch
        if firstFile.waitForExistence(timeout: 2) {
            firstFile.tap()

            // Scroll to recommendations
            let recommendationsHeading = app.staticTexts["Recommendations"]
            XCTAssertTrue(recommendationsHeading.exists)
        }
    }
}
```

## Performance Testing

### 1. Analysis Performance

```swift
import XCTest
@testable import MixDoctor

final class AnalysisPerformanceTests: XCTestCase {

    var sut: AudioAnalysisService!

    override func setUp() {
        super.setUp()
        sut = AudioAnalysisService()
    }

    func testAnalysisPerformance_5MinuteFile() throws {
        // Given: 5-minute audio file
        let testBundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_5min", withExtension: "wav"))

        let audioFile = AudioFile(
            fileName: "test_audio_5min.wav",
            fileURL: url,
            duration: 300.0,
            sampleRate: 44100,
            bitDepth: 16,
            numberOfChannels: 2,
            fileSize: 50000000
        )

        // When/Then: Should complete within 10 seconds
        measure {
            Task {
                _ = try? await sut.analyzeAudio(audioFile)
            }
        }
    }

    func testFFTPerformance() {
        let extractor = AudioFeatureExtractor()
        let samples = [Float](repeating: 0.5, count: 44100) // 1 second of audio

        measure {
            _ = try? extractor.extractFrequencyFeatures(audio: samples, sampleRate: 44100)
        }
    }
}
```

### 2. Memory Testing

```swift
import XCTest
@testable import MixDoctor

final class MemoryTests: XCTestCase {

    func testImportService_NoMemoryLeaks() {
        weak var weakService: AudioImportService?

        autoreleasepool {
            let service = AudioImportService()
            weakService = service

            // Perform operations
            // ...
        }

        // Service should be deallocated
        XCTAssertNil(weakService, "AudioImportService has a memory leak")
    }

    func testAnalysisService_HandlesLargeFile() throws {
        // Given: Very large audio file
        let testBundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(testBundle.url(forResource: "test_audio_large", withExtension: "wav"))

        let audioFile = AudioFile(
            fileName: "test_audio_large.wav",
            fileURL: url,
            duration: 600.0, // 10 minutes
            sampleRate: 44100,
            bitDepth: 24,
            numberOfChannels: 2,
            fileSize: 200000000 // 200 MB
        )

        let service = AudioAnalysisService()

        // When: Analyze large file
        // Should not crash or run out of memory
        Task {
            do {
                _ = try await service.analyzeAudio(audioFile)
            } catch {
                XCTFail("Failed to analyze large file: \(error)")
            }
        }
    }
}
```

## Optimization Strategies

### 1. Audio Processing Optimization

```swift
// Optimize FFT processing by reusing buffers
final class OptimizedAudioProcessor {
    private var fftSetup: FFTSetup?
    private var realBuffer: [Float]
    private var imagBuffer: [Float]

    init(fftSize: Int) {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func processFrame(_ samples: [Float]) -> [Float] {
        // Reuse pre-allocated buffers
        // ... processing code ...
        return []
    }
}
```

### 2. Memory Management

```swift
// Process audio in chunks to manage memory
func analyzeAudioInChunks(audioFile: AudioFile, chunkSize: Int = 44100) async throws -> AnalysisResult {
    let processor = AudioProcessor()
    let processedAudio = try processor.loadAudio(from: audioFile.fileURL)

    var aggregatedResults: [ChunkResult] = []

    // Process in chunks
    for startIndex in stride(from: 0, to: processedAudio.leftChannel.count, by: chunkSize) {
        let endIndex = min(startIndex + chunkSize, processedAudio.leftChannel.count)
        let leftChunk = Array(processedAudio.leftChannel[startIndex..<endIndex])
        let rightChunk = Array(processedAudio.rightChannel[startIndex..<endIndex])

        // Process chunk
        let chunkResult = processChunk(left: leftChunk, right: rightChunk)
        aggregatedResults.append(chunkResult)

        // Allow memory to be released
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
    }

    // Aggregate results
    return aggregateChunkResults(aggregatedResults, audioFile: audioFile)
}
```

### 3. UI Performance

```swift
// Lazy loading and virtualization for large lists
struct OptimizedDashboardView: View {
    @Query private var audioFiles: [AudioFile]

    var body: some View {
        List {
            // SwiftUI automatically virtualizes List
            ForEach(audioFiles) { file in
                AudioFileRow(audioFile: file)
                    .task {
                        // Load data on demand
                        await loadThumbnail(for: file)
                    }
            }
        }
    }

    private func loadThumbnail(for file: AudioFile) async {
        // Generate waveform thumbnail only when needed
    }
}
```

## Accessibility Testing

### Checklist

- [ ] All interactive elements have accessibility labels
- [ ] VoiceOver navigation works correctly
- [ ] Dynamic Type support (text scales properly)
- [ ] High contrast mode support
- [ ] Reduce motion support
- [ ] Color blind friendly (don't rely on color alone)
- [ ] Minimum touch targets (44x44 points)

### Example Implementation

```swift
// Add accessibility labels
Button(action: { /* ... */ }) {
    Image(systemName: "play.circle.fill")
}
.accessibilityLabel("Play audio")
.accessibilityHint("Plays the selected audio file")

// Support Dynamic Type
Text("Overall Score")
    .font(.headline)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

// Reduce motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .easeInOut
}
```

## Code Coverage Target

- **Minimum**: 70% code coverage
- **Target**: 80% code coverage
- **Critical paths**: 90%+ coverage (import, analysis, data persistence)

## Deliverables

- [ ] Unit tests for all services (80%+ coverage)
- [ ] UI tests for critical flows
- [ ] Performance tests and benchmarks
- [ ] Memory leak detection
- [ ] Accessibility compliance
- [ ] Optimization implementation
- [ ] Test documentation
- [ ] CI/CD integration for automated testing

## Tools & Setup

### Xcode Tools
- **XCTest**: Unit and UI testing
- **Instruments**: Performance profiling
  - Time Profiler
  - Allocations
  - Leaks
- **Code Coverage**: Built into Xcode

### CI/CD
```yaml
# Example GitHub Actions workflow
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'
      - name: Generate coverage
        run: xcov --scheme MixDoctor
```

## Next Phase

Proceed to [Phase 7: Polish & Deployment](07-phase-polish-deployment.md)

## Estimated Time

- Unit tests: 10 hours
- UI tests: 6 hours
- Performance optimization: 6 hours
- Memory optimization: 4 hours
- Accessibility: 4 hours
- Bug fixes: 6 hours

**Total: ~36 hours (5-6 days)**
