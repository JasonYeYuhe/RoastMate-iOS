import XCTest
@testable import RoastMate

/// Guards the curated-fallback pool's locale routing.
///
/// This is the surface a user hits on every device without an on-device model
/// — which, on macOS, is every Mac below 26. It shipped routing both Chinese
/// scripts to `case "zh"`, so every Traditional reader got Simplified text in
/// the one place the app promises hand-authored copy.
final class FallbackRoastsTests: XCTestCase {
    private let style = StylePreset(
        id: "test",
        displayKey: "test.name",
        blurbKey: "test.blurb",
        icon: "star",
        tier: .free,
        temperature: 0.8,
        tags: [],
        systemPreamble: "Be witty.",
        examples: [.init(situation: "S1", response: "R1")],
        localesSupported: nil
    )

    private func pool(_ identifier: String, count: Int = 5) -> [String] {
        FallbackRoasts.curated(for: style, locale: Locale(identifier: identifier), count: count)
    }

    /// Characters that only exist in one script. If a Traditional locale's
    /// pool contains a Simplified-only character, it is serving the wrong pool.
    private let simplifiedOnly: Set<Character> = ["这", "没", "着", "开", "过", "话", "买", "边"]
    private let traditionalOnly: Set<Character> = ["這", "沒", "著", "開", "過", "話", "買", "邊"]

    func testTraditionalLocaleNeverGetsSimplifiedText() {
        // zh-Hant-TW carries the script subtag; zh_TW / zh_HK / zh_MO do NOT —
        // and a real Taiwan device usually reports the latter. All four must
        // resolve Traditional, which is why this routes through
        // AppLanguage.contentBucket and not `identifier.contains("Hant")`.
        for id in ["zh-Hant", "zh-Hant-TW", "zh_TW", "zh_HK", "zh_MO"] {
            let texts = pool(id)
            XCTAssertFalse(texts.isEmpty, "\(id) returned no curated text")
            for text in texts {
                XCTAssertFalse(text.contains(where: { simplifiedOnly.contains($0) }),
                               "\(id) was served Simplified text: \(text)")
            }
        }
    }

    func testSimplifiedLocaleStillGetsSimplifiedText() {
        for id in ["zh-Hans", "zh-Hans-CN", "zh_CN"] {
            let texts = pool(id)
            XCTAssertFalse(texts.isEmpty, "\(id) returned no curated text")
            for text in texts {
                XCTAssertFalse(text.contains(where: { traditionalOnly.contains($0) }),
                               "\(id) was served Traditional text: \(text)")
            }
        }
    }

    /// The two Chinese pools must stay the same size, or one script silently
    /// gets less variety than the other as lines are added.
    func testBothChineseScriptPoolsAreTheSameSize() {
        XCTAssertEqual(pool("zh-Hans", count: 99).count,
                       pool("zh-Hant", count: 99).count,
                       "the zh-Hans and zh-Hant pools have diverged in size")
    }

    func testNonChineseLocalesUnaffected() {
        XCTAssertFalse(pool("ja_JP").isEmpty)
        XCTAssertFalse(pool("en_GB").isEmpty)
        // An unknown language falls back to English, not to empty.
        XCTAssertFalse(pool("de_DE").isEmpty)
    }

    func testCountIsHonouredAndNeverZero() {
        XCTAssertEqual(pool("zh-Hant", count: 3).count, 3)
        XCTAssertEqual(pool("zh-Hant", count: 0).count, 1, "must never return an empty result")
    }
}

/// The provenance contract P1.1 and P1.2 both read.
final class GenerationProvenanceTests: XCTestCase {
    func testCuratedIsDistinguishableFromModelOutput() {
        let curated = GeneratedOutput(texts: ["canned"], provenance: .curated)
        let model = GeneratedOutput(texts: ["real"], provenance: .model)
        XCTAssertTrue(curated.isCurated,
                      "a curated result must be identifiable — charging and labelling both read this")
        XCTAssertFalse(model.isCurated)
        XCTAssertNotEqual(curated.provenance, model.provenance)
    }

    func testSendableRewriteCarriesProvenance() {
        XCTAssertEqual(SendableRewrite(text: "x", provenance: .curated).provenance, .curated)
        XCTAssertEqual(SendableRewrite(text: "x", provenance: .model).provenance, .model)
    }
}
