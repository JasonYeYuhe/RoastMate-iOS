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

    /// Captures the credit/Pro paywall for App Store IAP review
    /// screenshots. Pinned to English; StoreKit-config products render
    /// because the scheme now carries `Configuration.storekit`.
    func test_paywall() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", "en",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        // Settings is the 4th tab (index 3); it hosts the paywall entry.
        let settingsTab = app.tabBars.buttons.element(boundBy: 3)
        if settingsTab.waitForExistence(timeout: 8) {
            settingsTab.tap()
        }

        // "Get more credits" is in the Subscription section, below the
        // fold — scroll the Settings form until it's hittable.
        let buy = app.buttons["Get more credits"]
        var tries = 0
        while !buy.isHittable && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        if buy.isHittable {
            buy.tap()
        } else if app.staticTexts["Get more credits"].isHittable {
            app.staticTexts["Get more credits"].tap()
        }

        // Credit-pack consumables resolve slower than subscriptions in
        // the StoreKit-config environment — wait generously so the packs
        // render (not "Loading…") for the IAP review screenshot.
        sleep(18)
        capture(app: app, name: "07-paywall")
    }

    // MARK: - 小红书 marketing screenshots

    /// 小红书 (Xiaohongshu) marketing captures — zh-Hans only. Unlike the
    /// App Store set above, these capture FEATURE OUTPUT: the 虚拟舍友群
    /// group-chat transcript, a 替你出气 transcript, and the bridge →
    /// rewrite closing loop. The roommate scene generates via the REAL
    /// cloud Worker (the consent sheet is accepted in-test) — run with
    /// network. Driven by scripts/xiaohongshu-screenshots.sh, which also
    /// resets app state so the consent sheet is deterministic.
    func test_screenshots_xiaohongshu() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", "zh-Hans",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans"
        ]
        app.launch()

        // ── Scene 1: generator filled with a relatable grievance ──
        let situationField = app.textViews.firstMatch
        if situationField.waitForExistence(timeout: 8) {
            var tries = 0
            while !situationField.isHittable && tries < 10 { usleep(300_000); tries += 1 }
            if situationField.isHittable {
                situationField.tap()
                situationField.typeText("同事把我做的方案署上他自己的名字交给老板，还在群里@我说谢谢配合")
            }
        }
        // Keyboard stays visible in this capture (promo crops use the top
        // 3:4 anyway). Root-level TextEditor keyboards can't be reliably
        // dismissed in SwiftUI via nav-bar taps (that only works in the
        // pushed Echoes views), and the keyboard covers the tab bar — so
        // scene 2 onward uses a clean RELAUNCH instead of dismissal.
        capture(app: app, name: "xhs-01-generator-filled")
        app.terminate()
        app.launch()

        // ── Scene 2: Explore tab — 替你出气 + 虚拟舍友群 tiles visible ──
        let exploreTab = app.tabBars.buttons.element(boundBy: 1)
        guard exploreTab.waitForExistence(timeout: 10) && exploreTab.isHittable else { return }
        exploreTab.tap()
        // The tools section can sit below the fold (lazy grid) — scroll
        // until the roommate tile exists so the capture shows both tiles.
        let roommateTile = anyElement(app, "roommate.tile")
        var exploreScrolls = 0
        while !roommateTile.exists && exploreScrolls < 4 {
            app.swipeUp()
            exploreScrolls += 1
        }
        sleep(1)
        capture(app: app, name: "xhs-02-explore-tiles")

        // ── Scene 3: roommate group setup, filled ──
        guard roommateTile.waitForExistence(timeout: 8) else { return }
        if !roommateTile.isHittable { app.swipeUp() }
        roommateTile.tap()

        let situation = anyElement(app, "echoes.situation")
        guard situation.waitForExistence(timeout: 8) else { return }
        situation.tap()
        situation.typeText("室友半夜两点开外放打游戏，说了三次都当耳旁风")
        // Dismiss the keyboard so the full setup (banner + button) shows.
        app.navigationBars.firstMatch.tap()
        capture(app: app, name: "xhs-03-roommate-setup")

        // ── Scene 4: generate → accept cloud consent → full group chat ──
        let generate = anyElement(app, "echoes.generate")
        guard generate.waitForExistence(timeout: 5) else { return }
        var scrollTries = 0
        while !generate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        generate.tap()

        // Roommate is cloud-only: the dedicated consent sheet appears when
        // not yet granted (fresh install via the runner script). Accept it.
        // If state carried over and it's already granted, the sheet just
        // never shows — poll briefly, then move on either way.
        let allow = app.buttons["允许 Feral 走云端"]
        var consentTries = 0
        while !allow.exists && consentTries < 10 {
            sleep(1)
            consentTries += 1
        }
        if allow.exists { allow.tap() }

        // Cloud latency (2–8s) + 8–10-message reveal (~350–550ms each).
        // The reveal animation keeps the app from reporting "idle", so
        // poll .exists instead of waitForExistence (same as EchoesFlow).
        let bridge = anyElement(app, "echoes.bridge")
        var revealTries = 0
        while !bridge.exists && revealTries < 60 {
            sleep(1)
            revealTries += 1
        }
        // Let the last bubble's animation finish before capturing.
        sleep(1)
        capture(app: app, name: "xhs-04-roommate-chat")

        // ── Scene 5: scroll to the top of the group chat (opening msgs) ──
        if bridge.exists {
            app.swipeDown()
            app.swipeDown()
            capture(app: app, name: "xhs-05-roommate-chat-top")
            // Return to the bottom so the bridge is tappable later if needed.
            app.swipeUp()
            app.swipeUp()
        }

        // ── Scene 6: classic 替你出气 transcript ──
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        let echoesTile = anyElement(app, "echoes.tile")
        guard echoesTile.waitForExistence(timeout: 8) else { return }
        echoesTile.tap()

        let echoesSituation = anyElement(app, "echoes.situation")
        guard echoesSituation.waitForExistence(timeout: 8) else { return }
        echoesSituation.tap()
        echoesSituation.typeText("借我钱的时候喊我宝，催他还钱就已读不回，朋友圈还在晒新手机")
        app.navigationBars.firstMatch.tap()

        let echoesGenerate = anyElement(app, "echoes.generate")
        guard echoesGenerate.waitForExistence(timeout: 5) else { return }
        scrollTries = 0
        while !echoesGenerate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        echoesGenerate.tap()

        // Casual tone = on-device / curated fallback — no consent sheet.
        let echoesBridge = anyElement(app, "echoes.bridge")
        revealTries = 0
        while !echoesBridge.exists && revealTries < 45 {
            sleep(1)
            revealTries += 1
        }
        sleep(1)
        capture(app: app, name: "xhs-06-echoes-chat")

        // ── Scene 7: the closing loop — bridge → generator pre-filled ──
        if echoesBridge.exists {
            echoesBridge.tap()
            let generatorSituation = app.textViews["situation_editor"]
            if generatorSituation.waitForExistence(timeout: 10) {
                // Give EchoBridgeStore a beat to pre-fill the grievance.
                sleep(2)
                capture(app: app, name: "xhs-07-bridge-rewrite")
            }
        }
    }

    /// Find an element by accessibility id across the element types a
    /// SwiftUI control may surface as (same helper as EchoesFlowUITests).
    private func anyElement(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
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
