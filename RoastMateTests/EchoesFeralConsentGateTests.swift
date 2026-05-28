import XCTest
@testable import RoastMate

final class EchoesFeralConsentGateTests: XCTestCase {

    // MARK: - Casual always uses local, regardless of consent.

    func test_casual_neverCloud_regardlessOfConsent() {
        for consent in CloudConsent.allCases {
            let gate = EchoesFeralConsentGate.decide(
                tone: .casual,
                cloudConfigured: true,
                consent: consent
            )
            XCTAssertEqual(gate, .useLocal,
                           "Casual must short-circuit to useLocal regardless of consent state (\(consent)).")
        }
    }

    // MARK: - Feral routing depends on consent + config.

    func test_feral_cloudConfigured_notAsked_needsConsent() {
        let gate = EchoesFeralConsentGate.decide(
            tone: .feral, cloudConfigured: true, consent: .notAsked
        )
        XCTAssertEqual(gate, .needsConsent)
        XCTAssertFalse(gate.allowsCloud)
    }

    func test_feral_cloudConfigured_granted_proceedsCloud() {
        let gate = EchoesFeralConsentGate.decide(
            tone: .feral, cloudConfigured: true, consent: .granted
        )
        XCTAssertEqual(gate, .proceedCloud)
        XCTAssertTrue(gate.allowsCloud)
    }

    func test_feral_cloudConfigured_denied_usesLocal() {
        let gate = EchoesFeralConsentGate.decide(
            tone: .feral, cloudConfigured: true, consent: .denied
        )
        XCTAssertEqual(gate, .useLocal)
        XCTAssertFalse(gate.allowsCloud)
    }

    func test_feral_cloudNotConfigured_alwaysUsesLocal() {
        for consent in CloudConsent.allCases {
            let gate = EchoesFeralConsentGate.decide(
                tone: .feral, cloudConfigured: false, consent: consent
            )
            XCTAssertEqual(gate, .useLocal,
                           "Feral with cloud unconfigured must fall to useLocal regardless of consent state (\(consent)).")
        }
    }
}
