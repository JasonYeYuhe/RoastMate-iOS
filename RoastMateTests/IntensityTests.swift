import XCTest
@testable import RoastMate

final class IntensityTests: XCTestCase {
    func testRequiresProPolicy() {
        XCTAssertFalse(Intensity.calm.requiresPro)
        XCTAssertFalse(Intensity.sharp.requiresPro)
        XCTAssertTrue(Intensity.savage.requiresPro)
        XCTAssertTrue(Intensity.feral.requiresPro)
        XCTAssertTrue(Intensity.vent.requiresPro)
    }

    func testOnlyVentIsPrivateDraft() {
        // Feral output is sendable text — it must not be flagged as a
        // private vent draft, otherwise the UI hides it behind the
        // "for yourself only" curtain.
        XCTAssertFalse(Intensity.feral.isVent)
        XCTAssertTrue(Intensity.vent.isVent)
    }

    func testLegacyDefaultIsSharp() {
        XCTAssertEqual(Intensity.legacyDefault, .sharp)
    }

    func testGeneratedRoastKindLegacyDefaultIsNormalRoast() {
        XCTAssertEqual(GeneratedRoastKind.legacyDefault, .normalRoast)
    }
}
