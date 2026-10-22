// Time budget for the upstream phase of one /v1/vent request.
//
// The app gives up at 25 s (Shared/Services/CloudConfig.swift:43,
// CloudConfig.requestTimeout) and then shows its labelled fallback. Before
// this, no upstream fetch had a timeout, so one hung provider used all 25 s
// and the user waited for nothing. Every upstream call — the first model-list
// call, the tail retries for a retired id, and the optional quality retry —
// now draws on ONE deadline measured from when the Worker received the
// request, so their sum can never pass it.
//
// The numbers, from measured latencies (client-observed, so they include the
// network):
//   - production vent/feral, shipped config: mean 4.77 s, median 4.61 s,
//     max 7.91 s (n=34, 2026-10-22 audit); roommate transcripts 6.2 / 6.65 s.
//   - the fallback model alone: 2.3–8.2 s (n=8, evals/runs/2026-10-07-p01-fallback.md
//     Run B); a retired primary (400) plus the tail retry: 3.9–4.7 s in total.
// So:
//   - FIRST_ATTEMPT_MS 12 s ≈ 1.5× the slowest call ever measured (8.2 s). That
//     call sends the whole model list, and OpenRouter runs its own fallback
//     inside it; 12 s leaves room for a fast primary failure plus a full
//     fallback answer, so the cap does not cut that fallback off mid-attempt
//     in any case we have measured.
//   - UPSTREAM_BUDGET_MS 18 s for everything. After a first call that hits its
//     12 s cap, a tail retry still gets 6 s (above the fallback's 3.6–4.7 s
//     medians). The Worker answers by ~18 s plus a quota round trip, which
//     leaves ~7 s of the app's 25 s for the phone's network.
//   - QUALITY_RETRY_MS 8 s ≈ the slowest normal call; the retry only runs when
//     at least QUALITY_RETRY_MIN_MS 6 s remain, and on a timeout the first
//     draft is kept. A typical request with a retry: ~5 s + ~5 s.

//
// Roommate transcripts (and the numbered roast variants, gated off) are 3–8x
// a vent draft, so they get a longer first call (review 2026-10-22). Measured
// roommate latencies, client-observed: 6.2, 6.65, 8.85 s (first gate), then
// 10.81, 9.94 and 1.6 s (worker-side 10.66, 9.79, 1.54 s; second gate) —
// against 4.77 s mean for a vent. 12 s was 1.1x the slowest of those; 16 s is
// 1.5x, the same margin the vent cap has over the slowest vent (8.2 s). Their
// whole budget is 20 s, which still leaves 5 s of the app's 25 s for the
// phone's network. A tail retry only starts with at least LONG_MIN_TAIL_MS
// left: after a fast failure (a retired id's 400) it gets nearly the whole
// budget, the case the tail retry exists for; after a first call that hit the
// 16 s cap, 4 s cannot produce a transcript, so the Worker answers 502 at once
// (quota refunded) instead of making a call that is likely billed and useless.
// Before this module there was no cap at all, so a longer cap is the
// conservative direction. The p95 of latency_ms for mode=roommate in Datadog
// should still be checked before deploy (the Datadog connector failed in this
// session and in the review's).

export const UPSTREAM_BUDGET_MS = 18000;
export const FIRST_ATTEMPT_MS = 12000;
export const LONG_BUDGET_MS = 20000;
export const LONG_FIRST_ATTEMPT_MS = 16000;
export const LONG_MIN_TAIL_MS = 6000;
export const QUALITY_RETRY_MS = 8000;
export const QUALITY_RETRY_MIN_MS = 6000;
/// Below this, an upstream call is not worth starting.
export const MIN_ATTEMPT_MS = 2000;

/// The budget for one request's mode: `totalMs` for every upstream call
/// together, `firstMs` for the first one, `minTailMs` the least time a tail
/// retry may start with. Vent / Feral drafts get the short budget; the
/// roommate transcript and the roast variants the long one.
export function budgetFor(mode) {
  return mode === "roommate" || mode === "roast"
    ? { totalMs: LONG_BUDGET_MS, firstMs: LONG_FIRST_ATTEMPT_MS, minTailMs: LONG_MIN_TAIL_MS }
    : { totalMs: UPSTREAM_BUDGET_MS, firstMs: FIRST_ATTEMPT_MS, minTailMs: MIN_ATTEMPT_MS };
}

/// The timeout for the next upstream call, capped at `cap` and at what is left
/// before `deadline`; 0 means "do not start it" (less than `minMs` left).
export function attemptTimeout(deadline, now, cap = Infinity, minMs = MIN_ATTEMPT_MS) {
  const left = deadline - now;
  if (!(left >= minMs)) return 0;
  return Math.min(cap, left);
}

/// The timeout for the optional quality retry; 0 means skip it and keep the
/// first draft.
export function qualityRetryTimeout(deadline, now) {
  const left = deadline - now;
  if (!(left >= QUALITY_RETRY_MIN_MS)) return 0;
  return Math.min(QUALITY_RETRY_MS, left);
}
