# ASC Dashboard Handoff Prompt

Copy everything below the `---` line into a new Claude Code session.
That session needs access to Chrome via MCP and must be logged in to
both `developer.apple.com` and `appstoreconnect.apple.com` on the same
Apple ID (Team ID `KHMK6Q3L3K`).

---

# RoastMate — App Store Connect dashboard setup

You're driving a multi-step App Store Connect + Apple Developer dashboard
configuration via Chrome MCP. The user has Chrome already logged in to
both `developer.apple.com` and `appstoreconnect.apple.com` on the
account that owns Team ID `KHMK6Q3L3K`.

The local iOS / macOS / watchOS app source lives at
`/Users/jason/Documents/RoastMate/`. It builds cleanly, all 30 unit
tests pass, and `scripts/preflight.sh` reports 70/70 sanity checks.
The user has NOT yet registered any of the App IDs, App Group, app
record, or IAP products in Apple's dashboards. That's your job.

## Operating rules

1. **Verify before mutating.** Take a Chrome screenshot before any
   create / save / delete. If unsure whether something already exists,
   navigate to its list page first and check.
2. **One destructive step at a time.** After each create / save, take
   a screenshot and confirm success before moving on.
3. **Never delete or rename anything that already exists** unless the
   user explicitly approves in the chat.
4. **All copy comes from files on disk.** Read content from the
   project's `metadata/` and `Configuration.storekit` files —
   don't paraphrase, don't translate. Paste verbatim.
5. **Apple's dashboards UI changes frequently.** If the screenshot
   doesn't match these instructions, describe what you see and ask
   the user how to proceed for that one step.
6. **Save URLs as bookmarks in your notes** so you can return to a
   page without re-navigating from the dashboard root.

## The constants you need

| Field | Value |
|---|---|
| Team ID | `KHMK6Q3L3K` |
| Primary Bundle ID | `yyh.roastmate.app` |
| Watch Bundle ID | `yyh.roastmate.app.watchkitapp` |
| Share Ext Bundle ID | `yyh.roastmate.app.share` |
| App Group | `group.yyh.roastmate.app` |
| App Store name (EN) | RoastMate |
| Display name (zh-Hans) | 帮你骂 |
| Display name (zh-Hant) | 幫你罵 |
| Display name (ja) | RoastMate |
| SKU | `roastmate-1` |
| Primary Category | Lifestyle |
| Secondary Category | Entertainment |
| Age Rating | 17+ |
| Pricing | Free with IAP |
| Monthly product ID | `yyh.roastmate.app.pro.monthly` ($2.99) |
| Yearly product ID | `yyh.roastmate.app.pro.yearly` ($19.99, 7-day trial) |
| Subscription Group | `RoastMate Pro` |
| Marketing URL | `https://jasonyeyuhe.github.io/RoastMate/` |
| Privacy URL | `https://jasonyeyuhe.github.io/RoastMate/privacy.html` |
| Support URL | `https://jasonyeyuhe.github.io/RoastMate/support.html` |

## Where to find the copy

Everything that goes into ASC text fields is on disk in this exact
shape. Read the file, paste its full content:

```
metadata/
├── review_notes.txt                 # App Review notes
├── en-US/   zh-Hans/   zh-Hant/   ja/
│     ├── name.txt                   # App Store name (≤30 chars)
│     ├── subtitle.txt               # ≤30 chars, shows under name
│     ├── description.txt            # 4000 chars
│     ├── keywords.txt               # 100 chars, comma-separated
│     ├── promotional_text.txt       # 170 chars, can update anytime
│     ├── release_notes.txt          # what's-new for this version
│     ├── support_url.txt
│     ├── marketing_url.txt
│     └── privacy_url.txt
└── screenshots/                      # filled in by scripts/screenshots.sh
```

ASC locale codes map: `en-US`, `zh-Hans` (Simplified Chinese),
`zh-Hant` (Traditional Chinese), `ja` (Japanese).

`Configuration.storekit` at `RoastMate/Configuration.storekit` is the
authoritative source for IAP product metadata — copy its
`localizations` arrays verbatim into ASC's product localization fields.

---

# Phase 1 — Apple Developer (developer.apple.com/account)

You're doing all four steps in the Identifiers and App Groups sections
under `Certificates, Identifiers & Profiles`.

## Step 1.1 — Register the App Group

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Switch the dropdown from "App IDs" to "App Groups"
3. Click `+`
4. Description: `RoastMate App Group`
5. Identifier: `group.yyh.roastmate.app`
6. Continue → Register
7. Screenshot confirmation.

## Step 1.2 — Register App ID 1 (main app)

1. Identifiers list → `+` → select "App IDs" → Continue
2. Type: App → Continue
3. Description: `RoastMate`
4. Bundle ID: **Explicit** — enter `yyh.roastmate.app`
5. Capabilities tab — enable ONLY:
   - **App Groups** (then click Configure → check `group.yyh.roastmate.app`)
6. App Services / Additional Capabilities — leave all OFF for V1.
7. Continue → Register
8. After registration, return to the App ID, edit, confirm App Group is
   linked. Save.
9. Screenshot.

## Step 1.3 — Register App ID 2 (watchOS app)

Same as 1.2 but:
- Description: `RoastMate Watch`
- Bundle ID: `yyh.roastmate.app.watchkitapp`
- Capabilities: App Groups → check `group.yyh.roastmate.app`

## Step 1.4 — Register App ID 3 (Share Extension)

Same as 1.2 but:
- Description: `RoastMate Share Extension`
- Bundle ID: `yyh.roastmate.app.share`
- Capabilities: App Groups → check `group.yyh.roastmate.app`

**Verification:** Identifiers list now contains 3 App IDs and 1 App
Group. Screenshot the list. Pause and tell the user before moving to
ASC.

---

# Phase 2 — App Store Connect (appstoreconnect.apple.com)

## Step 2.1 — Create the app record

1. Go to https://appstoreconnect.apple.com/apps
2. Click `+` → New App
3. Platforms: check both **iOS** and **macOS** (single record, two
   platforms). The watchOS app rides under the iOS app record.
4. Name: `RoastMate`
5. Primary Language: `English (U.S.)`
6. Bundle ID: select `yyh.roastmate.app` from the dropdown (it must
   appear because you registered it in Phase 1)
7. SKU: `roastmate-1`
8. User Access: Full Access
9. Create
10. Screenshot.

If the macOS checkbox doesn't appear, create with iOS only — you can
add the macOS platform later from the app's sidebar via "Add macOS App".

## Step 2.2 — App Information (English source-of-truth)

Open the new app → App Information (left sidebar).

1. **Subtitle:** paste from `metadata/en-US/subtitle.txt`
2. **Primary Category:** Lifestyle
3. **Secondary Category:** Entertainment
4. **Content Rights:** select "Does not contain, show, or access
   third-party content"
5. **Age Rating:** click Edit. Walk the questionnaire:
   - Cartoon or Fantasy Violence: None
   - Realistic Violence: None
   - Prolonged Graphic or Sadistic Realistic Violence: None
   - Profanity or Crude Humor: **Infrequent/Mild**
   - Mature/Suggestive Themes: **Infrequent/Mild** (or Frequent/Intense
     if you want to be conservative)
   - Horror/Fear Themes: None
   - Medical/Treatment Information: None
   - Alcohol, Tobacco, or Drug Use or References: None
   - Sexual Content or Nudity: None
   - Graphic Sexual Content and Nudity: None
   - Gambling: None
   - Contests: None
   - Unrestricted Web Access: **No**
   - Made for Kids: **No**
   Result should be 17+. Save.
6. Save the App Information page.

## Step 2.3 — Add the 3 additional localizations

Still in App Information, at the top there's a Localization dropdown
(currently "English (U.S.)"). Click the `+` next to it (or "Add
Language" — UI text varies).

For each of `Simplified Chinese`, `Traditional Chinese`, `Japanese`:

1. Add the language
2. Switch the localization dropdown to that language
3. Subtitle: paste from `metadata/<locale>/subtitle.txt`
4. Save

ASC locale mapping:
- `zh-Hans` → "Chinese (Simplified)"
- `zh-Hant` → "Chinese (Traditional)"
- `ja`      → "Japanese"

## Step 2.4 — Pricing and Availability

Left sidebar → Pricing and Availability.

1. Price: Free
2. Availability: All countries and regions
3. Save

## Step 2.5 — App Privacy

Left sidebar → App Privacy.

1. Privacy Policy URL: `https://jasonyeyuhe.github.io/RoastMate/privacy.html`
2. Privacy Choices URL: leave blank
3. Data Types: click Get Started (or Edit).
   - Question: "Do you or your third-party partners collect data from
     this app?" — **No**
   - Save
4. This produces a "Data Not Collected" nutrition label, which matches
   the README and the in-app About AI screen.

## Step 2.6 — Version 1.0 (the actual storefront copy)

Left sidebar → iOS App 1.0 (or "App Store" → "1.0 Prepare for
Submission").

For each of the 4 localizations (English first as source-of-truth,
then zh-Hans, zh-Hant, ja):

1. Switch the language dropdown at the top to that locale.
2. **Description:** paste from `metadata/<locale>/description.txt`
3. **Promotional Text:** paste from
   `metadata/<locale>/promotional_text.txt`
4. **Keywords:** paste from `metadata/<locale>/keywords.txt` (must be
   comma-separated, no spaces around commas — already correct in file)
5. **Support URL:** paste from `metadata/<locale>/support_url.txt`
6. **Marketing URL:** paste from `metadata/<locale>/marketing_url.txt`
7. **What's New in This Version:** paste from
   `metadata/<locale>/release_notes.txt`
8. **App Store Icon:** the icon is bundled with the build, but ASC
   asks for a 1024×1024 marketing icon separately. Upload
   `/Users/jason/Documents/RoastMate/RoastMate/Assets.xcassets/AppIcon.appiconset/icon_1024.png`
9. Save the page for that locale.

Repeat for zh-Hans, zh-Hant, ja.

## Step 2.7 — Version 1.0: App Review Information

Same Version 1.0 page, scroll down to "App Review Information":

1. Sign-in required: **No**
2. Contact Information:
   - First name: Yuhe
   - Last name: Ye
   - Phone: ask the user
   - Email: ask the user (probably `support@colorarchive.me` or their
     personal address)
3. Notes: paste the FULL content of
   `metadata/review_notes.txt` (it explicitly tells the reviewer to
   verify Airplane Mode and explains the on-device positioning)
4. Save.

## Step 2.8 — Build placeholder

Leave the Build section empty for now. The user will run
`./upload.sh` after you're done; the build will appear here
automatically.

---

# Phase 3 — In-App Purchases (Subscriptions)

Left sidebar → Subscriptions (under Monetization).

## Step 3.1 — Create the Subscription Group

1. Click `+` → Create Subscription Group
2. Reference Name: `RoastMate Pro`
3. Continue / Create

## Step 3.2 — Create Monthly subscription

Inside the `RoastMate Pro` group, click `+` to add a subscription.

1. Reference Name: `RoastMate Pro Monthly`
2. Product ID: `yyh.roastmate.app.pro.monthly`
3. Duration: 1 month
4. Family Sharing: Off
5. Save / Continue
6. **Subscription Pricing:**
   - Click "Add Subscription Price"
   - Starting price: USD `$2.99` (tier auto-fills)
   - Available in all countries
   - Save
7. **Localizations:** for each of `English (U.S.)`, `Simplified
   Chinese`, `Traditional Chinese`, `Japanese`:
   - Add the language
   - Display Name and Description: copy verbatim from
     `Configuration.storekit` — search the file for the matching
     `productID` and `locale`. For example:
     - en_US display name: `Monthly`
     - en_US description: `Unlimited generations + all styles, billed monthly.`
     - zh_Hans display name: `月度`
     - zh_Hans description: `无限生成 + 全部风格,按月订阅。`
   - Save
8. **Review Information:**
   - Screenshot: upload the monthly paywall screenshot from
     `metadata/screenshots/` if available, else use the 1024×1024 icon
     as a placeholder (you can replace later)
   - Review Notes: `Monthly subscription unlocks Pro features:
     unlimited generations, all 20+ styles, parallel multi-style,
     multi-turn Argument Simulator, unlimited history. No external
     payment links.`
   - Save

## Step 3.3 — Create Yearly subscription

Same as 3.2 but:

1. Reference Name: `RoastMate Pro Yearly`
2. Product ID: `yyh.roastmate.app.pro.yearly`
3. Duration: 1 year
4. Family Sharing: Off
5. Save / Continue
6. **Subscription Pricing:** USD `$19.99`
7. **Introductory Offer:**
   - Click "Set Up Introductory Offer"
   - Offer Type: Free
   - Duration: 1 week (7 days)
   - Available in all countries
   - Eligible Users: All eligible users
   - Save
8. **Localizations** (from `Configuration.storekit`):
   - en_US: name `Yearly`, desc `Unlimited generations + all styles, billed yearly. 7-day free trial.`
   - zh_Hans: name `年度`, desc `无限生成 + 全部风格,按年订阅。7 天免费试用。`
   - zh_Hant: name `年度`, desc `無限生成 + 全部風格,按年訂閱。7 天免費試用。`
   - ja_JP: name `年額`, desc `無制限の生成 + すべてのスタイル、年額。7日間無料体験。`
9. **Review Information:**
   - Same screenshot placeholder strategy
   - Review Notes: `Yearly subscription with 7-day free trial. Same
     Pro entitlements as Monthly.`
   - Save

## Step 3.4 — Subscription Group Localization

Back at the `RoastMate Pro` group page:

1. Click "Localizations" or the group's pencil icon
2. Add display names per locale, copy from `Configuration.storekit`:
   - en_US: Display Name `RoastMate Pro`
     Description: `Unlimited generations, all styles, and pro-only
     features.`
   - zh_Hans: `RoastMate Pro` / `无限生成,全部风格解锁,专属高级功能。`
   - zh_Hant: `RoastMate Pro` / `無限生成,全部風格解鎖,專屬高級功能。`
   - ja_JP: `RoastMate Pro` / `無制限の生成、すべてのスタイル、Pro限定機能。`
3. Save

---

# Phase 4 — Final verification

1. Take a screenshot of the App Store record's main page showing
   "Ready for Submission" or "Waiting for Build" status.
2. Take a screenshot of the Subscriptions tab showing both products
   approved or in "Ready to Submit" state.
3. Take a screenshot of App Privacy showing "Data Not Collected".
4. Take a screenshot of Age Rating showing 17+.

Send the screenshots to the user. Don't click "Submit for Review" — the
user needs to upload the build first via `./upload.sh` and may want
to do TestFlight rounds.

# When you're done

Report back with:

- Which steps completed without issues
- Which steps showed a UI that didn't match these instructions (with
  screenshots so the user can advise)
- What's left for the user to do manually (specifically: build upload
  via `./upload.sh`, TestFlight setup, the actual "Submit for Review"
  click)

If you hit a step that requires the user's personal info (phone, email
for review contact) or a payment-related confirmation, stop and ask.
