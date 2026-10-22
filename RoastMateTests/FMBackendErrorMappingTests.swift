import XCTest
@testable import RoastMate

/// 1.7.1: every non-cancellation error from the on-device backend must become
/// the labelled curated fallback — for generation AND for "make it sendable".
///
/// Why: since 1.6.0 the app is built with SDK 27, and on iOS/macOS 27 Apple's
/// refusals arrive as `LanguageModelError`, not `GenerationError`. The backend
/// matched only the old type, so refusals became `RoastError.generationFailed` (now removed)
/// and the user saw an error box (measured on macOS 27.0.1, 2026-10-22). These
/// tests drive `RoastEngine` with a fake backend that throws error types the
/// engine has never heard of, which is exactly the shape of that regression.
final class FMBackendErrorMappingTests: XCTestCase {

    // MARK: - generate

    func testGenerate_unknownErrorFromBackend_returnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(cached: [.languageModelLikeError]))
        let output = try await engine.generateDetailed(
            situation: "My roommate left dishes in the sink for a week.",
            style: testStyle, locale: Locale(identifier: "en_US"),
            variantCount: 3, intensity: .sharp)
        XCTAssertEqual(output.provenance, .curated,
                       "A refusal type the engine does not know must be a labelled curated fallback, not an error.")
        XCTAssertEqual(output.texts.count, 3)
    }

    func testGenerate_foreignNSErrorFromBackend_returnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(cached: [.foreignNSError]))
        let output = try await engine.generateDetailed(
            situation: "同事把我的方案說成是他的。",
            style: testStyle, locale: Locale(identifier: "zh_TW"),
            variantCount: 1, intensity: .sharp)
        XCTAssertTrue(output.isCurated)
    }

    func testGenerate_classifiedGenerationError_stillReturnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(cached: [.generation]))
        let output = try await engine.generateDetailed(
            situation: "X did Y.", style: testStyle, locale: Locale(identifier: "en_US"),
            variantCount: 1, intensity: .savage)
        XCTAssertTrue(output.isCurated)
    }

    /// A failed cloud Vent falls through to the on-device model, which refuses
    /// vent text; that refusal must also land on the curated path.
    func testGenerate_failedCloudVentThenUnknownLocalError_returnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(cached: [.languageModelLikeError]))
        let output = try await engine.generateDetailed(
            situation: "室友半夜開外放打遊戲。",
            style: testStyle, locale: Locale(identifier: "zh_TW"),
            variantCount: 1, intensity: .vent,
            cloudVentEnabled: true,
            cloudClient: FailingCloudVentService(),
            auth: StubAuth(token: nil))
        XCTAssertTrue(output.isCurated,
                      "Cloud failure + on-device refusal must show the labelled example, not an error.")
    }

    func testGenerate_cancellationPropagates() async {
        let engine = RoastEngine(fm: FakeFMBackend(cached: [.cancellation]))
        do {
            _ = try await engine.generateDetailed(
                situation: "X did Y.", style: testStyle, locale: Locale(identifier: "en_US"),
                variantCount: 1, intensity: .sharp)
            XCTFail("CancellationError must propagate, not turn into curated text")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
    }

    // MARK: - rewrite ("make it sendable")

    func testRewrite_unknownErrorFromBackend_returnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(fresh: [.languageModelLikeError]))
        let rewrite = try await engine.rewriteAsSendableDetailed(
            ventDraft: "You absolute snake, stop taking credit for my work.",
            originalSituation: "My coworker took credit for my report.",
            style: testStyle, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(rewrite.provenance, .curated)
        XCTAssertFalse(rewrite.text.isEmpty)
    }

    func testRewrite_foreignNSErrorFromBackend_returnsCurated() async throws {
        let engine = RoastEngine(fm: FakeFMBackend(fresh: [.foreignNSError]))
        let rewrite = try await engine.rewriteAsSendableDetailed(
            ventDraft: "他媽的，又搶我功勞。", originalSituation: "主管搶我功勞。",
            style: testStyle, locale: Locale(identifier: "zh_TW"))
        XCTAssertEqual(rewrite.provenance, .curated)
    }

    func testRewrite_usesPermissiveGuardrails_thenAsksTheThreatJudge() async throws {
        let reply = "You presented my report as yours. Correct that with the team today."
        let backend = FakeFMBackend(fresh: [.text(reply), .text("SAFE")])
        let engine = RoastEngine(fm: backend)
        let rewrite = try await engine.rewriteAsSendableDetailed(
            ventDraft: "You stole my damn report.", originalSituation: "My manager took credit.",
            style: testStyle, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(rewrite.provenance, .model)
        XCTAssertEqual(rewrite.text, reply)
        let used = await backend.freshGuardrails
        XCTAssertEqual(used, [.permissiveContentTransformations, .permissiveContentTransformations],
                       "Rewrite and threat judge both run permissive: default guardrails refused 12/36 legitimate complaints.")
        let prompts = await backend.freshInstructions
        XCTAssertEqual(prompts.last, RoastEngine.threatJudgeInstructions)
    }

    /// Permissive mode returns a refusal as TEXT. It must never be shown as
    /// the user's rewrite.
    func testRewrite_refusalText_returnsCurated() async throws {
        for refusal in ["Unable to work with that request.", "無法處理該請求。",
                        "无法处理该请求。", "そのリクエストには対応できません。"] {
            let engine = RoastEngine(fm: FakeFMBackend(fresh: [.text(refusal), .text("SAFE")]))
            let rewrite = try await engine.rewriteAsSendableDetailed(
                ventDraft: "draft", originalSituation: "situation",
                style: testStyle, locale: Locale(identifier: "en_US"))
            XCTAssertEqual(rewrite.provenance, .curated, "refusal shown as a rewrite: \(refusal)")
            XCTAssertNotEqual(rewrite.text, refusal)
        }
    }

    /// A threat phrase is caught without asking the model at all.
    func testRewrite_threatPhrase_returnsCuratedWithoutASecondCall() async throws {
        let threat = "I'll be waiting by your car tonight with a bat if you park there again."
        let backend = FakeFMBackend(fresh: [.text(threat), .text("SAFE")])
        let engine = RoastEngine(fm: backend)
        let rewrite = try await engine.rewriteAsSendableDetailed(
            ventDraft: "draft", originalSituation: "situation",
            style: testStyle, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(rewrite.provenance, .curated)
        XCTAssertNotEqual(rewrite.text, threat)
        let calls = await backend.freshGuardrails.count
        XCTAssertEqual(calls, 1, "the deterministic screen runs before the judge")
    }

    /// Anything from the judge but a plain SAFE — THREAT, UNSAFE, a refusal
    /// sentence, an empty reply, or an error — is the labelled fallback.
    func testRewrite_judgeDoesNotSaySafe_returnsCurated() async throws {
        let message = "Say that to my face again and see what happens."
        for verdict: FakeFMBackend.Step in [.text("THREAT"), .text("UNSAFE"), .text(""),
                                            .text("Unable to work with that request."),
                                            .languageModelLikeError, .foreignNSError] {
            let engine = RoastEngine(fm: FakeFMBackend(fresh: [.text(message), verdict]))
            let rewrite = try await engine.rewriteAsSendableDetailed(
                ventDraft: "draft", originalSituation: "situation",
                style: testStyle, locale: Locale(identifier: "en_US"))
            XCTAssertEqual(rewrite.provenance, .curated, "judge verdict \(verdict) let the text through")
        }
    }

    func testThreatJudgeVerdictParsing() {
        for safe in ["SAFE", "Safe.", " safe\n", "SAFE。"] {
            XCTAssertTrue(RoastEngine.threatJudgeSaysSafe(safe), safe)
        }
        for notSafe in ["THREAT", "UNSAFE", "Not safe", "SAFE THREAT", "", "無法處理該請求。"] {
            XCTAssertFalse(RoastEngine.threatJudgeSaysSafe(notSafe), notSafe)
        }
    }

    func testRewrite_judgeCancellationPropagates() async {
        let engine = RoastEngine(fm: FakeFMBackend(fresh: [.text("You keep taking my parking spot. Stop."), .cancellation]))
        do {
            _ = try await engine.rewriteAsSendableDetailed(
                ventDraft: "draft", originalSituation: "situation",
                style: testStyle, locale: Locale(identifier: "en_US"))
            XCTFail("CancellationError from the judge must propagate")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
    }

    func testRewrite_cancellationPropagates() async {
        let engine = RoastEngine(fm: FakeFMBackend(fresh: [.cancellation]))
        do {
            _ = try await engine.rewriteAsSendableDetailed(
                ventDraft: "draft", originalSituation: "situation",
                style: testStyle, locale: Locale(identifier: "en_US"))
            XCTFail("CancellationError must propagate")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
    }

    // MARK: - The real backend's own mapping

    func testAppleBackendMapsEveryNonCancellationErrorToGeneration() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw XCTSkip("AppleFMBackend needs iOS 26")
        }
        for error: any Error in [StandInLanguageModelError(), NSError(domain: "FoundationModels.LanguageModelError", code: 2)] {
            let mapped = AppleFMBackend.backendError(for: error)
            guard case FMBackendError.generation = mapped else {
                return XCTFail("\(error) mapped to \(mapped), expected .generation")
            }
        }
        XCTAssertEqual(AppleFMBackend.failureCategory(for: StandInLanguageModelError()), .guardrail,
                       "LanguageModelError's errorDescription names the safety guardrails")
        XCTAssertTrue(AppleFMBackend.backendError(for: CancellationError()) is CancellationError)
        #else
        throw XCTSkip("no FoundationModels in this SDK")
        #endif
    }

    private var testStyle: StylePreset {
        StylePreset(
            id: "test", displayKey: "test.name", blurbKey: "test.blurb", icon: "star",
            tier: .free, temperature: 0.8, tags: [], systemPreamble: "Be witty.",
            examples: [], localesSupported: nil)
    }
}

/// Same shape as iOS/macOS 27's `LanguageModelError` (a `LocalizedError`
/// whose description is "May contain unsafe content"), without needing the
/// iOS 27 runtime: the point is that the engine has never heard of the type.
struct StandInLanguageModelError: Error, LocalizedError, CustomStringConvertible, Sendable {
    var description: String { "May contain unsafe content" }
    var errorDescription: String? { "The model's safety guardrails were triggered." }
}

/// Scripted on-device backend. Each call consumes the next step.
actor FakeFMBackend: FMBackend {
    enum Step: Sendable {
        case text(String)
        case languageModelLikeError
        case foreignNSError
        case generation
        case cancellation
    }

    nonisolated let isAvailable: Bool
    private var cachedSteps: [Step]
    private var freshSteps: [Step]
    private(set) var freshGuardrails: [FMGuardrails] = []
    private(set) var freshInstructions: [String] = []

    init(available: Bool = true, cached: [Step] = [], fresh: [Step] = []) {
        self.isAvailable = available
        self.cachedSteps = cached
        self.freshSteps = fresh
    }

    func respondCached(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int,
        sessionKey: String, keepSession: Bool
    ) async throws -> String {
        try play(cachedSteps.isEmpty ? .text("1. scripted") : cachedSteps.removeFirst())
    }

    func respondFresh(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int,
        guardrails: FMGuardrails
    ) async throws -> String {
        freshGuardrails.append(guardrails)
        freshInstructions.append(instructions)
        return try play(freshSteps.isEmpty ? .text("scripted") : freshSteps.removeFirst())
    }

    func reset() async {}

    private func play(_ step: Step) throws -> String {
        switch step {
        case .text(let t): return t
        case .languageModelLikeError: throw StandInLanguageModelError()
        case .foreignNSError: throw NSError(domain: "FoundationModels.LanguageModelError", code: 2)
        case .generation: throw FMBackendError.generation(.guardrail)
        case .cancellation: throw CancellationError()
        }
    }
}

/// Cloud that always fails, so a Vent falls through to the on-device path.
struct FailingCloudVentService: CloudVentService {
    func generate(_ req: CloudVentRequest, authToken: String?) async throws -> CloudVentResponse {
        throw CloudVentError.http(status: 502, body: nil)
    }
}
