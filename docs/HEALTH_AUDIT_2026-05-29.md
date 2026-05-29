# RoastMate deep health audit — 2026-05-29

Full-project health check after the Echoes ship + cleanup. Strategy pass
by Gemini 3.1 Pro; engineering/security pass by Codex (running separately
— findings folded in when complete). My own scan + the two advisors.

## TL;DR

- **Codebase is healthy on the fundamentals.** 239 unit tests pass, full
  app `BUILD SUCCEEDED`, 0 `try!` force-unwraps in app code, only 3
  TODO/FIXME total, clean working tree. The credit ledger is genuinely
  well-designed (append-only, CloudKit-conflict-aware, double-grant +
  double-spend protected). This is not a messy codebase.
- **The risks are structural + attention-allocation, not bugs.** The
  three things below compound if ignored.

## Cleanup done this session

- Committed the 12-day-orphaned `test_paywall` ScreenshotTests method
  (App Store IAP review screenshot pipeline) — `354d1b0`.
- Restored 24 regenerable screenshot PNG re-renders → clean tree.
- Removed gitignored iCloud-dup cruft `RoastMate 2.xcodeproj`.
- Removed stale `.backup` files (PromptBuilder, EventLedger) + a stray
  root-level duplicate `ThreadDetailView.swift`.
- Verified: full build still succeeds, 0 dirty files, pushed.

## 1. Biggest structural risk (Gemini: UserSettings god-object)

`Shared/Models/UserSettings.swift` is 518 lines with ~20 nullable
CloudKit-migration fields spanning UI toggles, monetization (wallet,
Pro), consent (cloud + Echoes-feral), and telemetry opt-in — all on ONE
CloudKit-synced `@Model`. Gemini's call: this bites first and hardest
because silent iCloud sync conflicts / state-resolution bugs are the
worst thing to debug solo.

**Cheap pre-emptive fix (don't do a big-bang refactor):** when the next
settings field is needed, put it on a NEW small model
(`LocalDeviceState` for never-synced UI state vs the synced profile)
rather than growing UserSettings. Stop the bleeding; don't re-plumb the
existing 20 fields (that risks the exact migration bugs we're avoiding).

Runner-up: RoastEngine + EchoesEngine duplicate the cloud/local routing
+ consent-gate + fallback logic. Localized today, but a third generation
surface would make it a real "fix it in 3 places" tax. Note for when a
3rd surface appears: extract a shared `GenerationRouter`.

## 2. Feature sprawl — kill / freeze / keep (Gemini, ruthless)

| Surface | Verdict | Rationale |
|---|---|---|
| **Keyboard extension (dormant)** | **KILL — strip the code** | ~50MB extension memory ceiling makes on-device inference impossible; it's dead weight + a maintenance/illusion cost. The A′ `feature_usage_keyboard` counter will read ~0 forever because it's un-embedded. |
| **Watch app** | **FREEZE (let 30/90 execute)** | Venting on a wrist is high-friction. Stop maintaining now; let telemetry confirm the kill. |
| **Argument Simulator** | **FREEZE** | Multi-turn, high token cost, narrow use case. Wait for `feature_usage_argument_simulator` data; drop if it isn't driving Pro conversions. |
| **Echoes** | **KEEP — focus bandwidth here** | Highest-variance bet; shifts utility → emotional companion. |

The 30/90 kill telemetry is already instrumented (good — that decision is
data-driven, not vibes). The keyboard is the one to act on NOW since its
verdict is structural, not data-dependent.

## 3. Echoes — was shipping now right? + kill-criterion

Gemini: shipping was right (can't simulate real venting entropy in
tests), BUT relying on the on-device 3B model to emit parseable tagged
output is a real gamble — fallback-to-canned reads as broken/cringe.

**Concrete kill-criterion (metric + threshold):**
> `echoes_parse_fallback / echoes_session_started > 35%` over a 7-day
> rolling window → the empathy illusion is broken. Action: either force
> Echoes through the cloud path (sacrifice margin/privacy for quality)
> or disable the feature while the prompt/model is tuned.

We ALREADY ship the `echoes_parse_fallback` counter, so this is
measurable the moment real-device data arrives. **Still pending: the
real-device parse-vs-fallback baseline** (sim can't run Apple
Intelligence; Gemini is too strong to be representative).

## 4. Highest-ROI move this week (Gemini): remote kill-switch

**There is NO remote-config / kill-switch today** (verified: grep found
none; the only launch-time network is the cloud-vent POST). With THREE
builds stacked unreviewed in Apple's queue and Echoes unverified
on-device, a bad Echoes OOM/parse-storm can only be fixed by another
Apple review cycle (days).

**The move:** fetch a tiny JSON config on launch (host on the existing
Cloudflare Worker or GH Pages — infra already exists) that can remotely:
- disable Echoes,
- force on-device OR force cloud for any generation path,
- disable the Vent/Feral cloud path.

This decouples disaster recovery from Apple's review latency and is the
single highest-leverage thing because it de-risks every future
aggressive ship. ~Half a day of work; compounds forever.

## 5. What they're sleeping on (Gemini's next blind-spot): Context Collapse

Prior audits surfaced Apple-anti-personality moat, Bridge-to-Action,
Mirror-Shock. The NEXT one: **the app is transactional / stateless.** A
user who vents about their toxic boss Tuesday is a stranger again Friday.
Even Echoes is an isolated session.

**The moat opportunity — on-device semantic memory:** local CoreML
embeddings of past accepted rewrites + vents; on a new vent, local
semantic search injects a one-line context note into the system prompt
("user previously vented about a micromanaging boss"). Output goes from
generic-savage to personalized-resonant. Embeddings + search stay
on-device → preserves the absolute-privacy stance → a retention moat
cloud-first competitors structurally cannot copy without data liability.
This is a Q3+ bet, not now, but it's the direction that compounds the
privacy moat into retention.

## Engineering pass (Codex) — PENDING

Codex is running the code/security/correctness audit separately
(concurrency, StoreKit integrity, 5.1.2(i) leak paths, SwiftData/CloudKit
migration safety, the Cloudflare Worker, Echoes parser robustness). Its
ranked findings + "3 to fix first" + health verdict will be appended
here when it completes.

## My own scan (quick signals)

- 0 `try!` in app code · 3 TODO/FIXME total (all benign/tracked) ·
  239 tests green · full build green.
- Largest files: UserSettings (518), PromptBuilder (516),
  RoastGeneratorView (488), FeatureGenerator (476) — none alarming, but
  UserSettings size corroborates Gemini's #1.
- Network surface is minimal + auditable: cloud-vent POST + static
  GH-Pages links only. Good for a privacy product.

## Recommended next actions (priority order)

1. **Remote kill-switch** (½ day) — de-risks the 3 stacked builds + all
   future ships. Do this first.
2. **Strip the keyboard extension** (structural kill; no data needed).
3. **Real-device Echoes eval** — get the parse-fallback baseline; wire
   the 35% kill-criterion into the analysis.
4. Hold the line on UserSettings: new state → new small model, never
   grow the god-object.
5. (Q3+) On-device semantic memory — the next moat.
