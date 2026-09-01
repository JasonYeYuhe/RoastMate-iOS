# Privacy Policy for RoastMate (帮你骂)

**Effective: 2026-05-14**
**Last updated: 2026-05-14**

This policy describes how the RoastMate iOS, macOS, and watchOS app
("the app") handles your data. By installing or using the app, you
agree to the practices below.

---

## TL;DR

RoastMate keeps almost all your data on your device. There is **one
optional exception**: the Vent and Feral intensities can be routed
through a cloud AI proxy (off by default to verify privacy; on by
default in production to make the feature actually work).

- ✅ Calm, Sharp, and Savage intensities — 100% on-device, always.
- ✅ Rewrite-as-sendable — 100% on-device, always.
- ⚠️ Vent and Feral intensities — by default route through our private
  Cloudflare Worker proxy to a third-party LLM provider, because
  Apple's on-device model refuses to produce real vent output. The
  current upstream is Groq (Qwen3.6 27B) with OpenRouter as a
  fallback; we may swap to a
  different provider in the future without further notice if quality
  or availability requires it. You can turn this off in Settings →
  AI & Privacy → "Stronger Vent / Feral (Cloud AI)" to keep
  everything local.
- ✅ Your history, threads, and saved replies are never sent to us. They
  are stored on your device and, if you are signed in to iCloud, mirrored
  through Apple's CloudKit into **your own private iCloud database** so
  your history follows you across your devices. That data belongs to your
  Apple Account — we have no access to it and it never reaches our
  servers. Cloud requests for Vent / Feral are stateless on our side — we
  do not store a copy of the text on our proxy. Upstream providers may
  process or temporarily retain requests according to their own
  policies; see "Information we collect" below.
- ✅ No analytics SDKs, no advertising IDs, no device fingerprinting.

Verify the local-only path by toggling Cloud AI off in Settings, then
enabling Airplane Mode — every other intensity still works.

---

## Information we collect

**Cloud Vent / Feral requests** are the only data the app sends to
servers we operate. The request contains:

- The text of your situation (the input you typed).
- The intensity you chose (`vent` or `feral`).
- The style name you chose.
- Your UI locale (`zh-Hans`, `ja`, `en`, etc.).
- An opaque per-install UUID generated on your device. We use it
  exclusively to enforce a daily rate-limit per device. It is not
  linked to your Apple ID, name, email, or any other identity.

**What our proxy does with the request:**

1. Validates input length and intensity.
2. Increments the per-device daily counter in Cloudflare KV (we keep
   only the counter, not the text).
3. Builds the system prompt server-side (so the upstream provider
   never sees a user-controlled system prompt) and forwards your
   situation + locale to whichever upstream LLM provider we're
   currently using. As of the current build that's primarily Groq
   ([groq.com](https://groq.com)) with OpenRouter
   ([openrouter.ai](https://openrouter.ai)) as fallback.
4. Returns the generated text to your device. Our proxy does not
   retain a copy of either the request text or the response.

**What the upstream providers do:** Groq and OpenRouter each have
their own privacy policies that govern what they do with API
requests. In summary: by default neither provider retains customer
prompts long-term, but both reserve the right to retain them
temporarily (typically up to 30 days) for reliability investigation,
abuse prevention, or compliance purposes. Some upstream models may
be used to improve the model. Refer to their published policies
([Groq](https://groq.com/privacy-policy/),
[OpenRouter](https://openrouter.ai/privacy)) for the authoritative
terms. If this is unacceptable to you, turn Cloud AI off in
Settings — the local-only path will still produce a (gentler) Vent
draft using Apple's on-device model.

**Other network traffic** the app may initiate:

1. **App Store / StoreKit** — when you open the paywall or make a
   subscription purchase, the system frameworks talk to Apple. We do
   not see your purchase details directly; we only learn whether you
   have an active subscription via Apple's `Transaction` API.
2. **Crash reports** — if you have iOS / macOS Diagnostics & Usage
   sharing enabled, Apple may send crash reports to us. These contain
   no personal information.
3. **Sign in with Apple** — if you choose to sign in, Apple's system
   sign-in flow talks to Apple. We store only the Apple-issued user
   identifier and any name/email you choose to share locally in
   Keychain, so Settings can show your account state.

We do not use any AI service beyond the upstream providers described
above for Vent / Feral. We do not embed analytics SDKs (Firebase,
Amplitude, Mixpanel, Sentry, etc.). We do not use advertising
identifiers (IDFA, IDFV for tracking, AppsFlyer, etc.). We do not
fingerprint your device.

---

## Information stored locally on your device

The following is stored only on your device, inside the app's
sandbox / App Group container:

- **Roast history.** The situations you typed and the responses
  generated. Stored in SwiftData. You can delete individual entries or
  clear all sample data from Settings.
- **Settings.** Your language preference, Safe Mode toggle, daily
  quota counter, and onboarding state.
- **Subscription state.** Whether you have an active Pro subscription,
  derived from Apple's StoreKit framework.
- **Optional account state.** If you use Sign in with Apple, the
  Apple-issued user identifier and any shared name/email are stored
  locally in Keychain.

On the same device, app-family targets can use the App Group
`group.yyh.roastmate.app` as a local shared container where supported.

**Cross-device iCloud sync.** Roast history (including private Vent and
Feral drafts), threads, saved situations, settings and credit ledger
entries are mirrored via SwiftData + CloudKit into the private iCloud
database of the Apple Account signed in on the device (container
`iCloud.yyh.roastmate.app`). This is what makes your history available on
your other devices. It is **your** iCloud storage: RoastMate's developer
cannot read it, and it is never sent to our servers or to any third
party. It follows your device's iCloud state — signing out of iCloud, or
turning off iCloud Drive for RoastMate in iOS Settings, stops it.

---

## Children

RoastMate is rated **17+** for mature humor and sarcasm. It is not
intended for children under 17. We do not knowingly collect data from
anyone — including children.

---

## Your rights

Because we do not collect or store any data on our servers, there is
nothing to access, export, correct, or delete from us. To remove all
local data, uninstall the app or use the in-app **Settings → Clear
sample data** and **Settings → Manage subscription**.

---

## Changes to this policy

If we ever change the policy (for example, when adding the optional
Phase 2 cloud features), we will update the "Last updated" date and
post a notice in the app. Cloud features, if added, will be opt-in and
clearly described.

---

## Contact

Questions about this policy? Email **support@colorarchive.me**
(replace with the real support address before launch).
