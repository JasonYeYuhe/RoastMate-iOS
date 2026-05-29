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
}
