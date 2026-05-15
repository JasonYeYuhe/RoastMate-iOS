# App Store Connect — final submission delta

Everything in code + metadata is ready. This doc lists the ASC-side
changes (those happen in the ASC web UI, NOT in this repo) and the
Review Notes template to paste into App Review Information.

---

## 1. App Privacy / Nutrition Labels (App Privacy section in ASC)

Status before v1.6: "Data Not Collected" (because everything was
on-device).

Status after v1.6: We now route Vent + Feral private drafts through
our own Cloudflare Worker → OpenRouter / Groq for inference. That is
third-party data flow and **must** be declared.

Click **Edit** under App Privacy → Data Types and add these two
data types. Both go in the same `App Functionality` purpose
category.

### Data type 1 — User Content → Other User Content

- **Collected?** Yes
- **Linked to user's identity?** No (no Apple ID, no name, no email
  is sent — only the situation text + a random per-install UUID)
- **Used to track user across apps/websites?** No
- **Purposes** (check all that apply):
  - [x] App Functionality
- **What we tell Apple it is:** "User-typed situations are sent to
  our private edge proxy and forwarded to a third-party LLM provider
  (OpenRouter or Groq) solely to generate the requested Vent / Feral
  draft. The user can disable this routing in Settings; everything
  else (Calm / Sharp / Savage / Rewrite) runs on-device."

### Data type 2 — Identifiers → Device ID

- **Collected?** Yes
- **Linked to user's identity?** No
- **Used to track user across apps/websites?** No
- **Purposes**:
  - [x] App Functionality
- **What we tell Apple it is:** "An opaque UUID is generated once on
  first launch and stored in Keychain, sent with each Vent/Feral
  cloud request to enforce a per-device daily rate limit (30/day).
  Not linked to Apple ID or any other identifier."

### Data type 3 — Purchases (no change)

This was already declared (Pro IAP). Leave alone.

### Anything else to declare?

No. We do not collect:
- Contacts, photos, location, health, financial info
- Browsing history, search history
- Analytics, crash reports beyond Apple-provided diagnostics
- Advertising IDs, IDFV-for-tracking
- Audio data

---

## 2. App Review Information — Notes for the Reviewer

Paste this verbatim into **App Review Information → Notes**:

```
RoastMate is a creative-writing tool for venting + crafting hard
conversations. It has two AI paths:

1) On-device path (default):
   - Intensities: Calm, Sharp, Savage, plus the "rewrite as sendable"
     post-processor
   - Runs on Apple Foundation Models locally; works in Airplane Mode

2) Cloud path (default ON, user can disable):
   - Intensities: Vent, Feral (both labelled "for yourself only,
     private draft")
   - Routes the user's typed situation + intensity + locale + a
     random per-install UUID through our own Cloudflare Worker
     (https://roastmate-vent.yyyyy-yeyuhe.workers.dev) to OpenRouter
     or Groq for inference. The Worker enforces a 30 request/day
     per-device limit.
   - We chose this routing because Apple's on-device model declines
     to produce real venting output (it reframes anger into
     reflective self-help, which defeats the marquee feature). The
     cloud model produces actual cathartic text that the user is
     told NOT to send as-is — the app's second-pass "Make it
     sendable" rewrite (which runs on-device) is what converts the
     draft into a respectful reply.

How to verify the user can disable cloud routing:

  Settings → AI & Privacy → "Stronger Vent / Feral (Cloud AI)" toggle
  OFF → generate a Vent draft → output is now produced by Apple's
  on-device model (much gentler register, but still functional).

How to verify a Vent draft is not a sendable message:

  - The draft card shows a lock icon + the text
    "Vent / Feral drafts are private. Don't send them — tap below
     for a version that actually wins."
  - The card has an explicit "Make it sendable" button that
    triggers an on-device rewrite into a respectful version.

Demo account: not required — the app works fully without signing
in. Sign in with Apple is optional and only changes the Settings
greeting.

Safety:
- Universal safety preamble injected into every system prompt blocks
  slurs, threats of violence, sexual content, doxxing, and attacks on
  protected attributes — for both local and cloud paths.
- No external names are accepted: a SafetyFilter strips any
  recognizable real-person name from input before generation.
- Age gating: 17+ acknowledgement is required at first launch.

Privacy Policy: https://jasonyeyuhe.github.io/RoastMate/privacy.html
(updated to describe the Cloud Vent path and the user-controllable
toggle).

Contact for review: Yuhe Ye · +81 080 3526 7088 ·
yyyyy.yeyuhe@icloud.com
```

---

## 3. Sanity checks before hitting "Submit for Review"

- [ ] **App version** in ASC matches `MARKETING_VERSION` in
  `project.yml` (currently `1.0.0`).
- [ ] **Build number** in ASC matches `CURRENT_PROJECT_VERSION`
  (bump to `2` if you're uploading a new build, otherwise leave
  `1`).
- [ ] **Screenshots**: still valid for 6.9", 6.7", 6.5". Only the
  generator screen needs a refresh if your screenshots show old
  output text — capture one new "Vent draft + sendable" screenshot
  showing the orange + green paired card UX from v1.4.
- [ ] **App Description** in ASC matches
  `metadata/{en-US,zh-Hans,zh-Hant,ja}/description.txt` (we already
  rewrote the privacy paragraphs to mention the cloud path — make
  sure ASC reflects that, not the old "100% on-device" claim).
- [ ] **Privacy Policy URL** is reachable + content is up to date.
- [ ] **Subscription Group + IAP** still active.
- [ ] **TestFlight** smoke pass on at least one external tester
  before submitting (catches device-specific failures the simulator
  hides).

---

## 4. If Apple Review pushes back

Most likely complaints + responses:

| If they say | Your reply |
|---|---|
| "Cloud routing isn't disclosed clearly enough" | Point to Settings toggle + Privacy Policy section "Cloud AI for Vent / Feral" + in-app onboarding disclosure |
| "Vent output contains profanity that violates Guideline 1.1" | The Vent draft is explicitly marked "private, for yourself only" with a lock icon and a "do not send" disclosure. The sendable rewrite (on-device) strips profanity. Age-gated 17+. |
| "Where is the privacy practice description?" | Privacy Policy URL above; nutrition labels declare User Content + Device ID as collected for App Functionality |

If they ask for a real demo of the cloud path being optional: same
toggle path as the Notes section above.
