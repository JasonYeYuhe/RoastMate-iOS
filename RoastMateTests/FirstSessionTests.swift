import StoreKit
import XCTest
@testable import RoastMate

/// 1.7.1 first-session and purchase helpers that live in Shared.
final class FirstSessionTests: XCTestCase {

    /// Without the on-device model, Sharp can only show curated examples, so a
    /// new generator starts on Vent there (the consent sheet still runs first).
    func testFirstSessionDefaultIntensity() {
        XCTAssertEqual(Intensity.firstSessionDefault(onDeviceModelAvailable: true), .sharp)
        XCTAssertEqual(Intensity.firstSessionDefault(onDeviceModelAvailable: false), .vent)
        XCTAssertFalse(Intensity.firstSessionDefault(onDeviceModelAvailable: false).requiresPro,
                       "The no-model default must be usable by a free user.")
    }

    func testCuratedReason_privateDrafts() {
        for intensity in [Intensity.vent, .feral] {
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: false, onDeviceModelAvailable: true),
                           .cloudOff, "declined / never-asked cloud → point at Settings")
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: false, onDeviceModelAvailable: false),
                           .cloudOff)
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: true,
                                                       consentGranted: true, onDeviceModelAvailable: false),
                           .cloudFailed)
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: true, onDeviceModelAvailable: true),
                           .cloudPaused, "consent granted but the remote switch is off: neither retry nor Settings can fix it")
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: true, onDeviceModelAvailable: false),
                           .cloudPaused)
        }
    }

    func testCuratedReason_sendableModes() {
        for intensity in [Intensity.calm, .sharp, .savage] {
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: true, onDeviceModelAvailable: false),
                           .needsAppleIntelligence)
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: false,
                                                       consentGranted: false, onDeviceModelAvailable: true),
                           .modelDeclined)
            XCTAssertEqual(CuratedReason.forGeneration(intensity: intensity, cloudAllowed: true,
                                                       consentGranted: true, onDeviceModelAvailable: false),
                           .cloudFailed)
        }
        XCTAssertEqual(CuratedReason.forRewrite(onDeviceModelAvailable: false), .needsAppleIntelligence)
        XCTAssertEqual(CuratedReason.forRewrite(onDeviceModelAvailable: true), .modelDeclined)
        // This bundle runs on iOS, so the iPhone wording.
        XCTAssertEqual(CuratedReason.needsAppleIntelligence.localizationKey, "roast.notice.reason.apple_intelligence")
    }

    /// The paywall reports purchase failures, but never "you cancelled".
    func testUserCancellationIsNotReportedAsAPurchaseError() {
        XCTAssertTrue(StoreService.isUserCancellation(StoreKitError.userCancelled))
        XCTAssertTrue(StoreService.isUserCancellation(CancellationError()))
        XCTAssertFalse(StoreService.isUserCancellation(StoreKitError.networkError(URLError(.notConnectedToInternet))))
        XCTAssertFalse(StoreService.isUserCancellation(StoreKitError.notAvailableInStorefront))
        XCTAssertFalse(StoreService.isUserCancellation(NSError(domain: "x", code: 1)))
    }

    /// 1.7.1: Ask to Buy, an unverified transaction, a failed restore and an
    /// empty restore used to be silent. Each now maps to a message; success
    /// and the buyer cancelling still say nothing here.
    func testPurchaseNotices() {
        XCTAssertNil(PurchaseNotice.forPurchase(.purchased), "Pro has its own confirmation; credits show in the balance")
        XCTAssertNil(PurchaseNotice.forPurchase(.cancelled))
        XCTAssertEqual(PurchaseNotice.forPurchase(.pending)?.messageKey, "paywall.pending.body")
        XCTAssertEqual(PurchaseNotice.forPurchase(.pending)?.titleKey, "paywall.pending.title")
        XCTAssertEqual(PurchaseNotice.forPurchase(.unverified)?.messageKey, "paywall.unverified.body")

        XCTAssertNil(PurchaseNotice.forPurchaseError(StoreKitError.userCancelled))
        let failure = PurchaseNotice.forPurchaseError(StoreKitError.networkError(URLError(.notConnectedToInternet)))
        XCTAssertEqual(failure?.titleKey, "paywall.error.title")
        XCTAssertNil(failure?.messageKey)
        XCTAssertFalse((failure?.detail ?? "").isEmpty, "a real failure shows StoreKit's own description")

        XCTAssertNil(PurchaseNotice.forRestore(.restoredPro), "restored Pro shows the purchase confirmation")
        XCTAssertNil(PurchaseNotice.forRestore(.cancelled))
        XCTAssertEqual(PurchaseNotice.forRestore(.nothingToRestore)?.messageKey, "paywall.restore.none.body")
        let restoreFailure = PurchaseNotice.forRestore(.failed("The network connection was lost."))
        XCTAssertEqual(restoreFailure?.titleKey, "paywall.restore.failed.title")
        XCTAssertEqual(restoreFailure?.detail, "The network connection was lost.")
    }
}
