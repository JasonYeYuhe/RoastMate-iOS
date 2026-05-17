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

    // MARK: - Credit wallet (v1.1 Pillar B — consumables-primary)

    /// Spendable credit balance. One credit == one generation / one
    /// sendable-rewrite. Credits are a quantity knob only and never
    /// unlock a Pro capability. Nullable so CloudKit-backed stores
    /// upgrade without a migration (same pattern as `lifetimeFreeUsed`);
    /// resolves through `creditBalance`, which lazily seeds the trial
    /// wallet exactly once.
    var creditBalanceRaw: Int?

    /// Whether the one-time seeded trial wallet has been granted. Gates
    /// the grant so it happens once per install — including once for
    /// already-installed users on upgrade (nil → not yet granted).
    var hasSeededTrialWalletRaw: Bool?

    /// First-launch anchor for the starter window. Set when the trial
    /// wallet is seeded; nil on legacy stores until first resolve.
    var firstLaunchDate: Date?

    /// Free starter-window generations used today (does not touch the
    /// wallet). Separate from `dailyFreeUsed` so the legacy quota path
    /// and its tests stay byte-unchanged.
    var starterTrickleUsed: Int?

    /// Local-midnight reset anchor for `starterTrickleUsed`.
    var starterTrickleResetDate: Date?

    /// Comma-separated StoreKit `Transaction.id`s whose credits have
    /// already been deposited. The settlement path is durable-first
    /// (persist wallet + this ledger, save, THEN finish the
    /// transaction) and idempotent: a replayed/unfinished consumable is
    /// matched here so it is finished without double-granting. Nullable
    /// for CloudKit-safe migration.
    var grantedCreditTxIDsRaw: String?

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
        self.creditBalanceRaw = nil
        self.hasSeededTrialWalletRaw = nil
        self.firstLaunchDate = nil
        self.starterTrickleUsed = nil
        self.starterTrickleResetDate = nil
        self.grantedCreditTxIDsRaw = nil
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

    /// LEGACY (pre-v1.1). Superseded by the credit wallet
    /// (`spendOneCredit`); no longer on the live generation path. Kept
    /// byte-unchanged with its tests purely for migration safety — do
    /// not wire new callers to it.
    ///
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

    // MARK: - Credit wallet (v1.1 Pillar B)
    //
    // Additive layer over the legacy quota above. The generation path
    // now spends through `spendOneCredit`; the legacy lifetime/daily
    // counters and their tests are left byte-unchanged (same additive
    // discipline Pillar D used for the safety filter).

    /// Spendable balance. One credit == one generation/rewrite. Credits
    /// are a quantity knob only — they never unlock a Pro capability.
    var creditBalance: Int {
        get { creditBalanceRaw ?? 0 }
        set { creditBalanceRaw = max(0, newValue) }
    }

    /// Whether the one-time seeded trial wallet has been granted.
    var hasSeededTrialWallet: Bool {
        get { hasSeededTrialWalletRaw ?? false }
        set { hasSeededTrialWalletRaw = newValue }
    }

    /// Grants the one-time trial wallet if it has never been granted on
    /// this install. Covers fresh installs and a single top-up for users
    /// who upgrade into v1.1 (same one-time-bonus precedent as the
    /// 20-generation lifetime runway). Idempotent.
    ///
    /// `firstLaunchDate` is a v1.1-new field (nil on every pre-v1.1
    /// store), so it is stamped here at seed time for BOTH fresh and
    /// upgrading users — i.e. the starter window always begins when the
    /// user first meets the credit system, never from a stale install
    /// date (addresses the upgrader-misses-window concern).
    @discardableResult
    func ensureTrialWalletSeeded(now: Date = Date()) -> Bool {
        guard !hasSeededTrialWallet else { return false }
        creditBalance += CreditCatalog.seededTrialCredits
        hasSeededTrialWallet = true
        if firstLaunchDate == nil { firstLaunchDate = now }
        return true
    }

    /// True while the soft-landing starter window is still open. An
    /// un-seeded store is treated as day 0 (window open).
    ///
    /// Anchored to the *calendar day* of first launch: the window spans
    /// exactly `starterWindowDays` calendar days (day 0 … day N-1). The
    /// trickle counter resets at local midnight, so anchoring on the
    /// raw timestamp would leak one extra eligible day for any non-
    /// midnight seed time (a seed at 15:00 + 7×24h still covers parts of
    /// 8 dates). startOfDay closes that off.
    func isInStarterWindow(now: Date = Date()) -> Bool {
        guard let start = firstLaunchDate else { return true }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        guard let end = calendar.date(
            byAdding: .day, value: CreditCatalog.starterWindowDays, to: anchor
        ) else { return false }
        return now < end
    }

    /// Starter-trickle used today, honoring the local-midnight rollover
    /// without mutating (used by the read-only peeks).
    private func starterTrickleUsedToday(now: Date) -> Int {
        guard let reset = starterTrickleResetDate,
              Calendar.current.isDate(reset, inSameDayAs: now) else { return 0 }
        return starterTrickleUsed ?? 0
    }

    /// Free starter-window generations left today (0 once the window
    /// closes). Does not touch the wallet.
    func starterTrickleRemaining(now: Date = Date()) -> Int {
        guard isInStarterWindow(now: now) else { return 0 }
        return max(0, CreditCatalog.starterWindowDailyTrickle - starterTrickleUsedToday(now: now))
    }

    /// Read-only: can the user generate right now without paying?
    /// (pending trial grant, today's free trickle, or a wallet credit).
    func canSpendNow(now: Date = Date()) -> Bool {
        if !hasSeededTrialWallet { return true }
        if starterTrickleRemaining(now: now) > 0 { return true }
        return creditBalance > 0
    }

    /// Spends one unit for a generation/rewrite. Priority:
    /// 1. Lazily seed the trial wallet (first spend ever).
    /// 2. Free starter-window trickle — does NOT touch the wallet, so the
    ///    seeded credits survive the soft-landing window.
    /// 3. One wallet credit.
    /// Returns false only when nothing is available → the caller shows
    /// the intent-triggered paywall.
    func spendOneCredit(now: Date = Date()) -> Bool {
        ensureTrialWalletSeeded(now: now)

        if isInStarterWindow(now: now) {
            let calendar = Calendar.current
            if let reset = starterTrickleResetDate,
               calendar.isDate(reset, inSameDayAs: now) {
                // same day — keep the running count
            } else {
                starterTrickleUsed = 0
                starterTrickleResetDate = calendar.startOfDay(for: now)
            }
            let used = starterTrickleUsed ?? 0
            if used < CreditCatalog.starterWindowDailyTrickle {
                starterTrickleUsed = used + 1
                return true
            }
        }

        guard creditBalance > 0 else { return false }
        creditBalance -= 1
        return true
    }

    /// Deposits purchased credits into the wallet.
    func grantCredits(_ amount: Int) {
        guard amount > 0 else { return }
        creditBalance += amount
    }

    /// Generations available right now without paying (trial-aware) —
    /// surfaced in the wallet chip.
    func availableCreditsNow(now: Date = Date()) -> Int {
        let pendingTrial = hasSeededTrialWallet ? 0 : CreditCatalog.seededTrialCredits
        return creditBalance + pendingTrial + starterTrickleRemaining(now: now)
    }

    // MARK: - Purchased-credit settlement ledger (durable-first, exactly-once)

    private var grantedCreditTxIDs: Set<String> {
        guard let raw = grantedCreditTxIDsRaw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// True if this StoreKit transaction's credits were already
    /// deposited — so a replayed/unfinished consumable is safe to just
    /// finish without granting again.
    func hasGrantedCreditTx(_ txID: String) -> Bool {
        grantedCreditTxIDs.contains(txID)
    }

    /// Idempotently deposit a verified consumable's credits. Returns
    /// true if, after this call, the transaction is fully accounted for
    /// (either just applied, or applied by an earlier call) — i.e. the
    /// caller may now finish the StoreKit transaction. The wallet and
    /// this ledger move together so a crash before the model is saved
    /// simply leaves the transaction unfinished for StoreKit to replay.
    @discardableResult
    func applyCreditGrant(txID: String, credits: Int) -> Bool {
        guard credits > 0, !txID.isEmpty else { return true }
        if grantedCreditTxIDs.contains(txID) { return true }
        creditBalance += credits
        var ids = grantedCreditTxIDs
        ids.insert(txID)
        grantedCreditTxIDsRaw = ids.sorted().joined(separator: ",")
        return true
    }
}
