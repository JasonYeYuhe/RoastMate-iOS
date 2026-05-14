import XCTest
@testable import RoastMate

final class PromptBuilderModesTests: XCTestCase {
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

    func testRoastModeWrapsAsSituation() {
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .roast)
        XCTAssertTrue(user.contains("Situation:"))
    }

    func testReplyModeWrapsAsMessage() {
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .reply)
        XCTAssertTrue(user.contains("Message I received"))
        XCTAssertTrue(user.contains("replies I could send back"))
    }

    func testTranslateModeWrapsAsPhrase() {
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .translate)
        XCTAssertTrue(user.contains("Phrase to translate"))
        XCTAssertTrue(user.contains("Same meaning"))
    }

    func testArgumentModeWrapsAsArgumentSetup() {
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .argument)
        XCTAssertTrue(user.contains("Argument setup"))
        XCTAssertTrue(user.contains("rehearsal"))
    }

    func testSocialModeWrapsAsPost() {
        let user = PromptBuilder.userPrompt(situation: "x", styleName: "s", variants: 1, mode: .social)
        XCTAssertTrue(user.contains("Post to react to"))
        XCTAssertTrue(user.contains("reaction replies"))
    }

    func testSystemPromptIncludesModeGuidance() {
        for mode in RoastMode.allCases {
            let prompt = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "en"), mode: mode)
            XCTAssertTrue(prompt.contains("Mode: \(mode.rawValue)"), "missing mode guidance for \(mode)")
        }
    }
}
