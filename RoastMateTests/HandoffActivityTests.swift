import XCTest
@testable import RoastMate

final class HandoffActivityTests: XCTestCase {
    func testPayloadRoundTrip() {
        let payload = HandoffActivity.payload(
            situation: "Roommate plays games at 2am",
            styleId: "high_eq",
            mode: .roast,
            locale: Locale(identifier: "zh-Hans")
        )
        let parsed = HandoffActivity.ContinuationPayload(from: payload)
        XCTAssertEqual(parsed?.situation, "Roommate plays games at 2am")
        XCTAssertEqual(parsed?.styleId, "high_eq")
        XCTAssertEqual(parsed?.mode, .roast)
    }

    func testEmptyPayloadRejected() {
        XCTAssertNil(HandoffActivity.ContinuationPayload(from: [:]))
        XCTAssertNil(HandoffActivity.ContinuationPayload(from: nil))
    }

    func testMalformedModeRejected() {
        let bad: [AnyHashable: Any] = [
            HandoffActivity.UserInfoKey.situation: "x",
            HandoffActivity.UserInfoKey.styleId: "high_eq",
            HandoffActivity.UserInfoKey.modeRaw: "not_a_mode"
        ]
        XCTAssertNil(HandoffActivity.ContinuationPayload(from: bad))
    }
}
