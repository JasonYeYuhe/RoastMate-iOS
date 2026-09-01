import XCTest
@testable import RoastMate

/// Pillar A: share artifact. Pins the v1.3.1 contract — a share card carries
/// the sendable line and nothing else, and a private vent draft has no share
/// affordance at all.
final class ShareCardTests: XCTestCase {

    // MARK: - Redactor
    //
    // Retained for v1.4 Track B.2, which will expand this (NER + Chinese
    // patterns) and run it on the sendable text. It has no production call
    // site today — see Redactor.swift.

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

    // MARK: - Privacy invariant: the card renders the sendable line ONLY
    //
    // These are the regression guards for the v1.3.1 purge. `ShareCardContent`
    // deliberately has no vent field, so "the card can't carry the vent" is
    // enforced by the type system; what these pin is that the rendered content
    // is exactly the sendable text and is not derived from anything else.

    func testContentCarriesOnlyTheSendableLine() {
        let c = ShareCardContent(styleName: "Sharp", sentText: "Noted, and corrected.")
        XCTAssertEqual(c.sentText, "Noted, and corrected.")
        XCTAssertEqual(c.styleName, "Sharp")
    }

    func testContentIsValueEqualByRenderedText() {
        // Guards the composer's render key: two contents that render the same
        // pixels must compare equal, so a re-render isn't silently skipped.
        let a = ShareCardContent(styleName: "Sharp", sentText: "same")
        let b = ShareCardContent(styleName: "Sharp", sentText: "same")
        let c = ShareCardContent(styleName: "Sharp", sentText: "different")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testStyleNameIsOptional() {
        let c = ShareCardContent(styleName: nil, sentText: "x")
        XCTAssertNil(c.styleName)
        XCTAssertEqual(c.sentText, "x")
    }

    // MARK: - Format

    func testExportFormatsAreExactPixelSizes() {
        // ImageRenderer exports at these exact sizes; 小红书/IG 4:5 and 抖音 9:16.
        XCTAssertEqual(ShareCardFormat.portrait45.pixelSize, CGSize(width: 1080, height: 1350))
        XCTAssertEqual(ShareCardFormat.story916.pixelSize, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(ShareCardFormat.allCases.count, 2)
    }
}
