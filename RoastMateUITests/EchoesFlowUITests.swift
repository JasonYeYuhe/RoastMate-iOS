import XCTest

/// Runtime verification of the Echoes wiring after 1.8.0 (B3 + A7): the
/// Classic Echoes (替你出气) tile is retired, and the roommate group asks the
/// corrected cloud consent again. Until 1.8.0 these tests drove the classic
/// tile's canned on-device transcript and its "只用本机生成" button — the
/// copy A7 found false. The roommate group is cloud-only, so no transcript
/// is generated here (that needs the Worker); these tests stop at the sheet.
///
/// Launches in zh-Hans because the roommate tile is locale-gated to
/// Simplified Chinese.
final class EchoesFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchZhHans() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", "zh-Hans",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans"
        ]
        app.launch()
        return app
    }

    /// Find an element by accessibility id across the common types a
    /// SwiftUI control might surface as (button / other / link / static).
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let any = app.descendants(matching: .any).matching(identifier: id).firstMatch
        return any
    }

    private func goToLibraryTab(_ app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist on launch.")
        // Generator(0), Library(1), History(2), Settings(3)
        let libraryTab = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5), "Library tab should exist.")
        libraryTab.tap()
    }

    // MARK: - Test 1: classic retired, roommate group still there

    func test_classicEchoesRetired_roommateTileShows() {
        let app = launchZhHans()
        goToLibraryTab(app)

        let roommate = element(app, "roommate.tile")
        XCTAssertTrue(roommate.waitForExistence(timeout: 10),
                      "The roommate group tile must still show in zh-Hans Explore.")
        XCTAssertFalse(element(app, "echoes.tile").exists,
                       "Classic Echoes (替你出气) is retired in 1.8.0.")
    }

    // MARK: - Test 2: the roommate group asks the corrected consent

    func test_roommate_asksTheCorrectedCloudConsent() {
        let app = launchZhHans()  // -uitest resets the consent to notAsked
        goToLibraryTab(app)

        let tile = element(app, "roommate.tile")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()

        let situation = element(app, "echoes.situation")
        XCTAssertTrue(situation.waitForExistence(timeout: 10))
        situation.tap()
        situation.typeText("同事又把我的方案抢去邀功")
        app.navigationBars.firstMatch.tap()

        let generate = element(app, "echoes.generate")
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        var scrollTries = 0
        while !generate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        generate.tap()

        // Poll .exists: the sheet presents while the app is not idle.
        let allow = app.buttons["同意，发到云端生成"]
        let deny = app.buttons["不同意"]
        var sheetTries = 0
        while !(allow.exists || deny.exists) && sheetTries < 15 {
            sleep(1)
            sheetTries += 1
        }
        XCTAssertTrue(allow.exists && deny.exists,
                      "The roommate group must present the corrected cloud-consent sheet.")
        XCTAssertFalse(app.buttons["只用本机生成"].exists,
                       "The old deny button promised on-device generation the roommate group never does.")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "OpenRouter")).firstMatch.exists,
                      "The consent body must name OpenRouter.")

        deny.tap()
        XCTAssertTrue(app.state == .runningForeground, "Denying must leave the app usable.")
    }
}
