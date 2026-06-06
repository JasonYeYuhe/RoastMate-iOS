import XCTest
@testable import RoastMate

final class EventLedgerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var ledger: EventLedger!

    override func setUp() {
        super.setUp()
        // Isolated per-test UserDefaults suite — no contamination across
        // tests or with the real app's App-Group store.
        suiteName = "ledger-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        ledger = EventLedger(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        ledger = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Opt-out is a hard no-op

    func test_defaultIsOptedOut() {
        XCTAssertFalse(ledger.isOptedIn,
                       "Fresh ledger must default to opted out.")
    }

    func test_recordIsNoOp_whenOptedOut() {
        ledger.recordPaywallImpression()
        ledger.recordGeneration(cloud: true)
        ledger.recordPurchaseAttempt()
        ledger.recordShareTap()
        ledger.recordSessionStart()
        let snap = ledger.snapshot()
        // Every known counter must read 0 because nothing should have
        // landed while opted out.
        for c in EventLedger.Counter.allCases {
            XCTAssertEqual(snap[c.rawValue], 0,
                           "counter \(c.rawValue) leaked through opt-out gate.")
        }
    }

    // MARK: - Opt-in records

    func test_optInThenRecord_incrementsCounters() {
        ledger.setOptIn(true)
        XCTAssertTrue(ledger.isOptedIn)

        ledger.recordPaywallImpression()
        ledger.recordPaywallImpression()
        ledger.recordPurchaseAttempt()
        ledger.recordPurchaseCompleted()
        ledger.recordShareTap()
        ledger.recordSessionStart()

        let s = ledger.snapshot()
        XCTAssertEqual(s["paywall_impressions"], 2)
        XCTAssertEqual(s["purchase_attempts"], 1)
        XCTAssertEqual(s["purchases_completed"], 1)
        XCTAssertEqual(s["share_taps"], 1)
        XCTAssertEqual(s["session_starts"], 1)
    }

    func test_recordGeneration_incrementsTotalAndCloudSplit() {
        ledger.setOptIn(true)
        ledger.recordGeneration(cloud: true)
        ledger.recordGeneration(cloud: false)
        ledger.recordGeneration(cloud: false)
        let s = ledger.snapshot()
        XCTAssertEqual(s["generations_total"], 3,
                       "every generation must bump generations_total.")
        XCTAssertEqual(s["generations_cloud"], 1)
        XCTAssertEqual(s["generations_on_device"], 2)
    }

    // MARK: - Reset

    func test_resetCounters_clearsAll() {
        ledger.setOptIn(true)
        for _ in 0..<5 { ledger.recordPaywallImpression() }
        ledger.recordGeneration(cloud: true)
        XCTAssertGreaterThan(ledger.snapshot()["paywall_impressions"] ?? 0, 0)

        ledger.resetCounters()
        let s = ledger.snapshot()
        for c in EventLedger.Counter.allCases {
            XCTAssertEqual(s[c.rawValue], 0,
                           "reset must zero \(c.rawValue).")
        }
        // Opt-in state survives the counter reset.
        XCTAssertTrue(ledger.isOptedIn,
                      "resetCounters() must NOT also flip opt-out.")
    }

    func test_snapshotAlwaysReturnsEveryKnownCounter() {
        // Fresh suite — never written — every counter must be present as 0.
        let s = ledger.snapshot()
        for c in EventLedger.Counter.allCases {
            XCTAssertNotNil(s[c.rawValue],
                            "snapshot missing key \(c.rawValue).")
            XCTAssertEqual(s[c.rawValue], 0)
        }
    }

    func test_optOutAfterCounting_freezesFurtherBumps() {
        ledger.setOptIn(true)
        ledger.recordPaywallImpression()
        ledger.recordPaywallImpression()
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2)

        ledger.setOptIn(false)
        // Snapshot is still readable (we don't wipe on opt-out at the
        // ledger level — SettingsView does that explicitly).
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2)
        // Future bumps don't land.
        ledger.recordPaywallImpression()
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2,
                       "post-opt-out bump must be a no-op.")
    }

    // MARK: - Thread safety

    func test_concurrentBumps_doNotLoseUpdates() {
        ledger.setOptIn(true)
        let iterations = 200
        let workers = 8
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ledger-test.workers", attributes: .concurrent)
        // Capture the Sendable ledger directly; `self` (XCTestCase) is
        // non-Sendable and would warn under strict concurrency.
        let ledgerRef = ledger!
        for _ in 0..<workers {
            group.enter()
            queue.async {
                for _ in 0..<iterations { ledgerRef.recordPaywallImpression() }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success,
                       "concurrent bump workers did not finish in time.")
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"],
                       iterations * workers,
                       "lost an update under concurrent bumps.")
    }

    // MARK: - Schema v2 — ε2 generation feedback (Phase 3 W1)

    func test_feedbackUpAndDown_incrementSeparateCounters() {
        ledger.setOptIn(true)
        ledger.recordFeedbackUp()
        ledger.recordFeedbackUp()
        ledger.recordFeedbackDown()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_thumbsup"], 2)
        XCTAssertEqual(s["feedback_thumbsdown"], 1)
    }

    func test_feedbackTag_eachTagHasItsOwnCounter() {
        ledger.setOptIn(true)
        ledger.recordFeedbackTag(.wrongTone)
        ledger.recordFeedbackTag(.wrongTone)
        ledger.recordFeedbackTag(.tooSoft)
        ledger.recordFeedbackTag(.tooHarsh)
        ledger.recordFeedbackTag(.wrongLanguage)
        ledger.recordFeedbackTag(.wrongStyle)
        ledger.recordFeedbackTag(.didntAddress)
        ledger.recordFeedbackTag(.factuallyWrong)
        ledger.recordFeedbackTag(.other)
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_tag_wrong_tone"], 2)
        XCTAssertEqual(s["feedback_tag_too_soft"], 1)
        XCTAssertEqual(s["feedback_tag_too_harsh"], 1)
        XCTAssertEqual(s["feedback_tag_wrong_language"], 1)
        XCTAssertEqual(s["feedback_tag_wrong_style"], 1)
        XCTAssertEqual(s["feedback_tag_didnt_address"], 1)
        XCTAssertEqual(s["feedback_tag_factually_wrong"], 1)
        XCTAssertEqual(s["feedback_tag_other"], 1)
    }

    func test_feedbackCounters_areOptOutGated() {
        // Opted out by default → feedback bumps must be no-ops.
        ledger.recordFeedbackUp()
        ledger.recordFeedbackDown()
        ledger.recordFeedbackTag(.wrongTone)
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_thumbsup"], 0)
        XCTAssertEqual(s["feedback_thumbsdown"], 0)
        XCTAssertEqual(s["feedback_tag_wrong_tone"], 0)
    }

    func test_v1Counters_keepTheirRawKeysAfterV2() {
        // Public-contract regression guard: the v1 raw keys must never
        // rename. Lock the exact strings the export schema documents.
        let allRaw = EventLedger.Counter.allCases.map(\.rawValue)
        for expected in [
            "paywall_impressions",
            "generations_total",
            "generations_cloud",
            "generations_on_device",
            "purchase_attempts",
            "purchases_completed",
            "share_taps",
            "session_starts",
        ] {
            XCTAssertTrue(allRaw.contains(expected),
                          "v1 counter \(expected) must still exist as a Counter case.")
        }
    }

    func test_v2Counters_areAppendedAtEndOfEnum() {
        // The additive contract says v2 counters land AFTER v1 counters in
        // Counter.allCases. Verify by checking the first v2 index is past
        // the last v1 index.
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastV1 = cases.firstIndex(of: "session_starts") ?? -1
        let firstV2 = cases.firstIndex(of: "feedback_thumbsup") ?? -1
        XCTAssertGreaterThan(firstV2, lastV1,
                             "v2 counters must be appended at end of the enum.")
    }

    // MARK: - Schema v2 — α3 failure + paywall + sessions_with_generation (Phase 3 W2)

    func test_recordFailure_eachCategoryHasItsOwnCounter() {
        ledger.setOptIn(true)
        ledger.recordFailure(.guardrail)
        ledger.recordFailure(.guardrail)
        ledger.recordFailure(.network)
        ledger.recordFailure(.quota)
        ledger.recordFailure(.safetyFilter)
        ledger.recordFailure(.modelAssetMissing)
        let s = ledger.snapshot()
        XCTAssertEqual(s["generations_failed_guardrail"], 2)
        XCTAssertEqual(s["generations_failed_network"], 1)
        XCTAssertEqual(s["generations_failed_quota"], 1)
        XCTAssertEqual(s["generations_failed_safety_filter"], 1)
        XCTAssertEqual(s["generations_failed_model_asset_missing"], 1)
    }

    func test_recordPaywallImpression_sourceBumpsBothLegacyAndSource() {
        ledger.setOptIn(true)
        ledger.recordPaywallImpression(source: .lowCredits)
        ledger.recordPaywallImpression(source: .lowCredits)
        ledger.recordPaywallImpression(source: .proTap)
        ledger.recordPaywallImpression(source: .styleLocked)
        ledger.recordPaywallImpression(source: .intensityLocked)
        let s = ledger.snapshot()
        // Legacy counter accumulates ALL sourced bumps for back-compat.
        XCTAssertEqual(s["paywall_impressions"], 5,
                       "Sourced impression must also bump the legacy paywall_impressions counter.")
        XCTAssertEqual(s["paywall_trigger_low_credits"], 2)
        XCTAssertEqual(s["paywall_trigger_pro_tap"], 1)
        XCTAssertEqual(s["paywall_trigger_style_locked"], 1)
        XCTAssertEqual(s["paywall_trigger_intensity_locked"], 1)
    }

    func test_recordFirstGenerationOfSession_bumpsOnlyOncePerSession() {
        ledger.setOptIn(true)
        ledger.recordFirstGenerationOfSession()
        ledger.recordFirstGenerationOfSession()
        ledger.recordFirstGenerationOfSession()
        XCTAssertEqual(ledger.snapshot()["sessions_with_generation"], 1,
                       "Per-session gate must clamp to one bump per process lifetime until resetSessionMarkers().")
        ledger.resetSessionMarkers()
        ledger.recordFirstGenerationOfSession()
        XCTAssertEqual(ledger.snapshot()["sessions_with_generation"], 2,
                       "After resetSessionMarkers(), the next first-generation re-arms the counter.")
    }

    func test_α3Counters_areOptOutGated() {
        // Opted out by default — every α3 record* call must be a no-op.
        ledger.recordFailure(.guardrail)
        ledger.recordPaywallImpression(source: .lowCredits)
        ledger.recordFirstGenerationOfSession()
        let s = ledger.snapshot()
        XCTAssertEqual(s["generations_failed_guardrail"], 0)
        XCTAssertEqual(s["paywall_impressions"], 0)
        XCTAssertEqual(s["paywall_trigger_low_credits"], 0)
        XCTAssertEqual(s["sessions_with_generation"], 0)
    }

    func test_α3Counters_areAppendedAfterε2Counters() {
        // Sequence regression: α3 keys come AFTER the ε2 v2 keys, which
        // come AFTER v1. Locks the on-the-wire ordering.
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastEpsilon2 = cases.firstIndex(of: "feedback_tag_other") ?? -1
        let firstAlpha3  = cases.firstIndex(of: "generations_failed_guardrail") ?? -1
        XCTAssertGreaterThan(firstAlpha3, lastEpsilon2,
                             "α3 counters must follow the ε2 block at end of enum.")
    }

    // MARK: - Schema v2 — P5 strategic kill-list usage (Phase 5)

    func test_p5StrategicCounters_areAppendedAfterAlpha3Counters() {
        // Sequence regression: P5-strategic feature_usage_* keys come
        // AFTER the α3 block, which comes AFTER ε2, which comes AFTER v1.
        // Locks the on-the-wire ordering.
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastAlpha3 = cases.firstIndex(of: "sessions_with_generation") ?? -1
        let firstP5   = cases.firstIndex(of: "feature_usage_watch") ?? -1
        XCTAssertGreaterThan(firstP5, lastAlpha3,
                             "P5-strategic feature_usage_* counters must follow the α3 block at end of enum.")
    }

    func test_recordFeatureUsage_eachSurfaceHasItsOwnCounter() {
        ledger.setOptIn(true)
        ledger.recordFeatureUsageWatch()
        ledger.recordFeatureUsageWatch()
        ledger.recordFeatureUsageKeyboard()
        ledger.recordFeatureUsageArgumentSimulator()
        ledger.recordFeatureUsageArgumentSimulator()
        ledger.recordFeatureUsageArgumentSimulator()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feature_usage_watch"], 2)
        XCTAssertEqual(s["feature_usage_keyboard"], 1)
        XCTAssertEqual(s["feature_usage_argument_simulator"], 3)
    }

    func test_p5StrategicCounters_areOptOutGated() {
        // Opted out by default — every P5 record* call must be a no-op.
        ledger.recordFeatureUsageWatch()
        ledger.recordFeatureUsageKeyboard()
        ledger.recordFeatureUsageArgumentSimulator()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feature_usage_watch"], 0)
        XCTAssertEqual(s["feature_usage_keyboard"], 0)
        XCTAssertEqual(s["feature_usage_argument_simulator"], 0)
    }

    // MARK: - Schema v2 — P5 Tier-1 distribution-research (Phase 5 Q1 W1)

    func test_p5Tier1Counters_areAppendedAfterP5StrategicCounters() {
        // Sequence regression: P5 Tier-1 distribution-research keys come
        // AFTER the P5-strategic block. Locks the on-the-wire ordering.
        // The "last item" assertion moved to
        // test_echoesCounters_areAppendedAfterP5Tier1Counters now that
        // Echoes counters occupy end-of-enum (v1.0.6).
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastP5Strategic = cases.firstIndex(of: "feature_usage_argument_simulator") ?? -1
        let firstTier1      = cases.firstIndex(of: "feature_usage_share_extension") ?? -1
        XCTAssertGreaterThan(firstTier1, lastP5Strategic,
                             "P5 Tier-1 counters must follow the P5-strategic block at end of enum.")
    }

    func test_recordTier1_eachCounterIncrementsCorrectly() {
        ledger.setOptIn(true)
        ledger.recordFeatureUsageShareExtension()
        ledger.recordFeatureUsageShareExtension()
        ledger.recordAppOpenFromKeyboardHandoff()
        ledger.recordOutputCopied()
        ledger.recordOutputCopied()
        ledger.recordOutputCopied()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feature_usage_share_extension"], 2)
        XCTAssertEqual(s["app_open_from_keyboard_handoff"], 1)
        XCTAssertEqual(s["output_destination_copied"], 3)
    }

    func test_recordOutputShareTap_bumpsBothLegacyAndSourcedCounters() {
        ledger.setOptIn(true)
        ledger.recordOutputShareTap()
        ledger.recordOutputShareTap()
        let s = ledger.snapshot()
        // Both the legacy v1 share_taps AND the new Tier-1 counter must
        // increment on each call — back-compat with the existing
        // share_taps consumers + clean uniform output-share signal.
        XCTAssertEqual(s["share_taps"], 2,
                       "Legacy v1 share_taps must also bump on every output share tap.")
        XCTAssertEqual(s["output_destination_sent_share_tap"], 2)
    }

    func test_recordPurchaseCompleted_dispatchesToBeforeFirstOutput_whenFlagFalse() {
        ledger.setOptIn(true)
        // markSuccessfulOutput NOT called — boolean flag stays false.
        ledger.recordPurchaseCompleted()
        let s = ledger.snapshot()
        XCTAssertEqual(s["purchases_completed"], 1,
                       "Legacy purchases_completed must still bump on every purchase.")
        XCTAssertEqual(s["purchase_before_first_output"], 1,
                       "Without a prior successful output, the pay-timing dispatch must land in before-first-output.")
        XCTAssertEqual(s["purchase_after_first_output"], 0,
                       "After-first-output must remain 0 when no output has been recorded.")
    }

    func test_recordPurchaseCompleted_dispatchesToAfterFirstOutput_whenFlagTrue() {
        ledger.setOptIn(true)
        ledger.markSuccessfulOutput()  // Flag flips to true.
        ledger.recordPurchaseCompleted()
        let s = ledger.snapshot()
        XCTAssertEqual(s["purchases_completed"], 1)
        XCTAssertEqual(s["purchase_after_first_output"], 1,
                       "With a prior successful output, the pay-timing dispatch must land in after-first-output.")
        XCTAssertEqual(s["purchase_before_first_output"], 0,
                       "Before-first-output must remain 0 when an output has been recorded.")
    }

    func test_markSuccessfulOutput_isOptOutGated() {
        // Opted out by default — markSuccessfulOutput must not flip the
        // flag, so a subsequent purchase still dispatches to before-
        // first-output. Privacy posture parity with the counter API.
        ledger.markSuccessfulOutput()
        ledger.setOptIn(true)
        ledger.recordPurchaseCompleted()
        XCTAssertEqual(ledger.snapshot()["purchase_before_first_output"], 1,
                       "Opted-out markSuccessfulOutput must be a no-op, so a later opted-in purchase still lands in before-first-output.")
    }

    func test_p5Tier1Counters_areOptOutGated() {
        // Opted out by default — every Tier-1 record* call must be a no-op.
        ledger.recordFeatureUsageShareExtension()
        ledger.recordAppOpenFromKeyboardHandoff()
        ledger.recordOutputShareTap()
        ledger.recordOutputCopied()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feature_usage_share_extension"], 0)
        XCTAssertEqual(s["app_open_from_keyboard_handoff"], 0)
        XCTAssertEqual(s["share_taps"], 0)
        XCTAssertEqual(s["output_destination_sent_share_tap"], 0)
        XCTAssertEqual(s["output_destination_copied"], 0)
    }

    func test_resetCounters_clearsSuccessfulOutputFlag() {
        ledger.setOptIn(true)
        ledger.markSuccessfulOutput()
        // Confirm the flag is set: a purchase now lands in after-first-output.
        ledger.recordPurchaseCompleted()
        XCTAssertEqual(ledger.snapshot()["purchase_after_first_output"], 1)
        // Reset everything — including the boolean flag.
        ledger.resetCounters()
        // A subsequent purchase should now land in before-first-output
        // (flag was cleared, so the pay-timing baseline is fresh).
        ledger.recordPurchaseCompleted()
        XCTAssertEqual(ledger.snapshot()["purchase_before_first_output"], 1,
                       "resetCounters must clear the has_successful_output flag so a re-opt-in starts from a fresh pay-timing baseline.")
        XCTAssertEqual(ledger.snapshot()["purchase_after_first_output"], 0,
                       "After-first-output must have been cleared along with the flag.")
    }

    // MARK: - Schema v2 — Echoes / 替你出气 (Phase 5 Q2 — v1.0.6)

    func test_echoesCounters_areAppendedAfterP5Tier1Counters() {
        // Sequence regression: Echoes counters end-of-enum, AFTER all
        // P5 Tier-1 counters. Locks the on-the-wire ordering.
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastTier1 = cases.firstIndex(of: "purchase_after_first_output") ?? -1
        let firstEchoes = cases.firstIndex(of: "echoes_session_started") ?? -1
        XCTAssertGreaterThan(firstEchoes, lastTier1,
                             "Echoes counters must follow the P5 Tier-1 block.")
        // The kill-switch wave (health audit 2026-05-29 §4) appended
        // remote_config_kill_applied AFTER the Echoes block — it is now the
        // end-of-enum tail until the next additive wave.
        let echoesModelUnavailable = cases.firstIndex(of: "echoes_model_unavailable") ?? -1
        XCTAssertGreaterThan(echoesModelUnavailable, firstEchoes,
                             "echoes_model_unavailable stays within/after the Echoes block.")
        let killSwitch = cases.firstIndex(of: "remote_config_kill_applied") ?? -1
        XCTAssertGreaterThan(killSwitch, echoesModelUnavailable,
                             "remote_config_kill_applied follows the Echoes block (the roommate-group wave now occupies end-of-enum).")
    }

    func test_echoesCounters_eachIncrementsCorrectly() {
        ledger.setOptIn(true)
        ledger.recordEchoesSessionStarted()
        ledger.recordEchoesCompleted()
        ledger.recordEchoesBridgeTap()
        ledger.recordEchoesBridgeTap()  // double-tap counted once each
        ledger.recordEchoesRegenerated()
        ledger.recordEchoesShareSheetOpened()
        ledger.recordEchoesShareSheetCompleted()
        ledger.recordEchoesParseFallback()
        ledger.recordEchoesFeralCloudConsentGranted()
        ledger.recordEchoesFeralCloudConsentDenied()
        ledger.recordEchoesPaywallHit()
        ledger.recordEchoesModelUnavailable()
        let s = ledger.snapshot()
        XCTAssertEqual(s["echoes_session_started"], 1)
        XCTAssertEqual(s["echoes_completed"], 1)
        XCTAssertEqual(s["echoes_bridge_tap"], 2,
                       "Bridge taps count each press — strategic conversion metric.")
        XCTAssertEqual(s["echoes_regenerated"], 1)
        XCTAssertEqual(s["echoes_share_sheet_opened"], 1)
        XCTAssertEqual(s["echoes_share_sheet_completed"], 1)
        XCTAssertEqual(s["echoes_parse_fallback"], 1)
        XCTAssertEqual(s["echoes_feral_cloud_consent_granted"], 1)
        XCTAssertEqual(s["echoes_feral_cloud_consent_denied"], 1)
        XCTAssertEqual(s["echoes_paywall_hit"], 1)
        XCTAssertEqual(s["echoes_model_unavailable"], 1,
                       "model-unavailable counter is distinct from parse_fallback (kill-criterion integrity).")
    }

    func test_echoesCounters_areOptOutGated() {
        // Default opt-out — every Echoes record* must be a no-op.
        ledger.recordEchoesSessionStarted()
        ledger.recordEchoesCompleted()
        ledger.recordEchoesBridgeTap()
        ledger.recordEchoesPaywallHit()
        let s = ledger.snapshot()
        XCTAssertEqual(s["echoes_session_started"], 0)
        XCTAssertEqual(s["echoes_completed"], 0)
        XCTAssertEqual(s["echoes_bridge_tap"], 0)
        XCTAssertEqual(s["echoes_paywall_hit"], 0)
    }

    // MARK: - Schema v2 — 虚拟舍友群 / roommate group (Echoes vNext)

    func test_roommateGroupCounters_areAppendedAfterKillSwitch() {
        // Sequence regression: roommate-group counters land at end-of-enum,
        // AFTER the kill-switch counter (the prior tail).
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let killSwitch = cases.firstIndex(of: "remote_config_kill_applied") ?? -1
        let firstRoommate = cases.firstIndex(of: "roommate_group_started") ?? -1
        XCTAssertGreaterThan(firstRoommate, killSwitch,
                             "Roommate-group counters must follow the kill-switch counter.")
        XCTAssertEqual(cases.last, "roommate_group_regenerated",
                       "roommate_group_regenerated is the new end-of-enum tail until the next additive wave.")
    }

    func test_roommateGroupCounters_eachIncrementsCorrectly() {
        ledger.setOptIn(true)
        ledger.recordRoommateGroupStarted()
        ledger.recordRoommateGroupCompleted()
        ledger.recordRoommateGroupParseFallback()
        ledger.recordRoommateGroupBridgeTapped()
        ledger.recordRoommateGroupBridgeTapped()
        ledger.recordRoommateGroupRegenerated()
        let s = ledger.snapshot()
        XCTAssertEqual(s["roommate_group_started"], 1)
        XCTAssertEqual(s["roommate_group_completed"], 1)
        XCTAssertEqual(s["roommate_group_parse_fallback"], 1)
        XCTAssertEqual(s["roommate_group_bridge_tapped"], 2,
                       "Bridge taps count each press — the strategic conversion metric.")
        XCTAssertEqual(s["roommate_group_regenerated"], 1)
    }

    func test_roommateGroupCounters_areOptOutGated() {
        ledger.recordRoommateGroupStarted()
        ledger.recordRoommateGroupParseFallback()
        let s = ledger.snapshot()
        XCTAssertEqual(s["roommate_group_started"], 0)
        XCTAssertEqual(s["roommate_group_parse_fallback"], 0)
    }
}
