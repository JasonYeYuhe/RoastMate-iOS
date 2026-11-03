# iOS 1.8.0 (28) rejected — 2.1(b), subscription purchase error (2026-11-02)

**Apple's report:** submission `da992ccb-85ed-4d95-89de-364c0cc95a98`, reviewed
2026-11-02 on an iPhone 17 Pro Max with iOS 27.2: "when we tried to purchase the
subscriptions the app showed an error message". The message mentions no
screenshot. macOS 1.8.0 (28), with the same paywall and `StoreService`, was
approved the same day and is READY_FOR_SALE.

## Checked (read-only, 11-02)

| question | answer | how |
|---|---|---|
| Subscriptions configured? | both APPROVED; review screenshot COMPLETE; availability set; yearly 1-week trial (5 territory offers) | ASC API |
| `multiSeatStatus: ENABLED` / `marketSettings` new fields? | on every subscription of every app on the team → a default, not a cause | ASC API, all apps |
| Subscription text edits | the 8 new descriptions are still PREPARE_FOR_SUBMISSION, the old ones APPROVED; they were 2 of the 3 items in the rejected submission | ASC API |
| What does the buyer see? | a StoreKit throw → alert "Purchase didn't go through" + StoreKit's `localizedDescription`; the success alert is "You're Pro" and the A6 hand-off runs only after the sheet closes, so neither is the reported error | `PaywallView.swift`, `StoreService.swift` |
| Purchase code changed since 1.7.3 (passed iOS review)? | no: `product.purchase()` with no arguments in both | `git diff v1.7.3 cd1667d` |
| Does the 27.2 SDK deprecate `purchase(options:)`? | no: identical declaration in Xcode 27.1 and 27.2 SDKs | `StoreKit.swiftinterface` |
| Paid Apps Agreement in effect? | **not checkable through the API** — Jason, ASC → Business | — |

## Suspected cause (not proven)

`Product.purchase()` passes no UI context, so StoreKit picks the window that
confirms the purchase. Apple's documented purchase API for SwiftUI apps is
`@Environment(\.purchase)` (`PurchaseAction`); UIKit apps get
`purchase(confirmIn:)`. A Flutter plugin hit the same 2.1(b) wording on iPadOS
27.0 with the same scene-less call and passed review after switching to
`purchase(confirmIn:)` — circumstantial, not reproduced by its reporter either
(github.com/flutter/flutter/issues/194373). Nothing found names iOS 27.2.

## Change in build 29

- `StoreService.purchase(_:using:)` / `purchaseCredits(_:using:)` take the
  purchase function from the caller; `PaywallView` passes its
  `@Environment(\.purchase)`. Same on macOS (shared code).
- A failed purchase is logged in full (`Store` category, product id + error),
  which build 28 discarded.

## Verification plan

1. Build 28 in TestFlight on Jason's iPhone (sandbox, free): buy a plan. Does it
   show the error? Screenshot either way, with the iOS version.
2. Release `PaywallFlowUITests` (SKTestSession) on iOS 27.0 with build 29's code.
3. Build 29 in TestFlight on the same iPhone: the same purchase must succeed.
4. Resubmit iOS 1.8.0 with build 29 (the two subscription edits ride along again).

If step 1 does not reproduce, the cause stays unknown: ship 29 anyway (the
documented API, no behaviour change otherwise) and send the reply below.

## Draft Resolution Center reply (Jason approves the text before it is sent)

> Hello, and thank you for the review.
>
> We have updated the purchase flow in build 29: the paywall now starts
> purchases with StoreKit's SwiftUI purchase action, so the confirmation sheet
> is presented in the app's active window. We tested a subscription purchase in
> the sandbox with this build on [device, iOS version] and it completed. The
> Paid Applications Agreement is in effect.
>
> If the error appears again, could you attach a screenshot of the message? It
> shows StoreKit's own error text, which would tell us what failed.
>
> Thank you.

The bracket is filled from step 3; the agreement sentence only after Jason checks.
