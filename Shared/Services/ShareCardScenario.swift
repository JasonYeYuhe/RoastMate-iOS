import Foundation

/// The closed set of setup lines a Comeback Card may carry above the punchline.
///
/// ## Why a fixed catalog and not model output
///
/// The card lost its joke when v1.3.1 correctly deleted the raw vent: a lone
/// polished line on a gradient is a corporate email snippet, not a meme. The
/// obvious repair — have the model emit an "abstracted scenario line" — was
/// designed and then rejected, for two independent reasons that are both worth
/// recording because each one alone would have shipped a defect:
///
/// 1. **It could not reach the users.** The vent→sendable pair the setup line is
///    meant to restore comes from `RoastEngine.rewriteAsSendable`, which is
///    Foundation-Models-only and falls back to `FallbackRoasts.curated`. A tag
///    emitted by the Worker's roast prompt never arrives there; a tag generated
///    on-device is `nil` below iOS 26, which is the floor this app deliberately
///    ships to. Both proposed generation sites miss the installed base.
/// 2. **It would have been a privacy regression.** A model summary of the user's
///    private situation, rendered onto a branded public image, is a different
///    thing from the sendable reply (which the user was always going to send to
///    the counterparty). `Redactor` is measured weak on exactly this: names
///    survived in 2 of 3 generations, and its CJK rules were Simplified-only
///    until 2026-09-06.
///
/// A closed catalog answers both. The display text is authored, so PII leakage
/// is impossible **by construction** rather than by mitigation, and it renders
/// identically on every generation path — Apple FM, curated fallback, cloud,
/// consent-denied — because it does not depend on generation at all.
///
/// ## Why the user picks it
///
/// The remaining risk after closing the catalog is not leakage but **false
/// assertion**: several of these describe conduct (credit taken, blame shifted,
/// a broken promise). A classifier that guesses wrong would publish a factual
/// allegation about a real person under the RoastMate watermark. So the model
/// does not choose — the user taps a chip. That makes the person who knows what
/// happened the author of the claim, and it is categorically different from the
/// free-text field v1.3.1 removed: selecting a case from a fixed enum cannot put
/// user-typed bytes onto a branded image.
///
/// A classifier may later *suggest* a chip. It must never select one silently.
///
/// ## Stability
///
/// Raw values are a wire/analytics contract — keep them stable. Renaming a case
/// is fine; changing its `rawValue` is not. Display strings live in
/// `Localizable.strings` under `sharecard.scenario.<rawValue>` and are safe to
/// reword, because nothing keys off the text.
public enum ShareCardScenario: String, CaseIterable, Identifiable, Sendable {
    // Work — the app's largest scenario category (`evals/scenarios/base.json`).
    case afterHoursPing        = "after_hours_ping"
    case lastMinuteDemand      = "last_minute_demand"
    case creditTaken           = "credit_taken"
    case blameShifted          = "blame_shifted"
    case movingGoalposts       = "moving_goalposts"
    case groupChatCallOut      = "group_chat_call_out"
    // Interpersonal — friends, partners, exes.
    case readNoReply           = "read_no_reply"
    case backhandedCompliment  = "backhanded_compliment"
    case unsolicitedAdvice     = "unsolicited_advice"
    case brokenPromise         = "broken_promise"
    case exResurfaced          = "ex_resurfaced"
    // Home — roommates and family.
    case borrowedNotReturned   = "borrowed_not_returned"
    case choresIgnored         = "chores_ignored"
    case noiseAtNight          = "noise_at_night"
    case familyComparison      = "family_comparison"
    case marriagePressure      = "marriage_pressure"

    public var id: String { rawValue }

    /// Localization key for the rendered line. Authored per locale — this is the
    /// property that makes the setup text PII-free by construction.
    public var displayKey: String { "sharecard.scenario.\(rawValue)" }

    /// Rough grouping, used only to order the picker so related chips sit
    /// together. Deliberately not persisted and not part of any contract.
    public enum Group: String, CaseIterable, Sendable {
        case work, people, home
    }

    public var group: Group {
        switch self {
        case .afterHoursPing, .lastMinuteDemand, .creditTaken,
             .blameShifted, .movingGoalposts, .groupChatCallOut:
            return .work
        case .readNoReply, .backhandedCompliment, .unsolicitedAdvice,
             .brokenPromise, .exResurfaced:
            return .people
        case .borrowedNotReturned, .choresIgnored, .noiseAtNight,
             .familyComparison, .marriagePressure:
            return .home
        }
    }

    /// Catalog order for the picker: grouped, and stable across launches so the
    /// chip a user reached for last time is in the same place.
    public static var ordered: [ShareCardScenario] {
        Group.allCases.flatMap { g in allCases.filter { $0.group == g } }
    }
}
