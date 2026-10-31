# A9 — the privacy policy says what the code does (draft, NOT pushed)

The live page is `privacy.html` in the Pages repo `JasonYeYuhe/RoastMate`
(last updated 2026-10-20). `privacy.proposed.html` is the draft, `privacy.diff`
the change. **It is a legal page in Jason's name: nothing is pushed until he
approves it.** To publish: copy `privacy.proposed.html` over `privacy.html` in a
clone of `JasonYeYuhe/RoastMate`, push `main` (Pages deploys in ~60 s).

## False or incomplete on the live page (checked against the code 2026-10-31)

| live claim | what the code does | evidence |
|---|---|---|
| Vent/Feral go to the cloud "by default" | only after the consent sheet is answered `.granted` | `CloudPermission.resolve`, `UserSettings.cloudConsent` (nil/true installs read as `.notAsked`) |
| with cloud off, Vent/Feral are generated on-device "with gentler output" | Apple's model refuses them (64/64 on 26, 0/50 sendable on 27.2); the user gets labelled examples | `RoastEngine.generateDetailed` private-draft path → curated; `project_pcc_guardrail_veto` |
| the Worker "stores only a per-device daily counter" | also a counter per keyed-hash of the IP, a per-subscription counter (hash of originalTransactionId) and a ~5-min subscription-status cache (hash) | `cloud-worker/src/ipguard.js`, `lane.js`, `auth.js:106-111`, `appstore_status.js:80-104`; TTL 48 h `quota.js:59` |
| fields sent: text, intensity, style name, locale, UUID | also the style **id** (since 1.7.1) and, for Pro, a session token | `CloudVentRequest` (`CloudVentClient.swift:82-100`), `Authorization: Bearer` (:147) |
| the roommate group is not mentioned | zh-Hans users can send the same fields with `mode: roommate` under its own consent | `EchoesEngine.swift:189-234` |
| "No other third parties" | the Worker sends operational logs to Datadog (outcome, status, latency, intensity, locale, mode, model, lane; no text, no UUID, no IP, no account id) | `ddLog` call sites, `index.js:195-501` |
| toggle "Stronger Vent / Feral (Cloud AI)" | it is "Vent / Feral via Cloud AI" | `settings.cloud_vent` (en) |
| clear history via "Settings → Clear sample data" | that removes only the bundled samples; history is deleted entry by entry | `settings.clear_samples.footer`, `history.delete` |
| "iPhone, iPad, Mac, or Apple Watch" | the Watch app is in no shipped bundle | `project.yml:82-102` |
| Calm/Sharp/Savage "run entirely on your device" | true on Apple Intelligence devices; elsewhere labelled examples, nothing sent | `RoastEngine` curated path; `cloud_sendable_enabled` false forever |

New in 1.8.0 and covered: the Argument Simulator is on-device only (no cloud
path at all, `RoastEngine.opponentTurn`); B5's preview is an ordinary Feral
request under the same consent. Unchanged and still true: Sign in with Apple,
iCloud sync, the nutrition-label rows, the opt-in usage summary is never sent
automatically (`settings.telemetry.footer`), production models are Qwen via
OpenRouter (`wrangler.toml` DEFAULT_MODEL / FALLBACK_MODELS), so the in-app
"No OpenAI / Anthropic / Google" is true.

## Still Jason's

- Approve this diff (or edit it) before it is pushed.
- Check the OpenRouter account's privacy setting (exclude providers that train
  on or keep prompts). The optional Worker field `provider.data_collection:
  "deny"` is not added: it would be a production deploy, and A1 (the deploy it
  was to ride) was cut.
