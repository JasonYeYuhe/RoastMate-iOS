import XCTest
@testable import RoastMate

final class PromptBuilderTests: XCTestCase {
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

    func testSystemPromptContainsSafetyPreambleAndExamples() {
        let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(prompt.contains("SAFETY RULES"))
        XCTAssertTrue(prompt.contains("Be witty."))
        XCTAssertTrue(prompt.contains("R1"))
    }

    func testLanguageHintZhHans() {
        let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "zh_Hans"))
        XCTAssertTrue(prompt.contains("简体中文"))
    }

    func testLanguageHintZhHant() {
        let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "zh_Hant"))
        XCTAssertTrue(prompt.contains("繁體中文"))
    }

    func testLanguageHintJapanese() {
        let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "ja_JP"))
        XCTAssertTrue(prompt.contains("日本語"))
    }

    func testUserPromptClampsVariantCount() {
        XCTAssertTrue(PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 0).contains("1 distinct"))
        XCTAssertTrue(PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 99).contains("5 distinct"))
    }

    func testSplitVariantsArabicNumerals() {
        let raw = """
        1. First witty reply here.
        2. Second one, even better.
        3. Third — the kicker.
        """
        let parts = PromptBuilder.splitVariants(raw)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "First witty reply here.")
    }

    func testSplitVariantsCJKNumerals() {
        let raw = """
        一、第一句。
        二、第二句。
        三、第三句。
        """
        let parts = PromptBuilder.splitVariants(raw)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[2], "第三句。")
    }

    func testSplitVariantsFallsBackToWhole() {
        let raw = "No numbering at all, just one paragraph."
        let parts = PromptBuilder.splitVariants(raw)
        XCTAssertEqual(parts, [raw])
    }
}
