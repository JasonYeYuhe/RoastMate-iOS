import XCTest

/// Drives the app through the App Store screenshot scenes. Run per
/// locale × simulator from `scripts/screenshots.sh`. Each `XCTAttachment`
/// it produces is extracted from the resulting `.xcresult` bundle by
/// `scripts/extract-screenshots.sh`.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        // The marketing flows below poll and carry on after a flaky tap.
        // test_screenshots does NOT rely on this: each of its guards
        // XCTFails and returns, so a broken App Store set fails the run.
        continueAfterFailure = true
    }

    /// App Store set. Every scene is guarded: a capture is only taken once
    /// the screen it claims to show is provably on screen, and any guard
    /// that fails stops the run (a broken set must fail, not upload).
    ///
    /// History of what went wrong here (2026-10-07 root cause):
    /// - The locale never reached this process. scripts/screenshots.sh ran
    ///   `LOCALE=zh_Hant xcodebuild …`, but xcodebuild forwards only
    ///   `TEST_RUNNER_`-prefixed variables to the test runner, so `LOCALE`
    ///   was nil here and the old `?? "en_US"` default produced an ENGLISH
    ///   set for every locale (measured: same UI, same English typed text,
    ///   with LOCALE=zh_Hant; correct zh-Hant with TEST_RUNNER_LOCALE).
    /// - Scenes 2–5 typed into the TextEditor and then tapped the tab bar
    ///   while the keyboard covered it, so every tab tap hit the keyboard:
    ///   4 byte-identical frames, and the last tap hit the dictation key
    ///   ("Enable Dictation?" — a system alert that then survives into the
    ///   NEXT run's first frame).
    /// - The PNGs committed in metadata/screenshots/ (all added in 9e27583,
    ///   2026-05-15, never regenerated) are stale: en_US/ja_JP/zh_Hant are
    ///   the PRE-fix run (onboarding, English); the "zh_Hans" folder is one
    ///   post-fix run that is English (LOCALE never arrived) with the
    ///   keyboard bug above.
    func test_screenshots() throws {
        // Not launched by scripts/screenshots.sh (e.g. preflight runs the whole
        // scheme): nothing to capture, so skip rather than fail. Inside a
        // screenshot run every guard below still fails loudly.
        guard let locale = ProcessInfo.processInfo.environment["LOCALE"], !locale.isEmpty else {
            throw XCTSkip("LOCALE is not set in the test-runner environment. xcodebuild forwards only "
                          + "TEST_RUNNER_-prefixed variables: run scripts/screenshots.sh, or pass "
                          + "TEST_RUNNER_LOCALE=<en_US|zh_Hans|zh_Hant|ja_JP>.")
        }
        guard let spec = ShotLocale(locale) else {
            XCTFail("Unsupported LOCALE '\(locale)' (expected en_US, zh_Hans, zh_Hant or ja_JP).")
            return
        }

        dismissLeftoverDictationAlert()

        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", spec.languageCode,
            // Belt-and-braces: the app's -uitest path pins LanguageManager,
            // these keep system-formatted dates etc. in the locale too.
            "-AppleLanguages", "(\(spec.languageCode))",
            "-AppleLocale", locale
        ]
        // Scene 01 needs a Vent result without the network: a real Worker
        // reply with its profanity tokens deleted (store screenshots must be 4+,
        // App Review 2.3.8), base64, from marketing/appstore/vent-fixtures/
        // via TEST_RUNNER_VENT_FIXTURE. The app swaps it in for the network
        // call only — consent, the cloud gate and the safety filter still run.
        guard let ventFixture = ProcessInfo.processInfo.environment["VENT_FIXTURE"],
              !ventFixture.isEmpty else {
            XCTFail("VENT_FIXTURE is not set: run scripts/screenshots.sh (it passes "
                    + "TEST_RUNNER_VENT_FIXTURE per locale).")
            return
        }
        app.launchArguments += ["-uitestVentFixture", ventFixture]
        app.launch()

        // Guard 1 — the generator is on screen and nothing covers it
        // (onboarding sheet, consent sheet, a system alert).
        let editor = app.textViews["situation_editor"]
        guard waitForHittable(editor, timeout: 20) else {
            XCTFail("The generator's situation editor never became hittable — something covers the root UI.")
            return
        }
        // Guard 2 — the app renders the requested language. The tab label
        // is resolved by the app from its own .strings, so this proves the
        // language forcing worked end to end, not just that LOCALE arrived.
        guard app.tabBars.buttons[spec.settingsTabLabel].waitForExistence(timeout: 5) else {
            XCTFail("No '\(spec.settingsTabLabel)' tab: the app is not rendering \(spec.languageCode).")
            return
        }

        // 2. Situation filled + Vent selected. Filled by tapping the app's
        //    own first scenario card (Scenarios.json `boss_credit`, written
        //    per locale — zh-Hant in Taiwan wording), NOT by typing: the
        //    scenario button never focuses the TextEditor, so no keyboard
        //    ever covers the tab bar. Vent is selected after, because a
        //    scenario sets its own default intensity.
        let scenario = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", spec.scenarioPrefix)).firstMatch
        guard waitForHittable(scenario, timeout: 5) else {
            XCTFail("Scenario card '\(spec.scenarioPrefix)…' not found or not hittable.")
            return
        }
        scenario.tap()
        guard (editor.value as? String)?.hasPrefix(spec.scenarioPrefix) == true else {
            XCTFail("Tapping the scenario did not fill the situation editor (value: \(String(describing: editor.value))).")
            return
        }
        guard selectVent(app, spec) else {
            XCTFail("Could not select the '\(spec.ventLabel)' intensity chip.")
            return
        }
        guard !app.keyboards.firstMatch.exists else {
            XCTFail("Keyboard is up — tab-bar taps would land on it.")
            return
        }
        settle()
        capture(app: app, name: "02-generator-vent")

        // 1. The Vent result card — the store's first, inline-in-search shot.
        //    Generate → the cloud consent sheet (reset to "not asked" on every
        //    -uitest launch) → Allow → the fixture renders through the real
        //    post-consent path.
        let generate = app.buttons[spec.generateLabel]
        guard waitForHittable(generate, timeout: 5) else {
            XCTFail("'\(spec.generateLabel)' button not hittable.")
            return
        }
        generate.tap()
        let allow = app.buttons[spec.allowCloudLabel]
        guard waitForHittable(allow, timeout: 10) else {
            XCTFail("Cloud consent sheet never offered '\(spec.allowCloudLabel)'.")
            return
        }
        allow.tap()
        let rewrite = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", spec.rewriteLabel)).firstMatch
        guard rewrite.waitForExistence(timeout: 20) else {
            XCTFail("No Vent result card ('\(spec.rewriteLabel)' never appeared).")
            return
        }
        guard app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", spec.ventDraftLabelPrefix)).firstMatch.exists else {
            XCTFail("The result is not a Vent draft (no '\(spec.ventDraftLabelPrefix)…' label) — "
                    + "the fixture did not render; check that it passes the vent safety filter.")
            return
        }
        // Bring the whole card into frame: scroll until its bottom button sits
        // ABOVE the tab bar (the scenario/sample sections hide once results
        // land). "Hittable" alone is not enough: a button under the
        // translucent tab bar still counts as hittable, and the 2026-10-14
        // zh-Hans set shipped its card's buttons hidden behind the tab bar.
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        var swipes = 0
        while (!rewrite.isHittable || rewrite.frame.maxY > tabBarTop) && swipes < 4 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        guard rewrite.isHittable, rewrite.frame.maxY <= tabBarTop else {
            XCTFail("The Vent result card never scrolled fully above the tab bar "
                    + "(button maxY \(rewrite.frame.maxY), tab bar top \(tabBarTop)).")
            return
        }
        settle()
        capture(app: app, name: "01-vent-result")

        // 3–4. Tabs. Each tap must actually select its tab before capture.
        // History is deliberately NOT captured: its seeded samples are in
        // mixed languages in every locale (HistoryService seeds each sample
        // in its response language) — known, not fixed in v1.7.
        let tabScenes: [(index: Int, name: String)] = [
            (1, "03-explore"), (3, "04-settings")
        ]
        for scene in tabScenes {
            let tab = app.tabBars.buttons.element(boundBy: scene.index)
            guard waitForHittable(tab, timeout: 5) else {
                XCTFail("Tab \(scene.index) is not hittable (for \(scene.name)).")
                return
            }
            tab.tap()
            guard waitFor(tab, "isSelected == true", timeout: 5) else {
                XCTFail("Tab \(scene.index) did not become selected (for \(scene.name)).")
                return
            }
            settle()
            capture(app: app, name: scene.name)
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
        let allow = app.buttons["同意，发到云端生成"]  // 1.8.0 consent text (A7)
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
        // Retired in 1.8.0 (B3): the tile no longer exists, so the guard
        // below ends the run here.
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

        // Switch tone to 狂怒 (feral) so this transcript comes from the
        // CLOUD model — the casual register is on-device/curated and reads
        // far too gentle for marketing. Consent was already granted in the
        // roommate scene (same surface), so generation routes straight to
        // the Worker. Keyboard must be down first (EchoesFlowUITests).
        let feralInSeg = app.segmentedControls.buttons["狂怒"]
        let feralPlain = app.buttons["狂怒"]
        if feralInSeg.waitForExistence(timeout: 3) {
            feralInSeg.tap()
        } else if feralPlain.waitForExistence(timeout: 2) {
            feralPlain.tap()
        }

        let echoesGenerate = anyElement(app, "echoes.generate")
        guard echoesGenerate.waitForExistence(timeout: 5) else { return }
        scrollTries = 0
        while !echoesGenerate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        // Groq's free tier rate-limits per minute and the roommate scene
        // just consumed the window — without this gap the feral call 429s
        // into the (slow) OpenRouter fallback and the capture times out
        // on the loading spinner (round-4 failure mode).
        sleep(45)
        echoesGenerate.tap()

        // Belt-and-braces: if consent somehow wasn't granted, accept it.
        let echoesAllow = app.buttons["允许 Feral 走云端"]
        var echoesConsentTries = 0
        while !echoesAllow.exists && echoesConsentTries < 4 {
            sleep(1)
            echoesConsentTries += 1
        }
        if echoesAllow.exists { echoesAllow.tap() }

        // Generous poll: worst case is cloud latency + the app's ~60s
        // request timeout + curated-fallback reveal — still ends in a
        // bridge bubble eventually.
        let echoesBridge = anyElement(app, "echoes.bridge")
        revealTries = 0
        while !echoesBridge.exists && revealTries < 110 {
            sleep(1)
            revealTries += 1
        }
        sleep(1)
        capture(app: app, name: "xhs-06-echoes-chat")

        // ── Scene 7: the closing loop — bridge → generator pre-filled ──
        guard echoesBridge.exists else { return }
        echoesBridge.tap()
        let generatorSituation = app.textViews["situation_editor"]
        guard generatorSituation.waitForExistence(timeout: 10) else { return }
        // Give EchoBridgeStore a beat to pre-fill the grievance.
        sleep(2)
        capture(app: app, name: "xhs-07-bridge-rewrite")

        // ── Scene 8: generator VENT output — the cloud roast itself ──
        // 发泄 routes through the cloud Worker (after its own consent,
        // separate from the Echoes one) — the on-device register is far
        // too gentle for the marketing "先骂个爽" promise. The 发泄 chip
        // sits past 体面/锐利/狠 in the horizontal intensity row: drag
        // the row left using a visible chip as the anchor until hittable.
        let ventChip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '发泄'")).firstMatch
        let anchorChip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '锐利' OR label BEGINSWITH '狠'")).firstMatch
        var chipTries = 0
        while !ventChip.isHittable && anchorChip.exists && chipTries < 5 {
            let start = anchorChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = anchorChip.coordinate(withNormalizedOffset: CGVector(dx: -2.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
            chipTries += 1
        }
        guard ventChip.exists else { return }
        ventChip.tap()

        let startGenerate = app.buttons["开始生成"].firstMatch
        guard startGenerate.waitForExistence(timeout: 5) else { return }
        var genScrolls = 0
        while !startGenerate.isHittable && genScrolls < 3 {
            app.swipeUp()
            genScrolls += 1
        }
        // Same Groq per-minute window logic as the echoes scene above.
        sleep(45)
        startGenerate.tap()

        // First vent generation presents the Vent/Feral cloud-consent
        // sheet (separate surface from Echoes). Accept → cloud output.
        let ventAllow = app.buttons["允许使用云端 AI"]
        var ventConsentTries = 0
        while !ventAllow.exists && ventConsentTries < 10 {
            sleep(1)
            ventConsentTries += 1
        }
        if ventAllow.exists { ventAllow.tap() }

        // Wait for the output card: the private-draft actions (改成能发的
        // rewrite CTA) appear under the generated text. Poll generously —
        // cloud latency + streaming/typewriter render.
        let sendable = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '改成能发'")).firstMatch
        var outputTries = 0
        while !sendable.exists && outputTries < 90 {
            sleep(1)
            outputTries += 1
        }
        sleep(2)
        capture(app: app, name: "xhs-08-generator-vent")
    }

    /// Targeted re-roll of the roommate group chat ONLY — for when a cloud
    /// generation's prose is clunky and needs another try WITHOUT
    /// re-rolling the other (already approved) captures. Each run yields
    /// TWO candidates: the first generation (xhs-04-roommate-chat) and an
    /// in-app 换个角度 regenerate (xhs-04-roommate-chat-alt).
    func test_screenshots_roommate_reroll() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest",
            "-uitestLang", "zh-Hans",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans"
        ]
        app.launch()

        let exploreTab = app.tabBars.buttons.element(boundBy: 1)
        guard exploreTab.waitForExistence(timeout: 10) && exploreTab.isHittable else { return }
        exploreTab.tap()
        let roommateTile = anyElement(app, "roommate.tile")
        var exploreScrolls = 0
        while !roommateTile.exists && exploreScrolls < 4 {
            app.swipeUp()
            exploreScrolls += 1
        }
        guard roommateTile.waitForExistence(timeout: 8) else { return }
        if !roommateTile.isHittable { app.swipeUp() }
        roommateTile.tap()

        let situation = anyElement(app, "echoes.situation")
        guard situation.waitForExistence(timeout: 8) else { return }
        situation.tap()
        situation.typeText("室友半夜两点开外放打游戏，说了三次都当耳旁风")
        app.navigationBars.firstMatch.tap()

        let generate = anyElement(app, "echoes.generate")
        guard generate.waitForExistence(timeout: 5) else { return }
        var scrollTries = 0
        while !generate.isHittable && scrollTries < 4 {
            app.swipeUp()
            scrollTries += 1
        }
        generate.tap()

        let allow = app.buttons["同意，发到云端生成"]  // 1.8.0 consent text (A7)
        var consentTries = 0
        while !allow.exists && consentTries < 10 {
            sleep(1)
            consentTries += 1
        }
        if allow.exists { allow.tap() }

        let bridge = anyElement(app, "echoes.bridge")
        var revealTries = 0
        while !bridge.exists && revealTries < 110 {
            sleep(1)
            revealTries += 1
        }
        sleep(1)
        capture(app: app, name: "xhs-04-roommate-chat")

        // Candidate 2 via the in-app regenerate (one per session). Pace
        // past Groq's per-minute window first, same as the main flow.
        let reroll = app.buttons["换个角度"]
        guard reroll.waitForExistence(timeout: 5) else { return }
        sleep(45)
        reroll.tap()
        sleep(3)
        revealTries = 0
        while !bridge.exists && revealTries < 110 {
            sleep(1)
            revealTries += 1
        }
        sleep(1)
        capture(app: app, name: "xhs-04-roommate-chat-alt")
    }

    /// Deterministic roommate capture from an INJECTED transcript (the
    /// judge-panel winner), passed via TEST_RUNNER_ROOMMATE_FIXTURE ->
    /// the `-uitestRoommateFixture` launch arg. Generation is instant (no
    /// cloud roll), so the exact hand-picked text renders every time.
    func test_screenshot_roommate_fixture() {
        guard let fixture = ProcessInfo.processInfo.environment["ROOMMATE_FIXTURE"],
              !fixture.isEmpty else { return }
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest", "-uitestLang", "zh-Hans",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans",
            "-uitestRoommateFixture", fixture
        ]
        app.launch()

        let exploreTab = app.tabBars.buttons.element(boundBy: 1)
        guard exploreTab.waitForExistence(timeout: 10) && exploreTab.isHittable else { return }
        exploreTab.tap()
        let roommateTile = anyElement(app, "roommate.tile")
        var s = 0
        while !roommateTile.exists && s < 4 { app.swipeUp(); s += 1 }
        guard roommateTile.waitForExistence(timeout: 8) else { return }
        if !roommateTile.isHittable { app.swipeUp() }
        roommateTile.tap()

        let situation = anyElement(app, "echoes.situation")
        guard situation.waitForExistence(timeout: 8) else { return }
        situation.tap()
        situation.typeText("室友半夜两点开外放打游戏，说了三次都当耳旁风")
        app.navigationBars.firstMatch.tap()

        let generate = anyElement(app, "echoes.generate")
        guard generate.waitForExistence(timeout: 5) else { return }
        var sc = 0
        while !generate.isHittable && sc < 4 { app.swipeUp(); sc += 1 }
        generate.tap()

        // Roommate is cloud-only -> consent sheet first; accept it, then the
        // fixture renders instantly (no network).
        let allow = app.buttons["同意，发到云端生成"]  // 1.8.0 consent text (A7)
        var c = 0
        while !allow.exists && c < 8 { sleep(1); c += 1 }
        if allow.exists { allow.tap() }

        let bridge = anyElement(app, "echoes.bridge")
        var r = 0
        while !bridge.exists && r < 25 { sleep(1); r += 1 }
        sleep(1)
        capture(app: app, name: "xhs-04-roommate-chat")
    }

    /// Find an element by accessibility id across the element types a
    /// SwiftUI control may surface as (same helper as EchoesFlowUITests).
    private func anyElement(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    // MARK: - Helpers

    /// Per-locale facts the App Store run needs. The labels mirror the
    /// app's `Shared/<lang>.lproj/Localizable.strings` and
    /// `Shared/Resources/Scenarios.json`; if one drifts, the guard that
    /// uses it fails loudly instead of capturing the wrong screen.
    private struct ShotLocale {
        /// `-uitestLang` value (`AppLanguage.rawValue`).
        let languageCode: String
        /// "tab.settings" in this language.
        let settingsTabLabel: String
        /// "intensity.vent.name" in this language (messages only).
        let ventLabel: String
        /// Start of "intensity.vent.blurb" — unique to the Vent chip.
        let ventBlurbPrefix: String
        /// Start of Scenarios.json `boss_credit` prompt in this language.
        let scenarioPrefix: String
        /// "generator.generate", "cloud.consent.allow", "output.rewrite.button"
        /// and the start of "output.kind.vent_draft.label" in this language.
        let generateLabel: String
        let allowCloudLabel: String
        let rewriteLabel: String
        let ventDraftLabelPrefix: String

        init?(_ locale: String) {
            switch locale {
            case let s where s.hasPrefix("zh_Hans"):
                self.init(languageCode: "zh-Hans", settingsTabLabel: "设置",
                          ventLabel: "发泄", ventBlurbPrefix: "只给自己看的发泄稿",
                          scenarioPrefix: "我做的项目", generateLabel: "开始生成",
                          allowCloudLabel: "允许使用云端 AI", rewriteLabel: "改成能发的",
                          ventDraftLabelPrefix: "发泄稿")
            case let s where s.hasPrefix("zh_Hant"):
                self.init(languageCode: "zh-Hant", settingsTabLabel: "設定",
                          ventLabel: "發洩", ventBlurbPrefix: "只給自己看的發洩稿",
                          scenarioPrefix: "我做的專案", generateLabel: "開始生成",
                          allowCloudLabel: "允許使用雲端 AI", rewriteLabel: "改成能發的",
                          ventDraftLabelPrefix: "發洩稿")
            case let s where s.hasPrefix("ja"):
                self.init(languageCode: "ja", settingsTabLabel: "設定",
                          ventLabel: "吐き出し", ventBlurbPrefix: "自分だけの吐き出し草稿",
                          scenarioPrefix: "自分が進めたプロジェクト", generateLabel: "生成する",
                          allowCloudLabel: "クラウドAIを許可", rewriteLabel: "送れる形にする",
                          ventDraftLabelPrefix: "吐き出し草稿")
            case let s where s.hasPrefix("en"):
                self.init(languageCode: "en", settingsTabLabel: "Settings",
                          ventLabel: "Vent", ventBlurbPrefix: "Private vent draft",
                          scenarioPrefix: "My manager took credit", generateLabel: "Generate",
                          allowCloudLabel: "Allow Cloud AI", rewriteLabel: "Make it sendable",
                          ventDraftLabelPrefix: "Vent draft")
            default:
                return nil
            }
        }

        private init(languageCode: String, settingsTabLabel: String, ventLabel: String,
                     ventBlurbPrefix: String, scenarioPrefix: String, generateLabel: String,
                     allowCloudLabel: String, rewriteLabel: String, ventDraftLabelPrefix: String) {
            self.languageCode = languageCode
            self.settingsTabLabel = settingsTabLabel
            self.ventLabel = ventLabel
            self.ventBlurbPrefix = ventBlurbPrefix
            self.scenarioPrefix = scenarioPrefix
            self.generateLabel = generateLabel
            self.allowCloudLabel = allowCloudLabel
            self.rewriteLabel = rewriteLabel
            self.ventDraftLabelPrefix = ventDraftLabelPrefix
        }
    }

    /// Selects the Vent chip — the last chip in the horizontally scrolling
    /// intensity row, off-screen at launch. Drags the row left until the
    /// chip is hittable, taps it. Returns false if it never got there.
    ///
    /// Matched on the chip's BLURB, not its name: the name alone is not
    /// unique — in English the mic button over the editor is labelled
    /// "Vent by voice" ("voice.button"), sits earlier in the hierarchy, and
    /// a `BEGINSWITH "Vent"` match tapped it instead (measured 2026-10-07).
    private func selectVent(_ app: XCUIApplication, _ spec: ShotLocale) -> Bool {
        let vent = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", spec.ventBlurbPrefix)).firstMatch
        guard vent.waitForExistence(timeout: 5) else { return false }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let width = app.frame.width
        var drags = 0
        while !vent.isHittable && drags < 4 {
            let y = vent.frame.midY
            origin.withOffset(CGVector(dx: width * 0.85, dy: y))
                .press(forDuration: 0.05,
                       thenDragTo: origin.withOffset(CGVector(dx: width * 0.15, dy: y)))
            drags += 1
        }
        guard vent.isHittable else { return false }
        vent.tap()
        return waitFor(vent, "isSelected == true", timeout: 2) || vent.isHittable
    }

    /// A previous run that tapped the keyboard's dictation key leaves the
    /// system "Enable Dictation?" alert up, and it survives into the next
    /// launch's first frame. Dismiss only that alert, nothing else.
    private func dismissLeftoverDictationAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Dictation'")).firstMatch
        if alert.exists, alert.buttons["Not Now"].exists {
            alert.buttons["Not Now"].tap()
        }
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitFor(element, "exists == true AND isHittable == true", timeout: timeout)
    }

    private func waitFor(_ element: XCUIElement, _ format: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Lets transitions and the tab-switch animation finish so the frame
    /// is not mid-animation.
    private func settle() {
        sleep(1)
    }

    private func capture(app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
