//
//  LifetimeAccessTests.swift
//  MixDoctorTests
//
//  Coverage for the Lifetime Pro one-time-purchase feature: entitlement plumbing,
//  AnalysisResult.usedLocalModel defaulting, and the canPerformAnalysis()/
//  subscriptionStatus fixes so Lifetime purchasers aren't blocked by the Claude
//  free/Pro quota once it's exhausted.
//

import XCTest
@testable import MixDoctor

@MainActor
final class LifetimeAccessTests: XCTestCase {

    var mock: MockSubscriptionService!

    /// Whether the local model can actually run on this machine right now (OS +
    /// Apple Intelligence availability). Tests that exercise the Lifetime bypass only
    /// assert when this is true, since the bypass is intentionally conditional on it —
    /// they skip gracefully everywhere else rather than asserting a false negative.
    private var isLocalModelUsableOnThisMachine: Bool {
        if #available(iOS 26.0, *) {
            return LocalModelAnalysisService.isAvailable
        }
        return false
    }

    override func setUp() async throws {
        try await super.setUp()
        // MockSubscriptionService is a persisted singleton (iCloud KV store) shared with
        // SubscriptionTierTests, so start from a known, fully-reset state each time.
        mock = MockSubscriptionService.shared
        mock.resetToFree()
        mock.hasLifetimeAccess = false
        try await Task.sleep(nanoseconds: 50_000_000) // let state settle, matches SubscriptionTierTests
    }

    override func tearDown() async throws {
        mock.resetToFree()
        mock.hasLifetimeAccess = false
        mock = nil
        try await super.tearDown()
    }

    // MARK: - AnalysisResult.usedLocalModel

    func testAnalysisResultDefaultsToNotUsingLocalModel() {
        let result = AnalysisResult(audioFile: nil)
        XCTAssertFalse(result.usedLocalModel)
    }

    // MARK: - Purchase plumbing

    func testMockPurchaseLifetimeGrantsAccess() async {
        let success = await mock.mockPurchaseLifetime()

        XCTAssertTrue(success)
        XCTAssertTrue(mock.hasLifetimeAccess)
    }

    func testLifetimePackageIsListedSeparatelyFromSubscriptions() {
        XCTAssertEqual(mock.lifetimePackage.id, "lifetime")
        XCTAssertFalse(mock.mockPackages.contains { $0.id == "lifetime" })
    }

    // MARK: - canPerformAnalysis() — Lifetime must bypass the Claude quota

    /// Regression test for the bug where Lifetime purchasers hit the paywall once their
    /// free-tier quota ran out, even though local analysis is meant to be unlimited.
    func testCanPerformAnalysis_lifetimeAccessBypassesExhaustedFreeQuota() throws {
        try XCTSkipUnless(isLocalModelUsableOnThisMachine, "Local model unavailable on this machine — bypass branch not exercised")

        for _ in 1...4 { mock.incrementAnalysisCount() }
        XCTAssertEqual(mock.remainingFreeAnalyses, 0, "Sanity check: free quota should be exhausted")

        mock.hasLifetimeAccess = true

        XCTAssertTrue(mock.canPerformAnalysis(), "Lifetime access should bypass an exhausted free quota")
    }

    /// Same bypass, but for a user who is also (or instead) an exhausted Pro subscriber —
    /// the bypass must short-circuit before the Pro-quota check.
    func testCanPerformAnalysis_lifetimeAccessBypassesExhaustedProQuota() async throws {
        try XCTSkipUnless(isLocalModelUsableOnThisMachine, "Local model unavailable on this machine — bypass branch not exercised")

        _ = await mock.mockPurchase(packageId: "monthly")
        while mock.remainingProAnalyses > 0 { mock.incrementAnalysisCount() }
        XCTAssertEqual(mock.remainingProAnalyses, 0, "Sanity check: Pro quota should be exhausted")

        mock.hasLifetimeAccess = true

        XCTAssertTrue(mock.canPerformAnalysis(), "Lifetime access should bypass an exhausted Pro quota")
    }

    /// Baseline/regression: without Lifetime access, an exhausted free quota still blocks
    /// analysis exactly as before this feature was added.
    func testCanPerformAnalysis_withoutLifetimeAccess_stillRespectsFreeQuota() {
        for _ in 1...4 { mock.incrementAnalysisCount() }

        XCTAssertFalse(mock.canPerformAnalysis(), "Without Lifetime access, exhausted free quota should still block analysis")
    }

    // MARK: - subscriptionStatus text

    func testSubscriptionStatus_lifetimeOnlyUser_showsLifetimeText() {
        mock.hasLifetimeAccess = true

        let status = mock.subscriptionStatus

        XCTAssertTrue(status.contains("Lifetime"), "Status should mention Lifetime for a Lifetime-only user")
    }

    /// If a user somehow holds both an active Pro subscription and Lifetime, the status
    /// text shows the active-subscription info (what they're being billed for), not the
    /// Lifetime text — matches the routing precedence used elsewhere (Lifetime wins for
    /// analysis routing, but the subscription is still what's worth surfacing here since
    /// that's the one they might want to cancel).
    func testSubscriptionStatus_proUserTakesPriorityOverLifetimeText() async {
        _ = await mock.mockPurchase(packageId: "monthly")
        mock.hasLifetimeAccess = true

        let status = mock.subscriptionStatus

        XCTAssertTrue(status.contains("Pro"), "Status should show Pro text when an active subscription exists")
        XCTAssertFalse(status.contains("Lifetime"), "Status should not show Lifetime text while Pro text is shown")
    }

    func testSubscriptionStatus_noLifetimeNoProUser_showsFreeText() {
        let status = mock.subscriptionStatus

        XCTAssertTrue(status.contains("Free"), "Status should show Free text without Lifetime or Pro")
    }

    // MARK: - hasAnyPaidAccess — drives ResultsView's post-paywall auto-analyze decision

    /// Regression test for the bug where a successful Lifetime purchase was treated the
    /// same as "user closed the paywall without buying anything" because the dismiss
    /// handler only checked isProUser.
    func testHasAnyPaidAccess_trueForLifetimeOnly() {
        mock.hasLifetimeAccess = true
        XCTAssertTrue(mock.hasAnyPaidAccess)
    }

    func testHasAnyPaidAccess_trueForProOnly() async {
        _ = await mock.mockPurchase(packageId: "monthly")
        XCTAssertTrue(mock.hasAnyPaidAccess)
    }

    func testHasAnyPaidAccess_falseForNeither() {
        XCTAssertFalse(mock.hasAnyPaidAccess)
    }

    // MARK: - SettingsViewModel.subscriptionActionButton — drives the Settings action row

    func testSubscriptionActionButton_proUser_showsManageSubscription() {
        let button = SettingsViewModel.subscriptionActionButton(isProUser: true, hasLifetimeAccess: false)
        XCTAssertEqual(button, .manageSubscription)
    }

    /// Pro takes priority even if the user also holds Lifetime — they still need a way
    /// to manage/cancel the active subscription they're being billed for.
    func testSubscriptionActionButton_proAndLifetime_showsManageSubscription() {
        let button = SettingsViewModel.subscriptionActionButton(isProUser: true, hasLifetimeAccess: true)
        XCTAssertEqual(button, .manageSubscription)
    }

    /// Regression test: Lifetime-only users shouldn't see an "Upgrade to Pro" upsell for
    /// something they've already effectively unlocked via the one-time purchase.
    func testSubscriptionActionButton_lifetimeOnly_showsNone() {
        let button = SettingsViewModel.subscriptionActionButton(isProUser: false, hasLifetimeAccess: true)
        XCTAssertEqual(button, .none)
    }

    func testSubscriptionActionButton_neither_showsUpgradeToPro() {
        let button = SettingsViewModel.subscriptionActionButton(isProUser: false, hasLifetimeAccess: false)
        XCTAssertEqual(button, .upgradeToPro)
    }
}

// MARK: - Real SubscriptionService coverage

/// Mirrors the MockSubscriptionService tests above against the real singleton actually
/// used in production, since the Lifetime-bypass fix was applied to both independently.
/// Kept minimal and defensive: SubscriptionService persists real state to iCloud KV
/// storage across app runs (unlike the Mock's `resetToFree()`, there's no full reset
/// helper), so these avoid touching Pro-quota/reset-date state that could collide with
/// whatever real subscription state exists on the machine running the tests.
@MainActor
final class RealSubscriptionServiceLifetimeTests: XCTestCase {

    private var isLocalModelUsableOnThisMachine: Bool {
        if #available(iOS 26.0, *) {
            return LocalModelAnalysisService.isAvailable
        }
        return false
    }

    override func tearDown() async throws {
        SubscriptionService.shared.hasLifetimeAccess = false
        try await super.tearDown()
    }

    func testCanPerformAnalysis_lifetimeAccessBypassesExhaustedFreeQuota() throws {
        try XCTSkipUnless(isLocalModelUsableOnThisMachine, "Local model unavailable on this machine — bypass branch not exercised")

        let service = SubscriptionService.shared
        UserDefaults.standard.set(4, forKey: "analysisCount") // free tier limit is 4
        service.isProUser = false
        service.hasLifetimeAccess = true

        XCTAssertTrue(service.canPerformAnalysis(), "Lifetime access should bypass an exhausted free quota")
    }

    func testSubscriptionStatus_lifetimeOnlyUser_showsLifetimeText() {
        let service = SubscriptionService.shared
        service.isProUser = false
        service.hasLifetimeAccess = true

        XCTAssertTrue(service.subscriptionStatus.contains("Lifetime"), "Status should mention Lifetime for a Lifetime-only user")
    }
}
