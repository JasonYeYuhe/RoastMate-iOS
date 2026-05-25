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

    // MARK: - Event API (no-ops when opted out)

    public func recordPaywallImpression() { bump(.paywallImpressions) }

    public func recordGeneration(cloud: Bool) {
        bump(.generationsTotal)
        bump(cloud ? .generationsCloud : .generationsOnDevice)
    }

    public func recordPurchaseAttempt() { bump(.purchaseAttempts) }
    public func recordPurchaseCompleted() { bump(.purchasesCompleted) }
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

        public var storageKey: String { "aprime.counters.\(rawValue)" }
    }
}
