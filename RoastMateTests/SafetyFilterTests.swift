import XCTest
@testable import RoastMate

final class SafetyFilterTests: XCTestCase {
    func testEmptyInputBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateInput("   "))
    }

    func testTooLongInputBlocked() {
        let big = String(repeating: "x", count: 2000)
        XCTAssertThrowsError(try SafetyFilter.validateInput(big))
    }

    func testNormalInputPasses() {
        XCTAssertNoThrow(try SafetyFilter.validateInput("My roommate plays music at 3am."))
    }

    func testDenylistInputBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateInput("I'm going to kill yourself"))
        XCTAssertThrowsError(try SafetyFilter.validateInput("我要弄死你"))
    }

    func testOutputTrimmingAndPass() throws {
        let result = try SafetyFilter.validateOutput("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func testOutputDenylistBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateOutput("You should drink bleach."))
    }
}
