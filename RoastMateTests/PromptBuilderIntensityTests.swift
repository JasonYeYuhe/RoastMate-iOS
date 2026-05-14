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
