import XCTest
@testable import RoastMate

/// A6 (1.8.0): the purchase flow tells the truth and hands off. The views
/// only wire these decisions; never verify the flow itself in Debug (Debug is
/// always Pro) — the Release check is in docs/evidence/.../a6.
final class PurchaseHandoffTests: XCTestCase {

    private func style(_ tier: StylePreset.Tier, id: String = "s") -> StylePreset {
        StylePreset(id: id, displayKey: "k", blurbKey: "b", icon: "star", tier: tier,
                    temperature: 0.8, tags: [], systemPreamble: "p", examples: [], localesSupported: nil)
    }

    func testFreeUser_proStyleFromASample_opensThePaywallWithThatStyle() {
        let intent = PaywallGate.lockedSelection(
            isPro: false, style: style(.pro, id: "mba_boss"), intensity: .sharp, hasInput: true)
        XCTAssertEqual(intent, PaywallIntent(styleId: "mba_boss", intensity: nil, runAfterPurchase: true))
    }

    func testFreeUser_proIntensity_carriesTheIntensity() {
        let intent = PaywallGate.lockedSelection(
            isPro: false, style: style(.free), intensity: .savage, hasInput: false)
        XCTAssertEqual(intent, PaywallIntent(styleId: nil, intensity: .savage, runAfterPurchase: false))
    }

    func testBothLocked_carriesBoth() {
        let intent = PaywallGate.lockedSelection(
            isPro: false, style: style(.pro, id: "cold_violence"), intensity: .feral, hasInput: true)
        XCTAssertEqual(intent?.styleId, "cold_violence")
        XCTAssertEqual(intent?.intensity, .feral)
    }

    func testNothingLocked_orPro_isNil() {
        XCTAssertNil(PaywallGate.lockedSelection(isPro: false, style: style(.free), intensity: .sharp, hasInput: true))
        XCTAssertNil(PaywallGate.lockedSelection(isPro: true, style: style(.pro), intensity: .savage, hasInput: true))
    }

    func testTrialLine_onlyWhenEligibilityIsKnownTrue() {
        XCTAssertTrue(PaywallGate.showsTrialLine(offerIsFreeTrial: true, eligible: true))
        XCTAssertFalse(PaywallGate.showsTrialLine(offerIsFreeTrial: true, eligible: nil), "unknown → no line")
        XCTAssertFalse(PaywallGate.showsTrialLine(offerIsFreeTrial: true, eligible: false), "intro used → no line")
        XCTAssertFalse(PaywallGate.showsTrialLine(offerIsFreeTrial: false, eligible: true), "not a free trial")
    }

    func testPlans_yearlyFirst_whateverOrderStoreKitReturns() {
        let yearly = StoreService.yearlyProductId, monthly = StoreService.monthlyProductId
        XCTAssertEqual(PaywallGate.sortedPlanIDs([monthly, yearly], yearlyID: yearly), [yearly, monthly])
        XCTAssertEqual(PaywallGate.sortedPlanIDs([yearly, monthly], yearlyID: yearly), [yearly, monthly])
    }

    /// The sample the plan names: index 1 of the samples shown first is a Pro
    /// style, which is why the Generate button must check the style tier.
    @MainActor
    func testAProStyleSampleIsAmongTheFirstFive() {
        let pro = SampleRoastsCatalog.shared.all.prefix(5).compactMap { StyleCatalog.shared.style(id: $0.styleId) }
            .filter { $0.tier == .pro }
        XCTAssertFalse(pro.isEmpty)
    }
}
