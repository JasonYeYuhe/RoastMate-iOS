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
        for locale in locales {
            guard let body = string("paywall.body", locale) else {
                XCTFail("\(locale) is missing paywall.body"); continue
            }
            let range = NSRange(body.startIndex..., in: body)
            XCTAssertNil(vent.firstMatch(in: body, range: range),
                         "\(locale) paywall.body sells Vent, which is free: \(body)")
            XCTAssertTrue(body.contains(feral[locale]!),
                          "\(locale) paywall.body omits Feral: \(body)")
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
}
