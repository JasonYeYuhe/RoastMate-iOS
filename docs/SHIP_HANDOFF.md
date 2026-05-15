# RoastMate — final ship handoff

## ✅ DONE (code + ASC, by Claude)

Code / repo (RoastMate-iOS @ latest main):
- Cloud Vent/Feral live (Cloudflare Worker → Groq primary / OpenRouter
  fallback, 30/device/day, safety-filtered, falls back to local).
- Safety bypass bug fixed + regression test. 81/81 unit tests pass.
- All in-app copy, Privacy Policy, App Store metadata, and the
  marketing site (JasonYeYuhe/RoastMate, the privacy URL Apple visits)
  aligned to the real cloud architecture.
- Screenshot pipeline fixed (onboarding skip, CFBundleLocalizations,
  resilient capture). English screenshots correct @ 1320×2868.

App Store Connect (filled + saved by Claude via browser):
- **App Privacy nutrition labels — PUBLISHED.** Now declares:
  - Name + User ID → App Functionality, Linked (Sign in with Apple)
  - Other User Content + Device ID → App Functionality, NOT linked,
    NOT tracking (the cloud Vent/Feral path)
- **Promotional Text** — replaced stale "no data leaves your device"
  with the cloud-accurate line.
- **Description** — replaced the old "no cloud / Data Not Collected"
  text with the full cloud-accurate description.
- **App Review Notes** — full reviewer brief (two AI paths, how to
  disable cloud, how vent-draft framing works, safety, contact).
- **Contact Information** — Yuhe Ye / +81 08035267088 /
  yyyyy.yeyuhe@icloud.com.
- **Sign-in required** — UNCHECKED (app works without sign-in; this
  was checked-with-no-credentials, which would have blocked review).
- Privacy Policy URL already correct + its content now updated live.

## 🟢 BUILD 2 UPLOADED by Claude (Delivery UUID c8bcdada-dd8a-4d2c-8fcd-09f3ce446708)

Build **2** (v1.0.0) — includes the CloudKit background-export fix
(`processing` background mode + `BGTaskSchedulerPermittedIdentifiers`,
kills `BGSystemTaskSchedulerErrorDomain Code=3`). 81/81 unit tests pass.
Archive + export + altool upload all done via the ASC API key
(AuthKey_DMMFP6XTXX). Supersedes the earlier build 1 (Delivery
532fd901). ASC processes the binary (~10–15 min) — attach **build 2**.

## 🔴 REMAINING — only you can do

1. **Upload screenshots** (Apple CSP blocks programmatic upload):
   - Real-device screenshots (4, look better than the simulator set):
     - **6.5" Display box** → drag the 4 PNGs from
       `metadata/screenshots/iphone screenshots/asc_6.5_1284x2778/`
       (1284×2778, aspect-preserved, no distortion).
     - **OR 6.9"/6.7" box** → drag the originals from
       `metadata/screenshots/iphone screenshots/` (1290×2796 — a
       natively valid Apple size, no resize needed, full quality).
   - You only need one size; Apple scales it for all others. 4 ≥ the
     3-screenshot minimum. (Old 6-shot simulator set still at
     `metadata/screenshots/en_US/iPhone_17_Pro_Max/` if you want it.)

2. **Attach the build** (already uploaded by Claude via API):
   - Wait ~10–15 min for ASC to finish processing **build 2**.
   - In ASC → iOS App 1.0 → Build section, attach build **2**
     (Delivery c8bcdada…) — NOT build 1.

3. **Submit for Review** (final, irreversible — your call):
   - With screenshots + build attached, click "Add for Review"
     then "Submit for Review".

## If Apple pushes back
See `docs/ASC_FINAL_SUBMISSION_CHECKLIST.md` §4 (cloud disclosure,
vent profanity under 1.1, privacy description playbook).
