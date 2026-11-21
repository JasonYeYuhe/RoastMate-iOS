import XCTest

/// 1.8.0 on a device WITHOUT Apple's on-device model (class C/E devices:
/// iOS 18, or Apple Intelligence off). An iOS 26+ simulator usually has no
/// model either, but on 11-21 the iOS 27.0 simulator on this Mac reported it
/// available (the host's Apple Intelligence), so A4 skips itself when the
/// simulator opens the working tool. Run it on an iOS 18.5 simulator, which
/// never has the model, in a RELEASE build for the plan's class-C check (A2, A4):
///
///     xcodebuild test -scheme RoastMate -configuration Release \
///       -destination id=<iOS 18.5 UDID> -only-testing:RoastMateUITests/DeviceHonestyUITests
///
/// Screenshots are attached to the result bundle for the person who reads them.
final class DeviceHonestyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ lang: String, _ locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "-uitestLang", lang,
                                "-AppleLanguages", "(\(lang))", "-AppleLocale", locale]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// A4: no conversation of canned roast lines; an honest explanation and
    /// no paywall for a tool this device can't run.
    func test_argumentSimulator_explainsItNeedsAppleIntelligence() throws {
        for (lang, locale) in [("en", "en_US"), ("zh-Hant", "zh_TW")] {
            let app = launch(lang, locale)
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
            tabBar.buttons.element(boundBy: 1).tap()
            let tile = element(app, "argument.tile")
            var tries = 0
            while !(tile.exists && tile.isHittable) && tries < 6 { app.swipeUp(); tries += 1 }
            tile.tap()
            if !element(app, "argument.needs_ai").waitForExistence(timeout: 10),
               app.textViews.firstMatch.exists || element(app, "paywall.plan.yyh.roastmate.app.pro.yearly").exists {
                attach(app, "A4-model-available-\(lang)")
                throw XCTSkip("this simulator has Apple's on-device model, so A4 does not apply; run it on iOS 18.5")
            }
            XCTAssertTrue(element(app, "argument.needs_ai").exists,
                          "\(lang): the simulator must explain it needs Apple Intelligence")
            XCTAssertFalse(element(app, "paywall.plan.yyh.roastmate.app.pro.yearly").exists,
                           "\(lang): no paywall for a tool this device can't run")
            attach(app, "A4-simulator-\(lang)")
            app.terminate()
        }
    }

    /// A2 (Release only — Debug is always Pro and never shows the paywall):
    /// the paywall header here claims the style voice in Feral, not "24 styles
    /// need Apple Intelligence".
    func test_curatedPaywall_claimsWhatWorksHere() throws {
        let app = launch("en", "en_US")
        let feral = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Feral")).firstMatch
        XCTAssertTrue(feral.waitForExistence(timeout: 15))
        // The intensity row scrolls sideways; on a narrow layout Feral starts off-screen.
        let sharp = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Sharp")).firstMatch
        var tries = 0
        while !feral.isHittable && tries < 4 && sharp.exists {
            sharp.swipeLeft()
            tries += 1
        }
        feral.tap()
        let plan = element(app, "paywall.plan.yyh.roastmate.app.pro.yearly")
        guard plan.waitForExistence(timeout: 10) else {
            throw XCTSkip("No paywall: Debug build (always Pro). Run with -configuration Release.")
        }
        let header = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Pro style you pick")).firstMatch
        XCTAssertTrue(header.exists, "the curated header claims the style voice in Feral")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "24 styles")).firstMatch.exists)
        attach(app, "A2-paywall-curated-en")
    }
}
