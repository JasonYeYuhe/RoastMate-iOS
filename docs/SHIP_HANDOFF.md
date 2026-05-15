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

## 🟢 BUILD UPLOADED by Claude (Delivery UUID 532fd901-7d2a-4e3f-813b-139d85ab4c72)

Archive + export + altool upload all done via the ASC API key
(AuthKey_DMMFP6XTXX). ASC is now processing the binary (~10-15 min).

## 🔴 REMAINING — only you can do

1. **Upload screenshots** (Apple CSP blocks programmatic upload):
   - Go to ASC → RoastMate AI → iOS App 1.0 → Previews and
     Screenshots → drag in the 6 PNGs from
     `metadata/screenshots/en_US/iPhone_17_Pro_Max/`
     (01..06, they're 1320×2868 / 6.9").
   - Localizations without their own screenshots inherit en-US, so
     you can ship with just these. (zh/ja localized screenshots
     render English text — known SwiftUI issue, not a blocker;
     en-US screenshots are the standard fallback.)

2. **Upload the build** (Xcode, not browser):
   - Xcode → Any iOS Device → Product → Archive → Organizer →
     Distribute App → App Store Connect → Upload.
   - Wait ~10–15 min for ASC to finish processing the build.
   - In ASC, attach the processed build to the 1.0 version.

3. **Submit for Review** (final, irreversible — your call):
   - With screenshots + build attached, click "Add for Review"
     then "Submit for Review".

## If Apple pushes back
See `docs/ASC_FINAL_SUBMISSION_CHECKLIST.md` §4 (cloud disclosure,
vent profanity under 1.1, privacy description playbook).
