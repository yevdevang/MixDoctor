//
//  LifetimeAccessTests.swift
//  MixDoctorTests
//
//  Sanity checks for the Lifetime Pro one-time-purchase entitlement plumbing:
//  MockSubscriptionService's mirror of hasLifetimeAccess, and AnalysisResult's
//  usedLocalModel flag defaulting correctly.
//

import XCTest
@testable import MixDoctor

@MainActor
final class LifetimeAccessTests: XCTestCase {

    func testAnalysisResultDefaultsToNotUsingLocalModel() {
        let result = AnalysisResult(audioFile: nil)
        XCTAssertFalse(result.usedLocalModel)
    }

    func testMockPurchaseLifetimeGrantsAccess() async {
        // MockSubscriptionService is a persisted singleton (iCloud KV store), so start
        // from a known state rather than assuming a fresh-install default.
        let mock = MockSubscriptionService.shared
        mock.hasLifetimeAccess = false

        let success = await mock.mockPurchaseLifetime()

        XCTAssertTrue(success)
        XCTAssertTrue(mock.hasLifetimeAccess)
    }

    func testLifetimePackageIsListedSeparatelyFromSubscriptions() {
        let mock = MockSubscriptionService.shared
        XCTAssertEqual(mock.lifetimePackage.id, "lifetime")
        XCTAssertFalse(mock.mockPackages.contains { $0.id == "lifetime" })
    }
}
