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

    func testVentOverridesPoliteStylePreamble() {
        // Regression: real-device output for high_eq + vent was polished
        // sarcasm ("oh my, your gaming sure is loud at 2AM!") because the
        // high_eq style preamble said "polite, reasonable, emotionally
        // intelligent professional" — that fought the vent register and
        // averaged out to safe snark. Fix: for private drafts we drop the
        // style's tone preamble and explicitly tell the model to ignore
        // any politeness framing.
        let politeStyle = StylePreset(
            id: "high_eq_test",
            displayKey: "test.name",
            blurbKey: "test.blurb",
            icon: "star",
            tier: .free,
            temperature: 0.8,
            tags: [],
            systemPreamble: "POLITE_PROFESSIONAL_PREAMBLE_MARKER — be reasonable and emotionally intelligent.",
            examples: [],
            localesSupported: nil
        )
        let ventPrompt = PromptBuilder.systemPrompt(
            style: politeStyle,
            locale: Locale(identifier: "en_US"),
            intensity: .vent
        )
        XCTAssertFalse(ventPrompt.contains("POLITE_PROFESSIONAL_PREAMBLE_MARKER"),
                       "Private drafts must suppress the style's tone preamble so politeness doesn't dilute the vent.")
        XCTAssertTrue(ventPrompt.contains("Intensity overrides Style for private drafts"),
                      "The override directive should be explicit so the model can't average the two.")

        // Sanity: a non-private intensity STILL uses the style preamble.
        let sharpPrompt = PromptBuilder.systemPrompt(
            style: politeStyle,
            locale: Locale(identifier: "en_US"),
            intensity: .sharp
        )
        XCTAssertTrue(sharpPrompt.contains("POLITE_PROFESSIONAL_PREAMBLE_MARKER"),
                      "Non-private intensities continue to use the style's tone preamble verbatim.")
    }

    func testVentPreambleIsDirectiveNotPermissive() {
        // The original "may use strong language" phrasing produced safe
        // snark. The preamble now uses imperatives so the model commits.
        let prompt = PromptBuilder.systemPrompt(
            style: emptyStyle,
            locale: Locale(identifier: "en_US"),
            intensity: .vent
        )
        XCTAssertTrue(prompt.contains("FURIOUS"),
                      "Vent preamble should set the emotional baseline explicitly.")
        XCTAssertTrue(prompt.contains("FORBIDDEN openings"),
                      "Vent preamble must call out polite-sarcasm openings as forbidden.")
    }

    func testPrivateDraftAllowsImaginedDirectAddressInsteadOfForcingReflection() {
        let prompt = PromptBuilder.systemPrompt(
            style: emptyStyle,
            locale: Locale(identifier: "zh_Hans_CN"),
            intensity: .vent
        )
        XCTAssertTrue(prompt.contains("Imagined direct address is ALLOWED"),
                      "Private drafts should permit the user's imagined confrontation so anger can land.")
        XCTAssertTrue(prompt.contains("PRIVATE DRAFT CALIBRATION"),
                      "Private drafts should include a concrete same-language calibration block.")
        XCTAssertTrue(prompt.contains("如果你把这份心思放在自己身上"),
                      "The prompt should explicitly mark reflective self-help prose as the bad target shape.")
    }

    func testPrivateDraftTaskRejectsAdviceAndMoralLessons() {
        let prompt = PromptBuilder.userPrompt(
            situation: "My roommate games loudly at 2 AM.",
            styleName: "Savage",
            variants: 3,
            intensity: .vent
        )
        XCTAssertTrue(prompt.contains("Do not give advice, reflection, or moral lessons."),
                      "The private draft task should prevent therapist-tone drift.")
        XCTAssertTrue(prompt.contains("imagined direct address"),
                      "The private draft task should allow a sharper imagined confrontation.")
    }

    private var emptyStyle: StylePreset {
        StylePreset(
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
