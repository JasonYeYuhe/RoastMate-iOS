import XCTest
@testable import RoastMate

/// Pillar C: native capture. Pins the cross-process Quick Vent hand-off
/// — a peek that does not clear, a consume that clears exactly once, and
/// persistence across instances sharing the same defaults suite (the
/// real path is the App Group; here it is an isolated suite).
@MainActor
final class LaunchRouterTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.launchrouter.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testNoPendingByDefault() {
        let router = LaunchRouter(defaults: defaults)
        XCTAssertFalse(router.hasPendingQuickVent)
        XCTAssertFalse(router.consumeQuickVent())
    }

    func testFlagThenPeekIsNonDestructive() {
        let router = LaunchRouter(defaults: defaults)
        router.flagQuickVent()
        XCTAssertTrue(router.hasPendingQuickVent)
        XCTAssertTrue(router.hasPendingQuickVent, "Peek must not clear the request")
    }

    func testConsumeClearsExactlyOnce() {
        let router = LaunchRouter(defaults: defaults)
        router.flagQuickVent()
        XCTAssertTrue(router.consumeQuickVent())
        XCTAssertFalse(router.consumeQuickVent(), "Second consume must be empty")
        XCTAssertFalse(router.hasPendingQuickVent)
    }

    func testRequestSurvivesAcrossInstances() {
        // The intent process flags; a fresh foreground instance drains.
        LaunchRouter(defaults: defaults).flagQuickVent()
        let foreground = LaunchRouter(defaults: defaults)
        XCTAssertTrue(foreground.consumeQuickVent())
    }
}
