import XCTest
@testable import RoastMate

/// Pins the single cloud-permission rule.
///
/// The bug this prevents: the resolution was written out longhand in
/// `RoastGeneratorViewModel` and nowhere else, so `FeatureGenerator` and
/// `ArgumentSimulator` never got the sendable-cloud path and would fail on an
/// iOS-18 device instead of falling back to cloud. Found by the Track 0.2 eval.
final class CloudPermissionTests: XCTestCase {

    private func config(sendable: Bool, vent: Bool = true, forceLocal: Bool = false,
                        locales: [String]? = nil) -> RemoteConfigValues {
        RemoteConfigValues(configVersion: 1, echoesEnabled: true,
                           forceLocalOnly: forceLocal, ventCloudEnabled: vent,
                           minSupportedBuild: 0, roommateGroupEnabled: true,
                           cloudSendableEnabled: sendable,
                           cloudSendableLocales: locales)
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

    // MARK: - Per-locale narrowing (Track 0.2)
    //
    // zh-Hans/ja/en cleared the sendable quality gate; zh-Hant did not. Without
    // this, the only choices were "block all four" or "ship known-degraded
    // output to zh-Hant readers".

    func testLocaleListNarrowsTheSendablePath() {
        let cfg = config(sendable: true, locales: ["zh-Hans", "ja", "en"])
        func allowed(_ id: String) -> Bool {
            CloudPermission.resolve(intensity: .sharp, consent: .granted,
                                    locale: Locale(identifier: id), remote: cfg,
                                    cloudConfigured: true,
                                    onDeviceModelAvailable: false).cloudAllowed
        }
        XCTAssertTrue(allowed("zh-Hans"))
        XCTAssertTrue(allowed("ja_JP"))
        XCTAssertTrue(allowed("en_US"))
        XCTAssertFalse(allowed("zh-Hant"), "zh-Hant failed the 0.2 gate and must stay off")
        XCTAssertFalse(allowed("zh-Hant-TW"))
    }

    func testAbsentLocaleListMeansAllLocales() {
        // Back-compat: an existing config with no list behaves exactly as before.
        let cfg = config(sendable: true, locales: nil)
        for id in ["zh-Hans", "zh-Hant", "ja", "en"] {
            XCTAssertTrue(
                CloudPermission.resolve(intensity: .sharp, consent: .granted,
                                        locale: Locale(identifier: id), remote: cfg,
                                        cloudConfigured: true,
                                        onDeviceModelAvailable: false).cloudAllowed,
                "\(id) must be allowed when no list is set")
        }
    }

    func testLocaleListCannotWidenADisabledFlag() {
        // RESTRICT-only: the list narrows, never widens.
        let cfg = config(sendable: false, locales: ["zh-Hans", "zh-Hant", "ja", "en"])
        XCTAssertFalse(
            CloudPermission.resolve(intensity: .sharp, consent: .granted,
                                    locale: Locale(identifier: "zh-Hans"), remote: cfg,
                                    cloudConfigured: true,
                                    onDeviceModelAvailable: false).cloudAllowed)
    }

    func testLocaleNarrowingDoesNotAffectPrivateDrafts() {
        // Vent uses vent_cloud_enabled and must ignore the sendable locale list.
        let cfg = config(sendable: true, locales: ["ja"])
        XCTAssertTrue(
            CloudPermission.resolve(intensity: .vent, consent: .granted,
                                    locale: Locale(identifier: "zh-Hant"), remote: cfg,
                                    cloudConfigured: true,
                                    onDeviceModelAvailable: true).cloudAllowed,
            "the sendable locale list must not gate the vent path")
    }

    func testContentBucketNormalisesRealDeviceLocales() {
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "zh_Hans_CN")), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "zh-Hant-TW")), .traditionalChinese)
        // Traditional territories commonly omit the script subtag.
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "zh_TW")), .traditionalChinese)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "zh_HK")), .traditionalChinese)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "zh_CN")), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "ja_JP")), .japanese)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "en_GB")), .english)
        XCTAssertEqual(AppLanguage.contentBucket(for: Locale(identifier: "fr_FR")), .english)
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
