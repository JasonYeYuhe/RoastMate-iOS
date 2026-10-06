# RoastMate — Next-Phase Plan (v1.7): fix what every visitor sees, then go get visitors

_Drafted 2026-10-07 against the live ASC API, the live store, the live Worker
config and the code at `ee0654e`. Every number below was measured that day.
**Revised the same day after review by Gemini 3.1 Pro (High) and Gemini 3.8
Flash (High) via `agy` — both said SHIP-WITH-FIXES and both said the first
draft still smuggled in feature work for an audience of one.** §9 records what
changed and why. Supersedes the open parts of `DEV_PLAN_v1.6_2026-09.md`._

---

## 0. Where we actually are (measured 2026-10-07)

**Live:** iOS + macOS **v1.6.0 build 22** (released 2026-09-27 22:33 UTC).
Worker `200d240c`. Live flags: `vent_cloud_enabled:true`,
`roommate_group_enabled:true`, `echoes_enabled:true`, `share_card_enabled:false`,
`share_card_visible:true`, `cloud_sendable_enabled:false` (retired forever).
Mainland China delisted 2026-09-27; Taiwan is the chosen first market.

**Business numbers** — `python3 scripts/asc_analytics.py --since <date>` (new,
read-only; de-duplicates the repeated processing-date rows):

| window | first-time downloads | purchases | impressions | page views |
|---|---|---|---|---|
| 09-15 → 09-27 (CN still listed) | 9 (CN 5, TW 2, US 2) | Pro Monthly TW · Credits 10 CN | 342 (CN 177) | 37 |
| 09-28 → 10-04 (after v1.6.0 + delisting) | **2** (TW 1, US 1) | **Pro Monthly US** | **96** (US 37, JP 23, TW 8) | **3** |

- **The first two paying subscribers exist.** TW 2026-09-19 and US 2026-10-04,
  both `Full price subscription start`, both **converted on the day they
  downloaded**, both Pro Monthly. Proceeds since 09-15: $5.16. First renewals
  are due ~10-19 (TW) and ~11-04 (US).
- **0 offer-code redemptions** (no offer events in the subscription report);
  3 creator emails sent 09-28, 0 replies, one follow-up each sent 10-07.
- **Delisting CN removed about half of all impressions** (177 of 342 in the
  window before). What's left is ~14 impressions/day, mostly US and JP.
- **Cloud usage is real but tiny:** OpenRouter spend $0.0409 → $0.0471 between
  09-28 and 10-07 (≈45 generations at ~$0.00013 each — app + the web demo
  combined, no way to split them without new collection). Balance $9.95,
  auto-top-up OFF.
- Ratings/reviews: still 0. The rating prompt IS wired (`RoastEngine.swift:178,
  215, 332` → after 3 successful generations in a session); volume is the
  reason, not a bug.

**What the two subscribers tell us, and what they can't.** Both paid within a
day of installing, at full price, from App Store browse (TW) and search (US).
At n=2 that is an anecdote, but it points one way: the first session and the
paywall are not where people are lost — the top of the funnel is. We cannot
ask them why: the app has no accounts and no contact channel by design (the
zero-tracking moat). The Settings support link (`SettingsView.swift:236`) is
the only path, and it is theirs to use.

## 1. What the evidence says

Three findings, all verified on 10-07, none known before today:

1. **The product page is wrong for every storefront that is open.** The iOS
   1.6.0 version has screenshots **only under en-US** (4 × `APP_IPHONE_65`);
   zh-Hant, zh-Hans and ja have **no screenshot sets**, so every locale falls
   back to en-US. Those 4 images are **Simplified-Chinese real-device captures
   from 2026-05-15** (`metadata/screenshots/iphone screenshots/IMG_569*.PNG`),
   and they show **发泄 (Vent) with a lock icon** — false since v1.6.0. So a US
   or Japanese searcher sees Chinese UI, a Taiwan searcher sees Simplified, and
   everyone sees the headline free feature presented as locked. Search results
   render the first screenshots inline, so this hits impressions → taps, which
   is exactly where the funnel is thinnest (96 → 3).
   The local "zh_Hant" set cannot replace them: 5 of its 6 PNGs are
   byte-identical (md5 `43072bbc…`) and show the **English onboarding page** —
   the screenshot pipeline captured onboarding, not the app.
2. **The paywall header still sells Vent as Pro.** `paywall.body`
   (`PaywallView.swift:77`) reads "Vent Mode (private draft + rewrite) ·
   Savage · …" in all four locales and omits Feral. Vent has been free since
   v1.6.0. This is the same defect class v1.5/v1.6 existed to remove — copy
   promising what the code does not do — and it sits on the purchase screen.
   (The other claims hold: free history is pruned at 30
   (`HistoryService.swift:96`), 24 styles of which 16 are Pro, unlimited
   generations.)
3. **Pro's two Explore surfaces are invisible to every paying user.** Echoes and
   the roommate group render only when `ExploreView.isZhHansLocale()`
   (`ExploreView.swift:138-147`) is true. A Taiwan phone reports `zh_TW`, a US
   phone `en_US` — so neither subscriber can see either feature, and with CN
   delisted the roommate group has essentially no reachable audience. **This
   plan does not fix that** (see §6 and §9 — both reviewers called building it
   now feature work for one user). It is recorded so nobody "discovers" it again
   and so the paywall never starts advertising either surface. (Also: the check
   misses `zh_CN` — lowercased to `zh_cn`, underscore — and `zh_SG`.)

Plus two smaller ones:

4. **Shared cards point at a competitor.** Measured via the iTunes Search API
   on 10-07: a **different app named "RoastMate" is #1** in TW, US, HK and JP;
   ours is #2–#3. Terms that rank us **#1**: "RoastMate AI" (US, JP, TW),
   「幫你罵」 (TW, HK), 「帮你骂」 (TW, US). Two strings are involved, and the
   first draft only knew about one:
   - every card shared today carries a hardcoded **"RoastMate"** wordmark
     (`ShareCardView.swift:131`, `Text("RoastMate")`) — the card is
     live (`share_card_visible:true`), so anyone who searches what's printed
     on it finds the other app first;
   - `sharecard.findus` ("Search RoastMate on the App Store") renders only with
     the growth badge (`showsGrowthBadge` ← `share_card_enabled`, currently
     false), alongside a QR to the App Store link.
5. **Every cloud request still tries the dead Groq model first.** `index.js`
   attempts Groq (`qwen/qwen3.6-27b`, 404 since ~09-15) before OpenRouter, and
   OpenRouter is a single model (`DEFAULT_MODEL =
   qwen/qwen3-30b-a3b-instruct-2507`). One model retirement — which is what
   killed Groq — takes Vent, Feral (a Pro feature both subscribers paid for)
   and the roommate group down together.

**The verdict.** v1.6's lesson stands — distribution, not features, is the
bottleneck. The distribution surface we control most directly is the product
page, and it has been showing the wrong language and a false lock to every
visitor. Fix that and the paywall copy in one small binary, then spend the
month on distribution in Taiwan, with a stop rule that tests whether the
distribution actually happened.

---

## 2. Phase 0 — Worker (no binary, timebox 2 hours)

- **P0.1 — Remove the single point of failure, minimally.** (a) Skip the Groq
  hop — it 404s on every request; gate it off by env, keep the code. (b) Pass
  OpenRouter's native `models: [primary, secondary]` so a retirement of one
  model falls through inside the same request. Pick the secondary from
  `evals/runs/2026-05-23-backend-compare-zh-vent.md`; check it with **8 vents**
  (4 zh-Hant, 4 zh-Hans) through `npx wrangler dev --remote --port 8799`:
  real output, no fully-Simplified zh-Hant reply, no leaked reasoning. Not a
  matrix, not a latency study. `node --test` green; record the new rollback id
  (current prod `200d240c`, previous `df0123b3`).
  If it doesn't fit in the timebox, ship (a) alone.
- **P0.2 — No new telemetry.** Readouts come from `scripts/asc_analytics.py`,
  the OpenRouter balance log and the subscription-event report. Zero-tracking
  is the moat.

## 3. Phase 1 — v1.7.0 / build 23: one small honest binary (target: submitted 10-10)

Copy, one wordmark, one deletion, and the product page. No prompts, no
billing, no gates, no new surfaces.

- **P1.1 — Paywall header.** Rewrite `paywall.body` in 4 locales:
  Feral · Savage · unlimited generations · all 24 styles · argument simulator
  · unlimited history. No Vent, no Echoes, no roommate group (invisible to
  most users — see §1.3). Guard the class: a preflight grep (or a unit test
  over the `.strings` files) that fails if any locale's `paywall.body` names
  the Vent term (Vent / 发泄 / 發洩 / 吐き出し).
- **P1.2 — Shared cards name the app the way the store finds it.** The card
  wordmark becomes a localized string: en/ja "RoastMate AI", zh-Hant 「幫你罵」,
  zh-Hans 「帮你骂」 (the measured #1 terms; also the store names in those
  locales). `sharecard.findus` follows suit. Re-measure the four searches on
  the day of submission; rankings move. Render the card in all 4 locales and
  look at it — CJK at that size may need the font size adjusted.
- **P1.3 — Delete the research tile** (`SettingsView.swift:12-25, 142+`).
  Interviews were dropped 09-28; the tile still says "paid 30-min interview"
  and leads to a closed form until its hard-coded 11-01 sunset.
- **P1.4 — Product page (rides the 1.7.0 version record; screenshots and
  metadata are version-scoped and only editable there).** The highest-leverage
  item in the plan — both reviewers agree.
  - New screenshot sets for **en-US, zh-Hant, ja, zh-Hans**, current UI, Vent
    unlocked, 6.9" (`APP_IPHONE_67`; replace the 6.5" Simplified set). First
    fix the pipeline: `scripts/screenshots.sh` produced the onboarding page
    for 5 of 6 shots although `ScreenshotTests.swift:32` claims `-uitest`
    skips onboarding — find out why before regenerating. Gate: every PNG's md5
    distinct, and **look at every image** before upload.
  - The first screenshot per locale shows a filled Vent draft in that locale
    (the result card, not the empty form) — search results render it inline.
  - Upload via the ASC API (`appScreenshotSets` → reserve → PUT parts → commit
    with checksum); read back the set count per locale. macOS 1.6.0, measured:
    en-US 3 × `APP_DESKTOP`, zh-Hans 4, **zh-Hant and ja none**. Fill zh-Hant
    on macOS only if the iOS work makes it cheap.
  - **zh-Hant keywords: rewrite in Taiwan vocabulary.** The current list
    (`metadata/zh-Hant/keywords.txt`) is the zh-Hans list converted character
    by character — 嘴替, 回懟, 懟人, 陰陽怪氣, 高情商 are mainland slang.
    Candidates: 靠北, 慣老闆, 情勒, 奧客, 嘴砲, 抱怨, 發洩, 罵人, 吵架, 職場.
    This is judgment, not measurement (Apple publishes no search volume), so
    keep the terms that already work (we rank #1 for 幫你罵 regardless) and
    don't touch en/ja keywords.
- **P1.5 — Ship both platforms**, same path as v1.6.0:
  `build-upload-asc.sh` (iOS, then macOS) → `asc_bind_version.py` (needs
  `build/v1.7.0-release-notes*.md`, all 4 locales) → screenshots, keywords,
  reviewer notes → `asc_submit_review.py`. Probe codesign first (global
  CLAUDE.md). Gate: preflight 80/0 on `RoastMate-UITests`, or the v1.6.0
  control if not. One Release-build check (disposable iOS 18.5 device, recipe
  in the v1.6 handoff): the paywall header in zh-Hant and a shared card's
  wordmark.

## 4. Phase 2 — distribution in Taiwan (the actual work of this wave)

Starts the day 1.7.0 and its product page are live — not before, because every
visitor lands on that page.

- **P2.1 — Community posts, three, honest, as the developer.** Both reviewers'
  main "missing" item. The agent drafts; **Jason posts or confirms the exact
  text** (the accounts are his; the agent is not signed in to Threads/IG and
  will not solve CAPTCHAs).
  - Threads × 2 (Taiwan's live platform for this): one showing a real
    before/after (a vent draft → the sendable version) on a common TW
    situation (慣老闆, 奧客, 室友), one plain "I made this, it's free to vent".
  - Dcard **or** PTT × 1 — **read the board's self-promotion rules first**;
    both police ads, and a removed post or a ban is worse than no post. Post
    only where a developer sharing their own app is explicitly allowed, and say
    you are the developer in the first line.
  - Copy rules from the kit stand: no overclaiming (the rewrite is on-device,
    Apple Intelligence only), disclose auto-renew if a code is offered,
    合作/業配 labels if anyone posts for us.
- **P2.2 — Creator outreach decision on 10-21.** Batch 1 is closed (one
  follow-up, never another). Any reply → batch 2 from the backups (PLGM
  podcast, poopoo.studio, 小儀), same rules, Jason confirms each send. Zero
  replies → no more cold creator email; record 0/3 in the kit and put the
  effort into P2.1.
- **P2.3 — Flip `share_card_enabled`** once 1.7.0 is live. It adds the QR (a
  direct App Store link — works with no search) and the find-us line. 1.6.0
  binaries will show the old line next to a working QR; with a base this small
  that is accepted, not engineered around. `share_card_visible:false` is the
  kill.
- **P2.4 — Provider token `pt=`** for QR attribution — Jason's (ASC web UI,
  App Analytics → Campaigns), or the agent in Chrome with his session if he
  says so.

## 5. Phase 3 — cut (was: the roommate group in Traditional Chinese)

The first draft planned v1.8.0 = roommate group in zh-Hant, justified by one
Taiwan subscriber. Both reviewers: cut. They are right — it is the pattern
v1.6 diagnosed, days of prompt/persona/eval work for an audience that does not
exist yet. **Revisit only if** TW + HK first-time downloads reach **≥ 10 a week
for two consecutive weeks**. If that happens, the scope list is in git history
(this file, first revision) and the gate is a 20-scenario zh-Hant eval:
parse-fallback ≤ 10 %, 0 fully-Simplified transcripts.

## 6. Cut, with the reasons recorded

| cut | why |
|---|---|
| zh-Hant roommate group (old Phase 3) | §5. |
| Roommate eval on the OpenRouter model (old P0.1) | Both reviewers: the feature has no reachable audience (zh-Hans-only, CN delisted). The `roommate_group_enabled` kill-switch still works if a zh-Hans user ever reports garbage. Part of §5's gate if it is revived. |
| Explore gate → `contentBucket` (old P1.3) | Only widens Echoes/roommate to `zh_CN` (delisted) and `zh_SG`. Same bug class, near-zero users. Logged as known-unfixed. |
| Wallet reserve/commit/release | Still bounded: ≤ 1 unbilled generation per wallet exhaustion, ~$0.0003, in the user's favour. |
| Classic Echoes / roommate in en, ja, zh-Hant | No market signal. |
| Pricing / Pro reframe | 2 of 2 subscribers took Pro Monthly at full price on day 0. |
| New analytics / server counters / a way to contact subscribers | Zero-tracking is the moat. |
| Restoring CN | Needs 备案; nothing changed. |
| Latency study, model matrix, Worker CI, opencc, notifications, keyboard, rename | Same reasons as v1.6 §2. |

## 7. Decision calendar and the stop rule

| date | read | from | decides |
|---|---|---|---|
| 10-12 | OpenRouter balance (weekly task) | `scripts/openrouter-balance.sh` | top up by hand < $2 |
| ~10-19 | TW subscriber renews or not | `asc_analytics.py` subscription events | record it |
| 10-21 | creator replies | Gmail threads in the outreach log | P2.2 |
| ~11-04 | US subscriber renews or not | same | record it |
| **11-15** | **stop rule** | `asc_analytics.py` | below |

**Stop rule.** It tests whether distribution *happened* and whether it
*worked*, using only numbers we cannot edit (ASC first-time downloads and
subscription starts):

> Let **T** = the later of (1.7.0's product page live) and (the third P2.1 post
> published). On **11-15**, or 4 weeks after T if that is later:
> - **If T never happened by 11-15** (posts not published), distribution
>   isn't happening → **stop feature work**.
> - **Otherwise stop** if, over the 4 weeks after T, first-time downloads
>   (all territories) average **< 5 / week** (baseline 2 / week) **and** there is
>   **no new paying subscriber** beyond the two that exist today.

"Stop" means maintenance mode: the weekly balance check, the kill-switches,
one OS-compatibility binary a year, no new features. Distribution experiments
that need no code may continue. Passing the rule earns the next plan, not a
feature list — v1.3 through v1.6 each found a reason to keep building, and this
rule exists so v1.7 cannot.

## 8. Guardrails (unchanged, restated)

- Never render the raw vent on a shareable image.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted **false**; anything
  that spends a credit calls `generateDetailed` and checks provenance.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`, `Redactor.maskToken`,
  `AppLanguage.contentBucket`, `CuratedNoticeBanner`.
- CJK lists: an UNPAIRED term is the bug class; the parity test guards the rule.
- Copy must describe what the code does on every device the app ships to.
  Re-read every user-facing string you touch against the code path behind it —
  the v1.6.0 diff fixed the paywall's feature list and left its header selling
  Vent.
- Debug is always Pro — verify paywall/credits only in Release with a control.
- No third-party SDK. Never flip `cloud_sendable_enabled`. Never post or send
  in Jason's name without his confirmation of the exact text and destination.

## 9. Review synthesis — Gemini 3.1 Pro (High) + Gemini 3.8 Flash (High), 2026-10-07

Both via `agy` with read access to the repo, same prompt. **Both:
SHIP-WITH-FIXES.** Every code claim they marked VERIFIED was re-checked here.

| # | source | finding | applied |
|---|---|---|---|
| 1 | Both | Phase 3 (zh-Hant roommate group) is displacement — building for one subscriber | **Cut** (§5), with a numeric revisit condition |
| 2 | Both | P1.5 product page is the highest-leverage item; fixing it is distribution work | Kept, moved to the centre of Phase 1 |
| 3 | Both | Paywall header sells Vent (verified `zh-Hant.lproj:157`, `PaywallView.swift:77`) | Kept P1.1 |
| 4 | Both | Missing: grassroots distribution in TW communities (Threads, Dcard, PTT) | **New P2.1**, with the platforms' self-promo rules as a hard precondition |
| 5 | Both | Stop rule too late and too lenient | **Rewritten** (§7): earlier, and conditional on the distribution work actually happening — Flash's key point |
| 6 | Pro | Roommate eval (old P0.1) is displacement — zero reachable audience | **Cut** |
| 7 | Flash | Worker secondary-model work is over-engineering; just drop the Groq hop | **Partly**: kept OpenRouter's native fallback (Pro endorsed it; Feral is what both payers bought) but cut to 8 samples and a 2-hour timebox, with "ship the Groq skip alone" as the fallback |
| 8 | Flash | Explore-gate refactor (old P1.3) + zh-Hans-SG measurement is displacement | **Cut** — with Phase 3 gone it only helps delisted/near-zero locales |
| 9 | Both | Flipping `share_card_enabled` shows 1.6.0's competitor string | Accepted as small; **plus a finding neither reviewer had**: the findus line only renders with the badge, but every card shared *today* carries a hardcoded "RoastMate" wordmark → new P1.2 scope |
| 10 | Flash | Rewrite zh-Hant ASO for Taiwanese search terms | **Applied** to keywords — and the current list turned out to be the mainland list in Traditional characters |
| 11 | Pro | Find out why the two subscribers paid | **Not possible** without a contact channel (no accounts, zero tracking); what the data does say is recorded in §0 |
| 12 | Flash | 20–30+ creator DMs; stop rule at < 40 TW downloads / 30 days | **Rejected**: 0/3 replies is not a reason to send 30 more of the same; the kit's "three, then read" stands and effort moves to P2.1. 40/month is a 10× bar from a 4/month base — it would trigger on noise, not on the product |

**Citations, checked:** every finding's substance held. Pro's line numbers were
all right (`wrangler.toml:23` is the "Groq primary is dead" status comment).
Flash's were not: it cited `en.lproj/Localizable.strings#L452` for
`paywall.body` (a blank line; the key is at 157) and
`zh-Hant.lproj/Localizable.strings#L497` for `sharecard.findus` (that line is
`sharecard.comeback_eyebrow`; the key is at 500) while marking both
VERIFIED IN CODE — the failure mode §6–7 of the v1.6 plan recorded. Treat
advisor citations as leads, not evidence.
