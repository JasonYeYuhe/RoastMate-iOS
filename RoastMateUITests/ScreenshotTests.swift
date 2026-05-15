import XCTest

/// Drives the app through the six App Store screenshot scenes. Run per
/// locale × simulator from `scripts/screenshots.sh`. Each `XCTAttachment`
/// it produces is extracted from the resulting `.xcresult` bundle by
/// `scripts/extract-screenshots.sh`.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        // Screenshot capture must be resilient: one flaky tap (e.g. the
        // SwiftUI TextEditor briefly reporting "not hittable" while the
        // onboarding overlay finishes dismissing) should NOT abort the
        // other five scenes. We continue after failures and guard every
        // interaction defensively below.
        continueAfterFailure = true
    }

    func test_screenshots() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", uiTestLanguageCode(),
            // Belt-and-braces: also set the standard locale args. The
            // app's -uitest path pins LanguageManager so these aren't
            // load-bearing, but they keep system-formatted dates etc.
            // in the right locale too.
            "-AppleLanguages", appleLanguagesArgument(),
            "-AppleLocale", appleLocaleArgument()
        ]
        app.launch()

        // App skips onboarding entirely under -uitest, so we land
        // straight on the generator. No tapping-through required.
        capture(app: app, name: "01-generator-empty")

        // 2. Generator filled in. The TextEditor can momentarily report
        //    "not hittable" right after onboarding dismissal — poll for
        //    hittability instead of tapping blind, and don't fail the
        //    run if typing doesn't take (scene 1 + 3-6 are still useful).
        let situationField = app.textViews.firstMatch
        if situationField.waitForExistence(timeout: 4) {
            var tries = 0
            while !situationField.isHittable && tries < 10 {
                usleep(300_000)
                tries += 1
            }
            if situationField.isHittable {
                situationField.tap()
                situationField.typeText(sampleSituation())
            }
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

    /// Maps the screenshots.sh `LOCALE` env var to the app's
    /// `-uitestLang` codes (matching `AppLanguage.rawValue`).
    private func uiTestLanguageCode() -> String {
        switch currentLocale() {
        case let s where s.hasPrefix("zh_Hans"): return "zh-Hans"
        case let s where s.hasPrefix("zh_Hant"): return "zh-Hant"
        case let s where s.hasPrefix("ja"):      return "ja"
        default:                                 return "en"
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
