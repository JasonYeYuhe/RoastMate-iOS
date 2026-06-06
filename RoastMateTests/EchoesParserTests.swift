import XCTest
@testable import RoastMate

final class EchoesParserTests: XCTestCase {

    // MARK: - Valid output

    func test_parsesCanonicalTwoVoiceTranscript() {
        let raw = """
        [VALIDATE/A] 你被惹到这种程度完全合理。
        [ESCALATE/B] 这事换我我能气一个礼拜。
        [DEESCALATE/B] 但你别因为这事毁今晚。
        [BRIDGE/A:savage] 把这事用 Savage 给他怼回去 →
        """
        let result = EchoesParser.parse(raw)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 4)
        XCTAssertEqual(result?.first?.role, .validate)
        XCTAssertEqual(result?.last?.role, .bridge)
        XCTAssertEqual(result?.last?.bridgeIntensity, .savage)
    }

    func test_parsesOneVoiceTranscript() {
        let raw = """
        [VALIDATE/A] 完全理解。
        [ESCALATE/A] 这事儿真的过分。
        [DEESCALATE/A] 别让他毁你今晚。
        [BRIDGE/A:sharp] 用 Sharp 回他一句 →
        """
        let result = EchoesParser.parse(raw)
        XCTAssertEqual(result?.count, 4)
        XCTAssertTrue(result?.allSatisfy { $0.echoIndex == 0 } ?? false)
        XCTAssertEqual(result?.last?.bridgeIntensity, .sharp)
    }

    func test_parsesSixMessageMaxBoundary() {
        let raw = """
        [VALIDATE/A] 你气成这样合理。
        [ESCALATE/B] 这事我也会爆炸。
        [ESCALATE/A] 而且不是第一次。
        [ESCALATE/B] 我都替你不爽。
        [DEESCALATE/B] 但你别毁今晚。
        [BRIDGE/A:savage] Savage 回他 →
        """
        XCTAssertEqual(EchoesParser.parse(raw)?.count, 6)
    }

    // MARK: - Invalid output → returns nil (caller falls back)

    func test_rejectsCountBelowFour() {
        let raw = """
        [VALIDATE/A] 完全理解。
        [DEESCALATE/A] 别气了。
        [BRIDGE/A:sharp] Sharp 回他 →
        """
        XCTAssertNil(EchoesParser.parse(raw), "3 messages must be rejected — minimum is 4.")
    }

    func test_rejectsCountAboveSix() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/A] 三。
        [ESCALATE/B] 四。
        [ESCALATE/A] 五。
        [DEESCALATE/B] 六。
        [BRIDGE/A:savage] Savage 七 →
        """
        XCTAssertNil(EchoesParser.parse(raw), "7 messages must be rejected — maximum is 6.")
    }

    func test_rejectsLastNotBridge() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [DEESCALATE/B] 三。
        [ESCALATE/A] 四。
        """
        XCTAssertNil(EchoesParser.parse(raw), "Last must be a BRIDGE.")
    }

    func test_rejectsMissingValidate() {
        let raw = """
        [ESCALATE/A] 一。
        [ESCALATE/B] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A:savage] Savage →
        """
        XCTAssertNil(EchoesParser.parse(raw), "Must contain at least one VALIDATE.")
    }

    func test_rejectsMissingDeescalate() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/A] 三。
        [BRIDGE/A:savage] Savage →
        """
        XCTAssertNil(EchoesParser.parse(raw), "Must contain at least one DEESCALATE — Mirror Shock protection.")
    }

    func test_rejectsUnknownRole() {
        let raw = """
        [VALIDATE/A] 一。
        [TAUNT/B] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A:savage] Savage →
        """
        XCTAssertNil(EchoesParser.parse(raw), "Unknown role must invalidate parse.")
    }

    func test_rejectsUnknownEchoIndex() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/C] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A:savage] Savage →
        """
        XCTAssertNil(EchoesParser.parse(raw), "Echo index C is not valid (only A/B in v1).")
    }

    func test_rejectsOverlongMessage() {
        // Hard cap is 100 chars per message. 110-char message must drop.
        let longText = String(repeating: "x", count: 110)
        let raw = """
        [VALIDATE/A] \(longText)
        [ESCALATE/B] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A:savage] Savage →
        """
        // After the over-long line is dropped, only 3 valid messages remain → count check fails.
        XCTAssertNil(EchoesParser.parse(raw))
    }

    // MARK: - Bridge intensity hint extraction

    func test_bridgeWithoutIntensityHintHasNilBridgeIntensity() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A] Savage →
        """
        let bridge = EchoesParser.parse(raw)?.last
        XCTAssertEqual(bridge?.role, .bridge)
        XCTAssertNil(bridge?.bridgeIntensity)
    }

    func test_bridgeWithUnknownIntensityHintDefaultsToSavage() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [DEESCALATE/B] 三。
        [BRIDGE/A:nuke] Savage →
        """
        let bridge = EchoesParser.parse(raw)?.last
        XCTAssertEqual(bridge?.bridgeIntensity, .savage,
                       "Unknown intensity hint must fall back to .savage (most-conservative default).")
    }

    // MARK: - Output safety filter (EchoesEngine.safetyFilter — Codex pre-ship audit 2026-05-29)

    func test_safetyFilter_rejectsHardRailOutput_dropsToFallback() {
        // Structurally valid, but a line carries a self-harm hard-rail term.
        // The parser accepts it (structure only); the OUTPUT safety pass must
        // reject the whole transcript so the caller serves the curated
        // fallback instead of rendering unsafe model output.
        let raw = """
        [VALIDATE/A] 你被气到完全合理。
        [ESCALATE/B] 这种人真的该去死。
        [DEESCALATE/B] 但你别因为这事毁今晚。
        [BRIDGE/A] 用狠话怼回去 →
        """
        let parsed = EchoesParser.parse(raw)
        XCTAssertNotNil(parsed, "Structurally valid → parser accepts it.")
        XCTAssertNil(EchoesEngine.safetyFilter(parsed!, tone: .feral),
                     "A self-harm hard-rail line in MODEL OUTPUT must drop the whole transcript (→ curated fallback).")
    }

    func test_safetyFilter_passesCleanOutput_andInjectsBridgeIntensity() {
        let raw = """
        [VALIDATE/A] 你被气到完全合理。
        [ESCALATE/B] 这事换谁都火大。
        [DEESCALATE/B] 但你别因为这事毁今晚。
        [BRIDGE/A] 用狠话怼回去 →
        """
        let parsed = EchoesParser.parse(raw)!
        let safe = EchoesEngine.safetyFilter(parsed, tone: .feral)
        XCTAssertNotNil(safe, "Clean venting output must pass the safety filter.")
        XCTAssertEqual(safe?.count, parsed.count)
        XCTAssertEqual(safe?.last?.role, .bridge)
        XCTAssertEqual(safe?.last?.bridgeIntensity, EchoTone.feral.bridgeIntensity,
                       "A parsed bridge with no intensity suffix must get the tone-derived intensity injected.")
    }

    // MARK: - Roommate-group scene (3 voices, 8–10 msgs, strict)

    /// Canonical valid roommate transcript: A/B/C each speak ≥2×,
    /// validate first, a deescalate (reframe) before a single bridge last.
    static let validRoommate = """
    [VALIDATE/A] 这锅凭什么甩你头上。
    [ESCALATE/B] 他甩锅的速度能去练铁饼。
    [ESCALATE/A] 就是，这事真不赖你。
    [ESCALATE/B] 脸皮厚到能当防弹衣。
    [ESCALATE/C] 行，气也帮你撒到位了。
    [ESCALATE/B] 反正他一句占理的都没有。
    [DEESCALATE/C] 别替他背锅，把时间线留好。
    [BRIDGE/C] 与其干生气不如把话甩回去 →
    """

    func test_roommate_parsesValidEightMessageTranscript() {
        let result = EchoesParser.parse(Self.validRoommate, scene: .roommateGroup)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 8)
        XCTAssertEqual(result?.first?.role, .validate)
        XCTAssertEqual(result?.last?.role, .bridge)
        // C (index 2) present → proves the third voice parsed.
        XCTAssertTrue(result?.contains { $0.echoIndex == 2 } ?? false)
    }

    func test_roommate_parsesTenMessageBoundary() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/C] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [ESCALATE/C] 六。
        [ESCALATE/A] 七。
        [ESCALATE/B] 八。
        [DEESCALATE/C] 九。
        [BRIDGE/C] 十 →
        """
        XCTAssertEqual(EchoesParser.parse(raw, scene: .roommateGroup)?.count, 10)
    }

    func test_roommate_rejectsBelowEight() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/C] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [DEESCALATE/C] 六。
        [BRIDGE/C] 七 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "7 messages — roommate minimum is 8.")
    }

    func test_roommate_rejectsAboveTen() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/C] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [ESCALATE/C] 六。
        [ESCALATE/A] 七。
        [ESCALATE/B] 八。
        [ESCALATE/C] 九。
        [DEESCALATE/A] 十。
        [BRIDGE/C] 十一 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "11 messages — roommate maximum is 10.")
    }

    func test_roommate_rejectsVoiceSpeakingOnce() {
        // C speaks exactly once → not a group → reject.
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/A] 三。
        [ESCALATE/B] 四。
        [ESCALATE/A] 五。
        [ESCALATE/B] 六。
        [DEESCALATE/C] 七。
        [BRIDGE/A] 八 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "Every voice (A/B/C) must speak ≥2×.")
    }

    func test_roommate_rejectsLastNotBridge() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/C] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [DEESCALATE/C] 六。
        [BRIDGE/C] 七 →
        [ESCALATE/B] 八。
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "Last must be a BRIDGE.")
    }

    func test_roommate_rejectsMissingDeescalateReframe() {
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/C] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [ESCALATE/C] 六。
        [ESCALATE/A] 七。
        [BRIDGE/C] 八 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "Must contain a DEESCALATE (reframe).")
    }

    func test_roommate_rejectsTwoBridges() {
        let raw = """
        [VALIDATE/A] 一。
        [BRIDGE/B] 中间桥 →
        [ESCALATE/A] 三。
        [ESCALATE/B] 四。
        [ESCALATE/C] 五。
        [ESCALATE/C] 六。
        [DEESCALATE/C] 七。
        [BRIDGE/A] 八 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "Exactly one BRIDGE allowed.")
    }

    func test_roommate_rejectsOutOfRangeIndexD_strict() {
        // A malformed tagged line (index D) must HARD-reject the whole
        // transcript in strict roommate mode — not silently drop the line.
        let raw = """
        [VALIDATE/A] 一。
        [ESCALATE/B] 二。
        [ESCALATE/D] 三。
        [ESCALATE/A] 四。
        [ESCALATE/B] 五。
        [ESCALATE/C] 六。
        [DEESCALATE/C] 七。
        [BRIDGE/C] 八 →
        """
        XCTAssertNil(EchoesParser.parse(raw, scene: .roommateGroup), "Index D must reject the whole roommate transcript.")
    }

    func test_classic_defaultStillRejectsVoiceC() {
        // Regression: the default (classic) contract is unchanged — C is
        // not a valid voice there, so the roommate transcript must NOT
        // parse under the classic contract.
        XCTAssertNil(EchoesParser.parse(Self.validRoommate),
                     "Roommate transcript must not parse under the classic contract.")
    }
}
