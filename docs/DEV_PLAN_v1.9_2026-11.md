# RoastMate — next phase plan (2026-11-12 → 2027-01-31)

**Status: CHOSEN — D+ (Jason, 2026-11-12, AskUserQuestion).** Draft 2, below unchanged.
- Draft 1 recommended a paid Apple Ads sample (path E).
- Gemini 4 Argon (High) and Gemini 3.8 Flash (High) reviewed it separately. Both
  chose maintenance mode (D) and found real errors.
- After checking their claims, this draft recommends **D+**: maintenance mode plus
  three $0 store-page items. E and a 1.8.1 item stay as options, corrected.
- §9 lists what was accepted and rejected. The raw reviews are in
  `docs/evidence/2026-11-12-next-phase/`.
- Until Jason picks, path D (since 11-08) stays in force. What D keeps is in
  `docs/HANDOFF_v1.8_NEXT_SESSION.md`, "Update 2026-11-08 (late)".

**Why this plan exists, and the short answer.** On 11-12 Jason asked for the next
phase of development.
- The recommended next phase contains **no app code**. The constraint is reach
  (about 1.5 first-time downloads a week).
- Every binary since v1.3 shipped features, and downloads stayed in the low single
  digits.
- The rules Jason set for this moment say feature work stops when distribution
  hasn't happened. It hasn't.
- What is still worth doing costs $0: make the store page say what 1.8.0 actually
  offers. Then let the scheduled reads close v1.8.
- If Jason wants code anyway, the one sanctioned way is a single 1.8.1 item that he
  re-approves on or after 11-15 (option S below).

## 0. Where we are (measured 11-12 unless dated)

| what | number | source |
|---|---|---|
| Live | macOS 1.8.0 (28) since 11-02, iOS 1.8.0 (29) since 11-05 | ASC API |
| First-time downloads, all territories, by week | 10-05: 1 · 10-12: 4 · 10-19: 2 · 10-26: 1 · 11-02: 1 (≈ 1.8 a week) | Analytics via `scripts/weekly_readout.py` |
| Product page views by week | 15 · 9 · 8 · 9 · 5 | same |
| Since 1.8.0 (11-05 → 11-10) | **1** first-time unit, **0** new starts | Sales via `scripts/payer_read.py` |
| Paying subscribers | **0**: TW churned (a day-0 cancel, period ended 10-20); US in billing retry since 11-04 | Sales + Subscription |
| Install sources, 10-01 → 11-05 | 7 App Store search, 2 app referrer. The TW payer (09-19) came from App Store **browse** | NEXT_PHASE_PLAN §0; DEV_PLAN_v1.7 :44-45 |
| Reviews / posts | 0 / 0 (path A ended 11-08) | ASC, outreach log |
| Store text, zh-Hant | name 幫你罵 (3/30), subtitle 15/30, keywords 83/100. The promotional text is 1.6.0-era: it says Vent is free and new users get credits, and **does not mention** the yearly 7-day trial or the one free 痛罵 preview (both live in 1.8.0: `Shared/zh-Hant.lproj/Localizable.strings:36-38, 180`) | `metadata/zh-Hant/*` |
| Running cost | OpenRouter ≈ $0.02 a week; balance $9.86 (11-02) | balance task |

**The 01-31 read (v1.8 §2.3).** It needs 40 first-time downloads between 11-05 and
01-31. At the current pace there will be about 15–22. So it will be recorded as
"traffic-limited", and with ≤ 1 new start it is a KILL. §2.3 decided in advance
that this stands: "The consequences in §2.1 do not change, because missing traffic
is the distribution failure the stop rule tests."

## 1. The rules this plan sits inside (Jason's own; not reopened here)

- **v1.7 §7 stop rule, read 11-15.**
  - No posts were made, so T never happens and the first branch fires: "stop
    feature work". The scheduled task records it on 11-15.
  - "Stop" means maintenance mode: "the weekly balance check, the kill-switches,
    one OS-compatibility binary a year, no new features. Distribution experiments
    that need no code may continue."
- **v1.8 §2.1.**
  - 1.8.1 happens only if Jason, with the 11-15 record in front of him, explicitly
    re-approves **one** item from v1.8 §3 (B). The default is none.
  - Code freeze is **12-05**. After it: "fixes for regressions this plan
    introduced and App Review responses only".
  - "No self-extension."
- **v1.8 §2.3, read 01-31** (the task fires 02-04).
  - KILL → maintenance mode, no further plans.
  - SUCCESS → one more plan is allowed, and it starts with distribution.
  - In between → no new feature plan.
- **v1.7 §6:** no new analytics, server counters or attribution ("zero-tracking is
  the moat").

## 2. Recommended: D+ — maintenance mode plus three $0 store-page items

| # | item | who | when | cost | gate / rollback |
|---|---|---|---|---|---|
| D+1 | **Promotional text, live, no review.** Rewrite it in zh-Hant, en-US, ja and zh-Hans to say what 1.8.0 offers: Vent free (cloud, with consent); the yearly plan's 7-day free trial; one free 痛罵 preview after the first Vent; on-device rewrite only on Apple Intelligence devices. Check every claim against the 1.8.0 code and the live ASC products first (the trial is an intro offer on the yearly product: read it back). ≤ 170 characters each. Jason approves the exact text, since it is public. Apply with `python3 scripts/asc_product_page.py text --version 1.8.0 --live-promo --apply` and read it back. | agent drafts; Jason approves | 11-13 → 11-16 | 1–2 h; Jason 5 min | rollback: re-apply the old text (it is in `metadata/*/promotional_text.txt`, in git) |
| D+2 | **ASO queue for the next binary; nothing submitted now.** Keywords and subtitle change only with a new version. So prepare zh-Hant/en-US/ja edits in `metadata/*` and commit them, marked "ride the next binary". Ideas to check: the zh-Hant subtitle has 15 spare characters; keywords could add 回嘴/毒舌/靠北 if they don't duplicate the name. They apply only if an OS-compatibility binary or an App Review fix ships anyway. | agent | with D+1 | 1 h | not live until a version ships |
| D+3 | *Optional:* **one In-App Event** for Taiwan (no binary). For example, a year-end workplace one (尾牙/年終 season, 12-15 → 01-14). It shows on the product page and can show in search and browse, the channel that brought the TW payer. It needs an event card image and a detail image (sizes per Apple's current spec) and passes ASC review. Its text and images are public, so Jason approves both. The effect can't be measured at this volume; do it only if Jason wants it. | agent drafts; Jason approves | submit by ~12-05 | ≈ 2–3 h | delete the event |
| D+4 | **Maintenance as in D:** the weekly readout and balance tasks; the 11-15 record (scheduled); one production Worker smoke call (zh_TW Vent, ≈ $0.0001) because nothing unattended checks the Worker; App Review answers; the refusal probe after any 27.x point release; the 02-04 final read (scheduled). | agent / tasks | ongoing | — | — |

Total: agent ≈ 1 day, Jason ≈ 15 minutes, $0. No binary, no Worker deploy. The
reads are unchanged, so the 01-31 verdict means exactly what §2.3 said it would.

## 3. Option E — a paid sample through Apple Ads (only if Jason wants to pay for information)

*Not recommended.* Both reviewers rejected it.
- **It buys information that changes no action.** Suppose ads produced a SUCCESS.
  The next plan must "start with distribution". Jason won't post, and at this
  app's prices paid search cannot pay for itself. So nothing would follow from it.
- **It bends the rule's intent.** §2.3 made "traffic-limited" the intended failure
  signal.

If Jason picks it anyway, these corrections from the reviews apply:
- **E0 first, all on Apple's own pages, before any account exists:**
  - Taiwan availability;
  - the new-account credit: amount, and the condition of linking ASC at the top
    level;
  - **how a 17+/18+ app's ads are delivered.** Both reviewers say only to
    verified adults, possibly only with personalized ads on. That is UNVERIFIED
    here and could make the campaign unspendable;
  - whether keywords like 罵人/毒舌 pass Apple's ad content policy.
  - **No E if the credit isn't confirmed** (Argon).
- **Advanced only, never Basic.** Basic has no keyword control and would starve or
  bid broadly. Keywords must match the metadata.
- **Measure in "new downloads", not "installs".** Apple Ads installs include
  redownloads; §2.3 counts first-time units only.
- **Stops, pre-registered:**
  - after US$25, cost per new download > US$2.50, or new downloads ÷ taps < 15 %
    → stop;
  - after 14 days, fewer than 15 new downloads → stop;
  - total cap US$150 including the credit;
  - **hard end 12-31.** `payer_read.py` counts a second paid period only if it is
    dated ≤ 01-31, so a monthly start after 12-31 can never renew inside the window;
  - a §2.4 safety event → stop the same day.
- **Who does what.** Jason creates the account, links ASC, adds payment and sets
  the cap; the agent never does any of these. The agent writes the spec and reads
  the dashboard read-only.
- **No offer-code self-test.** An r320 cancel from Jason's test could be credited
  to a real subscriber in the same storefront (`payer_read.py` r320 matching).
- **Reporting.** ASC can't separate ad installs from organic search, and no
  attribution is added (v1.7 §6). The read reports spend, new downloads and the
  window's starts side by side. It never claims a start came from an ad.

## 4. Option S — one 1.8.1 item (only with Jason's explicit re-approval on/after 11-15)

*Not recommended*: its effect cannot be seen at ~1.5 downloads a week. But it is
the one rule-compliant way to write feature code before 01-31. If Jason picks it,
the item is **B8 Lifetime Pro** (a one-time purchase reaches every downloader,
including subscription-averse ones). Corrected scope, checked against the code on
11-12:
- **Client:**
  - `Shared/Services/StoreService.swift`: the product ids at :14-15 and the checks
    at :75, :77, :230-231 and :256-257, plus `PaywallGate.sortedPlanIDs` (:78);
  - `Shared/Services/PlanCopy.swift:21-30` (copy by product id);
  - `Shared/Services/PurchaseHandoff.swift` (plan ordering);
  - `RoastMateTests/PurchaseHandoffTests.swift`, the paywall row, restore.
- **Worker `cloud-worker/src/auth.js`:**
  - add the id to `PRO_PRODUCT_IDS` (:18);
  - a lifetime branch, because there is no `expiresDate` (:79);
  - a capped token expiry;
  - skip the subscription status check for non-consumables;
  - **an explicit `revocationDate` check.** The existing refund hardening (:94) is
    gated and fail-open, so it is not enough for a purchase that never expires;
  - tests, a preview, 1 production deploy.
- **Tooling:** `scripts/payer_read.py` must count lifetime purchases from SALES as
  §2.3 starts, "not cancelled unless refunded within 14 days" (v1.8 §2.3). Today
  it reads starts only from SUBSCRIPTION_EVENT and would count 0. A lifetime start
  can never reach "a second paid period", so SUCCESS would still need a
  subscription start.
- **ASC:** a new non-consumable `yyh.roastmate.app.pro.lifetime`, with a price
  Jason sets. Whether an account's first non-consumable must ship with a binary is
  UNVERIFIED.
- **Dates:** confirmation 11-15, submit by **12-03**, freeze 12-05. Effort 3–4
  days. The Release-build checks follow the Debug-is-Pro rule.

## 5. Not recommended

| path | why not |
|---|---|
| D (plain) | Fine, and $0. D+ adds only $0 store-page fixes, which plain D leaves stale. |
| Override (a bigger feature plan before 01-31) | Breaks v1.8 §2.1 ("no self-extension") and the stop rule Jason set for exactly this. |
| en-US keywords stuffed with Chinese terms for the TW storefront (Flash) | Which localizations Apple indexes per storefront is UNVERIFIED here. It would damage the US page, and keywords need a new version anyway. |
| Cross-promotion from Jason's other apps (Argon) | Code in other projects. Jason can do it whenever one of those ships; it is not RoastMate work. |
| Web demo SEO on the separate Pages repo (Argon) | Public site change for unknown traffic. Low value; Jason can ask for it. |
| Other paid channels (Meta/IG, Dcard) | New public creative in Jason's name, ad accounts, money: same objections as E, and more. |

## 6. Timeline (D+)

| date | what |
|---|---|
| 11-13 → 11-16 | D+1 promotional text: draft, Jason approves, apply, read back. D+2 metadata queue. The Worker smoke call. |
| 11-15 (Sat) | The scheduled task records the stop rule. Jason re-approves a 1.8.1 item or not (default none). |
| ~12-05 | D+3 event submitted, if Jason wants one |
| Mondays | weekly readout + balance (existing tasks) |
| 02-04 | final read (existing task; re-arms while data is late) |

## 7. Guardrails (unchanged, restated)

- Public text (promotional text, event text and images) goes live only after Jason
  approves the exact words. Nothing is posted or sent in his name.
- ASC changes: one sentence on what and how to roll back, first.
- No account creation, no payment details, no budgets by the agent.
- No AdServices, attribution SDK or new analytics.
- `cloud_sendable_enabled` never turns on. Evaluation spend ≤ $2. No individual
  Worker logs.
- §2.4 kill: `ondevice_permissive_enabled:false` the same day.
- The ASC app id is 6769317103, never `$ASC_APP_ID`. Debug builds are always Pro.
- Builds use `/Applications/Xcode-27.1.app`. Build output stays outside
  `~/Documents`. No simulator is deleted or erased.

## 8. Pre-mortem (D+)

1. **The promotional text promises something 1.8.0 doesn't do**, for example a
   trial on a product without an intro offer in TW. Mitigation: verify every claim
   against the code and the live ASC offer before Jason sees the draft.
2. **The agent drifts into feature work** because the session has little to do.
   Mitigation: §1 and the handoff rules. A new idea goes into the parked list, not
   into code.
3. **Jason doesn't approve the text.** Then nothing changes. That costs nothing,
   and the reads proceed.

## 9. Review synthesis — Gemini 4 Argon (High) + Gemini 3.8 Flash (High), 2026-11-12

Both read the repo read-only (`git status` showed no changes afterwards). Each
claim below was checked before it was accepted.

| # | who | claim | verdict |
|---|---|---|---|
| 1 | both | Pick D, not E: the money buys a label, not a decision; §2.3 made traffic-limited the intended signal | **Accepted.** Recommendation changed to D+ (draft 1 recommended E) |
| 2 | Argon | `payer_read.py` counts starts only from SUBSCRIPTION_EVENT, so a lifetime purchase counts as 0 | **Accepted, verified** (`COUNTED_STARTS`, SALES read only for first-time units). Added to option S as tooling work |
| 3 | Argon | A monthly start after 12-31 can't reach a second paid period by 01-31 | **Accepted, verified** (`second` requires an event dated ≤ hi). E's hard end is now 12-31 |
| 4 | both | B8 scope understated: 4 id checks + `PaywallGate.sortedPlanIDs` + `PlanCopy.swift` + `PurchaseHandoff`; no explicit `revocationDate` check | **Accepted, verified** (`StoreService.swift:14-15, 75, 77, 78, 230-231, 256-257`; `PlanCopy.swift:22, 26`; `auth.js:94` refund hardening is gated) |
| 5 | Argon | An offer-code self-test cancel could be credited to a real subscriber by the r320 matcher | **Accepted** (same territory and subscription, −1..+3 days). The self-test is dropped |
| 6 | Argon | "Search is the only channel that ever brought installs" overstated: 2 app referrer; the TW payer came from browse | **Accepted, verified** (v1.7 :44-45). §0 corrected |
| 7 | Argon | `weekly_readout.py` doesn't split downloads by source | **Accepted, verified.** E's read no longer relies on it |
| 8 | both | Stale promotional text misses the 1.8.0 trial and preview; it can be updated live without review | **Accepted, verified** (`metadata/zh-Hant/promotional_text.txt`; `asc_product_page.py text --live-promo`; strings :36-38, :180). It is D+1 |
| 9 | both | An In-App Event costs $0 and needs no binary | **Accepted as optional** (D+3). Its effect can't be measured at this volume |
| 10 | Argon | Use Advanced not Basic; cost per new download ≤ $2.50; 14-day floor | **Accepted into E** |
| 11 | both | 17+ apps' ads reach only verified adults (maybe only with personalized ads); profanity-adjacent keywords risk policy rejection | **Not verified here** (labelled KNOWN by both, with no source). E0 must check it on Apple's pages before any account exists |
| 12 | Flash | `APP_DAILY_LIMIT_PER_IP=200` could throttle ad users behind carrier NAT | **Rejected:** the limit exists (`wrangler.toml:115`), but ~100 users over 6 weeks cannot get near 200 a day per IP |
| 13 | Flash | Fill en-US keywords with Chinese terms; TW indexes en-US too | **Rejected:** per-storefront indexing is UNVERIFIED, it harms the US page, and keywords need a version |
| 14 | Flash | E "violates spending discipline" ($2 eval cap) | **Rejected as framed:** the $2 cap is for LLM evaluation, not marketing. The substance (spend ≫ revenue) is accepted under #1 |
| 15 | Flash | "No-code distribution experiments" meant free posting only | **Partly accepted:** the text doesn't say so, but #1 decides it anyway |
| 16 | Argon | Draft 1's §3 fix lane ("a broken core flow the ad sample exposes") went beyond §2.1(3) | **Accepted.** The fix lane is now exactly v1.7 §7 + v1.8 §2.1(3) |
| 17 | both | The header claimed reviews and §9 before they existed | **Accepted** (draft-order artefact). Fixed in draft 2 |
| 18 | Argon | Cross-promotion from his other apps; web-demo SEO | **Rejected for this plan** (§5); Jason's call |
