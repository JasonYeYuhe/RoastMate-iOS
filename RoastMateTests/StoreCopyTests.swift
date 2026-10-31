import XCTest
@testable import RoastMate

/// Copy on the purchase and share surfaces must describe what the code does.
/// v1.6.0 made Vent free and fixed the paywall's feature list, but left its
/// header (`paywall.body`) selling Vent as Pro in all four locales until v1.7.
/// These tests read the shipped .strings files straight from the hostless
/// test bundle (same pattern as ShareCardTests).
final class StoreCopyTests: XCTestCase {

    private let locales = ["en", "zh-Hans", "zh-Hant", "ja"]

    private func bundle(_ locale: String) -> Bundle? {
        guard let path = Bundle(for: type(of: self)).path(forResource: locale, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private func string(_ key: String, _ locale: String) -> String? {
        guard let b = bundle(locale) else { return nil }
        let v = b.localizedString(forKey: key, value: "__MISSING__", table: nil)
        return v == "__MISSING__" ? nil : v
    }

    /// The paywall header never names Vent (free since v1.6.0) and always
    /// names Feral (the Pro-only cloud mode). Scoped to `paywall.body` on
    /// purpose: `paywall.feature.feral.detail` uses the vent word as a verb
    /// ("Vent with the limits off") and is correct.
    func test_paywallHeader_neverSellsVent_andNamesFeral() throws {
        let vent = try NSRegularExpression(pattern: "(?i)\\bvent\\b|发泄|發洩|吐き出し")
        let feral = ["en": "Feral", "zh-Hans": "痛骂", "zh-Hant": "痛罵", "ja": "罵倒"]
        // 1.7.1: every header variant, including the one shown on devices
        // without the on-device model.
        for key in ["paywall.body", "paywall.body.curated"] {
            for locale in locales {
                guard let body = string(key, locale) else {
                    XCTFail("\(locale) is missing \(key)"); continue
                }
                let range = NSRange(body.startIndex..., in: body)
                XCTAssertNil(vent.firstMatch(in: body, range: range),
                             "\(locale) \(key) sells Vent, which is free: \(body)")
                XCTAssertTrue(body.contains(feral[locale]!),
                              "\(locale) \(key) omits Feral: \(body)")
            }
        }
    }

    /// The header shown without the on-device model (1.7.1) must say what
    /// needs Apple Intelligence instead of selling Savage, the styles, 3
    /// versions and the simulator as if they worked there. Apple's own
    /// Simplified Chinese name for it is "Apple 智能".
    func test_curatedPaywallHeader_saysWhatNeedsAppleIntelligence() {
        let name = ["en": "Apple Intelligence", "zh-Hans": "Apple 智能",
                    "zh-Hant": "Apple Intelligence", "ja": "Apple Intelligence"]
        for locale in locales {
            guard let body = string("paywall.body.curated", locale) else {
                XCTFail("\(locale) is missing paywall.body.curated"); continue
            }
            XCTAssertTrue(body.contains(name[locale]!),
                          "\(locale) paywall.body.curated must name \(name[locale]!): \(body)")
        }
    }

    /// Feature details must describe the code. Savage has no per-style gate
    /// anywhere in the app (it was sold as "for the styles that earn them" /
    /// 「僅在配得上的風格中開放」), and Feral's detail read as "unlimited" in
    /// three locales while the Worker caps Pro cloud use per day.
    func test_featureDetails_makeNoInventedClaims() {
        let banned = ["styles that earn them", "配得上", "対応するスタイルでのみ",
                      "limits off", "不设上限", "不設上限", "制限なし"]
        for key in ["paywall.feature.savage.detail", "paywall.feature.feral.detail"] {
            for locale in locales {
                guard let value = string(key, locale) else {
                    XCTFail("\(locale) is missing \(key)"); continue
                }
                for term in banned where value.contains(term) {
                    XCTFail("\(locale) \(key) still claims '\(term)': \(value)")
                }
            }
        }
    }

    /// After purchase (1.7.1) the confirmation must exist in every locale, and
    /// its no-model variant must name Apple Intelligence like the header does.
    func test_purchaseConfirmationAndErrorCopy_exist() {
        let keys = ["paywall.success.title", "paywall.success.body", "paywall.success.body.curated",
                    "paywall.success.done", "paywall.error.title", "common.ok"]
        for key in keys {
            for locale in locales {
                XCTAssertNotNil(string(key, locale), "\(locale) is missing \(key)")
            }
        }
        for locale in locales {
            let body = string("paywall.success.body.curated", locale) ?? ""
            XCTAssertTrue(body.contains("Apple Intelligence") || body.contains("Apple 智能"),
                          "\(locale) paywall.success.body.curated: \(body)")
        }
    }

    /// Every message `PurchaseNotice` can show exists in all four locales,
    /// and the no-op outcomes really show nothing.
    func test_purchaseNoticeCopy_existsForEveryOutcome() {
        let notices: [PurchaseNotice] = [
            PurchaseNotice.forPurchase(.pending), PurchaseNotice.forPurchase(.unverified),
            PurchaseNotice.forRestore(.nothingToRestore), PurchaseNotice.forRestore(.failed("x")),
            PurchaseNotice.forPurchaseError(NSError(domain: "x", code: 1)),
        ].compactMap { $0 }
        XCTAssertEqual(notices.count, 5)
        for notice in notices {
            for key in [notice.titleKey] + (notice.messageKey.map { [$0] } ?? []) {
                for locale in locales {
                    XCTAssertNotNil(string(key, locale), "\(locale) is missing \(key)")
                }
            }
        }
        // The cloud-paused reason must not send the user to retry or to Settings
        // as the fix (that is exactly the state where neither helps).
        let retryAsAFix = ["Try again in a moment", "稍後再試一次", "稍后再试一次", "もう一度お試しください"]
        for locale in locales {
            let value = string("roast.notice.reason.cloud_paused", locale) ?? ""
            for phrase in retryAsAFix where value.contains(phrase) {
                XCTFail("\(locale) cloud_paused tells the user to retry: \(value)")
            }
        }
    }

    /// The curated banner (1.7.1) says WHY, and "no credit used" is its own
    /// line so Pro users — who never spend credits — don't see it.
    func test_curatedBanner_hasReasons_andSeparatesTheCreditLine() {
        // Every CuratedReason's key (iOS wording), plus the Mac wording and
        // the credit line. Driven by allCases so a new reason can't ship
        // without copy.
        let reasons = CuratedReason.allCases.map(\.localizationKey)
            + ["roast.notice.reason.apple_intelligence.mac", "roast.notice.nocredit"]
        XCTAssertTrue(reasons.contains("roast.notice.reason.cloud_paused"))
        for key in reasons {
            for locale in locales {
                XCTAssertNotNil(string(key, locale), "\(locale) is missing \(key)")
            }
        }
        let creditWords = ["No credit", "不扣额度", "不扣額度", "クレジット"]
        for key in ["roast.notice.curated", "rewrite.notice.curated"] {
            for locale in locales {
                let value = string(key, locale) ?? ""
                for word in creditWords where value.contains(word) {
                    XCTFail("\(locale) \(key) still carries the credit line (\(word)): \(value)")
                }
            }
        }
        for locale in locales {
            let iOS = string("roast.notice.reason.apple_intelligence", locale) ?? ""
            XCTAssertTrue(iOS.contains("iPhone 15 Pro"), "\(locale) iOS reason: \(iOS)")
            let mac = string("roast.notice.reason.apple_intelligence.mac", locale) ?? ""
            XCTAssertTrue(mac.contains("Mac"), "\(locale) Mac reason: \(mac)")
        }
    }

    /// The Pro guards' message must not claim a daily free quota: the 5/day
    /// limit is legacy (credit wallet since v1.1), and these guards fire when
    /// a free user reaches a Pro-only style or intensity.
    func test_proGuardMessage_doesNotClaimADailyQuota() {
        for locale in locales {
            guard let body = string("quota.exhausted.body", locale) else {
                XCTFail("\(locale) is missing quota.exhausted.body"); continue
            }
            XCTAssertFalse(body.contains("5"), "\(locale) quota.exhausted.body still claims a 5/day quota: \(body)")
            XCTAssertTrue(body.contains("Pro"), "\(locale) quota.exhausted.body should say Pro is needed: \(body)")
        }
    }

    /// The Pro screen must not sell "unlimited generations" or "skip the
    /// daily cap": the 5/day limit is legacy (credit wallet since v1.1) and
    /// the Worker caps Pro cloud use per day. What Pro really removes is
    /// credits, which these strings now say.
    func test_proCopy_doesNotSellUnlimitedOrADailyCap() {
        let banned = ["unlimited", "daily cap", "无限", "無限", "無制限", "每日上限", "1日の上限"]
        let keys = ["paywall.feature.unlimited", "paywall.feature.unlimited.detail",
                    "paywall.pro.subtitle", "paywall.out_of_credits.body"]
        for locale in locales {
            for key in keys {
                guard let value = string(key, locale) else {
                    XCTFail("\(locale) is missing \(key)"); continue
                }
                for term in banned where value.lowercased().contains(term) {
                    XCTFail("\(locale) \(key) still sells '\(term)': \(value)")
                }
            }
        }
    }

    /// Declining cloud does NOT make Vent/Feral "gentler" or "on-device": the
    /// engine returns labelled curated examples (CloudPermission.willBeCurated —
    /// Apple's default guardrails refuse vent/feral). The consent sheet, the
    /// Settings footer and onboarding said otherwise in every locale until
    /// v1.7, on the exact screen App Review reads for 5.1.2(i).
    func test_declinedCloudCopy_saysExamplesNotGentlerOnDeviceOutput() {
        let banned = ["gentler", "stay on-device too", "更温和", "較溫和", "温和很多", "溫和很多",
                      "同样留在本地", "同樣留在本地", "出力は穏やか", "大幅に下がります", "端末内で処理されます"]
        let keys = ["cloud.consent.point.local", "settings.cloud_vent.footer", "onboarding.privacy.body"]
        for locale in locales {
            for key in keys {
                guard let value = string(key, locale) else {
                    XCTFail("\(locale) is missing \(key)"); continue
                }
                for term in banned where value.contains(term) {
                    XCTFail("\(locale) \(key) still promises '\(term)': \(value)")
                }
            }
        }
    }

    /// The subscription rows show app-owned copy (PlanCopy), not App Store
    /// Connect's descriptions, which still sell "Unlimited generations" and
    /// can't be edited by API while ACTIVE. Both products map, every locale
    /// has the copy, and none of it claims "unlimited".
    func test_planRows_useAppOwnedCopyThatNeverClaimsUnlimited() {
        let ids = [StoreService.monthlyProductId, StoreService.yearlyProductId]
        let banned = ["unlimited", "无限", "無限", "無制限"]
        for id in ids {
            guard let keys = PlanCopy.keys(forProductID: id) else {
                XCTFail("\(id) has no app-owned plan copy"); continue
            }
            for locale in locales {
                for key in [keys.name, keys.detail] {
                    guard let value = string(key, locale) else {
                        XCTFail("\(locale) is missing \(key)"); continue
                    }
                    for term in banned where value.lowercased().contains(term) {
                        XCTFail("\(locale) \(key) claims '\(term)': \(value)")
                    }
                }
            }
        }
        XCTAssertNil(PlanCopy.keys(forProductID: "yyh.roastmate.app.credits.10"))
        XCTAssertEqual(string("paywall.monthly", "zh-Hant"), "月訂閱")
    }

    /// The card's wordmark is the name people search to find us — the store
    /// name in that locale (v1.7 P1.2), never the bare "RoastMate", which ranks
    /// an unrelated app first in every storefront measured on 2026-10-07.
    func test_shareCardWordmark_isTheSearchableStoreName() {
        let expected = ["en": "RoastMate AI", "zh-Hans": "帮你骂", "zh-Hant": "幫你罵", "ja": "RoastMate AI"]
        for locale in locales {
            XCTAssertEqual(string("sharecard.wordmark", locale), expected[locale],
                           "\(locale) sharecard.wordmark")
            guard let findus = string("sharecard.findus", locale) else {
                XCTFail("\(locale) is missing sharecard.findus"); continue
            }
            XCTAssertTrue(findus.contains(expected[locale]!),
                          "\(locale) sharecard.findus should name \(expected[locale]!): \(findus)")
        }
    }

    /// App Store screenshot #1 renders these texts (via -uitestVentFixture).
    /// Store screenshots must be 4+ (App Review 2.3.8) although the app is
    /// 17+, and the screenshot only renders a fixture that clears the vent
    /// filter. So each fixture must pass the vent filter AND the stricter
    /// sendable filter (the denylist), and carry none of the strong words the
    /// Worker's zh/ja Vent prompt asks for. Read from the repo (the test runs
    /// on the simulator, which can read the host path).
    func test_screenshotVentFixtures_areCleanAndPassTheFilters() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("marketing/appstore/vent-fixtures")
        let strong = ["fuck", "shit", "damn", "bitch", "hell", "crap", "ass",
                      "他妈", "他媽", "妈的", "媽的", "靠北", "幹你", "干你", "操", "屌", "老子", "傻逼",
                      "クソ", "くそ", "死ね", "ふざけんな", "てめえ"]
        for lang in ["en", "zh-Hans", "zh-Hant", "ja"] {
            let url = dir.appendingPathComponent("\(lang).txt")
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertNoThrow(try SafetyFilter.validateVentOutput(text), "\(lang) fixture fails the vent filter")
            XCTAssertNoThrow(try SafetyFilter.validateOutput(text), "\(lang) fixture fails the sendable denylist")
            let lower = text.lowercased()
            let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
            for term in strong {
                let hit = term.unicodeScalars.allSatisfy(\.isASCII) ? words.contains(term) : lower.contains(term)
                XCTAssertFalse(hit, "\(lang) fixture contains '\(term)' — screenshots must be 4+")
            }
        }
    }

    /// Settings → AI & Privacy shows this toggle in every locale (it is not
    /// gated by language); zh-Hant and ja rendered the raw keys until v1.7.
    func test_settingsKeysShownToEveryLocale_exist() {
        for key in ["settings.echoes_feral_cloud", "settings.echoes_feral_cloud.footer"] {
            for locale in locales {
                XCTAssertNotNil(string(key, locale), "\(locale) is missing \(key) (renders as a raw key)")
            }
        }
    }

    // MARK: - A7 (1.8.0): Echoes / roommate copy and consent

    private let roommateReachable = [
        "echoes.consent.title", "echoes.consent.body", "echoes.consent.notice",
        "echoes.consent.allow", "echoes.consent.deny",
        "echoes.tone.casual.blurb", "echoes.tone.feral.blurb",
        "settings.echoes_feral_cloud", "settings.echoes_feral_cloud.footer",
        "roommate.setup.intro", "roommate.setup.privacy_banner", "roommate.transcript.banner",
    ]

    /// The roommate group is cloud-only (both tones, OpenRouter). Until 1.8.0
    /// its consent named Groq (dead since v1.6), said Casual stays on-device,
    /// and offered "Stay on-device" for a scene that generates nothing without
    /// the grant.
    func test_roommateCopy_namesNoGroq_andClaimsNothingOnDevice() throws {
        let onDevice = try NSRegularExpression(
            pattern: "(?i)groq|on-device|on this device|stays? on|本机|本機|本设备|本裝置|裝置上|设备上|端末")
        for key in roommateReachable {
            for locale in locales {
                guard let s = string(key, locale) else {
                    XCTFail("\(locale) is missing \(key)"); continue
                }
                XCTAssertNil(onDevice.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                             "\(locale) \(key): \(s)")
            }
        }
    }

    func test_roommateConsent_namesTheCloudRoute() {
        for locale in locales {
            let body = string("echoes.consent.body", locale) ?? ""
            XCTAssertTrue(body.contains("OpenRouter"), "\(locale) consent body must name OpenRouter")
            XCTAssertTrue(body.contains("Cloudflare"), "\(locale) consent body must name Cloudflare")
        }
    }

    /// The Settings toggle shows only where the roommate tile can (zh-Hans,
    /// not remotely killed).
    func test_echoesSurfaces_onlyInSimplifiedChinese_andNotWhenKilled() {
        let live = RemoteConfigValues.safeDefault
        XCTAssertTrue(EchoesAvailability.roommateTileVisible(localeIdentifier: "zh-Hans", remote: live))
        XCTAssertTrue(EchoesAvailability.roommateTileVisible(localeIdentifier: "zh_Hans_CN", remote: live))
        for id in ["zh-Hant", "zh_TW", "zh-Hant-TW", "en_US", "ja_JP"] {
            XCTAssertFalse(EchoesAvailability.roommateTileVisible(localeIdentifier: id, remote: live), id)
        }
        var killed = live
        killed.roommateGroupEnabled = false
        XCTAssertFalse(EchoesAvailability.roommateTileVisible(localeIdentifier: "zh-Hans", remote: killed))
        var echoesOff = live
        echoesOff.echoesEnabled = false
        XCTAssertFalse(EchoesAvailability.roommateTileVisible(localeIdentifier: "zh-Hans", remote: echoesOff))
    }

    /// Grants recorded before 1.8.0 were given under the false text: they are
    /// not read, so the consent is asked again.
    func test_echoesConsent_isVersioned_oldGrantIsAskedAgain() {
        let settings = UserSettings()
        settings.echoesFeralCloudConsentRaw = CloudConsent.granted.rawValue
        XCTAssertEqual(settings.echoesFeralConsent, .notAsked)
        settings.echoesFeralConsent = .granted
        XCTAssertEqual(settings.echoesCloudConsentV2Raw, CloudConsent.granted.rawValue)
        XCTAssertEqual(settings.echoesFeralConsent, .granted)
    }
}
