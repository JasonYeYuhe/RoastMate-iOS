# Phase 5 distribution research protocol (Q1, Aug–Oct 2026)

**Date:** 2026-05-27 · **Status:** Draft v2 (post-advisor synthesis) ·
**Parent:** `PHASE_5_STRATEGIC_2026-09.md` §9, §10

> Why this doc exists. The §9 advisor synthesis locked: **we do not pick a
> Fork B surface until we answer Codex's 5 unknowns.** This is the playbook
> for answering them. Three arms run in parallel — **Arm A** qualitative
> interviews, **Arm B** A′ counter additions, **Arm C** non-user discovery
> validation — feeding a single end-of-Q1 synthesis that delivers ONE of
> three first-class outcomes: ranked Fork B recommendation, "no candidate
> validated," or "defer Fork B and double down on Fork A."

## 0. The unknowns — what we are answering

| # | Unknown | Frame | Source |
|---|---|---|---|
| 1 | **Locus** | Where (which app / context) are users when the pain happens? | Codex §9 |
| 2 | **Substitutes** | What do they already try before reaching for RoastMate (text a friend, drink, Notes, give up)? | Codex §9 |
| 3 | **Destination** | After they generate a rewrite, **do they actually send it** to the person who angered them — or do they delete it (therapeutic vent) or sit on it? | Gemini v2 (decisive) |
| 4 | **Discovery phrasing** | What phrase would they search to find this kind of tool? | Codex §9 |
| 5 | **Trust** | Who would they trust recommending this — friend, social, App Store, search? | Codex §9 |
| 6 | **Pay timing** | Do they pay before or after first relief? | Codex §9 |

Until these are answered, **every Fork B surface bet is a guess.** That
is the entire reason §9 deferred Fork B to Q3.

**Unknown 3 (Destination)** is decisive: it determines whether RoastMate
is a communication-utility (rewrite → send → manage relationship) or an
emotional-regulation tool (vent → feel → delete). The two diagnoses pick
disjoint Fork B candidate sets. Gemini's catch from the v1 advisor review.

---

## 1. Arm A — Paid 20-person user interview protocol

### Recruit
- **Source:** existing iOS / macOS users on App Store AND on TestFlight.
  Recruitment frame is **"paid 30-minute research interview with existing
  users,"** NOT "TestFlight beta survey" — Apple App Review Guideline 2.2
  prohibits tying compensation to TestFlight participation (Codex catch).
- **Channel:** opt-in tile in Settings ("Help us improve — 30-min paid
  interview, no telemetry / consent required") + manual outreach to
  public App Store reviewers via the ASC review-response surface.
- **Target N = 20** — split:
  - 12 native zh-Hans / zh-Hant speakers (the v1.1 ICP)
  - 4 ja native
  - 4 en bilingual
  - Hard 50/50 split: weekly-active (engaged) **and** dormant-after-day-3
    (lost). Dormant cohort is the harder recruit and the more valuable
    answer — silent churn is the population most invisible to A′. See
    Arm C for the deeper silent-churn coverage.
- **Compensation:** **IAP Offer Code** for the 50-credit pack (Apple
  imposes 1M redemptions / app / quarter; min batch 500). NOT App Store
  promo codes (those are version-bound, limited 100/version/platform, and
  block the user from reviewing the app — both wrong for this use). The
  offer code is delivered after the interview, no public mention / review
  / social post conditional on it. No material-connection disclosure
  required because we never ask for any public mention.
- **Recruit gating:** compensation must NOT be conditional on telemetry
  opt-in. Decouple.

### Pre-interview screen (3 questions, self-hosted)
Hosted at **roastmate.app/research** (static page + serverless POST
endpoint; ~2 hours solo-dev effort with the existing GitHub Pages site
infra + a tiny Cloudflare Worker for the POST). **No Google Form** —
that would leak account, browser, IP, and emotionally-sensitive screening
text to a third party, violating the moat (Codex catch). Server logs
minimized; participant code only; 30-day deletion of raw form data.
Contact email lives in a separate table from answers.

1. "When was the last time you wanted to send a message you could not?"
   → 4 coarse buckets (this week / this month / longer / can't remember)
   + optional "prefer not to say." Free text dropped — too sensitive,
   too anchoring (Gemini + Codex agreement).
2. "Available for a 30-min video call in the next 2 weeks?"
   → yes / no / which timezone
3. **OPEN-ENDED, no app-list anchor:** "In which app or context were you
   typing when the moment hit? (just write it freely)"
   - v1 had a multiple-choice anchored to iMessage / WhatsApp / WeChat
     etc. Gemini flagged: that pre-anchors the user to specific platforms
     before the actual interview, contaminating the Locus answer (#1) in
     Block 1.

### Interview script (30 min)

| Block | Min | Question |
|---|---|---|
| **0. Warmup** | 2 | "Tell me about a recent time you had something to say to someone you couldn't just send. No specifics — just the type." |
| **1. Locus** (#1) | 4 | "When that moment hit — which app were you in? Which device? Was anything open on screen?" |
| **2. Substitutes** (#2) | 4 | "Before reaching for RoastMate (or instead) — what did you do? Text a friend, write in Notes, drink, give up? Walk me through." |
| **3. Destination** (#3) | 6 | "Think back to the last message RoastMate generated for you. Did you actually send it to the person? If not, what did you do with it — deleted, sat on it, saved, shared with a friend?" *(Gemini's dominant insertion — the single question that picks the entire product direction.)* |
| **4. Discovery + Trust** (#4, #5) | 5 | "If you were telling a friend about this app, what would you say? What would they Google? Where would they hear about it — TikTok, Xiaohongshu, friend, App Store, WeChat/LINE group?" |
| **5. Pay timing** (#6) | 5 | "Do you remember buying credits / subscribing? Was it before or after your first satisfying generation? What was the moment you decided?" |
| **6. Surface forced-rank** | 4 | "If RoastMate worked from inside [iMessage / Share Sheet / Safari / Watch / Keyboard / screenshot capture / WeChat or LINE Mini Program], rank your top 3 — **OR** select 'None of these, I prefer the standalone app.'" *(Gemini-fixed: v1 forced a top-3 rank with no escape hatch, which manufactures a winner from terrible options. The escape hatch is now first-class.)* |

### What we extract

| Unknown | Output format |
|---|---|
| 1 Locus | Top 3 apps per locale (zh / ja / en) |
| 2 Substitutes | Top 3 alternative behaviors per locale |
| 3 Destination | Distribution: % sent / % saved / % deleted / % shared-with-3rd-party — **THE pivot table** |
| 4 Discovery | Verbatim candidate search queries |
| 5 Trust | Top 3 recommendation channels per locale |
| 6 Pay timing | Distribution: % before-first-output / % after-first-output / % never-paid |
| Surface preference | Top 3 ranked, **OR** "none / standalone-only" count |

### Privacy posture
- **No screen recordings.** Audio only, transcribed live by interviewer
  to anonymized notes.
- **No vent text touched.** We never ask the user to share an actual
  roast or vent — only the situation type ("a roommate conflict") or
  even less.
- **No participant identifier persists** in the synthesis doc. Each
  participant is `P01`–`P20`; recruitment list is destroyed at Q1 close.
- **No third-party SaaS.** The screen is self-hosted; interviews via
  whatever video tool the user already has (FaceTime / WeChat / Zoom
  user-chosen).

---

## 1.5 Arm C — Non-user discovery validation (~10 target-language non-users)

**Why this exists.** Arms A and B together still cannot answer
distribution. Both advisors converged: research from existing users tells
us about **retention context**, not **acquisition surface** (Codex
explicit). Existing users are by definition the population we already
reached — they reveal nothing about the population we didn't. Without a
non-user channel, the "ranked Fork B recommendation" is workflow
preference dressed as distribution evidence.

### Method
- **Recruit:** 10 native-zh and 5 native-ja non-users (no prior install,
  no exposure). Channels: an outbound message via WeChat / LINE friend
  network, or a Xiaohongshu post inviting a paid interview, or a friend-
  of-friend bridge. Pay with cash or local equivalent (NOT App Store
  offer codes — they would require installing the app first).
- **Duration:** 15 min. Three questions only:
  1. "When you can't send a message you want to send, what do you do?"
  2. "If a tool existed that helped — what would you call it / search
     for? Where would you expect to find it?"
  3. "Who would have to recommend it before you'd try?"
- **Privacy:** identical to Arm A. No vent content; anonymized notes
  only; no installation required.
- **NO PRODUCT DEMO.** We do not show the app. Showing it converts the
  conversation from "what would you do?" to "what do you think of this
  thing?" — the latter is contaminated. (This is the silent-churn cohort
  Gemini called out: those who would not have installed regardless of
  what we built — they are the population that picks distribution.)

### Output
A separate column in the §3 synthesis: **"would discover via" / "would
trust if recommended by" / "would not install in any form."** Compares
against the Arm A "existing user surface preference" column. If the
columns disagree, distribution is the binding constraint, not surface.

---

## 2. Arm B — A′ counter wishlist

A′ infrastructure is the only sanctioned data spine. Every addition
follows the additive-only contract (end of `EventLedger.Counter`,
documented in `docs/A_PRIME_TELEMETRY.md`). Pure-integer counters,
opt-in, off by default, App-Group local, never CloudKit-synced.

### Tier-1 additions (low cost, high signal — ship with Phase 5 W1)

| key | semantics | unknown served |
|---|---|---|
| `feature_usage_share_extension` | `RoastMateShare` action extension invoked from a host app | 1 (locus) |
| `app_open_from_keyboard_handoff` | App foregrounded with non-empty `LaunchRouter` keyboard handoff | 1 (locus) — proxy for keyboard relevance |
| `has_successful_output_before_purchase` | App-Group **boolean** set to true by every successful output path (main app, share extension, keyboard handoff, watch dictation). Combined with `purchase_completed` it answers #6. **Replaces v1's broken `purchase_after_first_gen` / `purchase_before_first_gen` binary**, which used `sessions_with_generation` as proxy — that proxy under-counts share / keyboard / watch flows where a user CAN get value without a main-app session generation, then buy and be mis-classified (Codex catch). | 6 (pay timing) |
| `output_destination_sent_share_tap` | The user share-tapped a generated output (proxy for "sent it"). Differentiated from `share_taps` which counts all share actions. | 3 (destination) — quant proxy for the Arm A pivot question |
| `output_destination_copied` | The user tapped Copy on a generated output | 3 (destination) |

All five land at end-of-enum after `feature_usage_argument_simulator`.
Still `schemaVersion: 2` — additive within v2. If Phase 4 has already
bumped to v3 by the time these land, append at end of v3 instead.

### Tier-2 additions (require a new UX surface — defer to Phase 5 Q2)

| key | semantics | unknown served |
|---|---|---|
| `discovery_source_friend` | One-time opt-in 3-question survey on first launch: "how did you hear about RoastMate?" Bucket = friend | 4, 5 |
| `discovery_source_social` | Bucket = social (TikTok / Xiaohongshu / Threads / IG) | 4, 5 |
| `discovery_source_appstore_search` | Bucket = App Store search | 4, 5 |
| `discovery_source_appstore_feature` | Bucket = App Store feature / listing | 4, 5 |
| `discovery_source_other` | Bucket = other | 4, 5 |

**Why per-bucket counters, not a single `discoverySourceRaw: Int` on
`UserSettings`:** v1 proposed stamping the source bucket on
`UserSettings.discoverySourceRaw`. `UserSettings` is CloudKit-synced. A
per-device discovery integer that CloudKit-syncs is, in aggregate with
locale / install-week / consent-state, a re-identifiability surface
across the user's devices. The A_PRIME contract explicitly keeps usage
data OUT of CloudKit-synced SwiftData (`docs/A_PRIME_TELEMETRY.md` §1
posture). Therefore the bucket lands as one of five end-of-enum A′
counters incremented exactly once on survey response. Maintains the
privacy posture (Codex catch).

### What we deliberately DO NOT add
- No "user wrote text X" tracking — privacy moat absolute.
- No "user looked at app Y first" cross-app tracking — Apple does not
  permit this and we would not want it anyway.
- No location / contacts / calendar / health. The "anti-personality is
  the moat" thesis (Gemini §9) means we look NOTHING like a data-
  extraction product.
- No surface-pre-instrumentation for surfaces that don't exist yet
  (e.g. no `feature_usage_imessage_app` until that target ships).

---

## 3. Synthesis output (end of Phase 5 Q1, target 2026-10-05)

Deliverable: `docs/PHASE_5_DISTRIBUTION_FINDINGS_2026-10.md`. **Three
first-class outcomes (one will win):**

### Outcome (a) — ranked Fork B surface recommendation
Top 3 candidates ordered by (Arm A signal × Arm B signal × **Arm C
discovery signal**). The §9 candidates: iMessage app, share-extension
deepening, Safari Web Ext, screenshot/OCR, Watch dictation, WeChat /
LINE Mini Program (added per Gemini's structural-mismatch note —
Apple-ecosystem surfaces may be misaligned with zh/ja ICP whose chat
lives in non-Apple platforms; consider Mini Program only if compatible
with the privacy moat and solo-dev capacity).

This outcome requires all three of: locus density > 30% of one surface
in Arm A; platform capability technically validated (can it transform
the text?); Arm C confirms the surface is also a *discovery* path, not
just a *workflow* path.

### Outcome (b) — no candidate validated
The data does not justify any specific Fork B surface bet. Reasons might
include: locus too dispersed; Arm C reveals discovery happens entirely
outside any of the candidate surfaces; Destination data (#3) reveals the
product is regulation-not-comms and Fork B candidates were all comms-
side; etc. **This is the explicit "do not commit" outcome** — first-
class, not a failure mode. Codex catch from v1 review.

### Outcome (c) — defer Fork B, double down on Fork A
Findings instead validate that the next 6-month bet is locale depth (S4
tone packs in zh / ja, evaluate ko / hi / es per §10 Q4 fallback) and
Pro reframe (unlocked control + tone packs), not a new surface at all.

### Other synthesis sections
- Quant table — A′ Tier-1 + Tier-2 counter values from ~5 power-user
  volunteers (manual Share Sheet → encrypted DM → spreadsheet, per
  `feedback_shipping_workflow` memory). Small sample on purpose — A′ is
  hypothesis-checking, not hypothesis-generating.
- Qual table — 20 Arm A interviews + 10–15 Arm C interviews, synthesized
  across the 6 unknowns.
- Pricing reframe insight — does the data confirm Codex's "Pro = unlocked
  control + tone packs + on-device" hypothesis, or does usage shape
  demand a different repackaging?
- Apple-ecosystem alignment check — what fraction of Locus signal points
  to non-Apple surfaces (WeChat, LINE) that we structurally cannot reach
  with iOS extensions? Drives Q3 surface choice.

---

## 4. Timeline (Phase 5 Q1, 6 weeks, Aug 24 – Oct 5 2026)

| Week | Arm A | Arm B | Arm C |
|---|---|---|---|
| W1 | Self-host /research form + recruit copy | Tier-1 counters ship in v1.0.6 | Outreach copy + recruit channels mapped |
| W2 | Form goes live + Settings opt-in tile + ASC review outreach | Counters collecting data | Recruit 5 non-users |
| W3 | First 5 Arm A interviews | (data accruing) | First 5 Arm C interviews (15 min ea) |
| W4 | Next 5 Arm A interviews | (data accruing) | Next 5 Arm C interviews |
| W5 | Final 10 Arm A interviews | Tier-2 survey design ready (gates on Phase 4 β2 onboarding) | Final 5 Arm C interviews |
| W6 | Synthesis doc | Tier-2 deferred to v1.0.7 (post-Q1) | Folded into synthesis |

Solo-dev capacity check: 20 Arm A × 30 min + 15 Arm C × 15 min + analysis
= ~25 hours qualitative work spread over 5 weeks (~5 hr/week). Plus ~2
hours to self-host the form. Sustainable alongside Phase 4 tactical.

---

## 5. Risks

| Risk | Mitigation |
|---|---|
| Recruit skew toward engaged existing users | Force dormant-cohort split in Arm A pre-screen + run Arm C entirely on non-users (silent-churn coverage). |
| TestFlight cohort overrepresents early-adopter type | Recruit Arm A also from App Store review surface (manual ASC outreach); Arm C is purely outside the install funnel. |
| Apple App Review compensation rule violation | Recruit is decoupled from TestFlight participation; compensation via IAP offer code (not promo code or cash within app); no review / social mention required. |
| Google-style form leaks emotionally sensitive metadata | Self-host /research; coarse buckets instead of free text on screen; 30-day raw-data deletion; minimized server logs. |
| `discovery_source_*` CloudKit drift | Stored as A′ App-Group counters, NOT on CloudKit-synced UserSettings. |
| Findings shake Phase 4 work | Phase 4 ships per its own track; worst case Q2 pricing reframe absorbs findings. |
| Sample too small for statistical confidence | A′ Tier-1 quant fills the gap for high-volume questions; Arm C broadens base; the interview is for qualitative depth, not sample-size confidence. |
| Synthesis manufactures a winner from weak data | Outcomes (b) and (c) are first-class — explicit "do not commit to Fork B" allowed. |

---

## 6. Out of scope (this is research-only)
- No Fork B code ships this quarter.
- No marketing experiments / acquisition tests beyond the small Arm C
  recruit channels.
- No external announcements.
- No A/B testing infrastructure built (too much surface for a solo dev).

---

## 7. Why this can't be skipped

§9 synthesis (both Gemini and Codex independently): **"surface ≠ channel."**
iMessage extension is not distribution if no one discovers it. Safari ext
is not distribution if the ICP doesn't write painful messages in Safari.
Watch dictation is not distribution if the ICP isn't wearing a Watch when
the rage hits. WeChat/LINE Mini Program is not distribution if Apple
extensions cannot reach Tencent's ecosystem — the structural-mismatch
catch Gemini added in v2.

The 30/90 kill rule (instrumented in this same Phase 5 strategic pass,
see `EventLedger.Counter.featureUsageWatch` et al.) is the *removal*
discipline; this research is the *addition* discipline. Both must run.

---

## 8. Advisor synthesis log (v1 → v2)

v1 of this doc was reviewed by Gemini 3.1 Pro + Codex gpt-5.5
independently 2026-05-27. Material catches both converged on, applied
in v2:

| # | Catch | Source | v2 fix |
|---|---|---|---|
| 1 | Sample bias (silent churn missing) | Both | Arm C added; Arm A dormant-split forced. |
| 2 | Surface forced-rank has no escape hatch + premature ranking framing | Both | "None / standalone-only" escape + §3 ternary outcomes. |
| 3 | Google Form is a privacy leak | Codex P0 | Self-hosted /research form. |
| 4 | "TestFlight interview + compensation" violates App Review 2.2 | Codex P0 | Recruit decoupled from TestFlight, IAP offer code (not promo). |
| 5 | `sessions_with_generation` is a broken proxy for first-relief (under-counts share/keyboard/watch) | Codex P0 | Replaced with App-Group `has_successful_output_before_purchase` set by every output path. |
| 6 | `discoverySourceRaw` on CloudKit-synced UserSettings is a privacy leak across devices | Codex P0 | Moved to A′ App-Group counters (5 bucket-counters). |
| 7 | Missing 6th unknown: Destination (did the user send the rewrite?) | Gemini decisive | Added as #3 in §0 + Block 3 of the interview script. |
| 8 | Pre-screen Q3 anchors users to a list of apps | Gemini | Replaced with open-ended free-text. |
| 9 | Apple-ecosystem surfaces (iMessage) misaligned with zh/ja ICP whose chat lives in WeChat / LINE | Gemini | Added structural-mismatch note in §3; WeChat/LINE Mini Program added as a Q3 candidate (with caveats). |
| 10 | "Researching the wrong end of the funnel" — input locus is investigated but transformation-share viral loop is not | Gemini | §3 synthesis includes the "shared-with-3rd-party" destination bucket; if it dominates, that's the viral loop §9 Gemini flagged. |
