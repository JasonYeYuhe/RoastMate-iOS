import XCTest
@testable import RoastMate

/// Voice Venting. Pins the privacy-load-bearing gate logic: a locale
/// with no on-device model HIDES voice (we never fall back to a cloud
/// recognizer), and the affordance only goes "ready" when both
/// permissions are granted.
final class VoiceVentTests: XCTestCase {

    func testLocaleUnsupportedHidesVoiceEntirely() {
        // No on-device model for this locale → voice must not appear at
        // all (NO silent server fallback).
        let g = VoiceVentGate.decide(localeSupported: false, mic: .granted, speech: .granted)
        XCTAssertEqual(g, .localeUnsupported)
        XCTAssertFalse(g.showsAffordance, "Unsupported locale must hide the mic affordance")
    }

    func testReadyOnlyWhenLocaleSupportedAndBothGranted() {
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: true, mic: .granted, speech: .granted),
            .ready)
    }

    func testUndeterminedAsksForPermission() {
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: true, mic: .notDetermined, speech: .granted),
            .needsPermission)
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: true, mic: .granted, speech: .notDetermined),
            .needsPermission)
    }

    func testAnyDenialIsDenied() {
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: true, mic: .denied, speech: .granted),
            .denied)
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: true, mic: .granted, speech: .denied),
            .denied)
    }

    func testUnsupportedLocaleWinsOverDenied() {
        // Locale support is checked first: if there's no model, it
        // doesn't matter what permissions say — voice is simply absent.
        XCTAssertEqual(
            VoiceVentGate.decide(localeSupported: false, mic: .denied, speech: .denied),
            .localeUnsupported)
    }

    func testAffordanceShownForEveryStateExceptUnsupported() {
        XCTAssertTrue(VoiceVentGate.ready.showsAffordance)
        XCTAssertTrue(VoiceVentGate.needsPermission.showsAffordance)
        XCTAssertTrue(VoiceVentGate.denied.showsAffordance)
        XCTAssertFalse(VoiceVentGate.localeUnsupported.showsAffordance)
    }

    // MARK: - Voice input inherits the safety net (parity with typed)

    /// Voice only pre-fills the vent box; the transcript then goes
    /// through the SAME generate() path as typed text, whose first step
    /// is `SafetyFilter.crisisSignal`. Pin that a representative spoken
    /// hard self-harm transcript is classified `.hard` — so the voice
    /// path provably cannot bypass the crisis handoff. (Asserted at the
    /// Shared layer; the hostless test bundle can't link app-target
    /// view models — codebase convention.)
    func testSpokenHardSelfHarmIsCaughtByTheSharedCrisisPreflight() {
        XCTAssertEqual(SafetyFilter.crisisSignal("I want to kill myself"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("我不想活了"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("My coworker keeps overriding my work"), .none)
    }
}
