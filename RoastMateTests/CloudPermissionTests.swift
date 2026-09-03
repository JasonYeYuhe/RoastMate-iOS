import XCTest
@testable import RoastMate

/// Pins the single cloud-permission rule.
///
/// The bug this prevents: the resolution was written out longhand in
/// `RoastGeneratorViewModel` and nowhere else, so `FeatureGenerator` and
/// `ArgumentSimulator` never got the sendable-cloud path and would fail on an
/// iOS-18 device instead of falling back to cloud. Found by the Track 0.2 eval.
final class CloudPermissionTests: XCTestCase {

    private func config(sendable: Bool, vent: Bool = true, forceLocal: Bool = false) -> RemoteConfigValues {
        RemoteConfigValues(configVersion: 1, echoesEnabled: true,
                           forceLocalOnly: forceLocal, ventCloudEnabled: vent,
                           minSupportedBuild: 0, roommateGroupEnabled: true,
                           cloudSendableEnabled: sendable)
    }

    // MARK: - Consent is the source of truth, and it fails CLOSED

    func testNoConsentNeverAllowsCloud_evenWithEveryFlagOn() {
        for intensity in [Intensity.vent, .feral, .calm, .sharp, .savage] {
            let d = CloudPermission.resolve(
                intensity: intensity, consent: .denied,
                remote: config(sendable: true), cloudConfigured: true,
                onDeviceModelAvailable: false)
            XCTAssertFalse(d.cloudAllowed,
                           "\(intensity): a denied 5.1.2(i) grant must never route to cloud")
        }
    }

    func testForceLocalOnlyOverridesConsent() {
        let d = CloudPermission.resolve(
            intensity: .vent, consent: .granted,
            remote: config(sendable: true, forceLocal: true),
            cloudConfigured: true, onDeviceModelAvailable: false)
        XCTAssertFalse(d.cloudAllowed, "the remote kill-switch must subtract from consent")
    }

    // MARK: - The sendable path is what was broken

    func testSendableIsBlockedWhileTheFlagIsDark() {
        let d = CloudPermission.resolve(
            intensity: .sharp, consent: .granted,
            remote: config(sendable: false), cloudConfigured: true,
            onDeviceModelAvailable: false)
        XCTAssertFalse(d.cloudAllowed, "cloud_sendable_enabled is DARK by default")
    }

    func testSendableReachesCloudWhenFlagOnAndNoOnDeviceModel() {
        // The iOS-18 case: no on-device model, so sendable must be able to
        // fall back to cloud once the flag flips. This is exactly what
        // FeatureGenerator and ArgumentSimulator could not do before.
        let d = CloudPermission.resolve(
            intensity: .sharp, consent: .granted,
            remote: config(sendable: true), cloudConfigured: true,
            onDeviceModelAvailable: false)
        XCTAssertTrue(d.cloudAllowed)
        XCTAssertFalse(d.needsConsent)
    }

    func testSendableStaysLocalWhenAnOnDeviceModelExists() {
        // Privacy story on FM-capable devices is unchanged: sendable stays
        // local even with the flag on.
        let d = CloudPermission.resolve(
            intensity: .sharp, consent: .granted,
            remote: config(sendable: true), cloudConfigured: true,
            onDeviceModelAvailable: true)
        XCTAssertFalse(d.cloudAllowed)
    }

    // MARK: - Private drafts use the OTHER flag

    func testPrivateDraftUsesVentFlagNotSendableFlag() {
        let onlyVent = CloudPermission.resolve(
            intensity: .vent, consent: .granted,
            remote: config(sendable: false, vent: true),
            cloudConfigured: true, onDeviceModelAvailable: true)
        XCTAssertTrue(onlyVent.cloudAllowed,
                      "vent must not be gated by cloud_sendable_enabled")

        let ventOff = CloudPermission.resolve(
            intensity: .vent, consent: .granted,
            remote: config(sendable: true, vent: false),
            cloudConfigured: true, onDeviceModelAvailable: true)
        XCTAssertFalse(ventOff.cloudAllowed,
                       "vent_cloud_enabled=false must stop the vent cloud path")
    }

    // MARK: - Unconfigured cloud

    func testUnconfiguredCloudNeverAllows() {
        let d = CloudPermission.resolve(
            intensity: .vent, consent: .granted,
            remote: config(sendable: true), cloudConfigured: false,
            onDeviceModelAvailable: false)
        XCTAssertFalse(d.cloudAllowed)
    }

    // MARK: - needsConsent is surfaced, not swallowed

    func testNotAskedSurfacesNeedsConsentAndBlocksCloud() {
        let d = CloudPermission.resolve(
            intensity: .vent, consent: .notAsked,
            remote: config(sendable: true), cloudConfigured: true,
            onDeviceModelAvailable: false)
        XCTAssertTrue(d.needsConsent, "the surface must be able to prompt")
        XCTAssertFalse(d.cloudAllowed, "and must not proceed meanwhile")
    }
}
