# A′ — Post-launch instrumentation (privacy-compatible, no-SDK)

**Date:** 2026-05-23 · **Status:** MVP design (about to be coded) ·
**Builds on:** `docs/NEXT_PHASE_PLAN_v1.2.md` §4 milestone A′ +
Codex/Gemini convergent post-launch advisor synthesis.

> Both advisors flagged "feature-rich + evidence-poor" as the core failure
> mode now that the app is live. A′ converts that — but it must do so
> **without compromising the privacy moat that is the actual product**.

## Posture (non-negotiable)

1. **No third-party SDK.** Not RevenueCat, not Mixpanel, not anything.
2. **Opt-in default OFF.** The setting lives next to the cloud-consent
   toggle. Off ≠ broken — the app works identically.
3. **Aggregate, never per-event.** Counters only. No event timestamps tied
   to a user action; no per-screen trail.
4. **On-device only.** Counters live in the App-Group `UserDefaults` suite.
   Nothing leaves the device automatically.
5. **Export is user-initiated, one-shot.** Settings → "Share anonymized
   usage" → builds a single JSON snapshot → user-driven Share Sheet
   (Files / Mail / AirDrop). No background upload, ever.
6. **No PII, no free-text, no exact dates.** Dates round to the **ISO week**
   they occurred in. Counters are integers. The user's situation text,
   roast output, contacts, locations, etc. are NEVER touched.
7. **Read-side restraint.** Reset is one tap. Disabling clears the buffer
   on next save.

## Schema v1 (MVP)

### Counters (incremented only)
| key | what it counts |
|---|---|
| `paywall_impressions` | `PaywallView` appeared |
| `generations_total` | every roast/rewrite generation that ran |
| `generations_cloud` | of those, ones that hit the cloud Vent/Feral path |
| `generations_on_device` | of those, ones that ran on Apple Foundation Models |
| `purchase_attempts` | StoreKit `purchase()` was called |
| `purchases_completed` | a `Transaction.verified` result was reached |
| `share_taps` | a share-card/share-extension share action fired |
| `session_starts` | `RoastMateApp.bootstrap()` ran (cold or warm-from-background) |

### Counters added in schema v2 (ε2 — ships v1.0.2)
| key | semantics |
|---|---|
| `feedback_thumbsup` | user tapped 👍 on a generation card |
| `feedback_thumbsdown` | user tapped 👎 (and picked a tag — cancel doesn't count) |
| `feedback_tag_wrong_tone` | 👎 tag — output's tone was off |
| `feedback_tag_too_soft` | 👎 tag — output didn't bite enough |
| `feedback_tag_too_harsh` | 👎 tag — output went too hard |
| `feedback_tag_wrong_language` | 👎 tag — output came in the wrong language |
| `feedback_tag_wrong_style` | 👎 tag — output didn't read as the picked style |
| `feedback_tag_didnt_address` | 👎 tag — output ignored the situation |
| `feedback_tag_factually_wrong` | 👎 tag — output contained a factual error |
| `feedback_tag_other` | 👎 tag — user picked "other" |

### Counters added in schema v2 (α3 — ships v1.0.3)
| key | semantics |
|---|---|
| `generations_failed_guardrail` | LLM refused (Apple FM guardrailViolation or cloud safety bounce) |
| `generations_failed_network` | network error reached the user (cloud chain failed and no on-device fallback fired) |
| `generations_failed_quota` | context length / rate / TPM limit hit |
| `generations_failed_safety_filter` | every candidate tripped SafetyFilter — fell back to curated lines |
| `generations_failed_model_asset_missing` | Apple FM model asset unavailable on device (not yet downloaded) |
| `paywall_trigger_low_credits` | user reached for generate with empty wallet, OR tapped "Get more credits" in Settings |
| `paywall_trigger_pro_tap` | user tapped "Upgrade to Pro" OR entered a Pro-gated feature (Argument Simulator etc.) |
| `paywall_trigger_style_locked` | user tapped a Pro-only style chip while on Free |
| `paywall_trigger_intensity_locked` | user picked a Pro-only intensity (savage, etc.) while on Free |
| `sessions_with_generation` | bumped ONCE per cold launch the first time a generation succeeds — `sessions_with_generation / session_starts` is the D7/D30 return-to-tool proxy |

### Counters added in schema v2 (P5-strategic — Phase 5 kill-list 30/90)
| key | semantics |
|---|---|
| `feature_usage_watch` | `WatchHomeView` appeared on watchOS (per appearance, not per session) |
| `feature_usage_keyboard` | `KeyboardViewController.viewDidLoad()` ran in the keyboard extension (per host load) |
| `feature_usage_argument_simulator` | `ArgumentSimulatorView` appeared on iOS (per appearance — fires regardless of Pro gating so the Pro-locked impression is also visible) |

Why these three specifically: per the Phase 5 strategic doc §9 advisor
synthesis, these are the three 30/90 kill-list candidates. The rule:
30 days of clean low telemetry → freeze the feature (stop investing,
keep it in tree); 90 days → remove. Counter bumps fire on every entry,
not per-session, so a freeze decision sees the true usage shape.

### Counters added in schema v2 (P5 Tier-1 — Phase 5 Q1 W1 distribution research)
| key | semantics |
|---|---|
| `feature_usage_share_extension` | `ShareViewController.viewDidLoad()` ran — share extension was invoked from a host app's Share Sheet |
| `app_open_from_keyboard_handoff` | App foregrounded with a non-empty `LaunchRouter.consumeCapturedSituation()` payload (NOTE: drain consumer wire-up is dormant — keyboard target is currently un-embedded per `project_appstore_status` memory; counter remains 0 until both keyboard is re-embedded AND main-app drain wire-up lands) |
| `output_destination_sent_share_tap` | The user tapped a Share button on a generated output (RoastCard, GeneratedRoastCard, ShareCardComposer). Bumped via `recordOutputShareTap()` which ALSO bumps the legacy v1 `share_taps` — this fixes the prior bias where `share_taps` only fired from `ShareCardComposer`, under-counting plain-text shares (Codex Phase 4 §0.5 #5 audit) |
| `output_destination_copied` | The user tapped Copy on a generated output (RoastCard, GeneratedRoastCard, share-extension output card) |
| `purchase_before_first_output` | A purchase completed BEFORE the user produced their first successful output (driven by App-Group boolean `has_successful_output_before_purchase` — see below) |
| `purchase_after_first_output` | A purchase completed AFTER the user produced their first successful output |

### State flag added in schema v2 (P5 Tier-1) — NOT a counter
| key | semantics |
|---|---|
| `aprime.flags.has_successful_output_before_purchase` | App-Group boolean (not in `EventLedger.Counter`). Set to `true` ONCE on every successful `RoastEngine.generate()` (covers main app + share extension + watch + argument simulator — all funnel through RoastEngine). Drives `recordPurchaseCompleted()`'s pay-timing dispatch into the pre/post counter pair. Opt-out gated like the counters. Cleared by `resetCounters()` so a re-opt-in starts from a fresh pay-timing baseline. |

Why these six counters + flag: per the Phase 5 strategic doc §9 advisor
synthesis + the research protocol v2 §2 Tier-1 table. The earlier draft
proposed using `sessions_with_generation` as a proxy for "first relief"
in the pay-timing dispatch — Codex flagged that as broken (it under-
counts share/keyboard/watch output flows where a user can get value
without a main-app session generation, then buy and be mis-classified).
The boolean flag set by every successful RoastEngine output is the
correct proxy.

Note: the schema-v2 contract is additive only. v1 keys above stay verbatim
forever; new counters land end-of-enum. No raw text or generation content
is ever logged.

Note on `paywall_impressions` (v1, legacy): now bumped automatically by
`recordPaywallImpression(source:)` for back-compat — every sourced
impression bumps both the legacy counter AND the source-specific one. The
PaywallView.onAppear no-arg bump was removed in v1.0.3 to prevent
double-counting; if you see legacy paywall_impressions exceed the sum of
paywall_trigger_*, an untagged caller exists somewhere.

### Snapshot context (built at EXPORT time, never persisted as series)
| field | value |
|---|---|
| `schema_version` | `2` (was `1` in v1.0.0/v1.0.1; bumped in v1.0.2 with ε2 counters) |
| `exported_at_week` | ISO week of export, e.g. `2026-W21` |
| `app_version` | `MARKETING_VERSION` (e.g. `1.0.0`) |
| `build` | `CURRENT_PROJECT_VERSION` (e.g. `7`) |
| `platform` | `iOS` \| `macOS` |
| `os_major` | int, e.g. `26` |
| `locale` | the BCP-47 locale resolved at app launch |
| `install_week` | ISO week of `firstLaunchDate` (or `null` if never set) |
| `consent_state` | current cloud-consent (`notAsked`/`granted`/`denied`) |
| `opt_in_week` | ISO week the user first enabled telemetry, else `null` |

### Derivable at the analysis layer (not stored)
- **Cloud-use rate** = `generations_cloud / generations_total`.
- **Paywall→purchase rate** = `purchases_completed / paywall_impressions`.
- **Return-to-tool proxy** = `sessions_with_generation / session_starts`
  (added in v2 of the schema once we instrument a session-with-generation flag).

## Persistence

- App-Group `UserDefaults(suiteName: "group.yyh.roastmate.app")` under
  key prefix `aprime.counters.<name>`. Keeps it out of SwiftData (which
  is CloudKit-synced; A′ data stays per-device by design).
- The opt-in **flag** itself lives on `UserSettings` as
  `telemetryOptInRaw: Bool?` — nullable for CloudKit-safe migration,
  same pattern as `cloudAIConsentRaw`. Default `nil` ≡ off.
- `opt_in_week` is stamped the first time the flag flips to true.

## Architecture

- `Shared/Services/EventLedger.swift` — pure-ish counter API; reads the
  opt-in flag and short-circuits to a no-op when off. Unit-testable
  with an injectable `UserDefaults` and an injectable "is opted in?"
  closure.
- `Shared/Services/TelemetryExport.swift` — builds the JSON snapshot.
  Pure, unit-testable.
- `Shared/Models/UserSettings.swift` — adds `telemetryOptInRaw: Bool?`
  + `telemetryOptedIn: Bool` getter/setter + `telemetryOptInWeek: String?`
  (ISO week stamp).
- `RoastMate/Sources/Features/Settings/SettingsView.swift` — toggle +
  "Share anonymized usage" + "Reset counters" rows. iOS+macOS share
  via SwiftUI `ShareLink(item: URL)` so it works on both platforms
  without a UIActivityViewController hop.
- Hook sites this session (MVP):
  - `PaywallView.onAppear` → `paywall_impressions`
  - `RoastMateApp.bootstrap()` → `session_starts`
  - `RoastEngine` cloud branch → `generations_cloud` / `generations_on_device`
  - `StoreService.purchase(...)` → `purchase_attempts` / `purchases_completed`
  - Share-card / Share-Extension save action → `share_taps`

## Out of scope this session

- **Cohort D7/D30 return-to-tool** — needs a per-session "did_generate"
  flag the ledger can roll up. Add as schema v2.
- **Churn-reason exit survey** — UX surface; design before code.
- **App-Store-review mining** — separate ASC API script; not in-app.
- **User interviews** — workflow only.
- **Categorical paywall trigger** (`pro_tap` vs `low_credits` etc.) — easy
  add; defer to v2 to keep the MVP cardinality low.
