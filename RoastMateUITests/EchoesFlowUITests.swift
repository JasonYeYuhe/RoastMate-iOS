import XCTest

/// Runtime verification of the Echoes (替你出气) feature wiring. Exercises
/// the real SwiftUI views in the simulator — complements the pure-logic
/// unit tests (EchoesParserTests, EchoesFeralConsentGateTests).
///
/// In the simulator Foundation Models is unavailable, so EchoesEngine
/// takes the curated-fallback path and renders a deterministic canned
/// transcript. That's expected — this test verifies UI + navigation +
/// the Bridge-to-Action deep link, NOT model output quality (which is
/// covered by the eval harness against the cloud model).
///
/// Launches in zh-Hans because the Echoes tile is locale-gated to
/// Simplified Chinese in v1.
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

    // MARK: - Test 1: the critical Bridge-to-Action path

    func test_echoes_setup_generate_bridge_deeplink() {
        let app = launchZhHans()
        goToLibraryTab(app)

        // 1. Echoes tile is visible (locale-gated zh-Hans).
        let tile = element(app, "echoes.tile")
        XCTAssertTrue(tile.waitForExistence(timeout: 10),
                      "Echoes tile must be visible in zh-Hans Explore.")
        tile.tap()

        // 2. Setup screen renders with the situation editor + generate button.
        let situation = element(app, "echoes.situation")
        XCTAssertTrue(situation.waitForExistence(timeout: 10),
                      "Echoes setup situation editor must render.")
        situation.tap()
        situation.typeText("室友半夜三点还在打游戏开外放")

        let generate = element(app, "echoes.generate")
        XCTAssertTrue(generate.waitForExistence(timeout: 5),
                      "Generate button must render.")
        // Dismiss the keyboard by tapping the nav bar (safe — won't hit
        // the tone/voice pickers and accidentally flip to Feral).
        app.navigationBars.firstMatch.tap()
        // Scroll the button into a hittable position if the keyboard /
        // layout left it off-screen.
        var scrollTries = 0
        while !generate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        generate.tap()

        // 3. Transcript reveals — the bridge bubble appears after the
        //    message-by-message reveal (curated fallback = ~5 msgs ×
        //    600ms). Generous timeout covers generation + reveal.
        let bridge = element(app, "echoes.bridge")
        XCTAssertTrue(bridge.waitForExistence(timeout: 25),
                      "Bridge-to-Action bubble must appear at the end of the transcript reveal.")

        // 4. Tap the bridge → app switches to Generator tab + pre-fills.
        bridge.tap()

        let generatorSituation = element(app, "generator.situation")
        XCTAssertTrue(generatorSituation.waitForExistence(timeout: 10),
                      "Tapping the bridge must land on the Generator tab (its situation field must exist).")
        // The deep-link pre-fills the original grievance. Assert non-empty
        // value containing our typed text.
        let value = (generatorSituation.value as? String) ?? ""
        XCTAssertTrue(value.contains("室友") || value.contains("外放"),
                      "Bridge deep-link must pre-fill the Generator situation with the original grievance. Got: \(value)")
    }

    // MARK: - Test 2: Feral tone triggers the dedicated consent sheet

    func test_echoes_feral_triggers_consent_sheet() {
        let app = launchZhHans()
        goToLibraryTab(app)

        let tile = element(app, "echoes.tile")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()

        let situation = element(app, "echoes.situation")
        XCTAssertTrue(situation.waitForExistence(timeout: 10))
        situation.tap()
        situation.typeText("同事又把我的方案抢去邀功")

        // Switch tone to Feral (狂怒) — the second segment of the tone picker.
        // Segmented controls surface their segments as buttons.
        let feralSegment = app.buttons["狂怒"]
        if feralSegment.waitForExistence(timeout: 3) {
            feralSegment.tap()
        }

        let generate = element(app, "echoes.generate")
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        app.navigationBars.firstMatch.tap()  // dismiss keyboard safely
        var scrollTries = 0
        while !generate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        generate.tap()

        // The first Feral generation must present the dedicated consent
        // sheet (5.1.2(i) — separate from the Vent cloud consent).
        // Match on a distinctive substring of the sheet's body/buttons.
        let denyButton = app.buttons["只用本机生成"]
        let allowButton = app.buttons["允许 Feral 走云端"]
        let sheetAppeared = denyButton.waitForExistence(timeout: 10)
            || allowButton.waitForExistence(timeout: 2)
        XCTAssertTrue(sheetAppeared,
                      "First Feral selection must present the dedicated Echoes Feral cloud-consent sheet.")

        // Deny → should still generate on-device without crashing.
        if denyButton.exists { denyButton.tap() }

        // After denying, a Casual/on-device transcript should still
        // eventually produce a bridge bubble (or stay usable).
        let bridge = element(app, "echoes.bridge")
        // Not strictly required to appear on deny path in v1 (deny returns
        // to setup), so we only assert the app didn't crash — the tile/
        // setup is still reachable.
        _ = bridge.waitForExistence(timeout: 8)
        XCTAssertTrue(app.state == .runningForeground,
                      "App must remain alive after denying Feral cloud consent.")
    }
}
