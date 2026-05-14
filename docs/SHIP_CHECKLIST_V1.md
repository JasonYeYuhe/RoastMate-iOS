# RoastMate AI — Ship Checklist (post-Vent Mode pivot)

**Build state at handoff**: All 4 targets build clean (iOS, macOS, Share extension, Watch). 52/52 tests pass. Phases A–D complete.

What you (Jason) need to do to ship. Order matters — don't skip ahead.

---

## 1 · On-device smoke test (before anything else)

Plug in your iPhone and run the `RoastMate` scheme on it (not the simulator — Foundation Models behaves differently). Walk these flows:

**Vent → Sendable (the killer demo)**
- Pick a Pro style or use any free style; switch intensity to **Vent**.
- Type something heated: "我室友又把我做的饭吃完了,这是这周第三次了".
- Tap Generate. You should see ONE vent draft (orange card, "for yourself only" disclosure).
- Tap **Make it sendable**. A second blue card appears underneath with a cooled-off version.
- Verify both copy to clipboard cleanly.

**Free-tier quota**
- Open Settings → reset SwiftData store (or delete + reinstall).
- Open the Generator. Toolbar chip should read **"20 free to start"** in orange + "First 20 free, then 5 daily".
- Burn 20 generations (boring but worth it). After the 20th, chip switches to standard "X left today".
- Burn 5 more. After the 5th, generating shows the quota-exhausted error. Pull-to-refresh next day (or fudge device date) — chip resets to 5.

**Situation Thread**
- Generate a one-off session. Open History → swipe right on the session → "Group as event".
- The session moves to a new thread in the **Unresolved** section.
- Tap the thread. Verify Round 1 card shows your situation + the variant(s). Tap **Continue this event**.
- App jumps to Generator with an orange "Continuing this event" banner showing the prior situation.
- Type "他还假装没事人一样去打游戏了" and generate. Open History → thread now has 2 rounds.

**Sample gallery (App Reviewer optics)**
- Explore tab → Sample gallery. Scroll to the bottom.
- Confirm **sample_16_vent** (workplace bad-mouthing, Chinese) and **sample_17_vent** (anniversary, English) appear with an orange "Vent + Send" badge.
- Tap each — detail sheet shows the orange Vent Draft card + blue Sendable card with the disclosure between them.

**Paywall**
- Try to use a Pro style without Pro. Paywall sheet opens.
- Verify three callout rows: Vent Mode / Savage / Unlimited, each with icon + title + detail.
- Verify monthly + yearly products load with the right localized price.
- "Continue with free" dismisses cleanly.

**Watch & Share Extension**
- Open the Watch app on the paired watch — quick prompt should still generate.
- Long-press text in Safari → Share → RoastMate Share → confirm it opens the main app's Generator with the situation pre-filled.

**Sign in with Apple** (if you added the entitlement)
- Settings → Sign in with Apple. Auth sheet opens. Sign in. Verify the email/userID shows in Settings afterward.
- Sign out + sign back in — should pull from Keychain without re-asking.

---

## 2 · Code signing & provisioning

After the capability additions (iCloud + SIWA + Push), Xcode may still hold a stale provisioning profile. Before archiving:

1. Xcode → Settings → Accounts → your Apple ID → **Download Manual Profiles**.
2. Open `RoastMate.xcodeproj` → RoastMate target → Signing & Capabilities → toggle "Automatically manage signing" OFF then ON. Xcode regenerates the profile with the new entitlements (iCloud container `iCloud.yyh.roastmate.app`, App Group `group.yyh.roastmate.app`, SIWA).
3. Repeat for RoastMateMac, RoastMateShare (no SIWA on Share — already excluded), RoastMateWatch.
4. Build for `Any iOS Device` once with full signing to confirm no errors. If you hit "missing entitlement", the developer portal App ID is out of sync — go back to https://developer.apple.com/account/resources/identifiers/list and confirm all three App IDs still have iCloud + CloudKit + Push (+ SIWA for the main two).

---

## 3 · Screenshots (REDO — UI changed)

The UI added two new surfaces since the screenshots were captured:
- Vent Mode card + Sendable rewrite card on the Generator.
- Situation Thread detail view with rounds.
- New paywall callouts.

Required screenshot sizes (App Store Connect rejects anything else):
- 6.9" iPhone (iPhone 17 Pro Max): 1320 × 2868 — at least 3, ideally 5
- 6.5" iPhone fallback if your 6.9" set is incomplete

Suggested shot list (5 shots, in this order):
1. **Generator with Vent draft + Sendable rewrite visible** — the marquee shot. Use the "workplace bad-mouthing" sample (zh-Hans) since it ships.
2. **Situation Thread detail** — 2 rounds, "Continue this event" button prominent.
3. **Paywall** — feature callouts + product rows.
4. **Sample gallery** — vent demo pairs visible.
5. **History** — thread sections + standalone rounds, showing the variety.

I cannot upload screenshots through Chrome MCP (Apple CSP blocks `file_upload`). After capturing, upload manually via App Store Connect web → My Apps → RoastMate AI → App Information → 6.9" iPhone.

---

## 4 · App Store Connect

In ASC (https://appstoreconnect.apple.com → My Apps → RoastMate AI):

**Build upload**
- Xcode → Product → Archive (Release config, manual provisioning profile from §2).
- Window → Organizer → select archive → Distribute App → App Store Connect → Upload.
- Wait ~10 min for processing. Build appears under TestFlight → iOS.

**Version 1.0 prep**
- App Store tab → 1.0 Prepare for Submission. Attach the new build.
- "What's New" — leave blank for v1.0.
- Confirm description, keywords, promotional text are the Vent-pivot copy already saved in `metadata/{locale}/`. (You did this in a previous phase; check `metadata/en-US/description.txt` reads "Vent first, send second" if you want to sanity-check.)
- Age rating IARC — already set in a previous phase.
- App Privacy nutrition labels — already set (no data collected; on-device).
- Submit for Review.

**TestFlight test** (recommended before public submit)
- TestFlight → Internal Group → add yourself if not already there.
- Install via TestFlight on your phone. Repeat §1 smoke test against the TestFlight build, not the Xcode build, since signing differs.

---

## 5 · Known small issues / decisions you might want to make before shipping

These don't block shipping but you should be aware:

1. **The lifetime-20 bucket is per-install, not per-Apple-ID.** If a user reinstalls, they get another 20. This is by design (no server, no anti-abuse). If you ever want it per-Apple-ID, you'd need CloudKit private DB to mirror `UserSettings.lifetimeFreeUsed` — but that adds a server hop. Probably fine as-is.

2. **Paywall.body is dense in Japanese** — 6 features separated by middots can wrap awkwardly on a 6.1" iPhone in JP. If you see it wrap to 3 lines and look bad, shorten the body to 4 features in `Shared/ja.lproj/Localizable.strings`. The three feature callouts below cover the detail anyway.

3. **No "Continue this event" button on standalone sessions in History tab** — I did add it to the session detail screen (push from History row). If you want it on the swipe action too, add another `.swipeActions` block in `HistoryView.sessionRow`. Skipped for now to keep the UX one decision at a time.

4. **Sample_17_vent (anniversary) uses emotional all-caps in English** — well within "self-expression" framing but if App Review nitpicks, soften it. Edit `Shared/Resources/SampleRoasts.json` sample_17_vent.ventResponse — lowercase the "DARE", "FIVE", "EXHAUSTED", "NOT". Less impact for the demo, but safer optics.

---

## 6 · After approval

- Test the App Store version end-to-end on a fresh device (i.e. not your dev install). Make sure IAP renders prices.
- Tweet / xiaohongshu / Twitter the launch. The angle is the **vent → sendable** flow — that's the screenshot to lead with.
- Watch for crash reports + reviews in ASC. The first 48 hours tell you whether the value prop lands.

---

## Files changed in this session (Vent Mode pivot)

- `Shared/Models/UserSettings.swift` — lifetime 20 + daily 5 quota; new helpers
- `Shared/Services/ThreadContinuationStore.swift` — NEW; Threads → Generator bridge
- `Shared/Resources/SampleRoasts.json` — added sample_16 (zh) + sample_17 (en) vent pairs
- `Shared/Services/SampleRoast.swift` — optional ventResponse/sendableResponse fields
- `RoastMate/Sources/Features/History/ThreadDetailView.swift` — NEW
- `RoastMate/Sources/Features/History/HistoryView.swift` — sections: Unresolved threads / Resolved / Recent rounds
- `RoastMate/Sources/Features/RoastGenerator/RoastGeneratorView.swift` — continuation banner + lifetime-aware quota chip
- `RoastMate/Sources/Features/RoastGenerator/RoastGeneratorViewModel.swift` — pendingThread + priorContext plumbing
- `RoastMate/Sources/Features/StyleLibrary/SampleGalleryView.swift` — vent demo detail rendering
- `RoastMate/Sources/Features/Paywall/PaywallView.swift` — three feature callouts
- `RoastMate/Sources/App/RootView.swift` — onContinueGenerator wiring
- `RoastMateMac/Sources/MenuBar/MacMenuBarContent.swift` — restored to new State enum shape
- `Shared/{en,zh-Hans,zh-Hant,ja}.lproj/Localizable.strings` — 17 new keys per locale
- `RoastMateTests/UserSettingsQuotaTests.swift` — 9 tests (was 2)
- `RoastMateTests/ThreadContinuationStoreTests.swift` — NEW, 2 tests
