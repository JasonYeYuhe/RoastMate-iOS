import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID = UUID()
    var dailyFreeUsed: Int = 0
    var dailyFreeResetDate: Date = Date()
    var hasSeenOnboarding: Bool = false
    var hasAcknowledgedAgeGate: Bool = false
    var hasAcknowledgedContentNotice: Bool = false
    var safeModeEnabled: Bool = true
    var preferredLocale: String?
    var historyRetentionDays: Int = 30

    /// Lifetime free generations consumed by the user, counted independently
    /// of the daily quota. Added in v1.x to give new users a generous
    /// "first 20 free" runway before the daily 5-cap kicks in. Nullable so
    /// pre-existing stores upgrade without migration; reads back as 0 when
    /// missing (matching the legacy "no lifetime quota" behavior — those
    /// users have already been on the daily quota and lose nothing).
    var lifetimeFreeUsed: Int?

    /// Whether Vent / Feral generations route through the developer-owned
    /// Cloud AI proxy (currently Groq primary with OpenRouter fallback;
    /// model choice lives in `cloud-worker/wrangler.toml`) instead of
    /// Apple's on-device Foundation Models. We default to ON because the
    /// on-device model refuses to actually vent (it reframes into wise
    /// observations), so without cloud the marquee feature doesn't work.
    /// Nullable so legacy stores upgrade without migration; reads back
    /// as `true` (the new default) when missing.
    ///
    /// Calm / Sharp / Savage stay 100% on-device regardless of this flag.
    var cloudVentEnabledRaw: Bool?

    init() {
        self.id = UUID()
        self.dailyFreeUsed = 0
        self.dailyFreeResetDate = Calendar.current.startOfDay(for: Date())
        self.hasSeenOnboarding = false
        self.hasAcknowledgedAgeGate = false
        self.hasAcknowledgedContentNotice = false
        self.safeModeEnabled = true
        self.preferredLocale = nil
        self.historyRetentionDays = 30
        self.lifetimeFreeUsed = 0
        self.cloudVentEnabledRaw = true
    }

    /// Resolved cloud flag with legacy default. Treat nil (pre-cloud
    /// installs) as opted in, since the only way to discover the feature
    /// post-upgrade is to have it work the first time.
    var cloudVentEnabled: Bool {
        get { cloudVentEnabledRaw ?? true }
        set { cloudVentEnabledRaw = newValue }
    }

    /// Daily cap once the lifetime allotment is exhausted.
    static let freeDailyLimit = 5

    /// Lifetime onboarding allotment, consumed before the daily quota
    /// starts ticking. Users get this once across the lifetime of their
    /// install — there is no refill on a new day until they run out.
    static let freeLifetimeAllotment = 20

    /// Returns the lifetime counter, treating nil (legacy stores) as 0.
    var lifetimeUsedSafe: Int {
        get { lifetimeFreeUsed ?? 0 }
        set { lifetimeFreeUsed = newValue }
    }

    /// True if the user still has lifetime onboarding generations remaining.
    var lifetimeRemaining: Int {
        max(0, Self.freeLifetimeAllotment - lifetimeUsedSafe)
    }

    /// Attempts to consume one free generation. Priority order:
    /// 1. Lifetime allotment (first 20 generations ever) — never touches
    ///    daily counter while this is active so the user doesn't lose their
    ///    daily 5 to the lifetime bucket.
    /// 2. Daily quota (5/day, resets at local midnight).
    /// Returns `false` only if both buckets are empty.
    func consumeFreeQuotaIfAvailable(now: Date = Date()) -> Bool {
        // Lifetime bucket takes precedence and is not gated by day boundary.
        if lifetimeRemaining > 0 {
            lifetimeUsedSafe += 1
            return true
        }

        // Daily bucket — rollover at local midnight.
        let calendar = Calendar.current
        if !calendar.isDate(dailyFreeResetDate, inSameDayAs: now) {
            dailyFreeUsed = 0
            dailyFreeResetDate = calendar.startOfDay(for: now)
        }
        guard dailyFreeUsed < Self.freeDailyLimit else { return false }
        dailyFreeUsed += 1
        return true
    }

    /// Total remaining free generations available right now (lifetime +
    /// what's left of today's daily quota). Surfaced to the UI in the
    /// quota chip.
    func totalRemainingFree(now: Date = Date()) -> Int {
        return lifetimeRemaining + remainingDailyOnly(now: now)
    }

    /// Daily-bucket remaining only (does not include lifetime). Useful for
    /// labels like "after your lifetime runs out: 5/day".
    func remainingDailyOnly(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        if !calendar.isDate(dailyFreeResetDate, inSameDayAs: now) {
            return Self.freeDailyLimit
        }
        return max(0, Self.freeDailyLimit - dailyFreeUsed)
    }

    /// Convenience that reads `totalRemainingFree` against the real current
    /// date — for the quota chip in the toolbar.
    var totalRemainingFreeNow: Int { totalRemainingFree(now: Date()) }

    /// True while the user is in their first-20 onboarding window. The UI
    /// uses this to switch the quota chip copy from "X free today" to
    /// "X free to start (then 5/day)".
    var isInLifetimeWindow: Bool { lifetimeRemaining > 0 }
}
