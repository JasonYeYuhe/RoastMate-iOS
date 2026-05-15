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
  Cloudflare Worker proxy to a cloud model (DeepSeek V3 via OpenRouter)
  because Apple's on-device model refuses to produce real vent output.
  You can turn this off in Settings → AI & Privacy → "Stronger Vent /
  Feral (Cloud AI)" to keep everything local.
- ✅ Your history, threads, and saved replies stay on-device. Cloud
  requests for Vent / Feral are stateless — the proxy does not log
  your text and the upstream model does not retain it.
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
2. Increments the per-device daily counter in Cloudflare KV.
3. Forwards the situation + intensity + locale to OpenRouter
   ([openrouter.ai](https://openrouter.ai)) for inference using
   DeepSeek V3.
4. Returns the generated text to your device. We do not retain a copy.

**What OpenRouter / the upstream model do:** Per OpenRouter's policy,
prompts sent to the DeepSeek V3 free model may be retained briefly for
abuse-prevention purposes and may be used to improve the model. If this
is unacceptable to you, turn Cloud AI off in Settings. The local-only
path will still produce a (gentler) Vent draft.

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

We do not use OpenAI, Anthropic, Google, Meta, Microsoft Azure, or any
other AI service beyond the OpenRouter pathway described above for
Vent / Feral. We do not embed analytics SDKs (Firebase, Amplitude,
Mixpanel, Sentry, etc.). We do not use advertising identifiers (IDFA,
IDFV for tracking, AppsFlyer, etc.). We do not fingerprint your
device.

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
Cross-device iCloud sync is not part of the current 1.0 release; if
added later, it will be opt-in and clearly described.

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
