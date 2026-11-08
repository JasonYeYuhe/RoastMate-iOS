Model: gemini-3.8-flash-high (via agy-backed mcp__gemini__ask_gemini, workspace /Users/jason/Documents/RoastMate, read-only instruction) — answer received 2026-11-08. Verbatim, unedited. It reviewed the FIRST draft of docs/NEXT_PHASE_PLAN_2026-11.md (line numbers refer to that draft). What was accepted or rejected after checking: the plan's §7.

---

### (1) Recommended Path

I pick a **Strictly Bounded Path A that pivots immediately to Path D on 11-15 if posts are not live (A → D)**. 

Path A's core premise is correct: reach is the total bottleneck (78 Taiwan impressions and 1 install over 5 weeks), making another feature binary—whether Path B's cloud rewrite for 0 paying users or Path C's Lifetime Pro—a distraction from testing market demand. However, Path A as written in [docs/NEXT_PHASE_PLAN_2026-11.md](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L51-L75) is too lenient: it plans 11 weeks of passive readouts and batch 2 creator drafts even if Jason continues to defer posting. Jason should give external distribution a single, focused 7-day push this week; if the three posts are not live by 11-15, the v1.7 stop rule fires, and RoastMate should immediately enter Path D (maintenance mode) rather than drifting to 2027-01-31.

---

### (2) False or Unsupported Claims in docs/NEXT_PHASE_PLAN_2026-11.md

1. **Review verdicts in §7 are missing** ([`NEXT_PHASE_PLAN_2026-11.md:4-5`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L4-L5) vs [:124-127](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L124-L127)) **[VERIFIED]**:
   Lines 4–5 state: *"It was reviewed separately by Gemini 4 Argon (High) and Gemini 3.8 Flash (High); §7 has their verdicts and what changed because of them."* In reality, §7 is an unpopulated placeholder (*"_Filled in after the reviews..."*).
2. **01-31 Exit criteria contradict v1.8 §2.3** ([`NEXT_PHASE_PLAN_2026-11.md:70`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L70) vs [`DEV_PLAN_v1.8_2026-11.md:349-357`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L349-L357)) **[VERIFIED]**:
   Line 70 claims success on 01-31 is *"downloads ≥ 5/week over the 4 weeks after T, or a new start"*. This is false. [DEV_PLAN_v1.8 §2.3](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L349-L357) explicitly requires **all three**: ≥3 new starts, ≥2 not cancelled within 3 days, and ≥1 renewing/converting; fewer than 40 downloads or ≤1 new start is an explicit **KILL**. The plan incorrectly applies the v1.7 11-15 stop-rule threshold as the 01-31 phase exit gate.
3. **Billing Grace Period efficacy and setup** ([`NEXT_PHASE_PLAN_2026-11.md:60`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L60) vs [`brief-2026-11-15.md:67-68`](file:///Users/jason/Documents/RoastMate/docs/evidence/2026-10-27-v18-plan/brief-2026-11-15.md#L67-L68)) **[VERIFIED]**:
   Item A2 asserts turning on Billing Grace Period *"Keeps a subscriber's Pro while Apple retries a failed charge"* and lists *"agent or Jason sets it"*. Per Apple documentation, Billing Grace Period does not apply retroactively to active billing retries (the US subscriber entered retry on 11-04 when Grace Period was off). Furthermore, the App Store Connect REST API does not support enabling Grace Period; it requires manual configuration by the account holder in the ASC web portal.
4. **Pre-emptive stop rule override** ([`NEXT_PHASE_PLAN_2026-11.md:12-13`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L12-L13) vs [`DEV_PLAN_v1.8_2026-11.md:283-285`](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L283-L285)) **[VERIFIED]**:
   Lines 12–13 state: *"Choosing path B or C after reading this page counts as that re-approval."* Under [DEV_PLAN_v1.8 §2.1](file:///Users/jason/Documents/RoastMate/docs/DEV_PLAN_v1.8_2026-11.md#L283-L285), 1.8.1 defaults to "none" if the rule fires on 11-15 and requires explicit re-approval in chat *with the 11-15 brief and actual recorded rule result in front of Jason on 11-15*, not a week prior.
5. **Lifetime Pro technical barrier** ([`NEXT_PHASE_PLAN_2026-11.md:95-99`](file:///Users/jason/Documents/RoastMate/docs/NEXT_PHASE_PLAN_2026-11.md#L95-L99)) **[VERIFIED]**:
   The claim that Lifetime Pro requires changes to [`cloud-worker/src/auth.js`](file:///Users/jason/Documents/RoastMate/cloud-worker/src/auth.js#L18-L21) and [`StoreService.swift`](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L74-L79) is **TRUE**. `PRO_PRODUCT_IDS` only contains monthly and yearly, and `auth.js:79-82` rejects missing/zero `expiresDate` as `expired` (403). `StoreService.swift:230, 256` also checks only the two subscription IDs.

---

### (3) Missing Levers and Risks

1. **Immediate PTT 24-Hour Window Risk (Cost: $0, 15 min)**:
   The plan schedules A1 for 11-14, missing that tomorrow, **Monday 2026-11-09**, is the *only* Monday before 11-15. PTT iOS board rules ([`docs/distribution/2026-10-23-p21-posts.md:83`](file:///Users/jason/Documents/RoastMate/docs/distribution/2026-10-23-p21-posts.md#L83)) strictly restrict commercial announcements (`[廣宣]`) to Mondays (`3-B-⑶`). If post #3 is not posted tomorrow, T cannot occur before 11-15, guaranteeing the stop rule fires.
2. **ASO Keyword Expansion & In-App Events (Cost: $0, 1 hour)**:
   Search drove 7 of 9 downloads. Yet, RoastMate has 0 In-App Events, and Taiwan App Store keywords use only 48 of 100 available characters ([`docs/evidence/2026-10-07-v17-phase1-recon.json:3`](file:///Users/jason/Documents/RoastMate/docs/evidence/2026-10-07-v17-phase1-recon.json)). An In-App Event (e.g., 「年末社畜宣洩祭」) configured in the ASC web portal requires no new binary, appears in App Store search results, and captures organic traffic for free.
3. **Initial Taiwan Social Proof / Ratings (Cost: $0, 30 min)**:
   RoastMate has **0 written reviews and 0 ratings**. In Taiwan, 20 product page views yielded only 1 download (~5% CVR). Prospective users see "No Ratings" on a paid/subscription app and bounce. Having 3–5 trusted local contacts or beta testers leave honest App Store ratings and short reviews immediately removes this conversion drag.
4. **Contextual Social Commenting vs. Cold Creator Emails (Cost: $0, 15 min/day)**:
   Batch 1 creator emails yielded 0 redemptions. Cold pitching 3-month trial codes rarely works. Instead, commenting on trending workplace vents or boss drama on Threads with RoastMate screenshots or sample card links reaches real Taiwan audiences organically without cold email friction.

---

### (4) Primary Failure Mode and Early Detection

- **Single most likely failure**: **Jason does not publish the posts.** The P2.1 drafts have sat ready in [`docs/distribution/2026-10-23-p21-posts.md`](file:///Users/jason/Documents/RoastMate/docs/distribution/2026-10-23-p21-posts.md) for 16 days (since 10-23) because posting from personal accounts carries psychological friction. 
- **Early detection**: Check on **Monday 2026-11-09 at 23:59 (Taiwan time / UTC+8)**. If the PTT `[廣宣]` post and Threads #1 post URLs are not recorded in the distribution log by midnight Monday, the distribution push has failed; do not wait for 11-15 or 01-31—trigger Path D immediately.

---

### (5) What Jason Should Do This Week

Jason should either publish the drafted Threads and PTT `[廣宣]` posts on Monday 11-09 to give RoastMate its first genuine distribution test before 11-15, or let the stop rule fire on Sunday and transition the app directly to Path D (maintenance mode).
