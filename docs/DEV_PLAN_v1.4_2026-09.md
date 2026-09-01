# RoastMate — Next-Phase Development Plan (v1.4: Track B growth loop + closeouts)

_Drafted 2026-09-01. **Reviewed by Gemini 3.1 Pro + Gemini 3.7 Flash — both
`SHIP-WITH-FIXES`; all fixes folded in below (see §9).** Follows the v1.3 "Track M
cost/monetization dam" wave (`docs/DEV_PLAN_v1.3_2026-08.md`, memory
`project_v13_wave`)._

---

## 0. Where we are (verified against code 2026-09-01)

- **iOS v1.3.0 (build 18) SUBMITTED → WAITING_FOR_REVIEW.** Carries the whole
  **Track M dam** (client wiring). On approval+release it activates for real
  users: Pro receipt verify (`/v1/auth` + Apple `SignedDataVerifier`) →
  account-keyed Pro lane; free/Pro daily caps; per-IP attempt backstop; edge
  kill-switch (`CLOUD_DISABLED`). Adversarially reviewed → 5 fixes incl. a P0.
- Outage + latency fixes are Worker-side and already LIVE for all builds.
- **Track B is NOT greenfield — it is PARTIALLY BUILT and DANGEROUS as-is.** A May
  2026 pass shipped `RoastMate/Sources/Features/ShareCard/` (`ShareCardComposer`,
  `ShareCardView`, `ShareCardRenderer`) + `Shared/Services/Redactor.swift` +
  `RoastMateTests/ShareCardTests.swift`. It **predates the v1.3 "sendable-only,
  never the raw named vent" decision** and still contains a **raw-vent reveal**
  (`includeVent` / `showVentWarning` / `ventVsSent` / an editable `TextEditor` of
  the vent). **v1.4 Track B = FIX + HARDEN + WIRE this code, not build it.**
- **Deferred from v1.3 (documented):** roommate token wiring; enable the refund
  check (needs a key-scope decision); a load test; the KV-non-atomic quota
  over-grant (needs a Durable Object). Plus stale `cloud-worker/README.md` + a
  RemoteConfig GH-Pages mirror drift.

## 1. Thesis
Turn the dam into a **safety-clean growth loop** — the shareable **Comeback Card**
("the output is the ad") — but ship it ONLY after v1.3 proves the dam with real
users, and only after the existing ShareCard code's privacy/PII holes are closed.
Never weaken the "private draft, never sent" / non-companion / no-3rd-party-SDK moat.

## 2. Phase gate (load-bearing — hardened per review)
> **Decouple the binary release from the feature release.** Ship v1.4 with the
> Comeback Card **DARK behind a NEW RemoteConfig flag `share_card_enabled`
> (default false)** — do NOT hardcode-enable it. Submit v1.4 whenever ready. **Flip
> `share_card_enabled:true` from the server ONLY after** a QUANTITATIVE gate:
> ≥72h of v1.3 in prod, ≥50 verified `/v1/auth` Pro sessions, 0 crypto/verify 500s,
> 0 false IP-blocks on legit users, AND the M-d load test passed. (Both reviews:
> "v1.3 approved" alone ≠ "dam proven" — low volume proves nothing.)
> **Blast-radius fix:** `share_card_enabled` disables ONLY the card. The existing
> `CLOUD_DISABLED` kills ALL cloud (incl. paid Pro vent/roommate) — never use it as
> the card's routine throttle; it's the whole-cloud emergency brake only.

## 3. Tracks

### Track M-finish — prove the dam (first)
- **M-a Prod watch (on v1.3 approval):** Datadog dashboard/alert — Pro-lane fires,
  caps behave, `ip_rate_limited` ~0 for legit traffic (raise `APP_DAILY_LIMIT_PER_IP`
  if CGNAT users throttle). This feeds the §2 gate.
- **M-b Roommate token wiring — treat as a BUG, not cleanup (both reviews P1).**
  `EchoesEngine`'s roommate cloud path sends no Pro token → paying Pro users on the
  roommate feature draw the FREE cap and can hit `ip_rate_limited` → churn/1-star.
  Extract RoastEngine's `generateWithAuth` to a shared helper; route roommate
  through it (best-effort, dormant-safe).
- **M-c Enable the refund check:** decide the **key scope — a DEDICATED
  In-App-Purchase key (least privilege), NOT the broad Admin key `DMMFP6XTXX`, on
  edge infra** (both reviews). Provision `ASC_SIGNING_KEY` + `ASC_KEY_ID` +
  `ASC_ISSUER_ID`; flip `ASS_API_ENABLED=true`; **e2e-test with a real sandbox Pro
  JWS**. Stays fail-open.
- **M-d Load test — and reconsider the deferred Durable Object (see §6.2):** prove
  a surge degrades gracefully (free throttled, Pro unaffected, no global 502). A
  viral card is a deliberate surge generator on top of a KNOWN non-atomic KV race
  (Gemini Pro P0). If the test shows the race is exploitable at scale, **build the
  DO atomic counter BEFORE flipping `share_card_enabled`.**

### Track 0-finish — close v1.2 loops (parallel, Wk 1, time-boxed)
- **0.4** Reconcile stale `cloud-worker/README.md` ("OpenRouter primary / DeepSeek"
  → Groq `qwen/qwen3.6-27b` primary + OpenRouter `qwen/qwen3-30b-a3b-instruct-2507`
  fallback, both with reasoning disabled) + the RemoteConfig GH-Pages mirror.
- **0.2** zh-Hans **sendable** cloud-quality eval (extend `evals/runner`
  `WorkerBackend`; grade vs the vent bar on the deployed model). Gate for ever
  flipping `cloud_sendable_enabled` (still DARK; keep dark until >85% quality).
- **0.1** iOS-18 on-device voice smoke on a real device (`SFSpeechRecognizer`).
- **0.3** privacy copy: label CLEARED; optional — note in the ASC Purchases
  *description* that the receipt is sent to the dev Worker.

### Track B — Comeback Card: FIX + HARDEN the existing ShareCard code (build in parallel; ship DARK)
Files: `RoastMate/Sources/Features/ShareCard/{ShareCardComposer,ShareCardView,
ShareCardRenderer}.swift`, `Shared/Services/Redactor.swift`, `RoastMateTests/ShareCardTests.swift`.

- **B.1 (P0) Remove the raw-vent surface — make the card SENDABLE-ONLY + IMMUTABLE.**
  Delete from `ShareCardComposer`/`ShareCardView`: `includeVent`, `showVentWarning`,
  `editableVent` + its `TextEditor`, `revealVent`, `ventVsSent`, the `ventControls`,
  the warning alert, and the `sourceVent` param path. The card renders ONLY
  `sentText` (the LLM's sendable comeback). **No freeform text ever reaches
  `ImageRenderer`** — the rendered text is immutable (a user must edit their draft
  and re-generate through `SafetyFilter` to change it). This closes the moat breach
  (raw private vent on a branded image) AND the injection vector (typing
  PII/defamation back in), both flagged P0 by BOTH reviewers.
- **B.2 (P0) PII defense-in-depth — the shared text is `sentText`, so scrub THAT.**
  `NLTagger(.nameType)` alone cannot guarantee zero PII, and is especially weak in
  Chinese (2-char names "张伟", titles "张总"/"PM老王", nicknames "大聪明", obfuscated
  contacts `vx:`/`v信`/企鹅号, Chinese-numeral phones). So:
  1. **Worker prompt-level containment:** `buildRoastSystemPrompt` (and vent) MUST
     forbid echoing specific names/companies/addresses/phones — "替换为 '对方'/'你的同事'/
     '那家公司'." (server side; catches it at generation.)
  2. **Client `Redactor.swift` expansion:** add `NLTagger(.nameType)` NER (names→role)
     ON TOP of the existing email/URL/@handle/phone regex, PLUS Chinese contact
     regexes (`(vx|v信|微信|企鹅|扣扣|qq)[:：]?\s*\S+`) + title/nickname patterns +
     Chinese-numeral phone runs. Run `Redactor` on `sentText` (currently it isn't
     run on the shared text at all).
  3. **`SafetyFilter.validateOutput` (STRICT) runs LAST**, right before render; a
     "public share" register is stricter than a private draft — a fail blocks the
     export (no card), never renders raw.
- **B.3 App-Review 1.1/1.2 hardening (both reviews):** only **sendable/high-EQ/
  sharp** styles may reach the card — **bar Feral/toxic** from the composer. No
  "To: <Name>" field on the canvas; frame it as a witty quote ("职场嘴替金句" /
  "High-EQ Comeback"), never an accusatory named rant. Reviewer note: the image is
  generated strictly from LLM output that passed an on-device SafetyFilter and
  cannot be manually edited.
- **B.4 Watermark that actually works on static images (both reviews P1):** a raw
  URL is inert on Xiaohongshu/WeChat/IG. Use a localized "App Store 搜索 RoastMate"
  badge + a small `CIQRCodeGenerator` QR to the Universal Link.
- **B.5 Attribution (both reviews P1):** `EventLedger` is opt-in (~2–5% capture) →
  measures cohort trend only. Embed an App Store campaign referral param
  (`?ct=sharecard_v14`) in the QR/short URL for real store-level acquisition attribution.
- **B.6 Platform + share API (both reviews P1):** iOS-first. `UIActivityViewController`
  is UIKit-only → won't compile on macOS. Use SwiftUI `ShareLink`, or
  `#if os(macOS) NSSharingServicePicker`. Keep macOS compile-safe even if card is iOS-only.
- **B.7 Layout (P2):** long zh punchlines overflow the fixed 1080×1350 canvas → use
  `ViewThatFits`/dynamic font step-down in `ShareCardView`; add long-text cases to
  `ShareCardTests`.
- **B.8 Growth measurement (Pro):** log card-GENERATED-but-NOT-shared, so we can
  tell if aggressive safety scrubbing is killing the loop (over-masked = no punch =
  no share).
- **B.9 Micro-copy trust:** under the preview — "100% rendered on your device; your
  original vent stays private and is never uploaded."
- _AC:_ no code path can render the raw vent; `sentText` passes Redactor(NER+zh)+
  strict SafetyFilter pre-render; card renders 4 locales × light/dark on iOS; Feral
  barred; share behind `share_card_enabled` (DARK); share + no-share counted.

### Track B-2 — Native-capture top-ups (cheap wins only, after B.1)
Action-Button / Control-Center "Quick Vent"; richer App Intents. Defer the post-WWDC personal-context API.

### Track D — distribution (light-parallel; define minimum targets so it isn't performative)
Existing recruit/interview pipeline + 1 ASO pass + a small creator-seed of the card
once it exists. Set N-interviews / 1-ASO-iteration / X-seeds / share-attribution targets up front.

## 4. Sequencing (≈4–6 weeks, v1.4)
1. **Wk 1:** v1.3 approval watch (M-a) + M-b roommate wiring (bug) + 0.4 reconcile.
2. **Wk 1–2:** M-c refund-check enable (+ key + sandbox e2e) + M-d load test (+ DO
   decision) + 0.2 eval; kick off Track D.
3. **Wk 2–4:** **Track B fix+harden** (B.1–B.9) — build now; ship DARK (`share_card_enabled=false`).
4. **Wk 4–5:** submit v1.4 (card DARK); after the §2 gate passes, flip `share_card_enabled:true`; B-2 top-ups; D creator-seed; measure the loop.
5. **Wk 5–6:** hardening, real-device matrix.
If time slips: ship **M-finish + Track 0 + B.1 (dark)**; defer B-2 + Track D depth.

## 5. Guardrails / non-goals (do not regress)
- **NEVER render the raw vent** (or a before/after of it) onto a shareable image —
  purge `includeVent`/`ventVsSent`. The card is the sendable comeback ONLY.
- **The rendered card text is IMMUTABLE** — no freeform `TextEditor` feeding `ImageRenderer`.
- **Feral/toxic register is barred** from the card (App-Review 1.1/1.2).
- Ship the card **DARK** behind `share_card_enabled`; flip only after the quantitative §2 gate.
- No 3rd-party SDK (`NLTagger`, `ImageRenderer`, `CIQRCodeGenerator` are Apple).
- Don't move Vent/Feral off cloud; don't weaken `SafetyFilter` / 5.1.2(i) consent /
  the "private, never sent" framing / non-companion position.
- Branch + DARK-gate + eval-before-flip; never invalidate the live build; the
  byte-faithful `evals/runner` harness is the source of truth for model/prompt changes.

## 6. Open decisions (resolved by review unless noted)
1. **Refund-check key scope →** DEDICATED In-App-Purchase key (both reviews). CONFIRM + provision.
2. **Consumable DO ledger →** the reviewers SPLIT: Flash = defer (subs + static caps
   cover it); Pro = build NOW (a viral loop on a non-atomic KV race = cost blowout).
   **Recommendation: ship card DARK + gradual flip + kill-switch; run M-d; build the
   DO before FULL viral rollout IF the load test shows the race is exploitable.**
   Jason to weigh cost-risk appetite.
3. **Card scope →** SENDABLE-ONLY; kill before/after (both reviews). CLOSED.
4. **Platform →** iOS-first, macOS compile-safe (both reviews). CLOSED.
5. **cloud-sendable flip →** keep DARK until the 0.2 eval passes (>85%).

## 7. Reference frameworks / OSS (verified 2026-09-01)
- SwiftUI `ImageRenderer` (Apple) — card view → `UIImage`, MUST run `@MainActor`
  (hackingwithswift / swiftwithmajid / Apple docs).
- `NaturalLanguage.NLTagger` `.nameType` (Apple) — on-device NER; note the Chinese
  limits above → defense-in-depth, never sole control.
- `CoreImage.CIQRCodeGenerator` — the on-image QR for a working share link.
- Pattern: "the output is the ad" viral card loop (Wrapped-style quote cards).

## 8. Definition of done for v1.4
Dam proven live (Pro lane + caps observed, kill-switch tested, load test passed);
refund check enabled + sandbox-e2e'd; roommate wired; Track 0 loops finished-or-killed
with a dated reason; **ShareCard purged of the raw-vent surface, PII/immutable/safety-
gated, Feral-barred, shipped DARK then server-flipped after the §2 gate**; share loop
measured (incl. no-share); iOS + real-device matrix green; nothing left silently DARK.

## 9. Review synthesis — Gemini 3.1 Pro + 3.7 Flash (2026-09-01)
Both independent reviews returned **SHIP-WITH-FIXES** and converged. Adopted:

| # | Source | Sev | Finding | Applied |
|---|---|---|---|---|
| 1 | Both | **P0** | Editable text / raw-vent reveal on a branded card = moat breach + PII/defamation injection vector → 1.1/1.2 ban | §3 B.1: purge `includeVent`/`ventVsSent`/`TextEditor`; immutable sendable-only card |
| 2 | Flash | **P0** | The raw-vent code ALREADY EXISTS (`ShareCardComposer`/`ShareCardView`) — plan was wrong to call Track B greenfield | §0 + §3 reframed to FIX+HARDEN |
| 3 | Both | **P0** | `NLTagger` NER can't guarantee zero PII, esp. Chinese (2-char names, 张总, vx:/v信, numeral phones); and the shared `sentText` isn't scrubbed at all | §3 B.2 defense-in-depth: Worker prompt scrub + expanded `Redactor` (NER+zh) on `sentText` + strict SafetyFilter last |
| 4 | Pro | **P0** | Viral loop on the deferred KV non-atomic race = cost blowout on a surge | §6.2: build the DO before full rollout if M-d shows it exploitable; card DARK meanwhile |
| 5 | Both | P1 | Phase gate too vague ("approved" ≠ "proven"); ship behind a RemoteConfig flag with quantitative thresholds | §2 hardened: `share_card_enabled` DARK + 72h/≥50-session/0-500s gate |
| 6 | Both | P1 | Roommate token wiring is a BUG (Pro users hit free caps → churn), not cleanup | §3 M-b re-framed |
| 7 | Both | P1 | Watermark URL is inert on a static image (Xiaohongshu/WeChat) | §3 B.4 QR + "search RoastMate" badge |
| 8 | Both | P1 | `UIActivityViewController` won't compile on macOS | §3 B.6 `ShareLink`/`NSSharingServicePicker`, iOS-first |
| 9 | Both | P1 | `EventLedger` opt-in undercounts shares 20× | §3 B.5 App Store campaign referral param |
| 10 | Both | P1/2 | App-Review 1.1/1.2: bar Feral, no "To:<Name>", reviewer note | §3 B.3 |
| 11 | Flash | P2 | Long zh text overflows the fixed canvas | §3 B.7 `ViewThatFits` + tests |

**Single most important thing (both reviewers, verbatim-aligned):** *the Comeback
Card must NEVER share or reference the user's raw vent, and its text must be
immutable — anything else breaks the #1 privacy moat and hands Apple a 1.1/1.2 ban.*
