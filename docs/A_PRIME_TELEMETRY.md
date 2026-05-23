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

### Snapshot context (built at EXPORT time, never persisted as series)
| field | value |
|---|---|
| `schema_version` | `1` |
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
