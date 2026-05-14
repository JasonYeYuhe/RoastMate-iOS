import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var dailyFreeUsed: Int
    var dailyFreeResetDate: Date
    var hasSeenOnboarding: Bool
    var hasAcknowledgedAgeGate: Bool
    var hasAcknowledgedContentNotice: Bool
    var safeModeEnabled: Bool
    var preferredLocale: String?
    var historyRetentionDays: Int

    /// Lifetime free generations consumed by the user, counted independently
    /// of the daily quota. Added in v1.x to give new users a generous
    /// "first 20 free" runway before the daily 5-cap kicks in. Nullable so
    /// pre-existing stores upgrade without migration; reads back as 0 when
    /// missing (matching the legacy "no lifetime quota" behavior — those
    /// users have already been on the daily quota and lose nothing).
    var lifetimeFreeUsed: Int?

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
