import Foundation
import SwiftData

/// β3 (Phase 3 W2): append-only credit ledger.
///
/// Why this exists — `UserSettings.creditBalanceRaw` is a plain Int that
/// already mirrors via SwiftData's automatic CloudKit sync (default-store
/// `ModelConfiguration` on the private container `iCloud.yyh.roastmate.app`).
/// Two devices spending offline both write the decremented Int; CloudKit
/// resolves the field-level conflict via last-write-wins, erasing one
/// device's spend → the user effectively gets a "free" generation. The
/// existing `grantedCreditTxIDsRaw` set protects deposits from double-grant
/// (because the underlying primitive is a comma-joined string of stable
/// StoreKit transaction ids), but the SPEND counter has no analogous
/// idempotency key. Same lost-update risk applies to grants once the
/// string-Set diverges across devices.
///
/// Fix per advisor synthesis (Gemini 3.1 Pro + Codex gpt-5.5, 2026-05-26):
/// stop merging counters; record each grant and spend as an immutable
/// record-typed ledger entry instead. Cross-device sync becomes
/// set-union over independent records (each with its own UUID record id),
/// so CloudKit's record-level conflict resolution is sufficient. Balance
/// is a pure function of the merged set, no arithmetic-on-shared-scalar.
///
/// Migration: `UserSettings.creditBalanceRaw` is frozen at upgrade time
/// and used as the baseline. Every post-upgrade transaction lives in
/// the ledger. `computed_balance = creditBalanceRaw + sum(grants) -
/// sum(spends)`. Pre-existing in-flight wallet state is preserved
/// exactly; the multi-device hazard only applied going forward, which
/// the ledger now defuses.
@Model
final class CreditLedgerEntry {
    /// The CloudKit record id. SwiftData uses this as the primary key
    /// of the auto-mirrored CKRecord, so a `CreditLedgerEntry` inserted
    /// on one device is a different record from one inserted on another,
    /// regardless of when. That is the point.
    var id: UUID = UUID()

    /// `"grant"` | `"spend"`. Stored raw for forward-compat — adding a
    /// future case (e.g. `"refund"`) is additive and any unknown raw
    /// reads back as `.spend` so the computed balance trends toward
    /// being conservative.
    var kindRaw: String = Kind.spend.rawValue

    /// Always positive. Reading: `grant` adds `amount`, `spend`
    /// subtracts `amount`.
    var amount: Int = 1

    var createdAt: Date = Date()

    /// For grants: the StoreKit transaction id (or a stable migration
    /// marker for the legacy carryover). Used to dedupe replays. For
    /// spends: nil.
    var txID: String?

    /// For spends: a per-install random UUID stamped at first use; lets
    /// the on-device triage CSV attribute lost-credit anomalies to a
    /// specific install. Never includes account or device identifiers
    /// that could fingerprint a user. nil for grants.
    var deviceID: String?

    init(
        kind: Kind,
        amount: Int = 1,
        txID: String? = nil,
        deviceID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.amount = max(0, amount)
        self.createdAt = createdAt
        self.txID = txID
        self.deviceID = deviceID
    }

    var kind: Kind {
        Kind(rawValue: kindRaw) ?? .spend
    }

    /// Signed contribution to the wallet balance.
    var signedAmount: Int {
        kind == .grant ? amount : -amount
    }

    enum Kind: String, Codable, Sendable {
        case grant
        case spend
    }
}
