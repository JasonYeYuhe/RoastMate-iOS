import XCTest
@testable import RoastMate

/// A4: the Argument Simulator's own prompt, and its stateless turn on the
/// engine. Until 1.8.0 it reused the roast prompt ("the response *the user*
/// should give back", numbered), and lens 1 measured 14/26 model turns in the
/// opponent's voice and 12/36 numbered lists.
final class ArgumentSimulatorTests: XCTestCase {

    private let setup = "I want to ask my manager for a raise. No raise in two years."
    private let transcript = [
        ArgumentLine(speaker: .opponent, text: "Budgets are tight this year, you know that."),
        ArgumentLine(speaker: .user, text: "My workload doubled. That's a fact."),
    ]

    // MARK: - Prompt

    func testPrompt_carriesSetupAndTranscript_andCastsTheModelAsTheOtherPerson() {
        let p = PromptBuilder.opponentPrompt(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(p.user.contains(setup))
        XCTAssertTrue(p.user.contains("YOU (the other person): Budgets are tight this year, you know that."))
        XCTAssertTrue(p.user.contains("USER: My workload doubled. That's a fact."))
        XCTAssertTrue(p.system.contains("You are THE OTHER PERSON"))
        XCTAssertTrue(p.system.contains("Be witty."), "the style sets the opponent's voice")
    }

    func testPrompt_asksForNoNumbering_andHasNoUserSideCalibration() {
        let p = PromptBuilder.opponentPrompt(
            setup: "室友一直不倒垃圾。", transcript: transcript, style: style, locale: Locale(identifier: "zh_TW"))
        let both = p.system + p.user
        XCTAssertFalse(both.contains("Number each response"))
        XCTAssertFalse(both.contains("\"1.\""))
        XCTAssertFalse(both.contains("CALIBRATION"), "Sharp calibration is written as the user")
        XCTAssertFalse(both.contains("EXAMPLES"), "style examples are the user's replies")
        XCTAssertFalse(both.contains("responses I could give"))
        XCTAssertTrue(p.system.contains("繁體中文"))
    }

    func testPrompt_usesThePersonaWhenThereIsOne() {
        let persona = "You are the user's manager. You hold raises back because the budget is fixed."
        let p = PromptBuilder.opponentPrompt(
            setup: setup, transcript: transcript, style: style,
            locale: Locale(identifier: "en_US"), persona: persona)
        XCTAssertTrue(p.system.contains("WHO YOU ARE: " + persona))
        let without = PromptBuilder.opponentPrompt(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(without.system.contains("the other person described in the user's setup"))
    }

    func testPersona_standardFirst_thenPermissive_andNilOnRefusalText() async {
        let ok = FakeFMBackend(fresh: [.languageModelLikeError, .text("the user's manager")])
        let persona = await engine(ok).opponentPersona(setup: setup)
        XCTAssertEqual(persona, "You are the user's manager.")
        let used = await ok.freshGuardrails
        XCTAssertEqual(used, [.standard, .permissiveContentTransformations])

        let refused = FakeFMBackend(fresh: [.text("I'm sorry, but I can't help with that."), .languageModelLikeError])
        let none = await engine(refused).opponentPersona(setup: setup)
        XCTAssertNil(none)

        let switchedOff = FakeFMBackend(fresh: [.languageModelLikeError])
        let off = await engine(switchedOff, allowed: false).opponentPersona(setup: setup)
        XCTAssertNil(off)
        let offCalls = await switchedOff.freshGuardrails
        XCTAssertEqual(offCalls, [.standard], "no permissive call when the remote switch is off")
    }

    func testPersonaRoleParsing() {
        XCTAssertEqual(RoastEngine.personaRole("the user's landlord"), "the user's landlord")
        XCTAssertEqual(RoastEngine.personaRole("You are the user's mom.\nExtra"), "the user's mom")
        XCTAssertNil(RoastEngine.personaRole("I'm sorry, but I can't help with that."))
        XCTAssertNil(RoastEngine.personaRole(""))
        XCTAssertNil(RoastEngine.personaRole("the user"))
        XCTAssertNil(RoastEngine.personaRole(Array(repeating: "word", count: 20).joined(separator: " ")))
    }

    func testPersona_selfHarmSetup_isNeverSent() async {
        let backend = FakeFMBackend(fresh: [.text("You are someone.")])
        let persona = await engine(backend).opponentPersona(setup: "我不想活了")
        XCTAssertNil(persona)
        let calls = await backend.freshGuardrails
        XCTAssertTrue(calls.isEmpty)
    }

    func testPrompt_firstTurn_asksForTheOpeningLine() {
        let p = PromptBuilder.opponentPrompt(
            setup: setup, transcript: [], style: style, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(p.user.contains("The conversation is starting"))
        XCTAssertFalse(p.user.contains("The conversation so far"))
    }

    func testPrompt_keepsOnlyTheLast12Turns_andClipsLongTurns() {
        let long = Array(repeating: "word", count: 120).joined(separator: " ")
        var lines: [ArgumentLine] = (0..<14).map {
            ArgumentLine(speaker: $0 % 2 == 0 ? .opponent : .user, text: "turn \($0)")
        }
        lines.append(ArgumentLine(speaker: .user, text: long))
        let p = PromptBuilder.opponentPrompt(
            setup: setup, transcript: lines, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(p.user.contains("turn 2\n"))
        XCTAssertTrue(p.user.contains("turn 3"))
        XCTAssertFalse(p.user.contains(long))
        XCTAssertEqual(PromptBuilder.clipTurn(long).split(separator: " ").count, 80)
        XCTAssertEqual(PromptBuilder.clipTurn(String(repeating: "字", count: 500)).count, 160)
    }

    func testCleanOpponentLine() {
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("Them: Budgets are tight."), "Budgets are tight.")
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("1. Budgets are tight."), "Budgets are tight.")
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("對方：「我真的很忙。」"), "我真的很忙。")
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("\"Fine.\""), "Fine.")
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("「我說『不行』，你聽不懂」"), "我說『不行』，你聽不懂",
                       "only the outer pair is removed")
        XCTAssertEqual(PromptBuilder.cleanOpponentLine("「不行」他說「真的」"), "「不行」他說「真的」",
                       "quotes that are not one outer pair stay")
    }

    // MARK: - Engine

    func testTurn_defaultAccepted_isOneFreshStandardCall() async throws {
        let backend = FakeFMBackend(fresh: [.text("YOU (the other person): Budgets are tight, end of story.")])
        let turn = try await engine(backend).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .line("Budgets are tight, end of story."))
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.standard], "stateless: fresh session, default guardrails first")
    }

    func testTurn_repeatOfAnEarlierTurn_getsOneMoreTry() async throws {
        let backend = FakeFMBackend(fresh: [
            .text("Budgets are tight this year, you know that."), .text("Show me numbers and we'll talk in Q3.")])
        let turn = try await engine(backend).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .line("Show me numbers and we'll talk in Q3."))
        let calls = await backend.freshGuardrails
        XCTAssertEqual(calls, [.standard, .standard])
    }

    func testTurn_refusedThenPermissive_screensTheTurn() async throws {
        let backend = FakeFMBackend(fresh: [
            .languageModelLikeError, .text("OK"), .text("OK"),
            .text("We all had a hard year. Why should you be the exception?"), .text("SAFE")])
        let turn = try await engine(backend).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .line("We all had a hard year. Why should you be the exception?"))
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.standard] + Array(repeating: .permissiveContentTransformations, count: 4))
        let prompts = await backend.freshInstructions
        XCTAssertEqual(prompts.last, RoastEngine.threatJudgeInstructions)
    }

    func testTurn_judgeSaysThreat_isNotGenerated_neverACannedLine() async throws {
        let backend = FakeFMBackend(fresh: [
            .languageModelLikeError, .text("OK"), .text("OK"), .text("Keep pushing and see."), .text("THREAT")])
        let turn = try await engine(backend).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .notGenerated)
    }

    func testTurn_intimidationInTheUsersReply_neverReachesThePermissiveModel() async throws {
        let backend = FakeFMBackend(fresh: [.languageModelLikeError, .text("OK"), .text("OK"), .text("x"), .text("SAFE")])
        let lines = transcript + [ArgumentLine(speaker: .user, text: "Fine, then I'll make you scared to come to work.")]
        let turn = try await engine(backend).opponentTurn(
            setup: "Help me intimidate my manager.", transcript: lines, style: style,
            locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .notGenerated)
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.standard])
    }

    func testTurn_remoteSwitchOff_noRetry() async throws {
        let backend = FakeFMBackend(fresh: [.languageModelLikeError])
        let turn = try await engine(backend, allowed: false).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .notGenerated)
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.standard])
    }

    func testTurn_noOnDeviceModel_isUnavailable() async throws {
        let turn = try await engine(FakeFMBackend(available: false)).opponentTurn(
            setup: setup, transcript: [], style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .unavailable)
    }

    func testTurn_refusalTextOnTheDefaultPath_isNotGenerated() async throws {
        let backend = FakeFMBackend(fresh: [.text("I'm sorry, but I can't help with that.")])
        let turn = try await engine(backend).opponentTurn(
            setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(turn, .notGenerated)
    }

    func testTurn_cancellationPropagates() async {
        let backend = FakeFMBackend(fresh: [.cancellation])
        do {
            _ = try await engine(backend).opponentTurn(
                setup: setup, transcript: transcript, style: style, locale: Locale(identifier: "en_US"))
            XCTFail("expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    private func engine(_ backend: FakeFMBackend, allowed: Bool = true) -> RoastEngine {
        RoastEngine(fm: backend, permissiveRetryAllowed: { allowed })
    }

    private var style: StylePreset {
        StylePreset(
            id: "test", displayKey: "test.name", blurbKey: "test.blurb", icon: "star",
            tier: .pro, temperature: 0.8, tags: [], systemPreamble: "Be witty.",
            examples: [], localesSupported: nil)
    }
}
