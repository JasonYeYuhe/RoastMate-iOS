import Foundation

/// A′ post-launch instrumentation — privacy-compatible, no third-party SDK,
/// opt-in aggregate counters only.
///
/// Persistence: App-Group `UserDefaults(suiteName: "group.yyh.roastmate.app")`
/// (per-device by design — analytics counters intentionally don't sync via
/// CloudKit, unlike the user settings/wallet).
///
/// Opt-in source-of-truth lives on `UserSettings.telemetryOptedIn`
/// (CloudKit-synced, single user choice across devices). The UI mirrors
/// that boolean into the same App-Group defaults under
/// `aprime.opt_in` via `setOptIn(_:)`, so this class can read it
/// lock-free without crossing a SwiftData / main-actor boundary.
/// `RoastMateApp.bootstrap()` re-syncs the mirror at launch.
///
/// Concurrency: all reads/writes serialize through `queue.sync`; class is
/// `@unchecked Sendable` on that contract.
///
/// Default state when never `setOptIn(true)`'d: opt-out → every `record*`
/// call is a no-op.
///
/// See `docs/A_PRIME_TELEMETRY.md` for the schema + privacy posture.
public final class EventLedger: @unchecked Sendable {
    public static let shared = EventLedger()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "yyh.roastmate.aprime.ledger")

    /// Per-session flag — true once this app launch has recorded a
    /// successful generation. Reset on cold launch via
    /// `resetSessionMarkers()`. Not persisted (in-memory only) so the
    /// counter increments at most once per session.
    private var sessionGenerationRecorded: Bool = false

    public init(defaults: UserDefaults = EventLedger.defaultDefaults) {
        self.defaults = defaults
    }

    /// App-Group UserDefaults shared across iOS app + extensions + macOS.
    /// Falls back to `.standard` if the suite can't be opened (debug only).
    public static var defaultDefaults: UserDefaults {
        UserDefaults(suiteName: "group.yyh.roastmate.app") ?? .standard
    }

    // MARK: - Opt-in mirror

    /// Mirror the canonical `UserSettings.telemetryOptedIn` here. Cheap;
    /// safe to call from any thread.
    public func setOptIn(_ on: Bool) {
        queue.sync { defaults.set(on, forKey: Self.optInKey) }
    }

    /// Current mirrored opt-in state. Defaults to `false` (opt-out).
    public var isOptedIn: Bool {
        queue.sync { defaults.bool(forKey: Self.optInKey) }
    }

    private static let optInKey = "aprime.opt_in"

    /// P5 Tier-1 flag: has this user produced at least one successful
    /// output (main app, share extension, watch, or keyboard handoff)
    /// in their entire history? Set ONCE on first success, never reset
    /// except via `resetCounters()`. Used by `recordPurchaseCompleted()`
    /// to dispatch into `purchaseBeforeFirstOutput` vs
    /// `purchaseAfterFirstOutput`. Not a Counter (boolean state, not
    /// an event count).
    private static let hasSuccessfulOutputFlagKey = "aprime.flags.has_successful_output_before_purchase"

    // MARK: - Event API (no-ops when opted out)

    public func recordPaywallImpression() { bump(.paywallImpressions) }

    public func recordGeneration(cloud: Bool) {
        bump(.generationsTotal)
        bump(cloud ? .generationsCloud : .generationsOnDevice)
    }

    public func recordPurchaseAttempt() { bump(.purchaseAttempts) }
    /// Bumps the legacy `purchases_completed` counter AND the P5 Tier-1
    /// pay-timing pair (`purchase_before_first_output` /
    /// `purchase_after_first_output`) based on whether the user has
    /// produced at least one successful output before this purchase.
    public func recordPurchaseCompleted() {
        bump(.purchasesCompleted)
        let hadOutput = queue.sync { defaults.bool(forKey: Self.hasSuccessfulOutputFlagKey) }
        bump(hadOutput ? .purchaseAfterFirstOutput : .purchaseBeforeFirstOutput)
    }
    public func recordShareTap() { bump(.shareTaps) }
    public func recordSessionStart() { bump(.sessionStarts) }

    // MARK: - Schema v2 — ε2 generation feedback (Phase 3)
    //
    // Counters added at the end of `Counter` per the A′ public-contract
    // rule: existing keys never rename, only additive growth. No raw
    // text is ever logged — only the categorical tag is the unit.

    public func recordFeedbackUp() { bump(.feedbackThumbsUp) }
    public func recordFeedbackDown() { bump(.feedbackThumbsDown) }

    public func recordFeedbackTag(_ tag: FeedbackTag) {
        bump(tag.counter)
    }

    // MARK: - Schema v2 — α3 failure + paywall-source + return-to-tool (Phase 3 W2)
    //
    // schemaVersion stays at 2 — these are additive WITHIN v2 (the
    // additive-only contract still holds). Keys appended end-of-enum.

    public func recordFailure(_ category: FailureCategory) {
        bump(category.counter)
    }

    public func recordPaywallImpression(source: PaywallSource) {
        bump(.paywallImpressions)  // legacy v1 counter — keep bumping for back-compat
        bump(source.counter)
    }

    /// Per-session "did this session produce at least one generation"
    /// gate. Bumped once per process lifetime so `sessions_with_generation
    /// / session_starts` is a clean return-to-tool proxy. Reset via
    /// `resetSessionMarkers()` on cold launch.
    public func recordFirstGenerationOfSession() {
        let shouldBump: Bool = queue.sync {
            guard !sessionGenerationRecorded else { return false }
            sessionGenerationRecorded = true
            return true
        }
        if shouldBump { bump(.sessionsWithGeneration) }
    }

    /// `RoastMateApp.bootstrap()` calls this on cold launch so the
    /// per-session sessions_with_generation gate re-arms.
    public func resetSessionMarkers() {
        queue.sync { sessionGenerationRecorded = false }
    }

    // MARK: - Schema v2 — P5 strategic kill-list usage (Phase 5)
    //
    // 30/90 kill rule instrumentation. Each candidate surface (Watch app,
    // Keyboard skeleton, Argument Simulator) bumps its own counter on
    // entry. At 30 days clean low telemetry → freeze; at 90 → remove.
    // schemaVersion stays at 2 — these are additive WITHIN v2 (same
    // rationale as α3). Bumps fire on every appearance / viewDidLoad,
    // not per-session, so a freeze/remove decision sees the true usage
    // shape, not a clamp.

    public func recordFeatureUsageWatch() { bump(.featureUsageWatch) }
    public func recordFeatureUsageKeyboard() { bump(.featureUsageKeyboard) }
    public func recordFeatureUsageArgumentSimulator() { bump(.featureUsageArgumentSimulator) }

    // MARK: - Schema v2 — P5 Tier-1 distribution-research counters (Phase 5 Q1 W1)
    //
    // Five distribution-research counters + one boolean flag. Still
    // schemaVersion 2 — additive WITHIN v2 (same rationale as α3 / P5-
    // strategic). Counters bump end-of-output; the boolean flag is the
    // state input to `recordPurchaseCompleted()`'s pay-timing dispatch.
    // See `docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md` §2 Tier-1 + §8 #5.

    public func recordFeatureUsageShareExtension() { bump(.featureUsageShareExtension) }
    public func recordAppOpenFromKeyboardHandoff() { bump(.appOpenFromKeyboardHandoff) }

    /// Bumps BOTH the legacy v1 `share_taps` AND the P5 Tier-1
    /// `output_destination_sent_share_tap`. Use ONLY at output-content
    /// share sites (RoastCard, GeneratedRoastCard, ShareCardComposer),
    /// NOT at non-output shares like the telemetry-JSON share in
    /// Settings. The legacy counter audit (Codex Phase 4 §0.5 #5
    /// Risk register) is fixed by this method's uniform coverage —
    /// previously share_taps fired only from ShareCardComposer:64,
    /// biasing the count toward image-sharers. With this method wired
    /// at all three output-share sites, share_taps is now correct.
    public func recordOutputShareTap() {
        bump(.shareTaps)
        bump(.outputDestinationSentShareTap)
    }
    public func recordOutputCopied() { bump(.outputDestinationCopied) }

    /// Set the persistent App-Group boolean flag indicating the user
    /// has produced at least one successful output. Called from the
    /// success path of `RoastEngine.generate()` (covers main app, share
    /// extension, watch, argument simulator, and any other caller).
    /// Opt-out gated to match the rest of A′.
    public func markSuccessfulOutput() {
        queue.sync {
            guard defaults.bool(forKey: Self.optInKey) else { return }
            defaults.set(true, forKey: Self.hasSuccessfulOutputFlagKey)
        }
    }

    // MARK: - Schema v2 — Echoes / 替你出气 (Phase 5 Q2 Tier-2 feature telemetry)
    //
    // Counters added end-of-enum, schema stays v2 (additive within v2,
    // same rationale as α3 / P5-strategic / P5-Tier-1 blocks). The core
    // strategic metric is `echoesBridgeTap / echoesCompleted` — the
    // Bridge-to-Action conversion rate (Gemini decisive insight v2
    // plan §1). See `docs/A_PRIME_TELEMETRY.md`.

    public func recordEchoesSessionStarted() { bump(.echoesSessionStarted) }
    public func recordEchoesCompleted() { bump(.echoesCompleted) }
    public func recordEchoesBridgeTap() { bump(.echoesBridgeTap) }
    public func recordEchoesRegenerated() { bump(.echoesRegenerated) }
    public func recordEchoesShareSheetOpened() { bump(.echoesShareSheetOpened) }
    public func recordEchoesShareSheetCompleted() { bump(.echoesShareSheetCompleted) }
    public func recordEchoesParseFallback() { bump(.echoesParseFallback) }
    public func recordEchoesFeralCloudConsentGranted() { bump(.echoesFeralCloudConsentGranted) }
    public func recordEchoesFeralCloudConsentDenied() { bump(.echoesFeralCloudConsentDenied) }
    public func recordEchoesPaywallHit() { bump(.echoesPaywallHit) }
    /// On-device model was unavailable (AI off / unsupported / non-FM
    /// build) — curated lines served without a generation attempt. Use
    /// this, NOT recordEchoesParseFallback, when there was no model to
    /// parse the output of. Keeps the parse-failure rate honest.
    public func recordEchoesModelUnavailable() { bump(.echoesModelUnavailable) }

    // MARK: - Schema v2 — Remote kill-switch (health audit 2026-05-29 §4)

    /// Bumped (opt-in gated) when a freshly-fetched `RemoteConfig` actually
    /// disabled something relative to the all-enabled baseline — so an A′
    /// export confirms a remote kill propagated to this device. See
    /// `RemoteConfig.apply(fetchedData:)`.
    public func recordRemoteConfigKillApplied() { bump(.remoteConfigKillApplied) }

    // MARK: - Schema v2 — 虚拟舍友群 / roommate group (Echoes vNext)
    //
    // Counters appended end-of-enum, schema stays v2 (additive within v2,
    // same rationale as the Echoes / kill-switch blocks). The core metric is
    // `roommate_group_bridge_tapped / roommate_group_completed` (the
    // Bridge-to-Action conversion); `roommate_group_parse_fallback` feeds the
    // <15%-to-enable / 35%-kill real-device criterion. Aggregate counts only —
    // NEVER the situation text or generated messages.

    public func recordRoommateGroupStarted() { bump(.roommateGroupStarted) }
    public func recordRoommateGroupCompleted() { bump(.roommateGroupCompleted) }
    public func recordRoommateGroupParseFallback() { bump(.roommateGroupParseFallback) }
    public func recordRoommateGroupBridgeTapped() { bump(.roommateGroupBridgeTapped) }
    public func recordRoommateGroupRegenerated() { bump(.roommateGroupRegenerated) }

    public enum FailureCategory: String, CaseIterable, Sendable {
        case guardrail          = "guardrail"
        case network            = "network"
        case quota              = "quota"
        case safetyFilter       = "safety_filter"
        case modelAssetMissing  = "model_asset_missing"

        fileprivate var counter: Counter {
            switch self {
            case .guardrail:         return .generationsFailedGuardrail
            case .network:           return .generationsFailedNetwork
            case .quota:             return .generationsFailedQuota
            case .safetyFilter:      return .generationsFailedSafetyFilter
            case .modelAssetMissing: return .generationsFailedModelAssetMissing
            }
        }
    }

    public enum PaywallSource: String, CaseIterable, Sendable {
        case lowCredits      = "low_credits"
        case proTap          = "pro_tap"
        case styleLocked     = "style_locked"
        case intensityLocked = "intensity_locked"

        fileprivate var counter: Counter {
            switch self {
            case .lowCredits:      return .paywallTriggerLowCredits
            case .proTap:          return .paywallTriggerProTap
            case .styleLocked:     return .paywallTriggerStyleLocked
            case .intensityLocked: return .paywallTriggerIntensityLocked
            }
        }
    }

    /// Tag categories for a 👎 generation. Localized labels live in
    /// `Localizable.strings` under `feedback.tag.*`.
    public enum FeedbackTag: String, CaseIterable, Sendable {
        case wrongTone       = "wrong_tone"
        case tooSoft         = "too_soft"
        case tooHarsh        = "too_harsh"
        case wrongLanguage   = "wrong_language"
        case wrongStyle      = "wrong_style"
        case didntAddress    = "didnt_address"
        case factuallyWrong  = "factually_wrong"
        case other           = "other"

        fileprivate var counter: Counter {
            switch self {
            case .wrongTone:      return .feedbackTagWrongTone
            case .tooSoft:        return .feedbackTagTooSoft
            case .tooHarsh:       return .feedbackTagTooHarsh
            case .wrongLanguage:  return .feedbackTagWrongLanguage
            case .wrongStyle:     return .feedbackTagWrongStyle
            case .didntAddress:   return .feedbackTagDidntAddress
            case .factuallyWrong: return .feedbackTagFactuallyWrong
            case .other:          return .feedbackTagOther
            }
        }
    }

    // MARK: - Read / reset

    /// Aggregate counter snapshot. Always returns every known counter
    /// (missing keys read as 0). Safe to call even when opted out.
    public func snapshot() -> [String: Int] {
        queue.sync {
            var out: [String: Int] = [:]
            for c in Counter.allCases {
                out[c.rawValue] = defaults.integer(forKey: c.storageKey)
            }
            return out
        }
    }

    /// Clears every counter. Called from Settings "Reset" and after a
    /// user opts back out (so a re-opt-in starts from zero, not from
    /// whatever leaked between toggles).
    public func resetCounters() {
        queue.sync {
            for c in Counter.allCases {
                defaults.removeObject(forKey: c.storageKey)
            }
            // P5 Tier-1 boolean flag — clear alongside counters so a
            // re-opt-in starts from a fully fresh pay-timing baseline.
            defaults.removeObject(forKey: Self.hasSuccessfulOutputFlagKey)
        }
    }

    // MARK: - Private

    private func bump(_ counter: Counter, by amount: Int = 1) {
        queue.sync {
            guard defaults.bool(forKey: Self.optInKey) else { return }
            let current = defaults.integer(forKey: counter.storageKey)
            defaults.set(current + amount, forKey: counter.storageKey)
        }
    }

    /// Every counter known to the v1 schema. Keep `rawValue` keys stable —
    /// they appear in the exported JSON. New counters MUST be added at the
    /// end and documented in `docs/A_PRIME_TELEMETRY.md`.
    public enum Counter: String, CaseIterable, Sendable {
        // v1 schema (shipped in v1.0.1 — keys frozen, never rename).
        case paywallImpressions  = "paywall_impressions"
        case generationsTotal    = "generations_total"
        case generationsCloud    = "generations_cloud"
        case generationsOnDevice = "generations_on_device"
        case purchaseAttempts    = "purchase_attempts"
        case purchasesCompleted  = "purchases_completed"
        case shareTaps           = "share_taps"
        case sessionStarts       = "session_starts"
        // v2 additions (ε2 — Phase 3 W1, ships in v1.0.2). Appended at
        // end-of-enum per the additive-only contract documented in
        // `docs/A_PRIME_TELEMETRY.md`.
        case feedbackThumbsUp           = "feedback_thumbsup"
        case feedbackThumbsDown         = "feedback_thumbsdown"
        case feedbackTagWrongTone       = "feedback_tag_wrong_tone"
        case feedbackTagTooSoft         = "feedback_tag_too_soft"
        case feedbackTagTooHarsh        = "feedback_tag_too_harsh"
        case feedbackTagWrongLanguage   = "feedback_tag_wrong_language"
        case feedbackTagWrongStyle      = "feedback_tag_wrong_style"
        case feedbackTagDidntAddress    = "feedback_tag_didnt_address"
        case feedbackTagFactuallyWrong  = "feedback_tag_factually_wrong"
        case feedbackTagOther           = "feedback_tag_other"
        // v2 α3 additions (Phase 3 W2). Still schemaVersion 2 — additive
        // WITHIN v2. 5 failure categories + 4 paywall sources + 1
        // sessions_with_generation gate. End-of-enum.
        case generationsFailedGuardrail        = "generations_failed_guardrail"
        case generationsFailedNetwork          = "generations_failed_network"
        case generationsFailedQuota            = "generations_failed_quota"
        case generationsFailedSafetyFilter     = "generations_failed_safety_filter"
        case generationsFailedModelAssetMissing = "generations_failed_model_asset_missing"
        case paywallTriggerLowCredits          = "paywall_trigger_low_credits"
        case paywallTriggerProTap              = "paywall_trigger_pro_tap"
        case paywallTriggerStyleLocked         = "paywall_trigger_style_locked"
        case paywallTriggerIntensityLocked     = "paywall_trigger_intensity_locked"
        case sessionsWithGeneration            = "sessions_with_generation"
        // v2 P5-strategic additions (Phase 5 kill-list 30/90 instrumentation).
        // Per-feature usage counters for the three deprecation candidates
        // (Watch app, Keyboard skeleton, Argument Simulator). Still
        // schemaVersion 2 — additive WITHIN v2. End-of-enum.
        case featureUsageWatch                 = "feature_usage_watch"
        case featureUsageKeyboard              = "feature_usage_keyboard"
        case featureUsageArgumentSimulator     = "feature_usage_argument_simulator"
        // v2 P5 Tier-1 additions (Phase 5 Q1 W1 distribution research).
        // Surface usage + output destination + pay-timing pair. Boolean
        // flag `has_successful_output_before_purchase` lives separately
        // (state, not event count) — see `hasSuccessfulOutputFlagKey`.
        // Still schemaVersion 2 — additive WITHIN v2. End-of-enum.
        case featureUsageShareExtension        = "feature_usage_share_extension"
        case appOpenFromKeyboardHandoff        = "app_open_from_keyboard_handoff"
        case outputDestinationSentShareTap     = "output_destination_sent_share_tap"
        case outputDestinationCopied           = "output_destination_copied"
        case purchaseBeforeFirstOutput         = "purchase_before_first_output"
        case purchaseAfterFirstOutput          = "purchase_after_first_output"
        // v2 Echoes additions (Phase 5 Q2 — 替你出气 feature). End-of-enum.
        // Still schemaVersion 2 — additive WITHIN v2. The core strategic
        // metric is `echoes_bridge_tap / echoes_completed` (Bridge-to-Action
        // conversion). See v2 plan §7 + docs/A_PRIME_TELEMETRY.md.
        case echoesSessionStarted                 = "echoes_session_started"
        case echoesCompleted                      = "echoes_completed"
        case echoesBridgeTap                      = "echoes_bridge_tap"
        case echoesRegenerated                    = "echoes_regenerated"
        case echoesShareSheetOpened               = "echoes_share_sheet_opened"
        case echoesShareSheetCompleted            = "echoes_share_sheet_completed"
        case echoesParseFallback                  = "echoes_parse_fallback"
        case echoesFeralCloudConsentGranted       = "echoes_feral_cloud_consent_granted"
        case echoesFeralCloudConsentDenied        = "echoes_feral_cloud_consent_denied"
        case echoesPaywallHit                     = "echoes_paywall_hit"
        // Distinct from echoes_parse_fallback: the on-device model was
        // UNAVAILABLE (Apple Intelligence off / unsupported device / non-FM
        // build), so we served curated lines without ever attempting a
        // generation. Kept separate so the kill-criterion parse-failure
        // RATE (parse_fallback / sessions-where-model-was-available) isn't
        // polluted by AI-off devices. (Health audit 2026-05-29.)
        case echoesModelUnavailable               = "echoes_model_unavailable"
        // Remote kill-switch (health audit 2026-05-29 §4). Bumped once per
        // launch refresh whose fetched config disabled something
        // (echoes off / force-local-only / vent-cloud off). Still
        // schemaVersion 2 — additive WITHIN v2. End-of-enum.
        case remoteConfigKillApplied              = "remote_config_kill_applied"
        // v2 虚拟舍友群 / roommate-group additions (Echoes vNext). End-of-enum,
        // still schemaVersion 2 — additive WITHIN v2 (same rationale as the
        // Echoes / kill-switch blocks). See docs/A_PRIME_TELEMETRY.md.
        case roommateGroupStarted                 = "roommate_group_started"
        case roommateGroupCompleted               = "roommate_group_completed"
        case roommateGroupParseFallback           = "roommate_group_parse_fallback"
        case roommateGroupBridgeTapped            = "roommate_group_bridge_tapped"
        case roommateGroupRegenerated             = "roommate_group_regenerated"

        public var storageKey: String { "aprime.counters.\(rawValue)" }
    }
}
