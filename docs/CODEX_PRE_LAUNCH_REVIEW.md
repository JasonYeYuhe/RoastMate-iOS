# Codex pre-launch verification — RoastMate v1.6 (Cloud Vent)

Hey codex. Before we hit Submit on App Review, walk this list. Goal:
catch anything that would either (a) fail on a reviewer's device or
(b) misrepresent what the app does. ~30 min if everything passes,
longer if you find something.

Repo: https://github.com/JasonYeYuhe/RoastMate-iOS (latest commit on
`main` should be `495bc04` or later — the cloud-vent-live commit
plus the node_modules cleanup).

Output style: pass/fail per section. For any FAIL, tell me the
file + line + the exact fix. Don't apply fixes yourself — I want
to review each one. Speed > thoroughness on the trivially-OK
sections; lean in on the ones that touch user trust (privacy, safety
filter, cloud routing).

---

## A. Build + test (15 min)

- [ ] `xcodegen generate` succeeds with no warnings
- [ ] `xcodebuild test -project RoastMate.xcodeproj -scheme RoastMate
       -destination 'platform=iOS Simulator,name=iPhone 17'` reports
       **80/80 pass**
- [ ] All 4 build targets compile clean (iOS RoastMate, RoastMateMac,
       RoastMateWatch, RoastMateShare) with `CODE_SIGNING_ALLOWED=NO`
- [ ] No new compiler warnings introduced by v1.6 (cloud-vent) work
- [ ] No leftover debug code (e.g. `print(...)`, hardcoded test
       values, commented-out blocks) in the v1.6 diff

## B. Cloud Worker live verification (5 min)

The Worker is deployed at
`https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent`.

- [ ] POST to `/v1/vent` with a valid zh-Hans vent payload returns
       200 with `provider: "groq"`, `model: "qwen/qwen3-32b"`, and
       non-empty `text` containing visible Chinese
- [ ] Same payload with `intensity: "feral"` and `locale: "en-US"`
       returns 200 with provider:groq, model:llama-3.3-70b-versatile,
       and English text containing actual profanity (`fuck` /
       `shit` / `asshole`)
- [ ] POST with `intensity: "vent"`, but `situation` field set to
       `""` returns **400 `invalid_situation`** (validates rate
       limit doesn't consume on bad input)
- [ ] POST with same deviceId 31+ times in a UTC day eventually
       returns **429 `rate_limit_exceeded`** (you can simulate via
       repeated curl; the daily counter is in CF KV)
- [ ] OPTIONS preflight returns 204 with CORS headers
- [ ] GET / POST to wrong path (`/v1/something`) returns 404
- [ ] The Worker's `<think>...</think>` stripping handles a model
       that emits incomplete thinking — confirm by reading the code
       at `cloud-worker/src/index.js:stripReasoningTrace`. If the
       response starts with `<think>` but never closes, it returns
       empty → caller treats as failure → tries fallback.

## C. iOS routing decisions (5 min)

Verify in source, not via UI:

- [ ] `Shared/AI/RoastEngine.swift:generate(...)` calls cloud ONLY
       when ALL of: `intensity.isPrivateDraft && cloudVentEnabled &&
       CloudConfig.isConfigured`
- [ ] On cloud failure (`CloudVentError`), engine logs and falls
       through to the local Foundation Models path. No exception
       leaks to the caller for cloud-related failures.
- [ ] `Shared/Services/CloudConfig.swift:isConfigured` returns true
       (placeholder check no longer fires; endpoint is live)
- [ ] `Shared/Services/DeviceID.swift` generates a stable UUID and
       persists it via KeychainStore on first call, returns same
       value on subsequent calls
- [ ] `CloudVentEngineTests`: confirm the 3 tests assert correct
       behavior (cloud IS called for vent/feral when configured +
       enabled; NOT called for sharp; NOT called when user disabled
       cloud)
- [ ] Sharp/Calm/Savage intensities NEVER touch the cloud path
       under any combination of settings. Re-read the engine branch
       to confirm.

## D. Privacy + metadata consistency (highest priority — 5 min)

The privacy story changed in v1.6. Make sure no stale "fully
on-device" claim survives anywhere a user or Apple reviewer reads.
Grep for these phrases and verify each hit is either updated or
intentionally about the local-only paths:

- [ ] `metadata/en-US/description.txt` — privacy paragraph mentions
       cloud routing for Vent/Feral + the Settings toggle
- [ ] `metadata/zh-Hans/description.txt` — same in Simplified Chinese
- [ ] `metadata/zh-Hant/description.txt` — same in Traditional Chinese
- [ ] `metadata/ja/description.txt` — same in Japanese
- [ ] `metadata/*/promotional_text.txt` — short enough that "private
       on-device" can stay if it's about the headline message;
       confirm the text doesn't promise full on-device routing
- [ ] `docs/PRIVACY_POLICY.md` — TL;DR + "Information we collect"
       sections describe the Cloud Vent flow + OpenRouter/Groq
- [ ] `docs/site/privacy.html` — published GitHub Pages copy of the
       above; should match. If it doesn't, fix here too.
- [ ] **In-app onboarding text**: grep `Shared/*.lproj/Localizable.
       strings` for `onboarding.privacy.body`. If the text still
       claims "all generation happens on-device" / "nothing leaves
       your device", that's user-facing copy that contradicts
       reality — flag it. Suggested replacement: keep the
       on-device messaging but add "(Vent / Feral can route to our
       private cloud proxy for better catharsis — disable in
       Settings)".
- [ ] `RoastMate/RoastMate.entitlements` — should NOT have any new
       capabilities for v1.6 (cloud routing is just an outbound
       HTTPS call, no entitlement needed)

## E. Localization completeness (3 min)

The v1.5 + v1.6 cycles added new keys. Verify each appears in all 4
locales:

- [ ] `settings.cloud_vent` + `settings.cloud_vent.footer`
- [ ] `cloud.error.not_configured` / `.disabled` / `.rate_limited`
       / `.unavailable`
- [ ] `output.kind.feral_draft.label` + `output.feral.disclosure`
- [ ] `intensity.feral.name` + `intensity.feral.blurb`
- [ ] `history.section.saved_replies`
- [ ] `sample.thread.title` + `.round1.*` + `.round2.*`

A missing key in any locale → Apple reviewer running that locale
sees a literal key string like `cloud.error.unavailable`. Flag with
filename + key + locale.

## F. Sample data + seeding (2 min)

- [ ] `HistoryService.seedSamplesIfNeeded` is idempotent — only
       seeds when the v2 marker is missing AND no v1 marker exists
- [ ] Seeded sample thread has ≥ 2 rounds AND `isSampleData: true`
- [ ] The two JSON vent demos (sample_16_vent, sample_17_vent) seed
       as **standalone** sessions with paired ventDraft +
       sendableReply rows
- [ ] `HistoryService.clearSamples` removes BOTH sample threads
       (cascading their sessions) AND standalone sample sessions
- [ ] `GeneratedRoastSourceIntensityTests` + `RewriteCoordinator
       Tests` still pass — these protect the v1.4 invariants

## G. Build size / clean tree (1 min)

- [ ] `git status` is clean on `main` (no uncommitted local edits)
- [ ] `cloud-worker/node_modules` and `cloud-worker/.wrangler` are
       gitignored and NOT in the staging area
- [ ] No `wrangler-account.json` or any `.cache/wrangler/` content
       in the staged tree (those got accidentally pushed once;
       they're untracked now)
- [ ] No API keys or `.env` files anywhere in the working tree —
       `grep -r 'sk-or-v1\|gsk_' .` should return zero hits (the
       wrangler-stored secrets are in CF, not here)

## H. Smoke test on simulator (5 min, optional but recommended)

Build to iPhone 17 simulator and:

- [ ] Generate a zh-Hans Vent draft — verify the orange disclosure +
       lock icon appear, and the text contains directive Chinese
       (e.g. "他妈的", "你..." second-person address)
- [ ] Tap "Make it sendable" — verify a green Sendable Reply card
       appears below WITHOUT a new session row in History
- [ ] Open Settings → AI & Privacy → toggle off "Stronger Vent /
       Feral (Cloud AI)" → generate Vent again → verify output
       drops to the gentler Apple-on-device register
- [ ] Toggle Cloud back on → generate → cloud register returns
- [ ] Open History → confirm the seeded sample thread is at top
       (pinned via favorite) and the Saved Replies section is empty
       (unless you starred something during this test)

## I. Final report shape

For each section A-H, give me one of:
- ✅ PASS
- ⚠️ PASS WITH NOTES (works but here's the smell)
- ❌ FAIL — file + line + exact change

End with a one-paragraph **ship recommendation**: do we go to App
Review now, or is there a specific blocker. If there's a blocker
that's purely cosmetic (e.g. one stale "on-device" claim in a
non-customer-facing doc), call it out but recommend ship anyway.
Be specific.

If you want any context I haven't given, the relevant commits are
- `60313c9` — v1.6 iOS plumbing
- `633beb2` — cloud vent live (Groq primary)
- `495bc04` — node_modules cleanup
