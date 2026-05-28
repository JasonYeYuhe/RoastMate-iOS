# Co-Rant / 替你出气 — feature plan v2 (post advisor review)

**Date:** 2026-05-28 · **Status:** Draft v2 (post-advisor) ·
**Supersedes:** v1 of this doc (committed earlier 2026-05-28). v1's
advisor responses are summarized in §14.

**Working names:**
- en: **Echoes** (frame: voices that ring with you, not friends)
- zh-Hans: **替你出气**
- zh-Hant: **替你出氣**
- ja: **共鳴 (きょうめい)** — resonance

Naming locked at v2 after both advisors flagged "fake friends" framing
as parasocial / Replika-coded and pushed regulation-lane wording. Final
ASC App Name TBD.

## 0. Two-sentence pitch (revised)

User types a grievance. App returns a short **chat-style transcript of
4–6 messages from 1–2 virtual voices ("Echoes")** that escalate-validate
the user's anger, then de-escalate AND **bridge** the user to the
existing rewrite tool with a concrete CTA at the end. Read, not
written-to. One-shot, no reply turn. The transcript can be shared as an
image — but viral-loop is no longer the primary thesis (see §1).

---

## 1. Why this feature exists — strategic fit (REVISED)

### Anchors back to §9 advisor synthesis, with v1's overclaims removed

| §9 catch | What Co-Rant actually does (v2) |
|---|---|
| Apple-anti-personality is the moat | **Reframed**: the moat isn't "multi-persona chat UI" (Apple Intelligence will sherlock that within 12 months — Gemini decisive). The moat is **willingness to be feral** — Apple will NEVER let its assistant say "your boss is a sociopath." Echoes leverages exactly that wedge in the Bestie + Feral registers; the persona format is theater, the unfiltered language IS the moat. |
| Viral loop via Before/After share | **Demoted**: chat-screenshot is cliche on Xiaohongshu / Threads (Gemini). Multi-persona transcript reads as "I admitted I needed fake friends" — vulnerability share, not transformation share. v2 keeps share-as-image as a feature but does NOT pin the strategic bet on it. The thesis becomes "**Bridge to Action**" (next row). |
| Bursty usage ≠ daily subscription | Echoes fits the bursty pricing model IF we ship the consumable. v2 defers the consumable to **v0.2 (post-launch tuning)** — v1 ships as a Pro feature only. |
| Emotional regulation, not communication | v1's framing accidentally pushed parasocial (Echoes-as-fake-friends). v2 explicitly reframes Echoes as **"externalized internal dialogue"** — voices the user could plausibly have in their head. Drop "friends" terminology in all locales. |

### Net new thesis (Gemini decisive insight)

**Bridge to Action.** The strongest argument for Echoes is that the
chat-style transcript funnels the user into the existing rewrite tool
with a CTA at the end of the last message:

> Echo: 哎你别在这白生气了，把这事用 Savage 给他怼回去 →

The bridge IS the moat against "Echoes is a regulation dead-end."
Without the bridge, Echoes is theater. With the bridge, Echoes is the
**top-of-funnel for the rewrite product** — solves the "first-relief"
ambiguity (Codex §10 #6 in earlier audits) by making the relief
explicit and pipelined.

### Doesn't break anything in flight (v2 reaffirms)

- **Phase 5 Q1 research:** Echoes is HARD-DEFERRED to Q2 (post Oct 5,
  2026). Both advisors converged: shipping during research period
  contaminates Arm A answers on destination + pay-timing.
- **Phase 4 tactical track:** independent.
- **30/90 kill list:** if ArgumentSimulator gets killed, Echoes is a
  clean replacement with the regulation-tool framing ArgumentSimulator
  never had.

---

## 2. UX spec (REVISED)

### Entry point
- New entry on Generator tab, separate from the existing single-output
  intensities. Visually distinct: "Echoes" tile shows two small
  speech bubbles, not the singular sparkle.
- Pro-gated. Tap on Free → Pro paywall.

### Setup screen
- Text field: "What happened? Echoes will validate you, then nudge you
  toward what to say."
  - Note the second clause: it sets expectation that this isn't a
    dead-end vent — Bridge to Action is built into the framing.
- Tone picker: 2 options (CUT from v1's 3):
  - **Casual** (sharp register, light snark, on-device)
  - **Feral** (full lane open, **on-device first, cloud only via the
    new feature-specific consent in §5**)
  - "Bestie" middle option from v1 dropped — it muddied the intent and
    didn't differentiate from Casual on most outputs.
- Voice count: **1 or 2 voices** (CUT from v1's 1/2/3). 3-voice mode
  deferred to v0.2 once we learn whether multi-voice converts vs
  single-voice (Gemini split-recommendation).
- Default: **2 voices, Casual.** Gemini picked multi-voice as default
  because triangulation reads as "consensus" — harder for the user's
  brain to dismiss as algorithm.
- "Let it out →" generate button.

### Transcript screen
- Chat-style: bubble UI, but with a **deliberately stylized non-realism**:
  - No avatars (per advisor + simplicity)
  - Echo names are abstract handles (e.g. `Echo A`, `Echo B`, or
    locale-curated: `回声·甲 / 回声·乙`, `エコー1 / エコー2`)
  - One muted color per Echo (no skin-tone-coded UI)
  - No timestamps (Codex: timestamps push the "fake chat" perception
    closer to harassment-coded social-media-screenshot aesthetic)
- Message reveal: ~600ms per bubble, total ~3–4 sec.
- **Required structure (4–6 messages total):**
  1. Validate the grievance (1 message)
  2. Escalate / commiserate (1–2 messages)
  3. **De-escalate** — offer perspective / path out (1 message) ←
     answers Gemini's "Mirror Shock" critique. v1 missed this.
  4. **Bridge to Action** — CTA to rewrite tool with a one-tap link
     pre-filled with the original grievance (1 message). This is the
     strategic anchor of the entire feature.

### Bridge to Action interaction
- The final Echo's CTA bubble has a **tappable inline link**: "use
  Savage to send this →" / "Sharp で返信する →" / etc. Picks a register
  based on the Echo's tone (Casual squad → Sharp register; Feral squad
  → Savage register).
- Tap → opens the existing RoastGenerator with the same situation
  pre-filled + the suggested register pre-selected. User can adjust
  before generating, OR just hit generate and ship.
- This is the conversion mechanic. Telemetry counts the bridge tap
  separately from the rewrite that follows.

### Privacy / "is this real" affordance
- Persistent banner at top: "Echoes are synthetic. RoastMate doesn't
  have other users."
  - Drops "friends" / "people" wording entirely.
  - Locale-equivalents in 4 locales for v0.2; v1 ships only zh-Hans.

### Action bar (after transcript completes)
- **Save** (history)
- **Share as image** (vertical screenshot card with the Echoes branding
  + the bridge CTA preserved as static text)
- **Regenerate** (different angle, same setup) — CUT from v1: only
  1 regenerate per session permitted, no infinite reroll, to prevent
  the "slot machine" pattern Codex hadn't flagged but the spirit of
  "regulation-not-engagement" demands.
- **Reply turn — CUT FROM v1 ENTIRELY.** Both advisors said Reply
  turns Echoes from regulation → parasocial, duplicates ArgumentSimulator,
  and burns latency budget for marginal value. Defer to v0.3 IF
  v1 metrics demand it.

---

## 3. Technical spec (REVISED)

### Output structure
4–6 messages total (CUT from v1's 4–8). 1–2 Echoes (CUT from 1–3).
≤45 zh chars per message (NEW — Codex token math: 6 × 45 ≈ 270 zh-output
tokens, fits the 600 cap with prompt + persona descriptor overhead).

```swift
struct EchoMessage: Identifiable, Sendable {
    let id: UUID
    let echoIndex: Int          // 0 or 1 only in v1
    let role: EchoRole          // .validate / .escalate / .deescalate / .bridge
    let text: String            // ≤45 chars zh, ≤90 chars en, ≤55 chars ja
    let deliveryDelayMs: Int
    /// For .bridge role only: the suggested register to deep-link into
    /// the existing RoastGenerator with.
    let bridgeIntensity: Intensity?
}

struct EchoTranscript: Sendable {
    let messages: [EchoMessage]  // exactly 4–6, ordered, .bridge always last
    let echoes: [EchoSpec]       // 1 or 2 entries
    let situation: String        // preserved for the Bridge-to-Action deep link
}
```

### Architecture: NEW `EchoesEngine`, NOT a `RoastMode` case (Codex catch)

Per Codex's audit of `Shared/Models/RoastSession.swift`:
- `RoastMode` is mode-of-use (roast / reply / argument / translate /
  social) — flat string outputs or numbered variants.
- Echoes needs structured-transcript parsing, persona selection,
  staged role-based generation, animation timing, dedicated
  persistence.

New file `Shared/AI/EchoesEngine.swift`. Composes `RoastEngine`'s
lower-level cloud + local capabilities (call patterns shared) but
parses + persists differently.

### SwiftData models (NEW per Codex)
New SwiftData entities, added to `SharedModelContainer`:
- `EchoTranscriptRecord` (id, createdAt, situation, locale, tone,
  voiceCount, bridgeIntensity, isFavorite)
- `EchoMessageRecord` (id, transcriptId fk, echoIndex, role rawvalue,
  text, deliveryDelayMs)

These are CloudKit-syncable like existing `RoastSession`, gated by the
same Pro-on-other-devices logic from W2.

### Prompt design (v1, on-device only)
Combined-prompt single FM call. Structured output enforced via a
role-tagged ASCII format (NOT JSON — token budget):

```
[VALIDATE/A] 你被惹到这种程度完全合理。
[ESCALATE/B] 这事换我我能气一个礼拜。
[ESCALATE/A] 而且他还不只这一次。
[DEESCALATE/B] 但你别因为这事毁今晚。
[BRIDGE/A:savage] 把这事用 Savage 回他一句吧 →
```

5-message variant for 1-voice mode (no /B lines). 4–6 messages overall
budget. Parser splits on `[ROLE/IDX(:intensity)]` tag header.

If parsing fails (malformed model output): fall back to a static
curated transcript from the persona catalog. Fires the v1.0.5
`markSuccessfulOutput()` flag as the user still gets relief. **And**
fires a new `echoes_parse_fallback` counter (telemetry §7) so we can
measure parser robustness.

### On-device vs cloud — strictly tiered (v2 lock)
| Tone | Path | Consent gate |
|---|---|---|
| Casual | on-device only | none required |
| Feral | on-device first; cloud only if dedicated consent granted | **NEW `echoesFeralCloudConsentRaw` on UserSettings** — see §5 |

The Bestie middle tone from v1 is cut. The two-tier surface is much
easier to reason about for App Review.

### Generation latency budget (v1)
- Single combined-prompt FM call: 2–4 sec.
- Animated reveal: 4 × 600ms = 2.4 sec (4-msg minimum) up to 6 × 600ms
  = 3.6 sec.
- Total perceived: ~5–8 sec. Acceptable.
- Streaming (Phase 4 α6) gets layered on later — each message renders
  as the model emits its tag header.

---

## 4. Pricing / gating (REVISED — v1 is Pro-only)

| Plan | Echoes access (v1) |
|---|---|
| Free | First 1 transcript, then paywall to Pro. No consumable shown. |
| Pro | Unlimited Echoes (casual + feral) + Bridge-to-Action deep link + share-as-image. |
| Consumable | **CUT from v1**. v0.2 evaluates whether to add `yyy.roastmate.app.echoes.10` ($1.99 per 10 transcripts) — the Crisis Pack Codex floated in §9 — based on actual conversion data. |

The consumable adds App Store Connect IAP catalog complexity, requires
a fourth credit-pack price tier, and introduces a new SKU. NOT worth
shipping in v1 — gate cleanly on Pro until we have demand signal.

---

## 5. Privacy posture + NEW Feral cloud consent (Codex P0 catch)

### Input + output text
- Input: stays where the tone routes it (Casual = on-device, Feral =
  on-device first + cloud only if new consent granted).
- Output: subject to existing SafetyFilter. Hard-rail violations stripped
  candidate-by-candidate per `validateVentOutput` for Feral, strict
  `validateOutput` for Casual.

### NEW feature-specific cloud consent

The existing `cloudAIConsentRaw` (UserSettings:44–48) was granted for
"cloud Vent / Feral private-draft translation." Reusing it for an
Echoes Feral transcript is purpose creep — same class of breach as
the α2′ catch on Phase 4 plan.

Fix: new `echoesFeralCloudConsentRaw: Bool?` on UserSettings (nullable
for CloudKit-safe migration, same pattern as `telemetryOptInRaw`).
Triggers a dedicated 5.1.2(i) consent sheet the first time the user
selects Feral tone in Echoes:

> "Send this grievance to RoastMate's cloud AI to generate a Feral
> Echoes transcript? Casual Echoes always stays on this device. You
> can change this anytime in Settings."

Three buttons: "Use Cloud", "Stay on-device (less feral output)",
"Cancel". Persisted to UserSettings, CloudKit-synced.

### No persona personalization
- Persona archetypes are picked fresh per transcript from the static
  bundled catalog. No learning what tone the user prefers. No
  CloudKit sync of preferences.
- Catalog stored as `Shared/Resources/echoes-personas-zh-Hans.json`
  (v1) with locale-additive files in v0.2.

### No real-name lookalikes
- All Echo handles obviously synthetic. No avatars. Banner reminds.

### No third-party SDK introduced.

---

## 6. App Review compliance (RE-PRIORITIZED)

Codex re-prioritization: the actual first-cut risk is **5.1.2(i)**
(cloud-routing-consent), not 4.0 (fake user content). Reordered:

| Risk | Priority | Mitigation |
|---|---|---|
| 5.1.2(i) — Feral cloud routing on a NEW feature without dedicated consent | **P0** | New `echoesFeralCloudConsentRaw` per §5. Dedicated consent sheet, separate from the existing `cloudAIConsentRaw`. |
| 5.6 / 1.2 — "pile on" reads as bullying / harassment | **P1** | Output guardrail in PromptBuilder: prohibit slurs, threats of violence, self-harm encouragement; SafetyFilter passes apply. Banner copy never uses "pile on" wording. |
| 4.3 — duplicate of existing functionality (Argument Simulator) | **P1** | Differentiated by §13 table — different role (your-side not other-side), different output (transcript not dialogue), different framing (regulation not rehearsal). |
| 4.0 — spam / misleading / fake user content | **P2** | Replika / Character.AI / Snapchat My AI all approved in App Store today (Codex). Banner + abstract handles + no avatars cover this. Lower priority than v1 implied. |
| 1.4.x — health / wellness framing creep | **P2** | Marketing copy stays at "let it out / vent / Echoes have your back," NEVER "therapy / wellness / mental health." |

---

## 7. Telemetry (REVISED — adds privacy-safe share + parse counters)

End-of-enum new counters in `EventLedger.Counter` (additive in v2):

| key | semantics |
|---|---|
| `echoes_session_started` | User tapped "Let it out →" |
| `echoes_completed` | Transcript fully rendered to last message |
| `echoes_bridge_tap` | User tapped the Bridge-to-Action CTA on the final message → opens rewrite tool **CORE CONVERSION METRIC** |
| `echoes_regenerated` | User used the (one-per-session) regenerate |
| `echoes_share_sheet_opened` | UIActivityViewController presented for the transcript card |
| `echoes_share_sheet_completed` | `completionWithItemsHandler` reported `completed: true` (proper confirmed-share semantics per v1.0.5 ShareLink upgrade — Codex re-cite of A_PRIME §P5 Tier-1) |
| `echoes_parse_fallback` | Combined-prompt parser failed on the FM output; fell back to curated static transcript |
| `echoes_feral_cloud_consent_granted` | First-time grant of the NEW feature-specific Feral cloud consent (§5) |
| `echoes_feral_cloud_consent_denied` | First-time denial of same |
| `echoes_paywall_hit` | Free user tried past first-free → paywall opened |

Codex catch on missing destination metric: `share_sheet_completed`
beats v1's plain `_shared` for the same A′ Tier-1 reason — intent vs
confirmation. **No content, no recipient, no exact timestamp recorded.**

Bridge-tap is the v2 strategic metric: bridge_tap / completed >> 0 is
the validation that Echoes is a conversion engine, not a dead-end.

---

## 8. Localization considerations (v1 SLIM — zh-Hans only)

Per Codex CUT list: v1 ships **zh-Hans only**. Cuts the persona
catalog to one file, the SwiftData layer to one locale, the prompt
templates to one. Other locales added in v0.2.

zh-Hans-specific design:
- 2-Echo archetypes for v1: `回声·甲 (毒舌共情型)` + `回声·乙 (理性兜底型)`. One escalates, one de-escalates. Both fluent in mandarin
  Internet vent register (微博 / 小红书 / 朋友圈 idiom).
- Cursing register: mandarin baseline; HK / TW dialects deferred to v0.2.
- Bridge phrasing: "用 Savage 回他 →" / "Sharp 回他一句 →" — natural mandarin grammar with the rewrite tool's existing register names embedded.

---

## 9. Phasing (REVISED — v1 hard-deferred to Q2)

| Phase | Deliverable | When |
|---|---|---|
| **v0** (this doc) | Plan + advisor review v2 | 2026-05-28 |
| Phase 5 Q1 research | All Arm A/B/C interviews complete. **NO Echoes build during this period.** | 2026-08-24 → 2026-10-05 |
| **v0.1 design tuning** | Persona catalog drafted, prompt templates iterated against the Q1 research findings, FM token math validated, eval harness adds Echoes tier | 2026-10-05 → 2026-10-20 |
| **v1 ship** | zh-Hans only, on-device only (except Feral with new consent), 1–2 voices, 4–6 messages, Bridge-to-Action, share-as-image, Pro-only gate, NO Reply / NO consumable / NO 3-voice | v1.0.7 candidate, target 2026-11-15 |
| **v0.2** | en + ja + zh-Hant locales, 3-voice mode if v1 metrics support, consumable SKU if Pro conversion suggests bursty demand, persona catalog expanded | v1.0.8 / v1.0.9 |
| **v0.3** | Reply follow-up IF v1+v0.2 metrics show users need it (which both advisors doubt); streaming integration post Phase 4 α6 | Q1 2027 |

---

## 10. Open questions for advisor review (REVISED)

Most of v1's open questions resolved by the advisor round. What remains:

1. **Bridge-to-Action register matching.** The bridge CTA picks a
   register (`savage` for Feral squad, `sharp` for Casual). Should
   users be allowed to override the suggested register at the deep-link
   landing, or is the prescriptive pick part of the value?
2. **Free first-1 vs Pro-only-from-day-1.** v1 ships "first 1 free
   then paywall," but if Q1 research reveals strong willingness-to-pay
   on Echoes specifically, Pro-only-from-day-1 is cleaner.
3. **De-escalation message: required or optional?** v1 mandates 1
   de-escalation message in the role schema. Some users will want pure
   pile-on without the de-escalate. Trade-off: pure pile-on triggers
   "Mirror Shock" (Gemini); de-escalation defuses it. Open: should
   users see a "no de-escalation" toggle, gated behind an explicit
   self-awareness prompt ("I just want pile-on, no de-escalation")?

The 7 open questions in v1 are RESOLVED: cloud consent (§5 new
surface), naming (Echoes / 替你出气), persona catalog (static / zh-Hans
v1), single-vs-multi default (multi=2), Pro-vs-consumable (Pro v1),
sample contamination (hard-defer to Q2), App Review priority
(5.1.2(i) first).

---

## 11. Risks (REVISED)

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple rejects on 5.1.2(i) | **High if we don't ship the new consent surface** | Ship §5 dedicated consent. Reuse the consent-sheet UI pattern from existing Vent/Feral consent. |
| FM 600-token cap can't fit 6 × 45 zh-chars + prompt | Medium | Hard cap message lengths in PromptBuilder; on parse failure, fall back to curated transcript + bump `echoes_parse_fallback`. Eval harness must include a token-budget regression. |
| Mirror Shock — user feels MORE alone after closing the transcript | **High** (Gemini decisive) | The mandatory de-escalation + Bridge-to-Action structure addresses this directly. v1 metrics should track session-end-without-bridge-tap as a churn signal. |
| Bridge-to-Action conversion rate is low (< 15%) | Medium | Treats Echoes as a regulation-only product (lower margin but still valuable). v0.2 explores bridge-CTA copy tuning. |
| Apple Intelligence sherlocks the regulation-tool case within 12 months | Medium-High | The feral wedge stays defensible (Apple won't ship Savage). Pivot Echoes' positioning toward "Apple won't let its AI say this, ours will." |
| Sample contamination of Phase 5 Q1 research | Low (v2 hard-defers) | Don't ship before 2026-10-05. |
| Watch / Mac scope creep | Low | OUT of scope v1. |
| User shares the screenshot, the chat-style looks like cliche fake-chat-screenshot meme content | **High** (Gemini critique) | v1 share-card layout differs visually from real chat screenshots (no real-app chrome, Echoes branding, light-color bubbles, no timestamps). Track share-completed / share-sheet-opened ratio; if very low, deprecate share-as-image in v0.2. |

---

## 12. Out of scope (firm)

- watchOS / macOS specific UI.
- Real-person impersonation, celebrity personas, user-uploaded
  personas.
- Echoes of someone else's grievance (third-person target).
- AI-generated audio.
- Persona learning / personalization / cross-session preference.
- Multi-user shared rooms (Fork C, REJECTED in §9).
- All locales beyond zh-Hans in v1.
- Reply / multi-turn dialogue.
- 3+ voice mode.
- Consumable Crisis Pack SKU (v0.2 evaluation gate).
- Free-tier infinite regenerates ("slot machine" pattern is explicitly
  rejected; 1 regenerate per session max).

---

## 13. Why this isn't "just" Argument Simulator (RE-CHECKED)

| Argument Simulator | Echoes |
|---|---|
| AI plays the OTHER side | AI plays one or two YOUR-side voices |
| User types responses turn-by-turn | User reads a one-shot transcript |
| Communication-utility (rehearse a real convo) | Regulation-then-bridge (feel heard, then act) |
| Pro feature, no consumable | Pro feature, consumable evaluated v0.2 |
| Free-form dialogue | Structured 4-role transcript (validate / escalate / de-escalate / bridge) |
| Less shareable | Share-as-image possible but DOWN-WEIGHTED per Gemini critique |
| Sits at Fork D edge | Sits on the willingness-to-feral wedge (the actual moat) |
| Multi-turn = high token budget | One-shot = fits FM cap with constrained message length |

The differentiation holds; Codex's 4.3 concern is addressed by the
above table being meaningfully distinct.

---

## 14. Advisor synthesis log (v1 → v2)

Both Gemini 3.1 Pro + Codex gpt-5.5 reviewed v1 of this doc 2026-05-28
in the same session it was drafted. 12 catches applied in v2:

| # | Catch | Source | v2 fix |
|---|---|---|---|
| 1 | Hard-defer to Q2 — Co-Rant shipping during Q1 contaminates Arm A research answers | **Both** | §9 phasing locked v1 release to post 2026-10-05 |
| 2 | "Apple-anti-personality is the moat" claim overstated — Apple Intelligence may sherlock validation-style features within 12 months | **Gemini decisive** | §1 reframed: the moat is **willingness-to-be-feral**, not the persona format |
| 3 | Reply follow-up is a trap (parasocial, duplicates ArgumentSimulator, burns latency) | **Both** | §2 cut Reply entirely from v1; deferred to v0.3 contingent on metrics |
| 4 | 600-token FM cap: 8 msg × 80 zh-chars > cap. Combined prompt is fragile. | **Codex precise** | §3 capped at 4–6 msg × ≤45 zh-chars, ASCII role tags not JSON, parse-failure fallback |
| 5 | Need NEW feature-specific cloud consent surface for Feral squad — purpose creep from existing `cloudAIConsentRaw` | **Codex P0** | §5 + §6 introduce `echoesFeralCloudConsentRaw` on UserSettings + dedicated consent sheet |
| 6 | Should NOT be a `RoastMode.coRant` case — RoastMode is mode-of-use, Echoes is structured-transcript semantics | **Codex architecture** | §3 specifies new `Shared/AI/EchoesEngine.swift` + dedicated SwiftData models `EchoTranscriptRecord`, `EchoMessageRecord` |
| 7 | Cut v1 scope ruthlessly: zh-Hans only, on-device only, 1–2 archetypes, no Reply, no consumable, no 3-voice, no all-locales | **Codex** | §2/3/4/8/9 applied verbatim; §12 firmed |
| 8 | App Review actual first cut is 5.1.2(i), not 4.0. Replika / Character.AI / Snapchat My AI all approved in App Store today | **Codex calibration** | §6 reordered P0 → 5.1.2(i), P2 → 4.0 |
| 9 | **Bridge to Action** insight — final message should funnel to the rewrite tool, turning Echoes from regulation dead-end into a conversion engine | **Gemini decisive** | §1, §2 (final message role + tappable CTA), §7 (`echoes_bridge_tap` core metric), §13 |
| 10 | **Mirror Shock** — if squad always agrees, user perceives it as hollow algorithm and feels MORE alone | **Gemini decisive** | §2 + §3 mandatory de-escalation role; §11 risk track |
| 11 | Drop "friends" framing entirely; reframe as "Echoes" / "Reflections" — externalized internal dialogue, not parasocial chatbot | **Gemini decisive** | All copy in v2 says "Echoes" / "synthetic voices"; "friends" deleted |
| 12 | Naming: zh "帮你骂" risks ASC violence-filter; en "Co-Rant" too technical | **Gemini** | en → "Echoes"; zh-Hans → "替你出气"; zh-Hant → "替你出氣"; ja → "共鳴" |

### v1 questions resolved by the v2 rewrite

| v1 question | v2 answer |
|---|---|
| Q1 Naming | Echoes / 替你出气 / 替你出氣 / 共鳴 |
| Q2 Single vs multi default | Multi (2 voices) — triangulation reads as consensus, harder to dismiss (Gemini) |
| Q3 Free / Consumable / Pro split | v1 = Pro-only + first-free; consumable evaluated v0.2 |
| Q4 Cloud routing | NEW `echoesFeralCloudConsentRaw` for Feral; Casual on-device |
| Q5 Persona catalog | Static bundled JSON, zh-Hans only in v1, dedicated SwiftData records |
| Q6 4.0 risk | Re-prioritized to P2; 5.1.2(i) is the actual P0 |
| Q7 What kills it | Mirror Shock — addressed by mandatory de-escalation + bridge |
| Q8 Reply Pro vs universal | CUT entirely from v1 |
| Q9 Crisis Pack pricing | Deferred — Pro-only v1, consumable evaluated v0.2 |
| Q10 Sample contamination | Hard-deferred to Q2 |

### What v2 still doesn't know

Three open questions remain (§10): Bridge-to-Action register override
behavior, Free first-1 vs Pro-only-day-1, optional no-de-escalation
toggle. None of these block v0.1 design work; all can be locked
during the 2-week pre-build design phase after Q1 research closes.

---

## 15. Bottom line

v1 of this plan was a high-risk, high-reward pivot with three structural
weak points (Apple moat overclaim, parasocial framing, missing
conversion mechanic). v2 addresses all three:
- The moat is the **feral wedge**, not the persona format.
- Echoes is a **regulation-then-bridge** tool, not a fake-friend chat.
- The Bridge-to-Action mechanic makes Echoes a **conversion engine for
  the existing rewrite product**, solving the dead-end concern Gemini
  flagged.

Codex's verdict on v1 was "ship after major rewrite." v2 is that
rewrite. Resubmit to advisors only if scope changes materially in
v0.1 design tuning.

**Path forward this quarter:** keep this doc on ice through Phase 5 Q1
research. Revisit 2026-10-05 with the Arm A/B/C findings — they may
sharpen the persona-catalog design, the bridge CTA copy, and the
free-vs-Pro gating decision.
