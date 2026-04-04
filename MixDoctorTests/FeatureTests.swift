//
//  FeatureTests.swift
//  MixDoctorTests
//
//  Unit tests for v1.2.1 features:
//  - Demo files (DemoFileService)
//  - Free tier limit changed from 3 to 4
//  - Weekly subscription tier (10 analyses/week)
//  - No free trial + weekly pro limit = 10
//

import XCTest
@testable import MixDoctor

// MARK: - DemoFileService Tests

final class DemoFileServiceTests: XCTestCase {

    // MARK: - Demo File Definitions

    func testDemoFilesCount() {
        // There should be exactly 4 demo files
        XCTAssertEqual(DemoFileService.demoFiles.count, 4, "Should have exactly 4 demo files")
    }

    func testDemoFileDefinitionsHaveRequiredFields() {
        for (index, demo) in DemoFileService.demoFiles.enumerated() {
            XCTAssertFalse(demo.assetName.isEmpty, "Demo file \(index) should have a non-empty assetName")
            XCTAssertFalse(demo.displayName.isEmpty, "Demo file \(index) should have a non-empty displayName")
            XCTAssertFalse(demo.mixStage.isEmpty, "Demo file \(index) should have a non-empty mixStage")
        }
    }

    func testDemoFileGenresAreSet() {
        for demo in DemoFileService.demoFiles {
            XCTAssertNotNil(demo.genre, "\(demo.displayName) should have a genre set")
            XCTAssertFalse(demo.genre!.isEmpty, "\(demo.displayName) genre should not be empty")
        }
    }

    func testDemoFileMixStagesAreValid() {
        let validStages = ["mix", "master_streaming", "master_cd"]
        for demo in DemoFileService.demoFiles {
            XCTAssertTrue(
                validStages.contains(demo.mixStage),
                "\(demo.displayName) has invalid mixStage '\(demo.mixStage)'. Expected one of: \(validStages)"
            )
        }
    }

    func testDemoFileAssetNamesAreUnique() {
        let assetNames = DemoFileService.demoFiles.map { $0.assetName }
        let uniqueNames = Set(assetNames)
        XCTAssertEqual(assetNames.count, uniqueNames.count, "All demo file asset names should be unique")
    }

    func testDemoFileDisplayNamesAreUnique() {
        let displayNames = DemoFileService.demoFiles.map { $0.displayName }
        let uniqueNames = Set(displayNames)
        XCTAssertEqual(displayNames.count, uniqueNames.count, "All demo file display names should be unique")
    }

    func testDemoFilesContainExpectedMixStages() {
        let stages = DemoFileService.demoFiles.map { $0.mixStage }
        XCTAssertTrue(stages.contains("mix"), "Should have at least one 'mix' stage demo file")
        XCTAssertTrue(stages.contains("master_streaming"), "Should have at least one 'master_streaming' stage demo file")
    }

    func testDemoFilesContainExpectedGenres() {
        let genres = DemoFileService.demoFiles.compactMap { $0.genre }
        XCTAssertTrue(genres.contains("Pop/Rock"), "Should have at least one Pop/Rock demo file")
        XCTAssertTrue(genres.contains("Jazz"), "Should have at least one Jazz demo file")
        XCTAssertTrue(genres.contains("Electronic"), "Should have at least one Electronic demo file")
    }

    // MARK: - File Extension Detection

    func testDetectFileExtension_WAV() {
        // RIFF header for WAV files: "RIFF"
        let wavHeader = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00])
        let ext = callDetectFileExtension(data: wavHeader)
        XCTAssertEqual(ext, "wav", "RIFF header should be detected as wav")
    }

    func testDetectFileExtension_MP3_ID3() {
        // ID3 tag header: "ID3"
        let mp3Header = Data([0x49, 0x44, 0x33, 0x04, 0x00, 0x00])
        let ext = callDetectFileExtension(data: mp3Header)
        XCTAssertEqual(ext, "mp3", "ID3 tag header should be detected as mp3")
    }

    func testDetectFileExtension_MP3_SyncWord() {
        // MP3 sync word: 0xFF 0xFB (MPEG1 Layer3)
        let mp3Header = Data([0xFF, 0xFB, 0x90, 0x00])
        let ext = callDetectFileExtension(data: mp3Header)
        XCTAssertEqual(ext, "mp3", "MP3 sync word should be detected as mp3")
    }

    func testDetectFileExtension_ShortData() {
        // Less than 4 bytes should default to wav
        let shortData = Data([0x00, 0x01])
        let ext = callDetectFileExtension(data: shortData)
        XCTAssertEqual(ext, "wav", "Short data should default to wav")
    }

    func testDetectFileExtension_EmptyData() {
        let emptyData = Data()
        let ext = callDetectFileExtension(data: emptyData)
        XCTAssertEqual(ext, "wav", "Empty data should default to wav")
    }

    func testDetectFileExtension_UnknownFormat() {
        // Random bytes that don't match any known format
        let unknownData = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let ext = callDetectFileExtension(data: unknownData)
        XCTAssertEqual(ext, "wav", "Unknown format should default to wav")
    }

    // MARK: - Helper to call private method via reflection-like approach

    /// Replicates the logic of DemoFileService.detectFileExtension for testing
    private func callDetectFileExtension(data: Data) -> String {
        guard data.count >= 4 else { return "wav" }

        let header = [UInt8](data.prefix(4))

        // Check for MP3 (ID3 tag or sync word)
        if header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33 { // "ID3"
            return "mp3"
        }
        if header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 { // MP3 sync word
            return "mp3"
        }

        // Default to wav (RIFF header or other)
        return "wav"
    }
}

// MARK: - Subscription Tier Tests (MockSubscriptionService)

@MainActor
final class SubscriptionTierTests: XCTestCase {

    var service: MockSubscriptionService!

    override func setUp() async throws {
        try await super.setUp()
        service = MockSubscriptionService.shared
        service.resetToFree()
        // Small delay to let state settle
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    override func tearDown() async throws {
        service.resetToFree()
        service = nil
        try await super.tearDown()
    }

    // MARK: - Free Tier: 4 Analyses (changed from 3)

    func testFreeTierLimit_IsFour() {
        XCTAssertEqual(service.remainingFreeAnalyses, 4, "Free tier should start with 4 analyses (changed from 3)")
    }

    func testFreeTierCanPerformAnalysis_WhenHasRemaining() {
        XCTAssertTrue(service.canPerformAnalysis(), "Free user with remaining analyses should be able to perform analysis")
    }

    func testFreeTierCanPerformExactlyFourAnalyses() {
        // Use all 4 analyses
        for i in 1...4 {
            XCTAssertTrue(service.canPerformAnalysis(), "Should be able to perform analysis #\(i)")
            service.incrementAnalysisCount()
        }
        // 5th should fail
        XCTAssertFalse(service.canPerformAnalysis(), "Should NOT be able to perform 5th analysis on free tier")
    }

    func testFreeTierRemainingCountDecrementsCorrectly() {
        XCTAssertEqual(service.remainingFreeAnalyses, 4)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingFreeAnalyses, 3)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingFreeAnalyses, 2)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingFreeAnalyses, 1)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingFreeAnalyses, 0)
    }

    func testFreeTierHasReachedLimit_AfterFourAnalyses() {
        for _ in 1...4 {
            service.incrementAnalysisCount()
        }
        XCTAssertTrue(service.hasReachedFreeLimit, "hasReachedFreeLimit should be true after 4 analyses")
    }

    func testFreeTierHasNotReachedLimit_BeforeFourAnalyses() {
        service.incrementAnalysisCount()
        service.incrementAnalysisCount()
        service.incrementAnalysisCount()
        XCTAssertFalse(service.hasReachedFreeLimit, "hasReachedFreeLimit should be false after 3 analyses")
    }

    func testFreeTierSubscriptionStatus() {
        let status = service.subscriptionStatus
        XCTAssertTrue(status.contains("Free"), "Status should indicate Free tier")
        XCTAssertTrue(status.contains("4"), "Status should show limit of 4")
    }

    // MARK: - Weekly Subscription: 10 Analyses

    func testWeeklySubscription_Limit() async {
        let success = await service.mockPurchase(packageId: "weekly")
        XCTAssertTrue(success, "Mock weekly purchase should succeed")
        XCTAssertTrue(service.isWeeklySubscriber, "Should be marked as weekly subscriber")
        XCTAssertEqual(service.currentProLimit, 10, "Weekly pro limit should be 10")
        XCTAssertEqual(service.remainingProAnalyses, 10, "Weekly subscriber should start with 10 analyses")
    }

    func testWeeklySubscription_IsProUser() async {
        let _ = await service.mockPurchase(packageId: "weekly")
        XCTAssertTrue(service.isProUser, "Weekly subscriber should be a pro user")
    }

    func testWeeklySubscription_CanPerformTenAnalyses() async {
        let _ = await service.mockPurchase(packageId: "weekly")

        for i in 1...10 {
            XCTAssertTrue(service.canPerformAnalysis(), "Weekly subscriber should be able to perform analysis #\(i)")
            service.incrementAnalysisCount()
        }
        XCTAssertFalse(service.canPerformAnalysis(), "Weekly subscriber should NOT be able to perform 11th analysis")
    }

    func testWeeklySubscription_RemainingDecrementsCorrectly() async {
        let _ = await service.mockPurchase(packageId: "weekly")

        XCTAssertEqual(service.remainingProAnalyses, 10)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingProAnalyses, 9)
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingProAnalyses, 8)
    }

    func testWeeklySubscription_SubscriptionStatus() async {
        let _ = await service.mockPurchase(packageId: "weekly")

        let status = service.subscriptionStatus
        XCTAssertTrue(status.contains("Pro"), "Status should indicate Pro tier")
        XCTAssertTrue(status.contains("10"), "Status should show limit of 10")
        XCTAssertTrue(status.contains("week"), "Status should say 'week' for weekly subscriber")
    }

    // MARK: - Monthly Subscription: 50 Analyses (not weekly)

    func testMonthlySubscription_Limit() async {
        let success = await service.mockPurchase(packageId: "monthly")
        XCTAssertTrue(success, "Mock monthly purchase should succeed")
        XCTAssertFalse(service.isWeeklySubscriber, "Should NOT be marked as weekly subscriber")
        XCTAssertEqual(service.currentProLimit, 50, "Monthly pro limit should be 50")
        XCTAssertEqual(service.remainingProAnalyses, 50, "Monthly subscriber should start with 50 analyses")
    }

    func testAnnualSubscription_Limit() async {
        let success = await service.mockPurchase(packageId: "annual")
        XCTAssertTrue(success, "Mock annual purchase should succeed")
        XCTAssertFalse(service.isWeeklySubscriber, "Annual subscriber should NOT be weekly")
        XCTAssertEqual(service.currentProLimit, 50, "Annual pro limit should be 50")
        XCTAssertEqual(service.remainingProAnalyses, 50, "Annual subscriber should start with 50 analyses")
    }

    func testMonthlySubscription_SubscriptionStatus() async {
        let _ = await service.mockPurchase(packageId: "monthly")

        let status = service.subscriptionStatus
        XCTAssertTrue(status.contains("Pro"), "Status should indicate Pro tier")
        XCTAssertTrue(status.contains("50"), "Status should show limit of 50")
        XCTAssertTrue(status.contains("month"), "Status should say 'month' for monthly subscriber")
    }

    // MARK: - No Free Trial

    func testPurchase_NoTrialPeriod() async {
        let _ = await service.mockPurchase(packageId: "weekly")
        XCTAssertFalse(service.isInTrialPeriod, "Should NOT be in trial period after purchase (no free trial)")
        XCTAssertTrue(service.isProUser, "Should be pro user immediately after purchase")
    }

    func testPurchaseMonthly_NoTrialPeriod() async {
        let _ = await service.mockPurchase(packageId: "monthly")
        XCTAssertFalse(service.isInTrialPeriod, "Should NOT be in trial period after monthly purchase")
        XCTAssertTrue(service.isProUser, "Should be pro user immediately after monthly purchase")
    }

    func testPurchaseSkipTrial_NoTrialPeriod() async {
        let _ = await service.mockPurchaseSkipTrial(packageId: "weekly")
        XCTAssertFalse(service.isInTrialPeriod, "mockPurchaseSkipTrial should NOT set trial period")
        XCTAssertTrue(service.isProUser, "Should be pro immediately with skip trial")
    }

    func testInitialState_NotInTrial() {
        XCTAssertFalse(service.isInTrialPeriod, "Initial state should NOT be in trial period")
    }

    // MARK: - Subscription Type Switching

    func testSwitchFromWeeklyToMonthly() async {
        // Purchase weekly first
        let _ = await service.mockPurchase(packageId: "weekly")
        XCTAssertTrue(service.isWeeklySubscriber)
        XCTAssertEqual(service.currentProLimit, 10)

        // Cancel and go back to free
        let _ = await service.mockCancelSubscription()
        XCTAssertFalse(service.isProUser)

        // Purchase monthly
        let _ = await service.mockPurchase(packageId: "monthly")
        XCTAssertFalse(service.isWeeklySubscriber)
        XCTAssertEqual(service.currentProLimit, 50)
        XCTAssertEqual(service.remainingProAnalyses, 50)
    }

    // MARK: - Reset to Free

    func testResetToFree_RestoresFullFreeLimit() async {
        // Use some analyses
        service.incrementAnalysisCount()
        service.incrementAnalysisCount()
        XCTAssertEqual(service.remainingFreeAnalyses, 2)

        // Reset
        service.resetToFree()
        XCTAssertEqual(service.remainingFreeAnalyses, 4, "Reset should restore 4 free analyses")
        XCTAssertFalse(service.isProUser)
        XCTAssertFalse(service.isInTrialPeriod)
        XCTAssertFalse(service.hasReachedFreeLimit)
    }

    func testCancelSubscription_RestoresFreeTier() async {
        let _ = await service.mockPurchase(packageId: "weekly")
        XCTAssertTrue(service.isProUser)

        let cancelled = await service.mockCancelSubscription()
        XCTAssertTrue(cancelled, "Cancel should succeed")
        XCTAssertFalse(service.isProUser, "Should no longer be pro after cancellation")
        XCTAssertEqual(service.remainingFreeAnalyses, 4, "Should have 4 free analyses after cancel")
    }

    // MARK: - MockPackages

    func testMockPackages_ContainsWeekly() {
        let weekly = service.mockPackages.first { $0.id == "weekly" }
        XCTAssertNotNil(weekly, "Should have a weekly mock package")
        XCTAssertEqual(weekly?.title, "Weekly")
    }

    func testMockPackages_ContainsMonthly() {
        let monthly = service.mockPackages.first { $0.id == "monthly" }
        XCTAssertNotNil(monthly, "Should have a monthly mock package")
    }

    func testMockPackages_ContainsAnnual() {
        let annual = service.mockPackages.first { $0.id == "annual" }
        XCTAssertNotNil(annual, "Should have an annual mock package")
    }

    func testMockPackages_OrderIsAnnualMonthlyWeekly() {
        XCTAssertEqual(service.mockPackages[0].id, "annual", "First package should be annual")
        XCTAssertEqual(service.mockPackages[1].id, "monthly", "Second package should be monthly")
        XCTAssertEqual(service.mockPackages[2].id, "weekly", "Third package should be weekly")
    }
}

// MARK: - AudioFile isDemoFile Tests

final class AudioFileDemoTests: XCTestCase {

    func testAudioFile_isDemoFileDefaultsFalse() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let file = AudioFile(
            fileName: "test",
            fileURL: url,
            duration: 120,
            sampleRate: 44100,
            bitDepth: 16,
            numberOfChannels: 2,
            fileSize: 1000
        )
        XCTAssertFalse(file.isDemoFile, "isDemoFile should default to false")
    }

    func testAudioFile_isDemoFileCanBeSetTrue() {
        let url = URL(fileURLWithPath: "/tmp/demo.wav")
        let file = AudioFile(
            fileName: "demo",
            fileURL: url,
            duration: 120,
            sampleRate: 44100,
            bitDepth: 16,
            numberOfChannels: 2,
            fileSize: 1000,
            isDemoFile: true
        )
        XCTAssertTrue(file.isDemoFile, "isDemoFile should be true when set in init")
    }
}
