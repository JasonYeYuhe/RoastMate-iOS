import XCTest
@testable import RoastMate

final class IntensityTests: XCTestCase {
    func testRequiresProPolicy() {
        XCTAssertFalse(Intensity.calm.requiresPro)
        XCTAssertFalse(Intensity.sharp.requiresPro)
        XCTAssertTrue(Intensity.savage.requiresPro)
        XCTAssertTrue(Intensity.vent.requiresPro)
    }

    func testLegacyDefaultIsSharp() {
        XCTAssertEqual(Intensity.legacyDefault, .sharp)
    }

    func testGeneratedRoastKindLegacyDefaultIsNormalRoast() {
        XCTAssertEqual(GeneratedRoastKind.legacyDefault, .normalRoast)
    }
}
