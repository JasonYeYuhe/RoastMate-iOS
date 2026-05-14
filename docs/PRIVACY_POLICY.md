# Privacy Policy for RoastMate (帮你骂)

**Effective: 2026-05-14**
**Last updated: 2026-05-14**

This policy describes how the RoastMate iOS, macOS, and watchOS app
("the app") handles your data. By installing or using the app, you
agree to the practices below.

---

## TL;DR

RoastMate is built so your drafts and history **stay on your device**.

- ✅ All AI generation runs on your device using Apple's Foundation
  Models framework.
- ✅ Your inputs and generated text are **not** transmitted to RoastMate
  servers, OpenAI, Anthropic, Google, or any third-party AI service.
- ✅ We do not collect usage analytics, advertising IDs,
  or device identifiers.
- ✅ You can verify this by enabling Airplane Mode — RoastMate's
  generator continues to work.

---

## Information we collect

**None is collected by RoastMate servers.** The app does not contact our
servers for any feature. The app's App Store privacy nutrition label is
**Data Not Collected**.

The only network traffic the app initiates is:

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

We do not use OpenAI, Anthropic, Google, Meta, Microsoft, or any other
third-party AI service. We do not embed analytics SDKs (Firebase,
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
