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
    private let ko = Locale(identifier: "ko_KR")

    /// NLTagger's English lexical-class and lemma models never loaded in the
    /// iOS simulator's app process (11-21: `requestAssets` gave no answer in
    /// 120 s, while a binary spawned in the same simulator tagged fine). The
    /// cases that need them skip there and run in a macOS package, where the
    /// gate ran (bench README, "After the gate").
    private func requireEnglishModels() throws {
        try XCTSkipUnless(AnswerScreen.probeEnglishModels() == .all,
                          "no English NLTagger models in this process; run these cases on macOS")
    }

    func testEngineTxtNonAnswers() throws {
        try requireEnglishModels()
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

    func testNoVerbIsEnglishOnly() throws {
        XCTAssertFalse(AnswerScreen.reasons("簡報是團隊成果，不能單方面歸功。", situation: "x", locale: tw).contains(.noVerb))
        try requireEnglishModels()
        XCTAssertTrue(AnswerScreen.reasons("Total disaster of a weekend party, honestly.", situation: pans, locale: en).contains(.noVerb))
    }

    func testGrounded() throws {
        let sit = "房東說好這個月修冷氣，拖了三個禮拜，LINE已讀不回，倒是記得提醒我房租要準時。"
        XCTAssertTrue(AnswerScreen.grounded("冷氣拖三週，房租倒是很準時。", situation: sit, locale: tw))
        XCTAssertFalse(AnswerScreen.grounded("你真的很過分耶。", situation: sit, locale: tw))
        XCTAssertFalse(AnswerScreen.grounded("我們，這個。", situation: "我們這個人", locale: tw), "stop bigrams, never across punctuation")
        XCTAssertTrue(AnswerScreen.grounded("又在LINE上裝死。", situation: "LINE已讀不回", locale: tw))
        let jaSit = "ルームメイトが洗い物を三、四日シンクに放置している。"
        XCTAssertTrue(AnswerScreen.grounded("シンクの皿、また放置ですか。", situation: jaSit, locale: ja))
        XCTAssertFalse(AnswerScreen.grounded("それはしているだけですね。", situation: jaSit, locale: ja), "kana-only bigrams are grammar")
        try requireEnglishModels()
        XCTAssertTrue(AnswerScreen.grounded("You left the pans crusted in the sink for me again.", situation: pans, locale: en))
        XCTAssertFalse(AnswerScreen.grounded("Sleepwalking?", situation: pans, locale: en))
        XCTAssertFalse(AnswerScreen.grounded("You have it.", situation: "They have it.", locale: en), "light verbs never ground")
    }

    func testPoolPrefersAnswersThenStatementsThenFallback() throws {
        try requireEnglishModels()
        let target = AnswerTarget(situation: pans, locale: en)
        let answered = "You left the pans crusted in the sink for me again."
        let statement = "Some people simply never learn how to behave like adults."
        let fragment = "Sleepwalking?"
        let pool = target.sort([fragment, statement, answered])
        XCTAssertEqual(pool.answered, [answered])
        XCTAssertEqual(pool.statements, [statement])
        XCTAssertEqual(pool.rest, [fragment])
        XCTAssertEqual(pool.shown(count: 3, fallback: [fragment], locale: en), [answered, statement],
                       "answers first, topped up with full statements, never the fragment")
        XCTAssertFalse(pool.needsRetry(count: 3), "1 answer + 1 statement: no retry")

        let noAnswer = target.sort([fragment, statement])
        XCTAssertEqual(noAnswer.shown(count: 3, fallback: [fragment, statement], locale: en), [statement])
        XCTAssertTrue(noAnswer.needsRetry(count: 3), "nothing answered: retry")
        XCTAssertTrue(target.sort([answered, fragment]).needsRetry(count: 3), "one full sentence only: retry")
        XCTAssertEqual(target.sort([fragment]).shown(count: 3, fallback: [fragment], locale: en), [fragment],
                       "never empty while the model wrote something: no curated text from the screen")
    }

    /// Q1 gate attempt 1: topping up to 3 with ungrounded statements put
    /// grounded at 83.4 % on the fixed set. A statement now fills in only up
    /// to 2 versions when something answered.
    func testStatementsFillOnlyUpToTwo_whenSomethingAnswered() throws {
        try requireEnglishModels()
        let target = AnswerTarget(situation: pans, locale: en)
        let a1 = "You left the pans crusted in the sink for me again."
        let a2 = "Your 3am party ended up in my sink."
        let s1 = "Some people simply never learn how to behave like adults."
        let s2 = "Respect is not a hard concept to understand, honestly."
        XCTAssertEqual(target.sort([a1, a2, s1]).shown(count: 3, fallback: [], locale: en), [a1, a2],
                       "two answers: no ungrounded third version")
        XCTAssertEqual(target.sort([a1, s1, s2]).shown(count: 3, fallback: [], locale: en), [a1, s1],
                       "one answer: one statement beside it, not two")
        XCTAssertEqual(target.sort([s1, s2]).shown(count: 3, fallback: [], locale: en), [s1, s2],
                       "nothing answers: statements up to count")
        XCTAssertEqual(AnswerTarget.Pool.topUpLimit(count: 1), 1)
    }

    /// The bench's near-duplicate test (`score.py near_dup_pairs`); the
    /// values in the messages are score.py's for the same pairs (gate 1 rows).
    func testNearDuplicateMirrorsTheBench() {
        XCTAssertTrue(AnswerScreen.nearDuplicate(
            "「会議では寝ていたのに、最後の報告書には名前を載せた。」",
            "「最後の報告書には名前を載せられたのに、会議では何もしていなかった。」", locale: ja), "0.514")
        XCTAssertTrue(AnswerScreen.nearDuplicate(
            "再跟進一次，請提供這份簡報的原始檔案。為了確保資訊透明，同步給主管。感謝您的理解。",
            "再跟進一次，請確認這份簡報已提交至正確的檔案夾。為了確保資訊集中，同步給主管。感謝您的理解。", locale: tw), "0.471")
        XCTAssertFalse(AnswerScreen.nearDuplicate(
            "簡報需要明天早上八點前完成，但這次又是在晚上十一點突然要求。",
            "在簡報改稿時間上，你總在告訴我「年輕人多做一點不吃虧」，卻忘了實際執行。", locale: tw), "0.036")
        XCTAssertTrue(AnswerScreen.nearDuplicate(
            "You left the pans crusted in the sink after your party.",
            "You left the pans crusted in the sink for me again.", locale: en), "0.538")
        XCTAssertFalse(AnswerScreen.nearDuplicate(
            "You left the pans crusted in the sink after your party.",
            "Your 3am party ended up in my sink.", locale: en), "0.0")
    }

    func testShownDropsBenchNearDuplicates_andTopsUpInstead() {
        let sit = "我做了兩個禮拜的簡報，同事在週會上說是他做的，主管還當場誇他。"
        let target = AnswerTarget(situation: sit, locale: tw)
        let a1 = "再跟進一次，請提供這份簡報的原始檔案。為了確保資訊透明，同步給主管。感謝您的理解。"
        let a2 = "再跟進一次，請確認這份簡報已提交至正確的檔案夾。為了確保資訊集中，同步給主管。感謝您的理解。"
        let a3 = "兩個禮拜的心血，你在週會上一句話就拿走了。"
        let pool = target.sort([a1, a2, a3])
        XCTAssertEqual(pool.answered, [a1, a2, a3])
        XCTAssertEqual(pool.shown(count: 3, fallback: [], locale: tw), [a1, a3])
        XCTAssertFalse(target.repeats(a3, in: [a1]))
        XCTAssertTrue(target.repeats(a2, in: [a1]))
    }

    func testRetryPromptNamesTheProblemAndEndsWithTheLanguage() {
        let target = AnswerTarget(situation: "x", locale: tw)
        let p = target.retryPrompt("Situation: x", reasons: [.short, .questionOnly])
        XCTAssertTrue(p.hasPrefix("Situation: x"))
        XCTAssertTrue(p.contains("a word or a fragment"))
        XCTAssertTrue(p.contains("only a question"))
        XCTAssertTrue(p.hasSuffix(PromptBuilder.userLanguageReminder(for: tw)))
    }

    func testWithoutEnglishModels_onlyTheRulesThatNeedNoTaggerApply() {
        // The assets can be missing on iOS: then no verb and English grounding
        // are skipped, never failed.
        XCTAssertEqual(AnswerScreen.reasons("\"Sleepwalking?\"", situation: pans, locale: en, english: AnswerScreen.EnglishModels.none),
                       [.short, .questionOnly])
        XCTAssertEqual(AnswerScreen.reasons("Total disaster of a weekend party, honestly.", situation: pans,
                                            locale: en, english: AnswerScreen.EnglishModels.none), [])
        XCTAssertEqual(AnswerScreen.reasons("You left the pans crusted in the sink for me again.", situation: pans,
                                            locale: en, english: AnswerScreen.EnglishModels.none), [])
        // Chinese and Japanese never use the tagger.
        XCTAssertTrue(AnswerScreen.reasons("「封面？」", situation: "x", locale: tw, english: AnswerScreen.EnglishModels.none).contains(.short))
        XCTAssertTrue(AnswerScreen.reasons("這份帳單不是比賽，這是協作。", situation: "房東LINE已讀不回",
                                           locale: tw, english: AnswerScreen.EnglishModels.none).contains(.ungrounded))
    }

    func testLexicalClassesWithoutLemmas_noVerbApplies_groundingDoesNot() throws {
        try requireEnglishModels()
        let lexicalOnly = AnswerScreen.EnglishModels(lexicalClass: true, lemma: false)
        XCTAssertEqual(AnswerScreen.reasons("Total disaster of a weekend party, honestly.", situation: pans,
                                            locale: en, english: lexicalOnly), [.noVerb])
        XCTAssertEqual(AnswerScreen.reasons("Some people simply never learn how to behave like adults.", situation: pans,
                                            locale: en, english: lexicalOnly), [])
    }

    func testKoreanIsNotCovered_everyOtherLocaleIs() {
        XCTAssertFalse(AnswerScreen.covers(ko))
        for id in ["en_US", "fr_FR", "de_DE", "zh_TW", "zh_CN", "ja_JP"] {
            XCTAssertTrue(AnswerScreen.covers(Locale(identifier: id)), id)
        }
    }

    // MARK: Engine

    func testDefaultPath_korean_keeps180Behaviour_noScreenNoRetry() async throws {
        let backend = FakeFMBackend(cached: [.text("1. 설거지 좀 해.\n2. 왜?\n3. 진짜 너무하다.")])
        let out = try await RoastEngine(fm: backend).generateDetailed(
            situation: "룸메이트가 일주일 동안 설거지를 안 했어요.", style: style, locale: ko, variantCount: 3, intensity: .calm)
        XCTAssertEqual(out.provenance, .model)
        XCTAssertEqual(out.texts.count, 3)
        let used = await backend.freshGuardrails
        XCTAssertTrue(used.isEmpty, "no answer-screen retry for Korean")
    }

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

    /// Q1 gate attempt 2: when the judge rejects every version that
    /// answered, A3's path retries once (with the reason) instead of falling
    /// back to curated text; the retry is judged like the first try.
    func testPermissivePath_allJudgedThreats_retriesOnce_thenJudgesAgain() async throws {
        let backend = FakeFMBackend(
            cached: [.languageModelLikeError],
            fresh: [.text("OK"), .text("OK"),
                    .text("1. You dragged the couch at 1am again, so fix it or else.\n2. You ignored my note about the 1am noise, last warning.\n3. Your furniture at 1am wakes me up, stop or face it."),
                    .text("THREAT"), .text("THREAT"), .text("THREAT"),
                    .text("1. You dragged the couch across the floor at 1am again.\n2. You ignored the note I left about the noise."),
                    .text("SAFE"), .text("SAFE")])
        let out = try await RoastEngine(fm: backend, permissiveRetryAllowed: { true }).generateDetailed(
            situation: "My upstairs neighbor drags furniture at 1am every night and ignored my note.",
            style: style, locale: en, variantCount: 3, intensity: .sharp)
        XCTAssertEqual(out.provenance, .model)
        XCTAssertEqual(out.texts, ["You dragged the couch across the floor at 1am again.",
                                   "You ignored the note I left about the noise."])
        let prompts = await backend.freshPrompts
        XCTAssertTrue(prompts.contains { $0.contains("a threat or an ultimatum") && $0.contains("or else") },
                      "the retry names why the last try was rejected")
    }

    func testPermissivePath_retryAlsoJudgedThreats_isCurated() async throws {
        let threats = "1. You dragged the couch at 1am again, so fix it or else.\n2. You ignored my note about the 1am noise, last warning."
        let backend = FakeFMBackend(
            cached: [.languageModelLikeError],
            fresh: [.text("OK"), .text("OK"), .text(threats), .text("THREAT"), .text("THREAT"),
                    .text(threats), .text("THREAT"), .text("THREAT")])
        let out = try await RoastEngine(fm: backend, permissiveRetryAllowed: { true }).generateDetailed(
            situation: "My upstairs neighbor drags furniture at 1am every night and ignored my note.",
            style: style, locale: en, variantCount: 3, intensity: .sharp)
        XCTAssertEqual(out.provenance, .curated, "one retry only; the judge still decides")
    }

    func testRetryInstructionForJudgedThreats() {
        let line = AnswerScreen.retryInstruction(for: [.judgedThreat])
        XCTAssertTrue(line.contains("threat or an ultimatum"))
        XCTAssertTrue(line.contains("never attach a consequence"))
        XCTAssertTrue(line.contains("ends with a full stop, not a question"))
        XCTAssertFalse(AnswerScreen.retryInstruction(for: [.short]).contains("consequence"))
    }

    private var style: StylePreset {
        StylePreset(id: "test", displayKey: "test.name", blurbKey: "test.blurb", icon: "star",
                    tier: .pro, temperature: 0.8, tags: [], systemPreamble: "Be witty.",
                    examples: [], localesSupported: nil)
    }
}
