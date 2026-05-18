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

    // MARK: - Captured situation (v1.2 keyboard-extension spike)

    func testNoCapturedSituationByDefault() {
        let router = LaunchRouter(defaults: defaults)
        XCTAssertNil(router.pendingCapturedSituation)
        XCTAssertNil(router.consumeCapturedSituation())
    }

    func testFlagCapturedSituationTrimsAndPeekIsNonDestructive() {
        let router = LaunchRouter(defaults: defaults)
        router.flagCapturedSituation("  my coworker took credit again  ")
        XCTAssertEqual(router.pendingCapturedSituation, "my coworker took credit again")
        XCTAssertEqual(router.pendingCapturedSituation, "my coworker took credit again",
                       "Peek must not clear the captured text")
    }

    func testBlankCaptureIsIgnored() {
        let router = LaunchRouter(defaults: defaults)
        router.flagCapturedSituation("   \n  ")
        XCTAssertNil(router.pendingCapturedSituation,
                     "A stray keyboard tap with no real text must not leave a pending request")
    }

    func testConsumeCapturedSituationClearsExactlyOnce() {
        let router = LaunchRouter(defaults: defaults)
        router.flagCapturedSituation("ex texted at 2am")
        XCTAssertEqual(router.consumeCapturedSituation(), "ex texted at 2am")
        XCTAssertNil(router.consumeCapturedSituation(), "Second consume must be empty")
        XCTAssertNil(router.pendingCapturedSituation)
    }

    func testCapturedSituationSurvivesAcrossInstances() {
        // The keyboard extension process parks; a fresh app instance drains.
        LaunchRouter(defaults: defaults).flagCapturedSituation("group chat drama")
        let foreground = LaunchRouter(defaults: defaults)
        XCTAssertEqual(foreground.consumeCapturedSituation(), "group chat drama")
    }

    func testQuickVentAndCapturedSituationAreIndependent() {
        let router = LaunchRouter(defaults: defaults)
        router.flagQuickVent()
        router.flagCapturedSituation("landlord ignored my email")
        XCTAssertTrue(router.consumeQuickVent())
        // Draining quick-vent must not have eaten the captured text.
        XCTAssertEqual(router.consumeCapturedSituation(), "landlord ignored my email")
    }
}
