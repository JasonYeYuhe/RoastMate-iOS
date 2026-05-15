# RoastMate — final ship handoff

Everything that can be done from code/CLI is done. This doc is the
single source of truth for the human-only remaining steps.

## State of the build

- Cloud Vent/Feral: live. Worker at
  `https://roastmate-vent.yyyyy-yeyuhe.workers.dev`, Groq primary
  (Qwen3-32B zh / Llama-3.3-70B else), OpenRouter fallback,
  per-device 30/day rate limit.
- Default: Cloud AI **ON** (Settings → AI & Privacy lets the user
  switch Vent/Feral to local).
- Safety: cloud output runs the same vent safety filter as local;
  a hard-rail hit discards the cloud text and falls back to local
  (fixed + regression-tested this session).
- 81/81 unit tests pass. iOS/macOS/watchOS/Share build clean.
- All user-facing copy (in-app strings, App Store description,
  Privacy Policy, marketing site) aligned with the real cloud
  architecture. Both repos pushed:
  - app: `JasonYeYuhe/RoastMate-iOS`
  - marketing site (the privacy URL Apple visits):
    `JasonYeYuhe/RoastMate` — updated, GitHub Pages redeploys auto.

## Screenshots

- **English (en-US): done and correct.** 6 scenes, 1320×2868
  (App Store 6.9"), in `metadata/screenshots/en_US/iPhone_17_Pro_Max/`.
- **zh-Hans / zh-Hant / ja: render with English text.** Known issue:
  SwiftUI `Text("key")` does not honor the forced locale in the
  simulator screenshot harness. Real users are unaffected — the app
  follows the device system language correctly (a Chinese-system
  iPhone shows the app in Chinese; verified against your earlier
  device screenshots).
- Your options for the localized App Store listings:
  1. **Reuse the en-US screenshots for all locales** (very common;
     fastest path to ship). App Store allows this.
  2. Capture localized shots manually: set a simulator's *system*
     language to 简体中文 / 繁體中文 / 日本語 (Settings app inside
     the sim), run the app, screenshot the 6 scenes. The app will
     render correctly because it follows system language.
  3. Leave it with me as a dedicated follow-up: a localized-bundle
     wrapper so the in-app language override (and the screenshot
     harness) actually switches `Text` localization. This is a real
     latent issue worth fixing but is NOT a launch blocker.

## ASC steps — human only (auth-gated, irreversible; I won't automate)

Log in to App Store Connect yourself (Apple ID + 2FA). Then:

### 1. App Privacy → Data Types

Change from "Data Not Collected" to declaring these. All are
**App Functionality**, **Not linked to identity**, **Not used for
tracking**:

- **User Content → Other User Content** — the situation text sent on
  the Vent/Feral cloud path.
- **Identifiers → Device ID** — the opaque per-install UUID for rate
  limiting.
- (Keep the existing Purchases declaration for the Pro IAP.)

### 2. App Review Information → Notes

Paste the block verbatim from
`docs/ASC_FINAL_SUBMISSION_CHECKLIST.md` §2 (it explains the
on-device vs cloud split, how a reviewer disables cloud, the
"private draft, don't send" framing, and the safety rails).

### 3. Description

Sync from `metadata/{en-US,zh-Hans,zh-Hant,ja}/description.txt`
(already cloud-accurate).

### 4. Privacy Policy URL

Confirm it's `https://jasonyeyuhe.github.io/RoastMate/privacy.html`
and that the page shows the updated (cloud-aware) content. GitHub
Pages can take a few minutes to redeploy after the push.

### 5. Build + submit

In Xcode: Any iOS Device → Product → Archive → Organizer →
Distribute App → App Store Connect → Upload. Then in ASC, attach
the build to the 1.0 version, set screenshots, **Submit for
Review** (this final click is yours).

## If Apple pushes back

See `docs/ASC_FINAL_SUBMISSION_CHECKLIST.md` §4 — playbook for the
likely complaints (cloud disclosure, vent profanity under 1.1,
privacy practice description).
