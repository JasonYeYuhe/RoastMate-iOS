# Review — Gemini 4 Argon (High), 2026-11-12, of DEV_PLAN_v1.9 draft 1

Asked via `mcp__gemini__ask_gemini` (agy), workspace = repo, read-only instruction;
`git status` checked afterwards (no changes). Verbatim answer below. Its claims were
checked before use: see DEV_PLAN_v1.9 §9.

---

### 1. VERDICT

Pick **Path D (maintenance mode)** unless E0 confirms Apple's **$100 promotional credit** applies, in which case run **Path E (Advanced only, no binary)** with a tighter **CPI ≤ $2.50** stop gate (not $6).
- **Why not E+:** Shipping B8 (Lifetime Pro) burns 3 weeks before the 12-05 freeze, leaves Monthly buyers after 12-31 unable to renew before the 01-31 read cutoff in [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L243), and [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L97-L98) cannot count non-consumable purchases at all.
- **Why D over unsubsidized E:** This app has earned $2.54 in 5 weeks for a solo developer with five other live apps, and [`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L346-L348) explicitly defined `< 40` downloads not as a sample-size bug to fix with cash, but as the distribution failure the stop rule tests.
- **If E runs:** Skip Basic (go straight to Advanced exact-match), stop ads by **12-31** (never extend to 01-24), and cap CPI at **$2.50** after $25 so $150 actually buys ≥ 60 installs.

---

### 2. FALSE OR UNSUPPORTED CLAIMS in the draft

1. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L85) (§2 E5) & [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L121-L125) (§3 Option E+):** Claims the 02-04 final-read task runs unchanged while a B8 Lifetime Pro purchase "counts as a §2.3 start," and lists B8's scope as only [`StoreService.swift`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift), the paywall row, [`auth.js`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/auth.js), and ASC.
   - **What the repo says:**
     - [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L97-L98) and [`collect()`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L170-L210) count starts **exclusively** from `SUBSCRIPTION_EVENT` (`COUNTED_STARTS = {"Subscribe", "Start Introductory Offer"}`) and read `SALES` **only** for app download units (`FIRST_TIME_PTI = {"1", "1F", "1T", "F1"}` at [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L185-L187)). A non-consumable IAP (`IA1` in `SALES`) never appears in `SUBSCRIPTION_EVENT`, so unchanged [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py) counts **0 starts** for every Lifetime Pro buyer.
     - [`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L335-L337) and [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L240-L244) (`verdict()` at [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L284)) require `second >= 1` (`Renew*` / `Paid Subscription from*` / `Crossgrade*`) for `SUCCESS`, which a non-consumable can never satisfy without changing the rule and script.
   - **Confidence:** 100% (verified in code).

2. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L88-L90) (§2 Budget), [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L118) (§3 E+), & [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L153) (§5):** Proposes running or extending ads until **01-24** so those installs feed the 01-31 `v1.8 §2.3` read.
   - **What the repo says:** In [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L240-L244) (and docstring [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L52-L57)), while `Cancel` rows are read through `today`, `second` ("reached a second paid period") enforces `if e["Event Date"] <= H` (`2027-01-31`). Any Pro Monthly subscriber starting after **2026-12-31** (31-day period, [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L142)) renews in February and is **excluded from `second`** by `e["Event Date"] <= H`.
   - **Confidence:** 100% (verified in code).

3. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L122-L125) (§3 Option E+ B8 work list):** Lists "three hard-coded id sites" in [`StoreService.swift`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift) and omits `revocationDate` from the [`auth.js`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/auth.js) changes (`PRO_PRODUCT_IDS`, `expiresDate`, token expiry, status check).
   - **What the repo says:**
     - [`cloud-worker/src/auth.js`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/auth.js#L67-L105) has **no `tx.revocationDate` check** today (correctly noted in [`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L145) but dropped in v1.9); without it, a refunded lifetime JWS mints Pro tokens forever once `expiresDate` and `checkSubscriptionActive` are bypassed.
     - [`Shared/Services/StoreService.swift`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift) has **four** hard-coded ID checks across three methods ([`loadProducts()`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L75) and [`:77`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L77), [`refreshSubscriptionStatus()`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L230-L231), [`currentProTransactionJWS()`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L256-L257)) plus [`PaywallGate.sortedPlanIDs`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L78) (tested in [`RoastMateTests/PurchaseHandoffTests.swift`](file:///Users/jason/Documents/RoastMate/RoastMateTests/PurchaseHandoffTests.swift#L45-L49)).
   - **Confidence:** 100% (verified in code).

4. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L81) (§2 E1) & [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L182-L183) (§7 #4):** Recommends Jason redeem an unused offer code in production after 11-15, use Feral once, and immediately cancel.
   - **What the repo says:** While [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L98) excludes `"Start Offer Code"` from `starts` ([`:200-209`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L200-L209)), its `r320` cancel matcher ([`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L255-L266)) credits anonymous `r320` `"Cancels"` rows to the earliest counted `starts` row in the same territory/subscription within `−1..+3` days. If Jason cancels his offer code via the App Store sheet within 3 days of a real subscriber in the same storefront, [`payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L255-L266) will attribute Jason's `r320` cancel to that subscriber.
   - **Confidence:** 100% (verified in code).

5. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L64) (§2) & [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L141) (§4):** "App Store search is the one channel that has ever brought installs (7 of 9)."
   - **What the repo says:** In the 10-01..11-05 window, 2 of the 9 installs came from **App Referrer** ([`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L42)), and the **only Taiwan paying subscriber ever** (09-19) came from **App Store browse**, not search ([`DEV_PLAN_v1.7_2026-10.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L44-L45)).
   - **Confidence:** 100% (verified in docs).

6. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L80) (E0) & [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L84) (E4):** E0 checks whether ad installs show in ASC under `"App Store search"`, and E4 says the weekly ASC download side already comes from [`scripts/weekly_readout.py`](file:///Users/jason/Documents/RoastMate/scripts/weekly_readout.py).
   - **What the repo says:** [`scripts/weekly_readout.py`](file:///Users/jason/Documents/RoastMate/scripts/weekly_readout.py#L123-L143) only breaks down **TW page views** by `Source Type` ([`:138-140`](file:///Users/jason/Documents/RoastMate/scripts/weekly_readout.py#L138-L140)); it does **not** break down downloads (`dl` / `tw_dl`) by `Source Type` ([`:123-131`](file:///Users/jason/Documents/RoastMate/scripts/weekly_readout.py#L123-L131))—only [`scripts/asc_analytics.py`](file:///Users/jason/Documents/RoastMate/scripts/asc_analytics.py#L105-L108) prints `Source Type` for downloads.
   - **Confidence:** 100% (verified in code).

7. **Draft [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L3-L5) (Header):** States the draft "was reviewed separately by Gemini 4 Argon (High) and Gemini 3.8 Flash (High). §9 has what changed because of them…"
   - **What the repo says:** [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L190-L193) §9 is still an unfilled placeholder.
   - **Confidence:** 100% (verified in file).

---

### 3. MISSING LEVERS

1. **Update live `promotionalText` right now via `--live-promo` (no binary, no review, $0):**
   - [`metadata/zh-Hant/promotional_text.txt`](file:///Users/jason/Documents/RoastMate/metadata/zh-Hant/promotional_text.txt#L1) uses 122/170 chars and **never mentions the 7-day free trial (`年訂 7 天免費試用`) or the 1 free 痛罵 Pro preview** shipped in 1.8.0. [`scripts/asc_product_page.py`](file:///Users/jason/Documents/RoastMate/scripts/asc_product_page.py#L31) (`text --version 1.8.0 --live-promo --apply`) can push this to the live store immediately without App Review, addressing Taiwan's weak **20 page views → 1 download (5%)** conversion ([`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L43)) before any ad spend.
2. **Publish an App Store In-App Event for Taiwan (no binary, no social account, $0):**
   - Parked as A6 in [`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L91) and dropped only when D started ([`HANDOFF_v1.8_NEXT_SESSION.md`](file:///Users/jason/Documents/RoastMate/docs/HANDOFF_v1.8_NEXT_SESSION.md#L119)). An In-App Event needs no binary, is submitted in ASC (not a social post), runs for up to 31 days, expands search cards, and surfaces in **App Store Browse**—the channel that brought the only TW payer ([`DEV_PLAN_v1.7_2026-10.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L45)).
3. **Cross-promote from Jason's 5 other live apps ($0):**
   - [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L13-L14) notes the vendor (`94126306`) has **six apps** with daily `SALES` rows (e.g., `ColorArchive`, `Soundpost` in [`HANDOFF_v1.8_NEXT_SESSION.md`](file:///Users/jason/Documents/RoastMate/docs/HANDOFF_v1.8_NEXT_SESSION.md#L435)), and 2 of the 9 recent installs came from **App Referrer** ([`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L42)). Adding a "More by this developer" link or cross-promo in any sister app that touches zh-Hant/en users costs $0 and needs no social posting.
4. **Web demo (`jasonyeyuhe.github.io/RoastMate`) SEO + campaign link (`?pt=128677340&ct=web&mt=8`):**
   - The live GitHub Pages web demo already gets organic cloud traffic ([`DEV_PLAN_v1.7_2026-10.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L38), [`cloud-worker/src/ipguard.js`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/ipguard.js#L33)). Adding zh-Hant meta/title tags for Taiwan search queries (`幫你罵`, `罵人產生器`, `吵架回嘴 AI`) and the existing `pt=128677340` App Store link on the Pages repo needs no app binary and no social posts.
5. **If any version is ever opened (or if E2 runs): fix the keyword mismatch between E2 and ASO:**
   - [`metadata/zh-Hant/name.txt`](file:///Users/jason/Documents/RoastMate/metadata/zh-Hant/name.txt#L1) uses **3/30 chars** (`幫你罵`), [`metadata/zh-Hant/subtitle.txt`](file:///Users/jason/Documents/RoastMate/metadata/zh-Hant/subtitle.txt#L1) uses **15/30 chars**, and [`metadata/zh-Hant/keywords.txt`](file:///Users/jason/Documents/RoastMate/metadata/zh-Hant/keywords.txt#L1) uses **83/100 chars**—and omits `回嘴`, `毒舌`, and `靠北`, even though E2 ([`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L82)) bids on `回嘴` and `毒舌` (Apple Ads relevance scores penalize bidding on terms absent from your metadata).

---

### 4. APPLE ADS RISKS

- **17+/18+ age rating (`HANDOFF_v1.8_NEXT_SESSION.md:477`):**
  - **KNOWN:** Apple Ads allows 17+/18+ Lifestyle apps to run, **but** restricts ad delivery to accounts verified as 18+ that have **Personalized Ads enabled**. Because ~75%+ of iOS users keep Personalized Ads off (and Apple Ads disables demographic/age-verified delivery on non-personalized requests), an 18+ rating severely throttles addressable search impressions and forces reliance on Advanced with "All users" / no audience refinements (where age-gating still suppresses delivery to unverified accounts).
- **Taiwan availability:**
  - **KNOWN:** Apple Ads (both Basic and Advanced) is available in the Taiwan (`TW`) storefront.
  - **UNSURE:** Whether Apple's one-time **$100 new-account promotional credit** currently applies to accounts billing in/targeting Taiwan and whether it applies to Basic vs. Advanced.
- **Basic vs. Advanced:**
  - **KNOWN:** **Do not use Basic.** Basic has no keyword controls and relies on organic search velocity and automated CPI learning; for a 17+/18+ app with ~11 TW impressions/week, Basic will almost certainly fail to scale and trip E3(b) (`< $10 spent in 14 days`). Advanced allows immediate high-CPT bidding on exact-match keywords (`慣老闆`, `吵架`, `罵人`).
- **Minimum budgets:**
  - **KNOWN:** Neither Basic nor Advanced has a minimum spend floor that blocks a $150 test (Advanced allows daily caps as low as $1–$5/day; Basic allows small monthly budgets).
- **Keyword policy for insult/profanity terms:**
  - **KNOWN:** Apple Ads Content Policies prohibit "profanity, obscenity, vulgarity, or offensive language" and harassment/bullying content in **ad creative and app metadata**. While Advanced allows bidding on keywords like `罵人`, `吵架`, `毒舌`, `慣老闆`, putting an app named **「幫你罵」** (`AI 陪你發洩，把氣話罵個痛快`) into Apple Ads triggers editorial review of the product page, carrying a real risk of **campaign/app suspension for Offensive Content** even though App Review approved the binary.
- **Attribution in App Store Connect (without AdServices):**
  - **KNOWN:** In ASC Analytics, Apple Ads installs are bucketed inside **`Source Type = App Store search`** (indistinguishable from organic search), and without `AdServices` (`v1.7 §6`), **neither Apple Ads nor ASC can tell whether a subscription start came from an ad install or an organic install**.
  - **KNOWN:** Apple Ads dashboard "Installs" (`Tap-Through Installs`) counts **First-Time Downloads + Redownloads** combined, whereas [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L97) counts **only First-Time Units (`1/1F/1T/F1`)**—so Apple Ads "Installs" will overstate the §2.3 denominator.

---

### 5. The single most likely way this plan fails, and the pre-registered rule that should catch it

- **Most likely failure mode:** **The E3(a) `$6 CPI` gate and the `$150` budget cap contradict each other (`$150 / $5 CPI = 30 installs`), and Taiwan's measured 5% page-view-to-download rate (`20 PV → 1 install`, [`NEXT_PHASE_PLAN_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L43)) means either the campaign starves on impressions or spends all $150 at a $3.50–$5.99 CPI to buy only ~25–35 first-time units**—passing E3(a), exhausting the $150 cap, and *still* ending under 40 first-time units (or with a sample too small to separate a 0% from a 4% conversion rate).
- **Pre-registered rule that should catch it (replace E3a/b):**
  1. **Tighten E3(a):** After the first **US$25** spent, stop and revert to D if **Cost Per New Download (`New Downloads` in Apple Ads, excluding redownloads) > US$2.50** OR **Tap-Through Conversion Rate (New Downloads ÷ Taps) < 15%** (proving the TW product page is rejecting paid searchers).
  2. **Tighten E3(b):** After **14 days**, stop and revert to D if **fewer than 15 New Downloads** have been delivered at the bid cap.
  3. **Hard stop on 12-31 (drop the 01-24 extension):** Never run ads past **2026-12-31**, because [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L243) ignores Monthly renewals (`CPP >= 2`) occurring after `2027-01-31`.

---

### 6. Anything in the stop rules / v1.8 §2.1 that the draft violates or bends

1. **Bends `v1.8 §2.3` on the 40-download threshold ([`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L346-L348)):**
   - [`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L346-L348) explicitly states: *"If the window ends with fewer than 40 first-time downloads… the verdict is recorded as 'traffic-limited'. **The consequences in §2.1 do not change, because missing traffic is the distribution failure the stop rule tests.**"* Treating `< 40` downloads as an instrumentation problem to solve with unprofitable paid ads (`DEV_PLAN_v1.9_2026-11.md:29-34, 91-93`) bypasses the exact distribution test `v1.7 §7` and `v1.8 §2.3` were written to enforce.
2. **Violates `v1.8 §2.1(3)` ([`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L290-L291)) on post-12-05 code changes under Path E:**
   - [`DEV_PLAN_v1.8_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L290-L291) sets a hard **12-05** code freeze after which only *"fixes for regressions this plan introduced and App Review responses"* are permitted (plus the 1/year OS-compatibility binary in [`DEV_PLAN_v1.7_2026-10.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L271-L273)). [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L109-L110) (§3) widens this to *"a fix for a broken core flow that the ad sample exposes, such as a crash, or the purchase or Vent flow failing in zh_TW"* with no 12-05 cutoff and no requirement that the bug be a 1.8.0 regression.
3. **Bends `v1.8 §2.3` window homogeneity under Option E+ ([`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L117-L118)):**
   - [`DEV_PLAN_v1.9_2026-11.md`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.9_2026-11.md#L117-L118) claims holding ads until 1.8.1 ships (~12-07) means "the sample sees a single product," but [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py#L303) and [`scripts/weekly_readout.py`](file:///Users/jason/Documents/RoastMate/scripts/weekly_readout.py#L58) still count from `2026-11-05` (mixing ~4.5 weeks of 1.8.0 installs with 1.8.1 installs) and, as noted in §2 #1, fail to count B8 non-consumable starts or second periods under `v1.8 §2.3`.
