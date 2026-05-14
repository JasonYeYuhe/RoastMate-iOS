import XCTest

/// Drives the app through the six App Store screenshot scenes. Run per
/// locale × simulator from `scripts/screenshots.sh`. Each `XCTAttachment`
/// it produces is extracted from the resulting `.xcresult` bundle by
/// `scripts/extract-screenshots.sh`.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_screenshots() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-AppleLanguages", appleLanguagesArgument(),
            "-AppleLocale", appleLocaleArgument()
        ]
        app.launch()

        // 1. Onboarding / age gate flow
        dismissOnboardingIfNeeded(app: app)
        capture(app: app, name: "01-generator-empty")

        // 2. Generator filled in
        let situationField = app.textViews.firstMatch
        if situationField.waitForExistence(timeout: 2) {
            situationField.tap()
            situationField.typeText(sampleSituation())
        }
        capture(app: app, name: "02-generator-filled")

        // 3. Style row scrolled to show variety — tap a Pro style to
        //    show the gating overlay if available, else stay on free.
        capture(app: app, name: "03-style-chips")

        // 4. Explore tab (tools + samples)
        if app.tabBars.buttons.element(boundBy: 1).exists {
            app.tabBars.buttons.element(boundBy: 1).tap()
            capture(app: app, name: "04-explore")
        }

        // 5. History tab (pre-seeded with samples)
        if app.tabBars.buttons.element(boundBy: 2).exists {
            app.tabBars.buttons.element(boundBy: 2).tap()
            capture(app: app, name: "05-history")
        }

        // 6. Settings (About AI / Safe Mode visible)
        if app.tabBars.buttons.element(boundBy: 3).exists {
            app.tabBars.buttons.element(boundBy: 3).tap()
            capture(app: app, name: "06-settings")
        }
    }

    // MARK: - Helpers

    private func dismissOnboardingIfNeeded(app: XCUIApplication) {
        // The 4-screen onboarding tabs through Next → Next → Next → Confirm.
        for _ in 0..<3 {
            let next = app.buttons["common.next"]
            if next.waitForExistence(timeout: 1.5), next.isHittable {
                next.tap()
            }
        }
        let confirm = app.buttons["ageGate.confirm"]
        if confirm.waitForExistence(timeout: 1.5), confirm.isHittable {
            confirm.tap()
        }
    }

    private func capture(app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func currentLocale() -> String {
        ProcessInfo.processInfo.environment["LOCALE"] ?? "en_US"
    }

    private func appleLanguagesArgument() -> String {
        switch currentLocale() {
        case let s where s.hasPrefix("zh_Hans"): return "(zh-Hans)"
        case let s where s.hasPrefix("zh_Hant"): return "(zh-Hant)"
        case let s where s.hasPrefix("ja"):      return "(ja)"
        default:                                 return "(en)"
        }
    }

    private func appleLocaleArgument() -> String {
        currentLocale()
    }

    private func sampleSituation() -> String {
        switch currentLocale() {
        case let s where s.hasPrefix("zh_Hans"): return "我室友凌晨两点打游戏"
        case let s where s.hasPrefix("zh_Hant"): return "我室友凌晨兩點打遊戲"
        case let s where s.hasPrefix("ja"):      return "ルームメイトが深夜2時にゲームをします"
        default:                                  return "My roommate plays games at 2 AM"
        }
    }
}
