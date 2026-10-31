import XCTest
@testable import RoastMate

/// B5 (1.8.0): one labelled 痛罵 preview for free users, once per iCloud
/// account, only after a Vent the cloud wrote.
final class ProPreviewTests: XCTestCase {

    func testOffered_onlyAfterAFreeUsersCloudVent_once() {
        XCTAssertTrue(ProPreview.shouldOffer(isPro: false, intensity: .vent, servedByCloud: true, offeredAt: nil))
        XCTAssertFalse(ProPreview.shouldOffer(isPro: true, intensity: .vent, servedByCloud: true, offeredAt: nil), "never for Pro")
        XCTAssertFalse(ProPreview.shouldOffer(isPro: false, intensity: .vent, servedByCloud: false, offeredAt: nil),
                       "not after an on-device or curated Vent: no consent used, or no Worker voice")
        XCTAssertFalse(ProPreview.shouldOffer(isPro: false, intensity: .sharp, servedByCloud: true, offeredAt: nil))
        XCTAssertFalse(ProPreview.shouldOffer(isPro: false, intensity: .vent, servedByCloud: true, offeredAt: Date()),
                       "offered once, then never again")
    }

    func testTheFlagLivesOnSyncedSettings() {
        let settings = UserSettings()
        XCTAssertNil(settings.proPreviewOfferedAt)
    }

    @MainActor
    func testPreviewStyle_isAProStyleWithAVoiceInThatLanguage() {
        for id in ["zh_TW", "zh_CN", "en_US", "ja_JP"] {
            let locale = Locale(identifier: id)
            let style = StyleCatalog.shared.style(id: ProPreview.styleId(for: locale))
            XCTAssertEqual(style?.tier, .pro, id)
            XCTAssertTrue(style.map { StyleVoice.hasCloudVoice($0, locale: locale) } ?? false, id)
        }
    }

    func testEngineMarksCloudOutput_andNotTheLocalFallback() async throws {
        let style = StylePreset(id: "taiwanese_drama", displayKey: "k", blurbKey: "b", icon: "star", tier: .pro,
                                temperature: 0.8, tags: [], systemPreamble: "p", examples: [], localesSupported: nil)
        let cloud = try await RoastEngine(fm: FakeFMBackend()).generateDetailed(
            situation: "室友半夜打遊戲。", style: style, locale: Locale(identifier: "zh_TW"), variantCount: 1,
            intensity: .feral, cloudVentEnabled: true,
            cloudClient: RecordingCloudVentService(returning: "你半夜打遊戲，整層樓陪你熬夜。"))
        XCTAssertTrue(cloud.servedByCloud)
        let local = try await RoastEngine(fm: FakeFMBackend(cached: [.text("local draft")])).generateDetailed(
            situation: "室友半夜打遊戲。", style: style, locale: Locale(identifier: "zh_TW"), variantCount: 1,
            intensity: .feral, cloudVentEnabled: true, cloudClient: FailingCloudVentService())
        XCTAssertFalse(local.servedByCloud)
    }
}
