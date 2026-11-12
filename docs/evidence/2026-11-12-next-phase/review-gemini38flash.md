# Review — Gemini 3.8 Flash (High), 2026-11-12, of DEV_PLAN_v1.9 draft 1

Asked via `mcp__gemini__ask_gemini` (agy), workspace = repo, read-only instruction;
`git status` checked afterwards (no changes). Verbatim answer below. Its claims were
checked before use: see DEV_PLAN_v1.9 §9.

---

### 1. VERDICT
**Path D (Maintenance Mode).**
RoastMate has generated $2.54 in 5 weeks, has 0 paying subscribers, and averages ~1.5 downloads/week. Spending $50–$150 on Apple Ads to artificially manufacture 40 installs just to satisfy a self-imposed statistical threshold on 01-31 is throwing good money after bad. Paid search cannot be unit-economic at this conversion rate, and the owner has already stepped back from marketing. Let the 01-31 read fire naturally as traffic-limited/KILL under Path D at $0 cost and zero effort.

---

### 2. FALSE OR UNSUPPORTED CLAIMS IN THE DRAFT

1. **Claimed Reviews and Evidence Synthesis**
   - *Draft*: Lines 3–4 & §9 (lines 190–193) claim the plan was "reviewed separately by Gemini 4 Argon (High) and Gemini 3.8 Flash (High)" and cites raw answers in `docs/evidence/2026-11-12-next-phase/`.
   - *Repo reality*: The directory `docs/evidence/2026-11-12-next-phase/` does not exist, and §9 is an unpopulated placeholder. The text was copied verbatim from [`docs/NEXT_PHASE_PLAN_2026-11.md:21-23`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L21-L23) before any reviews occurred.
   - *Confidence*: Confirmed (100%).

2. **Understated Client Scope for Option E+ (Lifetime Pro)**
   - *Draft*: Lines 122–123 state client work is "a client change in `StoreService.swift` (three hard-coded id sites) and the paywall row".
   - *Repo reality*: In [`Shared/Services/StoreService.swift`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L74-L260), subscription IDs are hard-coded in 4 places (lines 75, 77, 230–231, 256–257), plus the static property declaration at lines 14–15. Crucially, the draft omits changes outside `StoreService`:
     - [`Shared/Services/PlanCopy.swift:21-30`](file:///Users/jason/Documents/RoastMate/Shared/Services/PlanCopy.swift#L21-L30) switches strictly on `monthlyProductId` and `yearlyProductId` and returns `nil` by default; without updating it, the paywall cannot display copy for Lifetime Pro.
     - [`Shared/Services/PurchaseHandoff.swift:55-60`](file:///Users/jason/Documents/RoastMate/Shared/Services/PurchaseHandoff.swift#L55-L60) (`sortedPlanIDs`) only orders yearly vs other IDs.
   - *Confidence*: Confirmed (100%).

3. **Claim that the 01-31 Read Runs §2.3 "Unchanged" with Ad Installs**
   - *Draft*: Line 85 (E5) and lines 29–34 state that "The 02-04 final-read task runs v1.8 §2.3 unchanged. Ad installs count like any other first-time download".
   - *Repo reality*: [`docs/DEV_PLAN_v1.8_2026-11.md:344-348`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L344-L348) explicitly defined the 40-download denominator as an organic distribution test ("missing traffic is the distribution failure the stop rule tests"). Injecting paid ad downloads to artificially avert a "traffic-limited" label fundamentally changes §2.3's registered purpose rather than running it unchanged.
   - *Confidence*: Confirmed (100%).

4. **Unsupported Net Budget Claim ($100 New-Account Credit / $50 Net Spend)**
   - *Draft*: Line 80 (E0) and lines 87–91 claim a cap of "US$150 in total, including Apple's new-account credit" so "Jason pays at most about $50".
   - *Repo reality*: The draft admits the $100 credit is UNVERIFIED (line 92). Apple Search Ads promo credits historically require matching spend thresholds, are currency/region-dependent (TWD in Taiwan), and are not guaranteed unconditional grants. Basing the recommendation on a guaranteed $50 net cap is unsupported.
   - *Confidence*: Confirmed (100%).

5. **Omission of App-Level Worker Per-IP Limits**
   - *Draft*: Lines 98–99 state "The web demo's per-IP cap does not apply to the app."
   - *Repo reality*: While `WEB_DAILY_LIMIT_PER_IP = "8"` does not apply, the app is strictly subject to `APP_DAILY_LIMIT_PER_IP = "200"` ([`cloud-worker/wrangler.toml:114-115`](file:///Users/jason/Documents/RoastMate/cloud-worker/wrangler.toml#L114-L115); [`cloud-worker/src/ipguard.js:14-16`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/ipguard.js#L14-L16)). In Taiwan, where mobile users are heavily concentrated behind cellular carrier-grade NAT (CGNAT) IPs, a burst of ad-acquired users risks hitting this attempt limit and returning 429s.
   - *Confidence*: High (95%).

---

### 3. MISSING LEVERS
Given that 7 of 9 installs came from App Store search and the owner will not post, these concrete, no-code, $0 levers leverage search without external ads:

1. **Cross-Localization Taiwan ASO (English `en-US` Keyword Field)**:
   - In the Taiwan App Store, Apple indexes search keywords from *both* the primary locale (`zh-Hant`) and secondary locale (`en-US`).
   - The `en-US` 100-character keyword field can be filled with Traditional Chinese search queries (e.g., `幫你罵,吵架回嘴,慣老闆,情緒勒索,毒舌,職場發洩,防小人,回信神器`).
   - This doubles indexed Taiwan search keywords for $0 with no code.
2. **In-App Events (IAE) in App Store Connect**:
   - Configured entirely via the ASC web portal (no binary, no code).
   - In-App Events appear directly as large visual cards in App Store search results for relevant keywords.
   - An event such as 「年末職場宣洩祭 / 慣老闆退散」 captures high-intent December/January workplace search traffic for free.
3. **App Store Connect Promotional Text (`promotionalText`)**:
   - Can be updated at any time in ASC while the app is `READY_FOR_SALE` without a binary review.
   - It is currently blank or stale across localizations. Placing the 7-day free trial and free Vent mode directly at the top of the product page costs $0.

---

### 4. APPLE ADS RISKS

1. **17+ / 18+ Age Rating**:
   - **KNOWN**: Apple Search Ads strictly restricts ad delivery for 17+ apps. Users with minor accounts (<18), users who turn off Personalized Ads, or unverified accounts will not see the ads. For niche utility/entertainment apps, this drastically throttles impression volume.
   - **UNSURE**: Specific category-level ad placement bans or localized age-verification filters imposed by Apple in the Taiwan storefront.
2. **Taiwan Availability**:
   - **KNOWN**: Apple Search Ads (Basic and Advanced) is fully available and supported in Taiwan.
3. **Basic vs. Advanced**:
   - **KNOWN**: Basic offers zero keyword targeting or negative keywords. Apple's ML automatically bids on broad terms, burning budget on irrelevant audiences or failing entirely on 17+ apps. Advanced allows exact match keywords and CPA caps, but requires active manual management.
   - **KNOWN**: Apple's promotional credits typically require Advanced accounts and matching spend rather than applying automatically to Basic.
4. **Minimum Budgets**:
   - **KNOWN**: Advanced requires daily campaign budgets. Setting daily caps too low (e.g., $1–$2/day) causes bidding algorithms to starve, resulting in 0 impressions.
5. **Keyword Policy for Insult / Profanity Terms**:
   - **KNOWN**: Apple Search Ads Content Guidelines strictly prohibit profanity, offensive language, vulgarity, and defamation in ad keywords and metadata.
   - **KNOWN**: Target terms like `罵人` (scolding/cursing) or `毒舌` (venomous tongue) risk being flagged, rejected, or throttled during editorial policy review.
   - **UNSURE**: The exact automated blocklist regex applied to Traditional Chinese search terms in Taiwan.
6. **Attribution in App Store Connect**:
   - **KNOWN**: RoastMate has no `AdServices.framework` token call and no third-party attribution SDK (due to the zero-tracking rule).
   - **KNOWN**: In ASC Analytics, Search Ads installs appear only for users who opted into sharing diagnostics with developers (~20–30%).
   - **KNOWN**: Sales reports used by [`scripts/payer_read.py`](file:///Users/jason/Documents/RoastMate/scripts/payer_read.py) aggregate all Product Type 1 units without source attribution. `payer_read.py` cannot distinguish paid ad downloads from organic downloads.

---

### 5. MOST LIKELY FAILURE MODE & CATCHING RULE

- **Most Likely Failure Mode**: **Owner inaction on account setup and payment.**
  On 11-08, Jason declined to post on Threads ("不发thread了吧") and dropped Path A within hours. Setting up Apple Ads requires him to log into Apple Search Ads with his Apple ID, link ASC, provide billing and tax information, and enter a credit card for an app that has earned $2.54 total. The probability that he abandons account setup is high.
- **Pre-Registered Rule That Catches It**:
  - Draft §7 item 3: "If it hasn't happened by 11-26, E ends, D continues, and that is recorded."
  - Combined with the [`docs/DEV_PLAN_v1.7_2026-10.md:263-267`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L263-L267) stop rule on 11-15 (T never occurred because posts were not published -> stop feature work -> Path D maintenance mode).

---

### 6. STOP RULES AND v1.8 §2.1 VIOLATIONS / BENDINGS

1. **Stretching the "Distribution experiments that need no code" Clause**:
   The [`docs/DEV_PLAN_v1.7_2026-10.md:272-273`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.7_2026-10.md#L272-L273) clause was explicitly written to allow free, grassroots developer posting (Threads/PTT/Dcard). Using it to justify setting up a commercial paid advertising campaign ($150) distorts the original intent.
2. **Subverting the Statistical Intent of the v1.8 §2.3 Denominator**:
   [`docs/DEV_PLAN_v1.8_2026-11.md:344-348`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L344-L348) pre-registered 40 first-time downloads as an indicator of organic distribution viability. Artificially buying downloads to clear the 40-unit threshold breaks the integrity of the test. If 3 starts occur from paid ads, §2.1 dictates that "one more plan is allowed, and it starts with distribution," yet the draft admits (lines 93–95) that Apple Ads is structurally unprofitable for this app.
3. **Violating "No Self-Extension" and Default-None via Option E+**:
   Under [`docs/DEV_PLAN_v1.8_2026-11.md:284-291`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L284-L291), when the 11-15 stop rule fires, the default is strictly **none**. Offering Option E+ (Lifetime Pro B8) reopens feature development (client changes, Worker updates, a production Worker deploy, ASC product setup) right before the 12-05 freeze for an app with 0 paying subscribers.
4. **Violating Project Spending Discipline**:
   Standing decisions cap evaluation spend at ≤ $2 and OpenRouter balance top-ups at < $2. Recommending a $150 ad spend (or $50 net out-of-pocket) is 20x to 60x the app's total 5-week revenue ($2.54), violating the project's strict spending constraints.
