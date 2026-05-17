import XCTest
@testable import RoastMate

/// Pillar A: share artifact. Pins the load-bearing privacy invariants
/// (vent obscured by default; PII stripped before any opt-in reveal).
final class ShareCardTests: XCTestCase {

    // MARK: - Redactor

    func testRedactsEmail() {
        let out = Redactor.redact("reach me at a.b+x@mail.example.com please")
        XCTAssertFalse(out.contains("a.b+x@mail.example.com"))
        XCTAssertTrue(out.contains("[email]"))
    }

    func testRedactsURLAndHandleAndPhone() {
        XCTAssertTrue(Redactor.redact("see https://evil.example/x now").contains("[link]"))
        let h = Redactor.redact("blame @john_doe lol")
        XCTAssertFalse(h.contains("@john_doe"))
        let p = Redactor.redact("call +1 (415) 555-2671 tonight")
        XCTAssertFalse(p.contains("2671"))
        XCTAssertTrue(p.contains("[number]"))
    }

    func testKeepsOrdinaryTextIntact() {
        let s = "my boss took credit for my work again"
        XCTAssertEqual(Redactor.redact(s), s)
    }

    // MARK: - Privacy invariant

    func testVentObscuredByDefault() {
        let c = ShareCardContent(styleName: "Sharp",
                                 sentText: "Noted, and corrected.",
                                 ventText: "raw private rage here")
        XCTAssertFalse(c.revealVent, "vent must be obscured unless explicitly revealed")
        XCTAssertTrue(c.hasVentPairing)
    }

    func testNoPairingWhenVentEmpty() {
        let c = ShareCardContent(styleName: nil, sentText: "x", ventText: "   ")
        XCTAssertFalse(c.hasVentPairing)
    }

    // MARK: - Vent↔Sent pairing resolution

    func testPairingResolvesSourceVent() {
        let vent = GeneratedRoast(text: "the raw vent", styleId: "high_eq",
                                  kind: .ventDraft, sourceIntensity: .vent)
        let sendable = GeneratedRoast(text: "the polished line", styleId: "high_eq",
                                      kind: .sendableReply, sourceVentDraftId: vent.id)
        let pool = [vent, sendable]
        XCTAssertEqual(ShareCardPairing.ventText(for: sendable, in: pool), "the raw vent")

        let normal = GeneratedRoast(text: "plain", styleId: "high_eq", kind: .normalRoast)
        XCTAssertNil(ShareCardPairing.ventText(for: normal, in: pool))
    }
}
