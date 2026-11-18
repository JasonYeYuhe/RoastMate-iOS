import XCTest
@testable import RoastMate

/// 1.9.0 Q1: the answer screen uses the bench's formulas
/// (`docs/evidence/2026-11-18-pro-bench/score.py`); these cases mirror
/// `test_score.py`, so the app and the gate agree on what a non-answer is.
final class AnswerScreenTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let tw = Locale(identifier: "zh_TW")
    private let ja = Locale(identifier: "ja_JP")
    private let pans = "My roommate had friends over until 3am on a work night and left my pans crusted in the sink."

    func testEngineTxtNonAnswers() {
        // the 11-18 en 高情商 Composed lines that motivated Q1
        XCTAssertEqual(AnswerScreen.reasons("\"Sleepwalking?\"", situation: pans, locale: en),
                       [.short, .questionOnly, .ungrounded])
        XCTAssertTrue(AnswerScreen.reasons("\"Recipe planning?\"", situation: pans, locale: en).contains(.questionOnly))
        XCTAssertTrue(AnswerScreen.passes("You left the pans crusted in the sink for me again.", situation: pans, locale: en))
    }

    func testShortThresholds() {
        XCTAssertEqual(AnswerScreen.hanKanaCount("LINE已讀不回，又在催租。"), 8)
        XCTAssertFalse(AnswerScreen.reasons("LINE已讀不回，又在催租。", situation: "房東LINE已讀不回", locale: tw).contains(.short))
        XCTAssertTrue(AnswerScreen.reasons("「封面？」", situation: "x", locale: tw).contains(.short))
        XCTAssertTrue(AnswerScreen.reasons("返金期限。", situation: "x", locale: ja).contains(.short))
        XCTAssertFalse(AnswerScreen.reasons("返金期限を逃している。", situation: "x", locale: ja).contains(.short))
    }

    func testQuestionOnly() {
        XCTAssertTrue(AnswerScreen.questionOnly("Recipe planning?"))
        XCTAssertTrue(AnswerScreen.questionOnly("「這樣真的好嗎？」"))
        XCTAssertTrue(AnswerScreen.questionOnly("Seriously?! You did that?"))
        XCTAssertFalse(AnswerScreen.questionOnly("修冷氣拖三個月，房租還要準時？邏輯能更簡單一點嗎？"))
        XCTAssertFalse(AnswerScreen.questionOnly("You left my pans in the sink. Planning to wash them?"))
        XCTAssertFalse(AnswerScreen.questionOnly("Wow! Really?"))
        XCTAssertFalse(AnswerScreen.questionOnly("「封面？這應該是你的責任。」"))
    }

    func testNoVerbIsEnglishOnly() {
        XCTAssertTrue(AnswerScreen.reasons("Total disaster of a weekend party, honestly.", situation: pans, locale: en).contains(.noVerb))
        XCTAssertFalse(AnswerScreen.reasons("簡報是團隊成果，不能單方面歸功。", situation: "x", locale: tw).contains(.noVerb))
    }

    func testGrounded() {
        let sit = "房東說好這個月修冷氣，拖了三個禮拜，LINE已讀不回，倒是記得提醒我房租要準時。"
        XCTAssertTrue(AnswerScreen.grounded("冷氣拖三週，房租倒是很準時。", situation: sit, locale: tw))
        XCTAssertFalse(AnswerScreen.grounded("你真的很過分耶。", situation: sit, locale: tw))
        XCTAssertFalse(AnswerScreen.grounded("我們，這個。", situation: "我們這個人", locale: tw), "stop bigrams, never across punctuation")
        XCTAssertTrue(AnswerScreen.grounded("又在LINE上裝死。", situation: "LINE已讀不回", locale: tw))
        let jaSit = "ルームメイトが洗い物を三、四日シンクに放置している。"
        XCTAssertTrue(AnswerScreen.grounded("シンクの皿、また放置ですか。", situation: jaSit, locale: ja))
        XCTAssertFalse(AnswerScreen.grounded("それはしているだけですね。", situation: jaSit, locale: ja), "kana-only bigrams are grammar")
        XCTAssertFalse(AnswerScreen.grounded("Sleepwalking?", situation: pans, locale: en))
        XCTAssertFalse(AnswerScreen.grounded("You have it.", situation: "They have it.", locale: en), "light verbs never ground")
    }

    func testPoolPrefersAnswersThenStatementsThenFallback() {
        let target = AnswerTarget(situation: pans, locale: en)
        let answered = "You left the pans crusted in the sink for me again."
        let statement = "Some people simply never learn how to behave like adults."
        let fragment = "Sleepwalking?"
        let pool = target.sort([fragment, statement, answered])
        XCTAssertEqual(pool.answered, [answered])
        XCTAssertEqual(pool.statements, [statement])
        XCTAssertEqual(pool.rest, [fragment])
        XCTAssertEqual(pool.shown(count: 3, fallback: [fragment]), [answered])

        let noAnswer = target.sort([fragment, statement])
        XCTAssertEqual(noAnswer.shown(count: 3, fallback: [fragment, statement]), [statement])
        XCTAssertEqual(target.sort([fragment]).shown(count: 3, fallback: [fragment]), [fragment],
                       "never empty while the model wrote something: no curated text from the screen")
    }

    func testRetryPromptNamesTheProblemAndEndsWithTheLanguage() {
        let target = AnswerTarget(situation: "x", locale: tw)
        let p = target.retryPrompt("Situation: x", reasons: [.short, .questionOnly])
        XCTAssertTrue(p.hasPrefix("Situation: x"))
        XCTAssertTrue(p.contains("a word or a fragment"))
        XCTAssertTrue(p.contains("only a question"))
        XCTAssertTrue(p.hasSuffix(PromptBuilder.userLanguageReminder(for: tw)))
    }

    // MARK: Engine

    func testDefaultPath_nonAnswersTriggerOneFreshRetry_andAnswersWin() async throws {
        let backend = FakeFMBackend(
            cached: [.text("1. Sleepwalking?\n2. Recipe planning?\n3. Emergency cleanup?")],
            fresh: [.text("1. You left the pans crusted in the sink after your 3am party.\n2. My pans are not your friends' leftovers bin.\n3. Recipe planning?")])
        let out = try await RoastEngine(fm: backend).generateDetailed(
            situation: pans, style: style, locale: en, variantCount: 3, intensity: .calm)
        XCTAssertEqual(out.provenance, .model)
        XCTAssertEqual(out.texts, ["You left the pans crusted in the sink after your 3am party.",
                                   "My pans are not your friends' leftovers bin."])
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.standard], "one retry, default guardrails")
        let prompts = await backend.freshPrompts
        XCTAssertTrue(prompts[0].contains("IMPORTANT:"))
    }

    func testDefaultPath_answersOnFirstTry_noRetry() async throws {
        let backend = FakeFMBackend(cached: [.text("1. You left my pans crusted in the sink.\n2. Your 3am party ended in my sink.\n3. Wash the pans your friends used.")])
        let out = try await RoastEngine(fm: backend).generateDetailed(
            situation: pans, style: style, locale: en, variantCount: 3, intensity: .sharp)
        XCTAssertEqual(out.texts.count, 3)
        let used = await backend.freshGuardrails
        XCTAssertTrue(used.isEmpty)
    }

    func testDefaultPath_retryStillNonAnswers_showsTheModelText_notCurated() async throws {
        let backend = FakeFMBackend(cached: [.text("1. Sleepwalking?")], fresh: [.languageModelLikeError])
        let out = try await RoastEngine(fm: backend).generateDetailed(
            situation: pans, style: style, locale: en, variantCount: 3, intensity: .calm)
        XCTAssertEqual(out.provenance, .model)
        XCTAssertEqual(out.texts, ["Sleepwalking?"])
    }

    func testPrivateDraftsAreNotScreened() async throws {
        let backend = FakeFMBackend(cached: [.text("Ugh.")])
        let out = try await RoastEngine(fm: backend).generateDetailed(
            situation: pans, style: style, locale: en, variantCount: 1, intensity: .vent)
        XCTAssertEqual(out.texts, ["Ugh."])
        let used = await backend.freshGuardrails
        XCTAssertTrue(used.isEmpty)
    }

    func testPermissivePath_nonAnswersRetryOnce_beforeTheJudge() async throws {
        let backend = FakeFMBackend(
            cached: [.languageModelLikeError],
            fresh: [.text("OK"), .text("OK"),
                    .text("1. Sleepwalking?\n2. Recipe planning?\n3. You left the pans crusted in the sink."),
                    .text("SAFE"),
                    .text("1. Your 3am party ended up in my sink.\n2. Emergency cleanup?"),
                    .text("SAFE")])
        let out = try await RoastEngine(fm: backend, permissiveRetryAllowed: { true }).generateDetailed(
            situation: pans, style: style, locale: en, variantCount: 3, intensity: .savage)
        XCTAssertEqual(out.provenance, .model)
        XCTAssertEqual(out.texts, ["You left the pans crusted in the sink.", "Your 3am party ended up in my sink."])
        let instructions = await backend.freshInstructions
        XCTAssertEqual(instructions.filter { $0 == RoastEngine.threatJudgeInstructions }.count, 2,
                       "dropped versions cost no judge call")
    }

    private var style: StylePreset {
        StylePreset(id: "test", displayKey: "test.name", blurbKey: "test.blurb", icon: "star",
                    tier: .pro, temperature: 0.8, tags: [], systemPreamble: "Be witty.",
                    examples: [], localesSupported: nil)
    }
}
