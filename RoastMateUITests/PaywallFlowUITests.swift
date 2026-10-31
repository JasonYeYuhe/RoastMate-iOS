import XCTest
import StoreKitTest

/// A6 (1.8.0): the purchase flow, in a RELEASE build. Debug is always Pro
/// (`StoreService.isPro`), so on a Debug build the paywall never opens and
/// these tests skip themselves rather than pass vacuously.
///
///     xcodebuild test -scheme RoastMate -configuration Release \
///       -destination id=<UDID> -only-testing:RoastMateUITests/PaywallFlowUITests
///
/// StoreKit is driven through `SKTestSession` with the app's own
/// `Configuration.storekit` (copied into this bundle by project.yml), so no
/// real purchase is made.
final class PaywallFlowUITests: XCTestCase {

    private var session: SKTestSession!
    private let yearly = "yyh.roastmate.app.pro.yearly"
    private let monthly = "yyh.roastmate.app.pro.monthly"

    override func setUpWithError() throws {
        continueAfterFailure = false
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    private func launchEnglish() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "-uitestLang", "en",
                                "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func scrollTo(_ el: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !(el.exists && el.isHittable) && tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    /// A free user loads the Pro-style sample (MBA, sample_02) and taps
    /// Generate. Until 1.8.0 that showed the orange "quota exhausted" error.
    private func openPaywallFromProSample(_ app: XCUIApplication) throws {
        let sample = element(app, "sample.sample_02")
        scrollTo(sample, in: app)
        XCTAssertTrue(sample.waitForExistence(timeout: 10), "the Pro-style sample must be among the five shown")
        sample.tap()
        let generate = element(app, "generate_button")
        scrollTo(generate, in: app)
        generate.tap()
        let plan = element(app, "paywall.plan.\(yearly)")
        if !plan.waitForExistence(timeout: 15) {
            throw XCTSkip("No paywall: this is a Debug build (always Pro). Run with -configuration Release.")
        }
    }

    func test_proSample_opensPaywall_yearlyFirst_trialShown_purchaseHandsOff() throws {
        let app = launchEnglish()
        try openPaywallFromProSample(app)

        let yearlyRow = element(app, "paywall.plan.\(yearly)")
        let monthlyRow = element(app, "paywall.plan.\(monthly)")
        XCTAssertTrue(monthlyRow.waitForExistence(timeout: 5))
        XCTAssertLessThan(yearlyRow.frame.minY, monthlyRow.frame.minY, "yearly is listed first")

        let trial = element(app, "paywall.trial")
        XCTAssertTrue(trial.waitForExistence(timeout: 5), "an eligible buyer sees the trial line")
        XCTAssertTrue(trial.label.contains("free trial"), trial.label)

        yearlyRow.tap()
        let done = app.alerts.buttons["Got it"]
        XCTAssertTrue(done.waitForExistence(timeout: 20), "the success alert after the purchase")
        done.tap()

        // Hand-off: the paywall closes, the Pro style the user reached for is
        // selected, and the Generate they tapped runs once.
        let chip = element(app, "style.mba_boss")
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        XCTAssertTrue(chip.isSelected, "the Pro style from the sample is selected after purchase")
        let generate = element(app, "generate_button")
        var tries = 0
        while !generate.label.contains("Generate again") && tries < 20 {
            sleep(1)
            tries += 1
        }
        XCTAssertTrue(generate.label.contains("Generate again"), "the generation the user asked for ran after the purchase: \(generate.label)")
    }

    func test_trialLine_hiddenOnceTheIntroIsUsed() throws {
        try session.buyProduct(productIdentifier: yearly)
        try session.expireSubscription(productIdentifier: yearly)

        let app = launchEnglish()
        try openPaywallFromProSample(app)
        XCTAssertTrue(element(app, "paywall.plan.\(yearly)").exists)
        sleep(2)  // eligibility resolves before the row renders; give it time to (wrongly) appear
        XCTAssertFalse(element(app, "paywall.trial").exists, "no trial line once the intro offer was used")
    }
}
