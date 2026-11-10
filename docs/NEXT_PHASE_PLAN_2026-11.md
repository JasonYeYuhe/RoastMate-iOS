# RoastMate — the next phase (2026-11-08 → 2027-01-31): four paths, one to pick

**Status: PATH D (maintenance mode) since 2026-11-08 (late).** Path A was chosen
earlier the same day (about 17:50 JST), with a hard pivot to D on 11-22. It ended early: Jason dropped the
Threads posts and the agent cannot post, so 3 posts by 11-22 could not happen. What
D keeps, and the scheduled reads, are in the section "Update 2026-11-08 (late) —
PATH D" of `docs/HANDOFF_v1.8_NEXT_SESSION.md`. (Original status line: "CHOSEN — path A, with
the hard pivot to D on 11-22 (Jason, 2026-11-08).")
A2 is done: Billing Grace Period has been on since 11-08 (16 days, all renewals,
production and sandbox; set through the ASC API and read back). To undo it,
`PATCH /v1/subscriptionGracePeriods/6769317103` with `optIn: false`. Apple only
accepts production on together with sandbox on.

Known side effect of the grace period: during it, StoreKit should still count the
subscriber as entitled (Apple's described behaviour; not tested here), so the app
shows Pro. The Worker's `/v1/auth` checks
`expiresDate` (`auth.js:79-82`), so it answers 403. The client then falls back to
the free lane's 30-a-day quota. That is acceptable at this volume, and not a
reason to deploy.

Written 2026-11-08, after 1.8.0 went live on both platforms. It was reviewed separately by Gemini 4 Argon (High) and Gemini 3.8
Flash (High). §7 has their verdicts, what changed because of them, and what was
rejected after checking.

This plan sits **inside** the commitments already made, and does not replace them:
- the v1.7 §7 stop rule, read on 11-15 (or 4 weeks after T, if T happens first);
- the v1.8 plan's §2.1 table (what 1.8.1 may be) and its §2.3 payer read on 01-31;
- code freeze **12-05**.

**When the choice binds.** Jason can pick a path now. The non-code parts of A and
D can start at once. Path B or C stays provisional until **11-15**: Jason confirms
it in chat with the recorded rule result in front of him, as v1.8 §2.1 requires.
No B or C code before that confirmation.

## 0. Where we are (measured 11-08 unless dated)

| what | number | source |
|---|---|---|
| Live | macOS 1.8.0 (28) since 11-02, tag `v1.8.0`; iOS 1.8.0 (29) since 11-05, tag `v1.8.0-ios29` | ASC API, iTunes lookup |
| Store impressions | **567** (US 161, JP 119, TW 78, HK 14, RU 14, SG 12) | Analytics API, ~10-01 → 11-05 window¹ |
| Product page views | **46** (TW 20, US 12, JP 9, HK 3) | same |
| First-time downloads | **9** (7 App Store search, 2 app referrer); the latest is 10-28 | same |
| Taiwan funnel | 78 impressions → 20 page views → **1** download | same |
| Paying subscribers | **0**: TW churned 10-19; US in billing retry since 11-04 (not cancelled) | Sales + Subscription reports |
| Billing Grace Period | off (`optIn: false`, readable through the API) | ASC API `subscriptionGracePeriod` |
| Proceeds | $2.54 in the window | Analytics |
| Written reviews / in-app events / custom product pages | 0 / 0 / 0 | ASC API |
| Distribution | P2.1 drafts ready since 10-23, **0 posted**. Creator batch 1 (3 emails 09-28): 1 declined, 0 redemptions. | `docs/distribution/`, outreach log |
| Store assets | iOS: new screenshots per locale (v1.7.0), Traditional 幫你罵 icon since 1.7.2 (`64c4867`), zh-Hant keywords 83 characters. macOS: May-era en-US/zh-Hans screenshots, **none** for zh-Hant/ja. | ASC API, git |
| Running costs | OpenRouter $9.86 (11-02), ≈ $0.02 a week; Worker `046f2134` | balance log |

¹ The Analytics API returned rows from about 10-01. Apple suppresses small counts,
so these are lower bounds.

## 1. What the numbers say

1. **Reach is the constraint, not the product.** About 16 store impressions a day
   across all storefronts, 9 page views a week. Even if every page view became a
   download, that is ≈ 9 a week. The stop rule's bar is 5 a week.
2. **No feature binary has moved downloads.** Every binary since v1.3 has been
   feature or quality work, and downloads stayed in the low single digits a week:
   the v1.8 plan's baseline was ≈ 3, and today it is ≈ 1.5.
3. **App Store search is the one channel that brings installs** (7 of 9). But the
   volume is too small to tune: an A/B test or a custom product page would not
   reach a readable sample before 01-31.
4. **The v1.8 §2.3 read on 01-31 will almost certainly be "traffic-limited"** (it
   needs 40 first-time downloads; the current pace gives ≈ 17). With ≤ 1 new start
   it is also a KILL, which means maintenance mode whatever 1.8.1 contains.
5. **The only lever not yet pulled is the external posts**, and only Jason can pull
   it (his accounts). The drafts have waited since 10-23. That wait is the most
   likely way any path fails.

## 2. Path A — Reach push, no feature binary *(recommended)*

**Goal:** find out whether external posts bring Taiwan installs, before another
binary is spent. This is what the v1.7 rule allows after it fires:
"distribution experiments that need no code may continue."

**Hard pivot (both reviewers):** if fewer than 3 posts are live by **11-22**, A
ends and D starts. That date covers two PTT Mondays, 11-09 and 11-16. The rule
still fires on 11-15 if T hasn't happened by then; that gets recorded as written.
A then continues only as a no-code experiment.

| # | item | who | when | cost | gate / rollback |
|---|---|---|---|---|---|
| A1 | **Post kit, final:** re-check every claim in `docs/distribution/2026-10-23-p21-posts.md` against 1.8.0, and add the 7-day yearly trial and the one free 痛罵 preview. Give each channel its own **campaign link** (`ct=`), so ASC can tell Threads from PTT. Jason posts; the agent logs each URL and time (the third post sets T). | agent drafts, Jason posts | **now**; PTT [廣宣] only on Mondays (11-09, 11-16) | agent 2 h; Jason 1–2 h | Jason confirms the exact text and place of every post |
| A2 | **Billing Grace Period on** (whole app). Keeps a subscriber's Pro while Apple retries a failed charge. Assume it does not help the US retry that started 11-04. | Jason says yes; agent sets it via API, or Jason in the web UI | this week | 15 min | rollback: turn it off |
| A3 | 11-14: refresh `brief-2026-11-15.md`. 11-15: record the rule's result word for word in the handoff. | agent | 11-14/15 | 1 h | — |
| A4 | **Funnel check 7 days after the third post:** TW page views and first-time downloads by campaign. If posts bring < 25 TW page views in a week, posts don't reach the store. If page views jump but downloads stay < 5, the product page is the problem. | agent | T + 7 | 1 h | — |
| A5 | **Weekly readout** (scheduled, read-only): downloads, page views, starts, billing-retry state; reports only on change. | agent | from 11-09 | 1 h to set up | disable at D |
| A6 | *Optional:* an **In-App Event** for the 1.8 Taiwan voice. No binary needed; it shows on the product page and in search. Effect unmeasurable at this volume. | agent drafts, Jason approves (public text) | after A1 | ≈ 2 h incl. images | delete the event |
| A7 | *Optional, only after 3 posts are live:* creator batch 2 (never the three from batch 1). | agent drafts, Jason sends | ≥ 11-22 | agent 0.5 day | each send confirmed by Jason |
| A8 | **Maintenance:** the weekly balance task (exists), a 5-call Worker smoke test monthly, the refusal probe after any iOS/macOS 27.x point release, App Review answers. | agent | ongoing | ≈ 1 h a month | — |
| A9 | **Reads:** the stop rule (11-15, or 4 weeks after T); 12-15 read 1 and 01-31 final read per v1.8 §2.3. | agent | as dated | 2 h | — |

No binary, no Worker deploy, $0 evaluation spend. Agent total ≈ 2 days.

**Exits:**
- The **stop-rule read**, 4 weeks after T: ≥ 5 first-time downloads a week, or a
  new paying subscriber → the rule passes. The next plan may then exist, and it
  starts with distribution (v1.8 §2.1 table).
- The **01-31 read** (v1.8 §2.3, unchanged):
  - **SUCCESS** needs all three: ≥ 3 new starts; ≥ 2 of them kept past 3 days;
    ≥ 1 reaching a second paid period.
  - **KILL** if ≤ 1 new start, or if every start cancels within 3 days.
  - Anything in between means no new feature plan.
- **No posts by 11-22 → path D.**

## 3. Path B — 1.8.1 = B1-R, the Pro cloud rewrite on devices without Apple Intelligence

As specified in DEV_PLAN_v1.8 §3 (B): Worker `mode:"rewrite"` (Pro lane only, own
daily limit, server-side threat judge, kill switch `REWRITE_MODE_ENABLED`), client
routing with token-in-hand, a new versioned consent, copy in 4 locales, App Privacy
re-check, preview gate ≤ 25 calls.

- **Reaches today:** Pro users on devices without Apple's model, which is **0
  paying users** right now.
- **Cost:** Worker 1 day, client 2–3 days, release 1 day; ≈ 1 h of Jason's time; 1
  production Worker deploy. Prerequisite: production Pro tokens are verified to
  mint.
- **Timeline:** confirmed 11-15 → Worker preview gate by 11-19 → client by 12-02 →
  **12-03 submit**; the flag goes on after it is live.
- A1–A5 and A8–A9 run alongside.

## 4. Path C — 1.8.1 = Lifetime Pro (B8), plus macOS zh-Hant/ja screenshots

Lifetime Pro would be a non-consumable `yyh.roastmate.app.pro.lifetime`, priced by
Jason.
- **Client (`Shared/Services/StoreService.swift`):** the two subscription ids are
  hard-coded in `loadProducts()`, `refreshSubscriptionStatus()` and
  `currentProTransactionJWS()` (around :74–79, :228–234, :253–261). All three need
  the lifetime id, or the app never treats the buyer as Pro and never sends their
  transaction to `/v1/auth`. It also needs a paywall row and restore.
- **Worker (`cloud-worker/src/auth.js`):**
  - `PRO_PRODUCT_IDS` (:18–21) lists only the subscriptions.
  - A transaction without a future `expiresDate` gets `expired` (:79–82).
  - The token's expiry is `min(expiresMs, now + SESSION_MAX_MS)` (:112), which is
    0 for a lifetime purchase.
  - If `ASS_API_ENABLED` is ever turned on, its status check calls the
    subscriptions endpoint, which does not cover non-consumables.
  - Without these fixes, a lifetime buyer is not cut off from cloud features: the
    client falls back to the free lane, which has the 30-a-day device quota. What
    they lose is the 200-a-day Pro quota. The Worker does not gate Feral or the
    Pro styles by lane.
  - The fix is a lifetime branch that checks `revocationDate`, gives the token a
    capped expiry, and skips the status check for non-consumables, plus tests, a
    preview, and 1 production deploy.
- **Screenshots:** macOS zh-Hant/ja screenshots ride the binary (today there are
  none).
- **Reaches:** the ≈ 1.5 downloaders a week. A lifetime purchase counts as a new
  start (v1.8 §2.3).
- **Cost:** client 1–2 days, Worker 0.5–1 day, ASC product and review,
  screenshots 0.5 day. Jason picks the price. Confirmed on 11-15, submitted by
  12-03.
- A1–A5 and A8–A9 run alongside.

## 5. Path D — maintenance mode now

No feature work and no distribution push. What stays: kill switches, the weekly
balance task, App Review responses, and one OS-compatibility binary a year. A2
(Grace Period) is still worth the 15 minutes. The 11-15 rule read and the 01-31
read still happen, to close the v1.8 plan. Jason's time goes to other projects.
Cost ≈ 0.

## 6. Recommendation

**A, with the hard pivot to D on 11-22.** Both reviewers chose the same, each on
their own.
- It is the only path aimed at the measured constraint (reach).
- It is the cheapest.
- It is the only path whose result changes what happens next.

B and C improve a funnel that 9 people entered in 5 weeks. On the current pace,
both end at the same 01-31 verdict as D.

**The deciding fact is whether Jason will post.** If he knows he won't, the honest
choice is D, not B or C. This week's action is the posts: Threads now, and PTT
[廣宣] on Monday 11-09 if the post kit is checked in time, otherwise 11-16.

## 7. Reviews (asked separately, read-only access to the repo)

Verbatim answers: `docs/evidence/2026-11-08-next-phase/review-gemini4argon.md` and
`review-gemini38flash.md`.

| point | Argon | Flash | outcome |
|---|---|---|---|
| Path | A now, auto-downgrade to D on 11-22 without 3 posts | A, pivot to D on 11-15 (or as early as 11-09) without posts | **Accepted, as A → D on 11-22.** It covers both PTT Mondays. The rule itself still fires on 11-15. |
| 01-31 exit used the 11-15 rule's bar | yes | yes | **Accepted.** §2 now separates the rule read from the §2.3 read. |
| Choosing B/C on 11-08 overrides v1.8 §2.1 | yes | yes | **Accepted.** B/C are provisional until confirmed on 11-15. |
| Lifetime: "loses cloud Pro" overstated; also `auth.js:112`, client JWS, status API | yes | (only confirmed the Worker change) | **Accepted, checked.** No lane gate in `index.js` `validate`; the free-lane fallback is in `lane.js`. |
| macOS screenshot line contradicted §0 | yes | — | **Accepted** ("none", not "May-era"). |
| Billing Grace Period: doesn't help the current retry | yes | yes ("per Apple docs") | **Kept as an assumption.** |
| PTT Monday 11-09 is the only Monday before 11-15 | yes | yes | **Accepted.** A1 starts now. |
| Campaign links per channel | yes | — | **Accepted** into A1. |
| In-App Event | — | yes | **Accepted as optional A6.** |
| Creator batch 2 only after posts / cold email is weak | yes | yes | **Accepted:** A7 only after 3 posts. |
| "The icon still reads Simplified 帮你骂" | yes | — | **Rejected, checked:** Traditional 幫你罵 icon since 1.7.2 (`64c4867`). The 10-23 post doc predates it. |
| "zh-Hant keywords use 48 of 100 characters" | — | yes | **Rejected, checked:** they are 83 characters now (the 10-07 recon file is stale). |
| "The API can't set Grace Period" | — | yes | **Rejected for reading:** `GET /v1/apps/6769317103/subscriptionGracePeriod` returns `optIn: false`. Whether PATCH works is untested; the web UI is the fallback. |
| Ask trusted contacts for ratings/reviews | — | yes | **Rejected:** that can read as review manipulation under Apple's rules. The in-app prompt (`RatingPromptService.swift`) already exists. |
| Offer codes in PTT's promo-code 專區 | yes | — | **Jason's call, not planned.** The codes auto-renew, which has to be said, and it is a post in his name. |
| Comment on trending Threads vents with screenshots | — | yes | **Jason's call** (his account). |

## 8. Guardrails (unchanged)

DEV_PLAN_v1.8 §6 applies to every path. In particular:
- Never post or send in Jason's name without his confirmation of the exact text and
  destination.
- Never flip `cloud_sendable_enabled`.
- Any new cloud path needs a new flag, a versioned consent, an App Privacy review, a
  CI guard, a kill switch and a server-side Pro check.
- Debug is always Pro, so verify paid flows only in Release.
- Every Worker deploy records its version id and the rollback.
- No third-party SDK.

## 9. Parked (found while executing A; not built under A)

| found | what | evidence | for |
|---|---|---|---|
| 11-08 | The 1.8.0 rewrite threat judge blocks harmless rewrites. 2 of 10 re-runs of the post examples on macOS 27.2 were judged THREAT (「…我今天已經很忙了。」, 「…好像大家都聽不見。」), so the user got the labelled example instead. This fits the 10-29 blind number (8/40 legitimate messages blocked). 2 of 5 roommate rewrites also said 「我的碗盤」 (wrong owner). | `docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck/` | the next plan, only if one exists (§2 exits). **11-11: not a 1.8.0 regression, so not in the maintenance fix lane.** 1.8.0 lowered it: blind 10/40 → 8/40, real outputs 39/297 → 20/297 (`docs/evidence/2026-10-27-v18-plan/harness/safety/judgetune/README.md`); handoff, Update 2026-11-08 (late) |
