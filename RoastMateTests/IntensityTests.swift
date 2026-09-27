import XCTest
@testable import RoastMate

final class IntensityTests: XCTestCase {
    func testRequiresProPolicy() {
        XCTAssertFalse(Intensity.calm.requiresPro)
        XCTAssertFalse(Intensity.sharp.requiresPro)
        XCTAssertTrue(Intensity.savage.requiresPro)
        XCTAssertTrue(Intensity.feral.requiresPro)
        XCTAssertFalse(Intensity.vent.requiresPro, "v1.6: Vent is free — the app's namesake")
    }

    func testPrivateDraftPolicy() {
        XCTAssertFalse(Intensity.calm.isPrivateDraft)
        XCTAssertFalse(Intensity.sharp.isPrivateDraft)
        XCTAssertFalse(Intensity.savage.isPrivateDraft)
        XCTAssertTrue(Intensity.feral.isPrivateDraft)
        XCTAssertTrue(Intensity.vent.isPrivateDraft)
    }

    func testLegacyDefaultIsSharp() {
        XCTAssertEqual(Intensity.legacyDefault, .sharp)
    }

    func testGeneratedRoastKindLegacyDefaultIsNormalRoast() {
        XCTAssertEqual(GeneratedRoastKind.legacyDefault, .normalRoast)
    }
}
