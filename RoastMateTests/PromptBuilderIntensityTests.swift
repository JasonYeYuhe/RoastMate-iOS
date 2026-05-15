import XCTest
@testable import RoastMate

final class PromptBuilderIntensityTests: XCTestCase {
    private let style = StylePreset(
        id: "test",
        displayKey: "test.name",
        blurbKey: "test.blurb",
        icon: "star",
        tier: .free,
        temperature: 0.8,
        tags: [],
        systemPreamble: "Be witty.",
        examples: [],
        localesSupported: nil
    )

    func testVentIntensityInjectsVentPreamble() {
        let prompt = PromptBuilder.systemPrompt(
            style: style,
            locale: Locale(identifier: "en_US"),
            intensity: .vent
        )
        XCTAssertTrue(prompt.contains("VENT DRAFT RULES"))
        XCTAssertTrue(prompt.contains("for yourself only"))
    }

    func testVentUserPromptAsksForOneUnnumberedDraft() {
        let prompt = PromptBuilder.userPrompt(
            situation: "My coworker dumped work on me again.",
            styleName: "Sharp",
            variants: 3,
            intensity: .vent
        )
        XCTAssertTrue(prompt.contains("Write 1 private vent draft"))
        XCTAssertTrue(prompt.contains("no numbering"))
        XCTAssertFalse(prompt.contains("Number each response"))
    }

    func testCalmIntensityGuidanceIsProfessional() {
        let prompt = PromptBuilder.systemPrompt(
            style: style,
            locale: Locale(identifier: "en_US"),
            intensity: .calm
        )
        XCTAssertTrue(prompt.lowercased().contains("professional"))
    }

    func testFeralIntensityInjectsFeralPreambleButNotVent() {
        let prompt = PromptBuilder.systemPrompt(
            style: style,
            locale: Locale(identifier: "en_US"),
            intensity: .feral
        )
        XCTAssertTrue(prompt.contains("FERAL DRAFT RULES"),
                      "Feral runs must include the profanity-unlocked private-draft preamble.")
        XCTAssertFalse(prompt.contains("VENT DRAFT RULES"),
                       "Feral has its own private-draft preamble — vent preamble must not leak in.")
    }

    func testLanguageDirectiveOverridesEnglishExamples_zhHans() {
        // Regression: with English-only style examples, the model was
        // ignoring the top-of-prompt "Reply in 简体中文" and echoing the
        // example language. The enforcement directive lives AFTER the
        // examples now and is unconditional.
        let styleWithEnglishExamples = StylePreset(
            id: "test",
            displayKey: "test.name",
            blurbKey: "test.blurb",
            icon: "star",
            tier: .free,
            temperature: 0.8,
            tags: [],
            systemPreamble: "Be witty.",
            examples: [
                .init(situation: "English situation", response: "English answer")
            ],
            localesSupported: nil
        )
        let prompt = PromptBuilder.systemPrompt(
            style: styleWithEnglishExamples,
            locale: Locale(identifier: "zh_Hans_CN"),
            intensity: .sharp
        )
        XCTAssertFalse(prompt.contains("English answer"),
                       "Mismatched English examples should be omitted for zh-Hans prompts.")
        XCTAssertTrue(prompt.contains("简体中文"))
    }

    func testExamplesForPromptKeepsTargetLanguageOnly() {
        let mixedStyle = StylePreset(
            id: "mixed",
            displayKey: "test.name",
            blurbKey: "test.blurb",
            icon: "star",
            tier: .free,
            temperature: 0.8,
            tags: [],
            systemPreamble: "Be witty.",
            examples: [
                .init(situation: "English situation", response: "English answer"),
                .init(situation: "邻居半夜很吵", response: "请先学会尊重别人。"),
                .init(situation: "上司が手柄を横取りした", response: "その成果、私の仕事でした。")
            ],
            localesSupported: nil
        )

        XCTAssertEqual(
            PromptBuilder.examplesForPrompt(style: mixedStyle, locale: Locale(identifier: "en_US")).count,
            1
        )
        XCTAssertEqual(
            PromptBuilder.examplesForPrompt(style: mixedStyle, locale: Locale(identifier: "zh_Hans_CN")).count,
            1
        )
        XCTAssertEqual(
            PromptBuilder.examplesForPrompt(style: mixedStyle, locale: Locale(identifier: "ja_JP")).count,
            1
        )
    }

    func testUserPromptAppendsLanguageReminderWhenLocaleProvided() {
        let prompt = PromptBuilder.userPrompt(
            situation: "X",
            styleName: "Sharp",
            variants: 3,
            intensity: .sharp,
            locale: Locale(identifier: "zh_Hans_CN")
        )
        XCTAssertTrue(prompt.contains("请用简体中文回复"))
    }

    func testSendableRewritePromptIncludesInputsAndNoProfanityRule() {
        let (system, user) = PromptBuilder.rewriteAsSendablePrompt(
            ventDraft: "This is such damn nonsense.",
            originalSituation: "A client ignored the deadline and blamed me.",
            styleName: "Sharp",
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(system.contains("Do not use profanity"))
        XCTAssertTrue(user.contains("This is such damn nonsense."))
        XCTAssertTrue(user.contains("A client ignored the deadline and blamed me."))
    }
}
