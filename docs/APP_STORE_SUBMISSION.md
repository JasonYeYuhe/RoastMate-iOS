# RoastMate — App Store Submission Checklist

Tracks everything required between today and uploading the V1 build to
App Store Connect. Aligned with the W4–W10 plan in
`/Users/jason/.claude/plans/app-store-ios-watchos-pure-hare.md`.

---

## 1. Before submission — hard requirements

### Apple Developer / ASC
- [ ] Confirm Team ID `KHMK6Q3L3K` is still active in Apple Developer.
- [ ] Register App ID `yyh.roastmate.app` in Apple Developer (Identifiers).
- [ ] Register App ID `yyh.roastmate.app.watchkitapp` and link to parent.
- [ ] Register App Group `group.yyh.roastmate.app` and attach to both
      App IDs.
- [ ] Create app record in App Store Connect (English primary).
- [ ] Set up zh-Hans, zh-Hant, ja as additional locales.
- [ ] Choose primary category **Lifestyle** / secondary **Entertainment**.
- [ ] Age rating: **17+** with Frequent/Intense Mature/Suggestive Themes.
- [ ] Privacy nutrition label: select **Data Not Collected**.
- [ ] Create in-app purchase products:
  - [ ] `yyh.roastmate.app.pro.monthly` — auto-renewing $2.99/mo
  - [ ] `yyh.roastmate.app.pro.yearly`  — auto-renewing $19.99/yr
        with 7-day free trial introductory offer

### Code-side
- [ ] Replace placeholder `AppIcon.appiconset` artwork (currently empty
      Contents.json) with the full set of sizes — at minimum the 1024×1024
      App Store icon plus per-platform sizes.
- [ ] Generate marketing screenshots for each locale × platform.
- [ ] Add `Configuration.storekit` for local sandbox testing
      (mirror Stride's `Stride/Configuration.storekit`).
- [ ] Replace `upload.sh` placeholder with a working archive + altool
      upload flow (port from `/Users/jason/Documents/Stride/upload.sh`).
- [ ] Replace `ExportOptions.plist` if a different signing style is needed.
- [ ] Tighten `INFOPLIST_KEY_NSHumanReadableCopyright` per target.

### Hosting (GitHub Pages at `jasonyeyuhe.github.io/RoastMate/`)
- [ ] Privacy Policy URL
- [ ] Terms of Use URL
- [ ] Support URL
- [ ] All three include explicit "on-device AI only" statement.

---

## 2. App Store metadata

### Description (English — required first)

> **On-device AI for witty, safe self-expression.**
>
> RoastMate is a creative writing tool that helps you turn frustration
> into clever, safe expression. Describe a situation in your own words,
> pick a style (Polite, Passive-Aggressive, Japanese Keigo, Literary,
> Stand-up, and 15+ more), and RoastMate generates a witty response
> just for you.
>
> All AI runs **on your device** using Apple's Foundation Models
> framework. Your situations never leave your iPhone, iPad, Mac, or
> Apple Watch. No tracking, no analytics, no cloud.
>
> RoastMate is a creative writing and emotional expression tool. It is
> not designed to target or harass any individual — we automatically
> remove names, threats, and slurs.
>
> **Features**
> - 20+ writing styles, from polite to literary to absurd
> - Reply Helper: paste a message, get suggested replies
> - Argument Simulator (Pro): role-play tough conversations
> - Emotion Translator: convert raw frustration into polished language
> - Apple Watch quick-roast — vent on your wrist, hand off to iPhone
> - macOS menu bar quick access with ⌥⌘R global shortcut
> - Available in English, 简体中文, 繁體中文, 日本語
>
> **Pro**
> - Unlimited generations
> - All 20+ styles
> - Generate 3 styles in parallel
> - Argument Simulator
> - Unlimited history
> Monthly $2.99 / Yearly $19.99 (7-day free trial)

### Keywords (English)
`AI, comeback, witty, expression, writing, ranting, mood, journal, reply, copilot`

### What's New (V1.0)
First release.

### Promotional Text
`Vent first. Then send the version that actually wins. Private on-device AI.`

---

## 3. Review notes (required to ship)

```
Reviewer notes for RoastMate v1.0:

1. ALL AI runs on-device using Apple's Foundation Models framework
   (LanguageModelSession). The app uses NO third-party AI service
   (no OpenAI, no Anthropic, no Google). You can verify by enabling
   Airplane Mode and using the Generator — it will continue to work.

2. The app is positioned as an emotional expression / creative writing
   tool, not as a harassment tool. There is no field to enter a target
   person's name. Safe Mode is enabled by default and is described in
   Settings → AI & Privacy.

3. To see the feature surface without typing: launch the app, complete
   the 4-screen onboarding (including the age gate), then in the
   Generator tab tap any of the pre-seeded sample situations. Each
   triggers a real on-device generation through Foundation Models.

4. The History tab is pre-seeded with 15 sample sessions clearly
   labeled "Sample". They can be cleared via Settings → "Clear sample
   data".

5. Subscriptions:
   - Monthly: yyh.roastmate.app.pro.monthly
   - Yearly:  yyh.roastmate.app.pro.yearly (7-day trial)
   Sandbox tester credentials: <TBD>

6. App Group: group.yyh.roastmate.app, shared between iOS, macOS, and
   watchOS so history syncs across the user's Apple devices.

7. No login. No user-generated content shared between users. No social
   features. No analytics SDK.

Thank you for the review.
```

---

## 4. Screenshots strategy (one set per locale × platform)

Each set: 6 screenshots, no real human names, no group targeting.

1. **Generator UI** — situation field with generic placeholder
   ("我室友凌晨两点打游戏" / "Roommate plays games at 2 AM"), style chips
   below, "Generate" CTA. Use Sample 01.
2. **About AI screen** — "Apple Foundation Models · on-device" badge
   prominent, "No OpenAI / Anthropic / Google" reassurance.
3. **Style Library** — grid view, mix of free and Pro styles visible.
4. **Generated result card** — Sample 04 (keigo) shown in zh-Hans
   screenshot to demonstrate cross-language. Buttons Copy / Share / Save.
5. **Apple Watch flow** — three-screen montage: templates → quick
   prompt → result. Use Sample 06.
6. **Settings — Safe Mode ON + About AI link** — visually proves the
   safety toggle exists. This is the screenshot that survives a strict
   guideline 1.2 review.

Stride's `scripts/` folder has screenshot pipeline references worth
adapting.

---

## 5. Test plan (W9 dry-run before submission)

- [ ] Fresh install on a real iPhone, iPad, Mac, Apple Watch.
- [ ] Onboarding completes; age gate persists across relaunch.
- [ ] Generator: empty input → no generation; trimmed-only input → no
      generation. Valid input → 1 variant (free) or 3 (Pro).
- [ ] Try all 8 free styles — each produces a non-fallback result on
      a network-disconnected device.
- [ ] Try a Pro style as a free user → paywall opens.
- [ ] Try denylist input ("kill yourself") → blocked with friendly
      message; no telemetry leaked.
- [ ] Tap each of the 15 samples — each opens the generator pre-filled
      and generates real on-device output.
- [ ] StoreKit sandbox: purchase monthly → Pro unlocks; purchase yearly
      → 7-day trial flows correctly; restore from another device.
- [ ] watchOS: complete a roast on the watch → hand off to iPhone (open
      handoff session on iPhone's lock screen).
- [ ] macOS: menu bar popover; ⌥⌘R global hotkey opens it; Cmd+Enter
      generates; Services menu "Roast with RoastMate" works from Mail.
- [ ] Each of zh-Hans, zh-Hant, ja, en — full UI translated; results
      come back in the chosen language.
- [ ] Airplane mode — full app works.

---

## 6. Known risks & mitigations (top 3)

**Guideline 1.2 — UGC, harassment, bullying.**
> Mitigation: positioning copy front-loaded ("creative writing tool, not
> targeting"). Safe Mode default ON. No name fields. Acknowledged in
> onboarding screen 3 — saved to `UserSettings.hasAcknowledgedContentNotice`.

**Guideline 5.1.1 — third-party AI transparency (Kinen's rejection mode).**
> Mitigation: V1 uses ONLY Apple Foundation Models. App Store description
> says so. Reviewer notes explicitly instruct verification via Airplane
> Mode. Privacy nutrition label "Data Not Collected".

**Guideline 4.3 — duplicate / spam / minimum functionality.**
> Mitigation: 5 distinct user-facing modes by W8 (Roast, Reply Helper,
> Argument Simulator, Emotion Translator, Style Library), 20+ styles,
> 4 localizations, 3 platforms with platform-specific UX. Reviewer notes
> link a 60-second feature tour video.
