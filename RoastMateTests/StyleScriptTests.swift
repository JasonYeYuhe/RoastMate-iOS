import XCTest
@testable import RoastMate

/// A5: on-device Pro styles stop sounding templated, and each language gets
/// examples in its own script. Lens 1 (2026-10-22): every zh-Hant prompt got
/// the Simplified examples, 台劇腔 put CJK into 18/18 English outputs, 9/12
/// Sharp-Pro outputs opened with "I'd have said:", and the top opener showed
/// up in 7/12.
@MainActor
final class StyleScriptTests: XCTestCase {

    private let buckets = ["en", "zh-Hans", "zh-Hant", "ja"]
    private let locales = ["en": "en_US", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW", "ja": "ja_JP"]

    func testEveryProStyleHasAnExampleInEachLanguage() {
        for style in StyleCatalog.shared.byTier(.pro) {
            let tagged = Set(style.examples.compactMap(\.lang))
            for bucket in buckets {
                XCTAssertTrue(tagged.contains(bucket), "\(style.id) has no \(bucket) example")
            }
        }
    }

    func testEveryExampleIsTagged() {
        for style in StyleCatalog.shared.all {
            for ex in style.examples {
                XCTAssertNotNil(ex.lang, "\(style.id): untagged example \(ex.situation)")
            }
        }
    }

    func testPromptsGetOnlyTheirOwnLanguagesExamples() {
        for style in StyleCatalog.shared.all {
            for bucket in buckets {
                let picked = PromptBuilder.examplesForPrompt(style: style, locale: Locale(identifier: locales[bucket]!))
                XCTAssertTrue(picked.allSatisfy { $0.lang == bucket }, "\(style.id) \(bucket)")
            }
        }
    }

    func testZhHantExamplesContainNoSimplifiedCharacters() {
        for style in StyleCatalog.shared.all {
            for ex in style.examples where ex.lang == "zh-Hant" {
                for text in [ex.situation, ex.response] {
                    XCTAssertEqual(simplifiedOnly(text), [], "\(style.id): \(text)")
                }
            }
        }
    }

    func testZhHantPromptsContainNoSimplifiedCharacters_proStyles() {
        for style in StyleCatalog.shared.byTier(.pro) {
            for intensity in [Intensity.calm, .sharp, .savage] {
                let prompt = PromptBuilder.systemPrompt(
                    style: style, locale: Locale(identifier: "zh_TW"), intensity: intensity)
                XCTAssertEqual(simplifiedOnly(prompt), [], "\(style.id) \(intensity)")
            }
        }
    }

    func testEnglishAndJapaneseExamplesStayInTheirScript() {
        for style in StyleCatalog.shared.all {
            for ex in style.examples {
                let text = ex.situation + ex.response
                if ex.lang == "en" { XCTAssertFalse(containsCJK(text), "\(style.id): CJK in en example") }
                if ex.lang == "ja" { XCTAssertTrue(text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }, "\(style.id): ja without kana") }
            }
        }
    }

    func testTaiwaneseDramaPreamble_noChineseInEnglishOrJapanese() throws {
        let style = try XCTUnwrap(StyleCatalog.shared.style(id: "taiwanese_drama"))
        XCTAssertFalse(containsCJK(style.systemPreamble(for: Locale(identifier: "en_US"))))
        XCTAssertFalse(style.systemPreamble(for: Locale(identifier: "ja_JP")).contains("啦"))
        XCTAssertTrue(style.systemPreamble(for: Locale(identifier: "zh_TW")).contains("啦"))
        XCTAssertFalse(style.systemPreamble.contains("命中注定"), "the drama title was Simplified")
    }

    func testSavageCalibration_onlyForSavage_inTheOutputLanguage() throws {
        let style = try XCTUnwrap(StyleCatalog.shared.style(id: "savage_no_filter"))
        for (bucket, id) in locales {
            let savage = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: id), intensity: .savage)
            XCTAssertTrue(savage.contains("SAVAGE TONE CALIBRATION"), bucket)
            for other in [Intensity.calm, .sharp, .vent, .feral] {
                let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: id), intensity: other)
                XCTAssertFalse(prompt.contains("SAVAGE TONE CALIBRATION"), "\(bucket) \(other)")
            }
        }
        let en = PromptBuilder.savageCalibration(for: Locale(identifier: "en_US"))
        XCTAssertFalse(containsCJK(en))
        XCTAssertEqual(simplifiedOnly(PromptBuilder.savageCalibration(for: Locale(identifier: "zh_TW"))), [])
    }

    func testRoastPromptAsksForTheWordsThemselves() {
        let style = StyleCatalog.shared.byTier(.free)[0]
        let system = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "en_US"), mode: .roast)
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 3, mode: .roast)
        XCTAssertFalse(system.contains("wishes"))
        XCTAssertFalse(user.contains("could have said"))
        XCTAssertTrue(user.contains("must open differently"))
        let one = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .roast)
        XCTAssertFalse(one.contains("must open differently"))
    }

    func testStripSaidWrapper() {
        XCTAssertEqual(PromptBuilder.stripSaidWrapper("I'd have said: \"You took my slides.\""), "You took my slides.")
        XCTAssertEqual(PromptBuilder.stripSaidWrapper("I’d have said: Late again."), "Late again.")
        XCTAssertEqual(PromptBuilder.stripSaidWrapper("我會說：「你又遲到了。」"), "你又遲到了。")
        XCTAssertEqual(PromptBuilder.stripSaidWrapper("I'd say congrats, but you didn't earn it."),
                       "I'd say congrats, but you didn't earn it.", "no colon or quote: left alone")
        XCTAssertEqual(PromptBuilder.splitVariants("1. I'd have said: A\n2. B"), ["A", "B"])
    }

    func testNearDuplicates() {
        let texts = [
            "You took my slides and my weekend. Next time, credit the person who did the work.",
            "You took my slides and my weekend. Next time credit the person who actually did the work.",
            "Credit isn't a group chat. It's mine.",
        ]
        XCTAssertEqual(PromptBuilder.nearDuplicateIndexes(texts), IndexSet(integer: 1))
        XCTAssertEqual(PromptBuilder.droppingNearDuplicates(texts).count, 2)
        XCTAssertEqual(PromptBuilder.nearDuplicateIndexes(["你又遲到了。", "房租準時到。", "簡報是我做的。"]), IndexSet())
    }

    // MARK: -

    /// Characters that exist only in Simplified: ICU turns them into a
    /// Traditional form that converts straight back (们 → 們 → 们). A plain
    /// Hans-Hant comparison also flags valid Taiwan forms ICU rewrites
    /// (沈穩 → 沉穩, which doesn't round-trip), so it can't be used directly.
    private func simplifiedOnly(_ s: String) -> [Character] {
        s.filter { ch in
            guard ch.unicodeScalars.allSatisfy({ (0x4E00...0x9FFF).contains($0.value) }) else { return false }
            let one = String(ch)
            guard let hant = one.applyingTransform(StringTransform("Hans-Hant"), reverse: false), hant != one,
                  let back = hant.applyingTransform(StringTransform("Hant-Hans"), reverse: false) else { return false }
            return back == one
        }.map { $0 }
    }

    private func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }
}
