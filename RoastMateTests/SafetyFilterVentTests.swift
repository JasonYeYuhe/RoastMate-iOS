import XCTest
@testable import RoastMate

final class SafetyFilterVentTests: XCTestCase {
    func testVentOutputBlocksExplicitViolenceHardRail() {
        XCTAssertThrowsError(try SafetyFilter.validateVentOutput("I want to shoot you for this."))
        XCTAssertThrowsError(try SafetyFilter.validateVentOutput("这种人真想让他去死。"))
    }

    func testVentOutputAllowsMildProfanity() throws {
        XCTAssertEqual(
            try SafetyFilter.validateVentOutput("This is damn ridiculous."),
            "This is damn ridiculous."
        )
        XCTAssertEqual(
            try SafetyFilter.validateVentOutput("这就是一堆屁话。"),
            "这就是一堆屁话。"
        )
    }

    func testStrictOutputStillBlocksHardDenylist() {
        XCTAssertThrowsError(try SafetyFilter.validateOutput("You should drink bleach."))
    }
}
