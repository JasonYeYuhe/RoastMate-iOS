import SwiftUI

/// Honest label for output that came from `FallbackRoasts` rather than a
/// model — the device has no on-device model, the model errored, or every
/// candidate tripped the safety filter.
///
/// **Why a banner and not an error.** `roast.error.unavailable` has always
/// carried exactly the right copy ("On-device AI isn't available right now.
/// Showing curated responses instead."), correctly translated in all four
/// locales, and it has never once rendered in a shipped build: its only
/// notional caller is `RoastError.modelUnavailable`, which nothing anywhere
/// constructs. Routing this through the `.error` state instead would render
/// zero cards and block the default action on every device without an
/// on-device model — a Guideline 2.1 rejection, and strictly worse for the
/// user than the unlabelled canned text it replaces.
///
/// So this is deliberately a *non-error* surface: the user keeps the text,
/// and simply learns where it came from. It is styled like `CrisisBanner`
/// (informational, secondary) rather than like `rewriteError` (orange
/// warning triangle), because nothing has gone wrong from the user's side.
///
/// One home for the rule: every surface that renders engine output shows
/// THIS view. Do not re-implement the copy inline.
struct CuratedNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.quote")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("roast.error.unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}
