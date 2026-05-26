import Foundation
import SwiftData

/// β3 (Phase 3 W2): the ledger-backed wallet service. Wraps
/// `CreditLedgerEntry` queries and inserts so callers don't have to
/// know about the SwiftData primitive. `UserSettings` delegates to
/// this from `spendOneCredit` / `applyCreditGrant` when a
/// `ModelContext` is available.
///
/// **Computed balance** = `UserSettings.creditBalanceRaw` (the
/// pre-upgrade baseline) + Σ grant ledger entries − Σ spend ledger
/// entries. The cached `creditBalanceRaw` is refreshed on every
/// ledger mutation AND on launch via `recomputeBalance(context:settings:)`,
/// so any caller that reads `UserSettings.creditBalance` without a
/// context sees an eventually-consistent snapshot of the merged
/// cross-device truth.
///
/// **Idempotency keys.** Grants are deduped by `txID` (StoreKit
/// transaction id, stable across replay). Spends use the entry's own
/// `id` (per-insert UUID) — each device's spend is its own record, so
/// they merge by record union with no clobber. No conflict-resolution
/// arithmetic needed.
enum CreditWallet {
    // MARK: - Read

    /// Net contribution of the ledger to the wallet balance. Add this
    /// to `UserSettings.creditBalanceRaw` (the pre-upgrade baseline)
    /// to get the user-facing balance.
    static func ledgerDelta(context: ModelContext) -> Int {
        let entries = (try? context.fetch(FetchDescriptor<CreditLedgerEntry>())) ?? []
        return entries.reduce(0) { $0 + $1.signedAmount }
    }

    /// True if a ledger grant entry for the given StoreKit txID already
    /// exists — so a replayed/unfinished consumable is safe to just
    /// finish without re-granting. Matches `UserSettings
    /// .hasGrantedCreditTx` semantics but reads from the ledger.
    static func hasGrant(txID: String, context: ModelContext) -> Bool {
        guard !txID.isEmpty else { return false }
        let id = txID  // capture into local; predicate can't reference parameter directly across actors
        var descriptor = FetchDescriptor<CreditLedgerEntry>(
            predicate: #Predicate { entry in
                entry.kindRaw == "grant" && entry.txID == id
            }
        )
        descriptor.fetchLimit = 1
        let hits = (try? context.fetch(descriptor)) ?? []
        return !hits.isEmpty
    }

    // MARK: - Write

    /// Inserts a spend ledger entry (kind: `.spend`, amount: 1) and
    /// refreshes the cached `UserSettings.creditBalanceRaw` memo from
    /// the recomputed balance. Returns true on success (always, today
    /// — spends are unconditional once the caller has confirmed
    /// `canSpendNow`).
    @discardableResult
    static func recordSpend(
        settings: UserSettings,
        context: ModelContext,
        amount: Int = 1
    ) -> Bool {
        guard amount > 0 else { return false }
        let entry = CreditLedgerEntry(
            kind: .spend,
            amount: amount,
            deviceID: deviceID()
        )
        context.insert(entry)
        recomputeBalance(context: context, settings: settings)
        return true
    }

    /// Inserts a grant ledger entry keyed by StoreKit transaction id,
    /// idempotent. Returns true if the credit is durably accounted for
    /// (just inserted OR already inserted by a prior call). Mirrors
    /// `UserSettings.applyCreditGrant` semantics but writes the ledger
    /// record instead of mutating the shared scalar.
    @discardableResult
    static func recordGrant(
        settings: UserSettings,
        context: ModelContext,
        txID: String,
        credits: Int
    ) -> Bool {
        guard credits > 0, !txID.isEmpty else { return true }
        if hasGrant(txID: txID, context: context) { return true }
        let entry = CreditLedgerEntry(
            kind: .grant,
            amount: credits,
            txID: txID
        )
        context.insert(entry)
        recomputeBalance(context: context, settings: settings)
        return true
    }

    /// Refreshes `UserSettings.creditBalanceRaw` from the ledger delta.
    /// Called after every ledger insert and at app launch so contextless
    /// readers (Watch, share extension, computed property paths) see
    /// the latest merged truth modulo CloudKit sync latency.
    ///
    /// **Baseline self-healing (Codex W2 review 2026-05-26):** instead
    /// of trusting a CloudKit-mirrored scalar (`legacyBalanceBaselineRaw`)
    /// which can be clobbered by last-writer-wins, this records each
    /// device's snapshot of the pre-β3 balance as its own
    /// `.legacyBaseline` ledger entry (keyed by `deviceID`). The
    /// computed baseline is MAX over all entries — multi-device
    /// upgrades converge on the most generous snapshot, no data loss
    /// from sync ordering.
    static func recomputeBalance(context: ModelContext, settings: UserSettings) {
        ensureLegacyBaselineEntry(settings: settings, context: context)
        let baseline = legacyBaseline(context: context, fallback: settings)
        // Migrate the deprecated scalar cache one-way so any stale
        // reader still sees something defensible. The ledger entries
        // are the canonical source of truth from here on.
        if settings.legacyBalanceBaselineRaw == nil {
            settings.legacyBalanceBaselineRaw = baseline
        }
        let delta = ledgerDelta(context: context)
        let computed = max(0, baseline + delta)
        settings.creditBalance = computed
    }

    /// Idempotently insert a `.legacyBaseline` entry for THIS device
    /// (keyed by `deviceID`). Each device contributes its own pre-β3
    /// balance snapshot; the maximum across all entries becomes the
    /// global baseline.
    private static func ensureLegacyBaselineEntry(
        settings: UserSettings,
        context: ModelContext
    ) {
        let myDeviceID = deviceID()
        let id = myDeviceID
        var existing = FetchDescriptor<CreditLedgerEntry>(
            predicate: #Predicate { entry in
                entry.kindRaw == "legacy_baseline" && entry.deviceID == id
            }
        )
        existing.fetchLimit = 1
        if (try? context.fetch(existing))?.first != nil {
            // Already snapshotted for this device — leave it alone. The
            // ledger is append-only and per-device baseline is a one-
            // time observation. (Re-promoting on subsequent launches
            // would create a feedback loop: recompute writes a new
            // `creditBalanceRaw`, next launch reads it back as
            // "scalarSeed", entry grows, recompute again, etc.)
            return
        }
        // First observation on this device: snapshot whatever
        // creditBalanceRaw is showing right now. legacyBalanceBaselineRaw
        // (if set by an earlier v1.0.3 launch on this device) is the
        // preferred seed since it's the frozen pre-ledger value.
        let snapshot = settings.legacyBalanceBaselineRaw
            ?? settings.creditBalanceRaw
            ?? 0
        let entry = CreditLedgerEntry(
            kind: .legacyBaseline,
            amount: snapshot,
            deviceID: myDeviceID
        )
        context.insert(entry)
    }

    /// MAX over all `.legacyBaseline` entries' amounts (across every
    /// device on this iCloud account). Falls back to
    /// `UserSettings.creditBalanceRaw` (clamped ≥0) when the ledger
    /// has no baseline entries yet — e.g. immediately after the very
    /// first recompute call before `context.save()` has fired.
    static func legacyBaseline(context: ModelContext, fallback settings: UserSettings) -> Int {
        var descriptor = FetchDescriptor<CreditLedgerEntry>(
            predicate: #Predicate { entry in
                entry.kindRaw == "legacy_baseline"
            }
        )
        descriptor.fetchLimit = 100  // multi-device upper bound; tighter than nil
        let entries = (try? context.fetch(descriptor)) ?? []
        guard !entries.isEmpty else {
            return max(0, settings.creditBalanceRaw ?? 0)
        }
        return entries.map(\.amount).max() ?? 0
    }

    // MARK: - Internals

    private static let deviceIDKey = "credit_wallet.device_id"

    /// Per-install random UUID, stable for the lifetime of the install.
    /// Reset on uninstall. Never includes Apple ID, hardware ids, or
    /// any other fingerprintable identifier.
    static func deviceID(defaults: UserDefaults = .standard) -> String {
        if let cached = defaults.string(forKey: deviceIDKey), !cached.isEmpty {
            return cached
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: deviceIDKey)
        return new
    }
}
