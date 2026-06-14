import XCTest
@testable import RoastMate

/// 5.1.2(i) consent gate — pure decision matrix + the UserSettings
/// resolution (incl. legacy migration) + the engine defense-in-depth
/// default. The marquee compliance invariant: a fresh/legacy install is
/// NEVER auto-opted-in, and no path clouds before an explicit grant.
final class CloudConsentGateTests: XCTestCase {

    // MARK: Pure gate matrix

    func testNotAskedPrivateDraftConfigured_NeedsConsent() {
        XCTAssertEqual(
            CloudConsentGate.decide(isPrivateDraft: true, cloudConfigured: true, consent: .notAsked),
            .needsConsent)
    }

    func testGrantedPrivateDraftConfigured_ProceedCloud() {
        let g = CloudConsentGate.decide(isPrivateDraft: true, cloudConfigured: true, consent: .granted)
        XCTAssertEqual(g, .proceedCloud)
        XCTAssertTrue(g.allowsCloud)
    }

    func testDeniedPrivateDraft_UseLocal() {
        let g = CloudConsentGate.decide(isPrivateDraft: true, cloudConfigured: true, consent: .denied)
        XCTAssertEqual(g, .useLocal)
        XCTAssertFalse(g.allowsCloud)
    }

    func testSendableIntensityNeverPromptsEvenWhenNotAsked() {
        // Sharp/Calm/Savage on an FM-capable device (the defaults) → no cloud,
        // no prompt. The two new params default to (onDevice=true, dark=false).
        XCTAssertEqual(
            CloudConsentGate.decide(isPrivateDraft: false, cloudConfigured: true, consent: .notAsked),
            .useLocal)
    }

    // MARK: Sendable cloud (iOS 18 no-FM path, increment 4)

    func testSendableNoFM_FlagOn_NotAsked_NeedsConsent() {
        // iOS 18 (no on-device model) + DARK flag flipped on + never asked →
        // the gate must PROMPT before any sendable text reaches the cloud.
        XCTAssertEqual(
            CloudConsentGate.decide(isPrivateDraft: false, cloudConfigured: true, consent: .notAsked,
                                    onDeviceModelAvailable: false, cloudSendableEnabled: true),
            .needsConsent)
    }

    func testSendableNoFM_FlagOn_Granted_ProceedCloud() {
        let g = CloudConsentGate.decide(isPrivateDraft: false, cloudConfigured: true, consent: .granted,
                                        onDeviceModelAvailable: false, cloudSendableEnabled: true)
        XCTAssertEqual(g, .proceedCloud)
        XCTAssertTrue(g.allowsCloud)
    }

    func testSendableNoFM_FlagOff_UseLocal() {
        // DARK by default: even on a no-FM device with consent, sendable stays
        // local until `cloud_sendable_enabled` is flipped on remotely.
        let g = CloudConsentGate.decide(isPrivateDraft: false, cloudConfigured: true, consent: .granted,
                                        onDeviceModelAvailable: false, cloudSendableEnabled: false)
        XCTAssertEqual(g, .useLocal)
    }

    func testSendableWithFMAvailable_UseLocal_EvenIfFlagOnAndGranted() {
        // On an FM-capable device, sendable always stays on-device — the cloud
        // path is only the fallback for devices that have no local model.
        let g = CloudConsentGate.decide(isPrivateDraft: false, cloudConfigured: true, consent: .granted,
                                        onDeviceModelAvailable: true, cloudSendableEnabled: true)
        XCTAssertEqual(g, .useLocal)
    }

    func testNotConfiguredNeverClouds_EvenIfGranted() {
        // Pre-deploy / forked build: no Worker URL → always local.
        let g = CloudConsentGate.decide(isPrivateDraft: true, cloudConfigured: false, consent: .granted)
        XCTAssertEqual(g, .useLocal)
        XCTAssertFalse(g.allowsCloud)
    }

    // MARK: UserSettings consent resolution + legacy migration

    func testFreshInstallIsNotAsked_NotAutoOptedIn() {
        let s = UserSettings()
        XCTAssertEqual(s.cloudConsent, .notAsked,
                       "A fresh install must NOT be auto-opted-in to third-party AI (5.1.2(i)).")
        XCTAssertFalse(s.cloudVentEnabled,
                       "cloudVentEnabled must be false until consent is explicitly granted.")
    }

    func testLegacyNilOrTrueRaw_IsNotAsked_OldAutoOnNotCarried() {
        let s = UserSettings()
        s.cloudAIConsentRaw = nil
        s.cloudVentEnabledRaw = true   // the old "auto opted-in" reading
        XCTAssertEqual(s.cloudConsent, .notAsked,
                       "Legacy nil/true must resolve to notAsked — the pre-5.1.2(i) auto-on default is intentionally dropped.")
    }

    func testLegacyExplicitOptOut_IsHonoredAsDenied() {
        let s = UserSettings()
        s.cloudAIConsentRaw = nil
        s.cloudVentEnabledRaw = false  // user previously turned the toggle OFF
        XCTAssertEqual(s.cloudConsent, .denied,
                       "A prior explicit Settings opt-out must be honored as denied (no re-nag).")
    }

    func testSettingConsentGrantedUpdatesBridgeAndMirror() {
        let s = UserSettings()
        s.cloudConsent = .granted
        XCTAssertTrue(s.cloudVentEnabled)
        XCTAssertEqual(s.cloudAIConsentRaw, "granted")
        XCTAssertEqual(s.cloudVentEnabledRaw, true, "Legacy mirror stays coherent for old readers.")
    }

    func testCloudVentEnabledFalseBridgesToDenied() {
        let s = UserSettings()
        s.cloudVentEnabled = false
        XCTAssertEqual(s.cloudConsent, .denied)
        XCTAssertFalse(s.cloudVentEnabled)
    }

    // MARK: Engine defense-in-depth default

    func testEngineDefaultDoesNotCloud_WhenCloudVentEnabledOmitted() async throws {
        // Any caller that forgets to pass a consent-resolved value must
        // NOT silently route Vent text to the third-party cloud.
        let recorder = RecordingCloudVentService(returning: "should not be called")
        _ = try? await RoastEngine.shared.generate(
            situation: "我室友每天凌晨两点打游戏。",
            style: Self.testStyle,
            locale: Locale(identifier: "zh-Hans"),
            variantCount: 1,
            intensity: .vent,
            cloudClient: recorder      // NOTE: cloudVentEnabled intentionally omitted
        )
        XCTAssertEqual(recorder.calls.count, 0,
                       "Engine default must be cloud-OFF (5.1.2(i) defense-in-depth).")
    }

    private static var testStyle: StylePreset {
        StylePreset(
            id: "test",
            displayKey: "test.name",
            blurbKey: "test.blurb",
            icon: "star",
            tier: .free,
            temperature: 0.8,
            tags: [],
            systemPreamble: "Be witty.",
            examples: [],
            localesSupported: nil
        )
    }
}
