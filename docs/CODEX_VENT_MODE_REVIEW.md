# Codex review request — Vent Mode + Intensity rework (v1.x)

## TL;DR for you (codex)

Yuhe shared with me the product brief that came out of your previous
conversation: pivot RoastMate from "AI roast generator" to "vent first,
then send the version that wins" — Vent Mode draft + Sendable Reply
rewrite + intensity levels + Situation Threads.

I read your brief and implemented the backend in full plus the App
Store-side copy. The current Xcode project **builds clean for iOS and
all 30 existing unit tests pass**. UI surfacing of the new intensity
picker / vent-disclosure / sendable-rewrite button has **not** been
wired into the SwiftUI views yet — that's the main thing I want you to
finish, plus a code review of what's already in.

I also pushed back on four parts of your brief — see "Disagreements"
below. If you think any of those are wrong, override me; you have full
context on the product direction and I only have one snapshot.

---

## What was actually changed (file-level)

All paths are relative to `/Users/jason/Documents/RoastMate/`.

### New files

- `Shared/Models/Intensity.swift`
  - `Intensity` enum: `.calm / .sharp / .savage / .vent`.
  - `GeneratedRoastKind` enum: `.normalRoast / .ventDraft / .sendableReply / .rewrite`.
  - Both have `.legacyDefault` for backward-compatible reads.
  - `Intensity.requiresPro` returns true for `.savage` and `.vent`.

- `Shared/Models/SituationThread.swift`
  - `SituationThread` `@Model` with `title / originalSituation /
    category / mood / createdAt / updatedAt / isFavorite / isResolved
    / sessions[]`.
  - `SituationCategory` enum: `work / relationship / family / friends
    / internet / other`.
  - `SituationMood` enum: `angry / wronged / speechless / anxious /
    petty / amused`.

- `Shared/Services/ThreadService.swift`
  - `promoteToThread(session:title:category:mood:context:)` — promotes
    an existing `RoastSession` to be the root of a new thread without
    duplicating data.
  - `priorContextSummary(thread:excluding:)` — builds the
    `priorContext` string `RoastEngine.generate` accepts so subsequent
    rounds remember earlier turns. Pulls the favorited output of each
    prior turn (or the first sendable reply, or the first output).
    Caps at last 4 turns.
  - `allThreads / threads(matching:) / favoriteThreads / markResolved`
    query helpers.

- `docs/CODEX_VENT_MODE_REVIEW.md` (this file).

### Modified files

- `Shared/Models/RoastSession.swift`
  - Added optional `intensityRaw: String?` (default reads back as
    `.legacyDefault` = `.sharp`).
  - Added optional `thread: SituationThread?` (inverse populated by
    `SituationThread.sessions`).
  - Default-arg `intensity:` in initializer.

- `Shared/Models/GeneratedRoast.swift`
  - Added optional `kindRaw: String?` (legacy default `.normalRoast`).
  - Added optional `sourceVentDraftIdRaw: String?` (id of the vent
    draft this sendable reply was rewritten from).
  - Added `isFavorite: Bool` (per-output favorite; was previously only
    on session level).

- `Shared/AI/PromptBuilder.swift` — full rewrite.
  - `systemPrompt(style:locale:mode:intensity:safeMode:)` — adds
    `intensityGuidance` line and, for `.vent`, the `ventPreamble`.
  - `userPrompt(situation:styleName:variants:mode:intensity:priorContext:)`
    — supports prior-context injection for thread continuation; in
    `.vent` always asks for exactly 1 result without numbering.
  - `rewriteAsSendablePrompt(ventDraft:originalSituation:styleName:locale:)`
    — returns `(system, user)` for the second-pass cool-down LLM call.

- `Shared/AI/RoastEngine.swift` — full rewrite.
  - `generate(... intensity: Intensity = .sharp, safeMode: Bool = true,
    priorContext: String? = nil ...)`.
  - Vent intensity bumps temperature by +0.1 (capped at 1.0), routes
    output through the relaxed `validateVentOutput`, always returns 1
    draft regardless of caller's variant count.
  - `rewriteAsSendable(ventDraft:originalSituation:style:locale:)` —
    creates a *fresh* `LanguageModelSession` (does NOT reuse the vent
    session), uses lower temperature, runs the result through the
    strict `validateOutput`.

- `Shared/AI/SafetyFilter.swift`
  - Added `validateVentOutput(_:)` — same length check, but only
    blocks on a small hard-rail substring list (`kill yourself / kys /
    去死 / 杀了你 / suicide / shoot / stab` etc.) instead of the full
    denylist. Vent drafts are allowed mild profanity by design — the
    full denylist still applies to anything routed through
    `validateOutput`, which is what sendable rewrites use.

- `Shared/Services/HistoryService.swift`
  - `saveSession` gained `intensity:` and `thread:` parameters.
    Variants of a `.vent` session are tagged `.ventDraft`; everything
    else is `.normalRoast`. Touches `thread.updatedAt` when attached.
  - **New** `appendSendableReply(toSession:sourceVentDraft:rewrittenText:context:)`
    — adds a `.sendableReply` `GeneratedRoast` to an existing session
    with `sourceVentDraftId` pointing back to the draft it came from.

- `Shared/SharedModelContainer.swift`
  - Schema now includes `SituationThread.self`.

- `Shared/{en,zh-Hans,zh-Hant,ja}.lproj/Localizable.strings`
  - `intensity.{calm,sharp,savage,vent}.{name,blurb}`
  - `output.kind.{vent_draft,sendable_reply}.label`
  - `output.vent.disclosure`
  - `output.rewrite.{button,in_progress}`
  - `thread.{untitled, continue.button, add_round.placeholder,
    section.{recent,favorites,unresolved,resolved},
    mark_{resolved,unresolved}}`
  - `category.{work,relationship,family,friends,internet,other}.name`
  - `mood.{angry,wronged,speechless,anxious,petty,amused}.name`
  - `rewrite.fallback.unavailable`

- `metadata/{en-US,zh-Hans,zh-Hant,ja}/description.txt` — hero
  paragraph + features bullet list updated for the new positioning
  ("Vent first. Then send the version that actually wins.").

- `metadata/{en-US,zh-Hans,zh-Hant,ja}/promotional_text.txt` —
  rewritten as one sentence matching the new positioning.

- `metadata/review_notes.txt` — item 2 (POSITIONING) is now a multi-
  paragraph entry that explicitly describes Vent Mode, the
  "for-yourself-only" UI labelling, and the reviewer test path
  (Generator → Vent intensity → "Make it sendable" button). Item 1
  also notes that BOTH the vent pass and the rewrite pass run
  on-device.

### Files I did NOT modify (intentionally, see "Gaps for codex")

- Any SwiftUI view file. The new `Intensity` parameter has a default
  of `.sharp` in `RoastEngine.generate` and `HistoryService.saveSession`,
  so existing call sites compile and behave identically to before. The
  UI gap is your work to finish.

---

## Disagreements with the brief — call these out if you disagree

### 1. Vent is an intensity, not a mode

Brief had both `mode: vent` and `intensity: vent`. I made `Intensity`
orthogonal to `RoastMode` — any mode (reply / translate / argument /
social / roast) can be invoked at `.vent` intensity. Concept-wise this
is cleaner; UI-wise the user sees mode-picker + intensity-picker as
two separate row of chips.

**If you want strict-vent-as-mode** instead, the cleanest patch is to
add a `vent` case to `RoastMode` and remove `.vent` from `Intensity`,
or keep both but make `.vent` intensity only valid in `.roast` mode.

### 2. Don't generate both cards every time

Brief implied always returning ventDraft + sendableReply pair. I made
the **rewrite a user-initiated second call**, surfaced as a "Make it
sendable" button on the vent-draft card. Reasoning:

- 2× LLM cost on every generation (latency + battery).
- Real path: user vents → cools down → *then* decides whether to
  actually send something. Forcing both at once breaks that arc.
- Auto-dual still possible for Pro as a settings toggle if you want.

If you want it auto-dual by default, the call site change is a single
extra `await rewriteAsSendable(...)` in the view-model after the
generate call.

### 3. SituationThread is an additive layer, not a rewrite of history

I didn't touch `RoastSession` / `GeneratedRoast` semantics. New
`SituationThread` model has a one-to-many to `RoastSession`. Existing
ad-hoc sessions remain thread-less and continue to render in the
history view via the existing `RoastSession` query.

`ThreadService.promoteToThread(session:...)` lets the UI create a
thread on demand when the user hits "Continue this event" on any
existing session.

### 4. Reviewer-facing safety claim: vent really must be vent

Vent intensity bumps temperature by +0.1 and uses the relaxed output
validator, **but** the `ventPreamble` in `PromptBuilder.swift`
explicitly forbids slurs, threats, sexual content, identity attacks,
and self-harm content. The hard-rail substring list in
`SafetyFilter.validateVentOutput` adds a belt-and-suspenders check for
violence-style phrases.

If a reviewer tries to use `.vent` to elicit something genuinely
harmful, the model preamble + post-filter should reject it. If you
write tests that prove this empirically with a few adversarial
inputs, that would be the highest-value test you could add — see
"Verification checklist" below.

---

## Gaps you should close

### Critical (blockers for shipping the new product)

1. **Intensity picker in `RoastGeneratorView` and `FeatureGeneratorView`**.
   - Add `selectedIntensity: Intensity = .sharp` to view-models.
   - A horizontal scroll row of 4 chips under the style picker.
   - Pro-gate `.savage` and `.vent` via the same paywall as Pro
     styles.
   - Pass `intensity:` to `RoastEngine.shared.generate(...)` and
     `HistoryService.saveSession(...)`.

2. **Result card rendering for vent vs sendable**.
   - When session was generated at `.vent`, the result card needs the
     "Vent draft · for yourself only" label and the
     `output.vent.disclosure` banner above the button row.
   - Replace / add a "Make it sendable" button (key
     `output.rewrite.button`).
   - On tap: show inline spinner with key `output.rewrite.in_progress`,
     call `RoastEngine.shared.rewriteAsSendable(...)`, then call
     `HistoryService.appendSendableReply(...)`. Render the new
     sendable reply card right below the vent draft, paired visually.
   - For `.normalRoast` outputs, keep the existing card chrome — no
     change.

3. **`appendSendableReply` actually goes into the source session.**
   - The view-model holds a `RoastSession` reference; it needs to call
     `HistoryService.appendSendableReply(toSession:sourceVentDraft:rewrittenText:context:)`.

### High-value but not blocking

4. **Situation Thread UI**.
   - History view: group existing sessions by thread (sessions whose
     `thread` is non-nil) vs. orphans.
   - Thread detail view: ordered list of rounds, each round = one
     `RoastSession` with its results. At the bottom: an input field
     with `thread.add_round.placeholder` and a button using
     `thread.continue.button` that calls `RoastEngine.generate` with
     `priorContext: ThreadService.priorContextSummary(thread:)`.
   - Quick-action "promote to thread" entry on any standalone session
     row.

5. **Fix Pro entitlement at the savage / vent gate**.
   - `Intensity.requiresPro` exists. Add an enforcement check in the
     view-model: if `intensity.requiresPro && !StoreService.shared.isPro`,
     surface the paywall instead of generating.

6. **Tests we should add**.
   - `IntensityTests.swift`:
     - `requiresPro` returns expected values.
     - `legacyDefault == .sharp`.
   - `PromptBuilderIntensityTests.swift`:
     - Vent intensity injects `ventPreamble` into system prompt.
     - Vent intensity user prompt omits numbering and asks for 1 draft.
     - Calm intensity guidance contains "professional".
     - Sendable rewrite prompt includes the original situation AND the
       vent draft, and instructs no profanity.
   - `SafetyFilterVentTests.swift`:
     - "shoot you" in vent output blocked.
     - Mild profanity ("damn", "屁话") in vent output passes.
     - Same content in `validateOutput` (sendable path) blocked.
   - `HistoryServiceSendableReplyTests.swift`:
     - `appendSendableReply` sets `kind == .sendableReply` and
       `sourceVentDraftId == ventDraft.id`.
   - `ThreadServiceTests.swift`:
     - `promoteToThread` attaches without duplicating.
     - `priorContextSummary` prefers favorited output, then sendable,
       then first.

### Polish / followups

7. The legacy `RoastCard` view (referenced from `FeatureGeneratorView.results`)
   doesn't know about `GeneratedRoastKind`. Either pass a `kind:` and
   add a label slot, or introduce `VentDraftCard` / `SendableReplyCard`
   variants. I'd vote for variant components — clearer at the call site.

8. `SampleRoastsCatalog` doesn't have any `.ventDraft` samples. If you
   want the reviewer to see Vent on first launch without typing, add at
   least one sample seeded as a vent draft + paired sendable reply via
   `HistoryService.appendSendableReply`.

9. The CloudKit / Sign in with Apple work from the previous round
   added entitlements that don't yet live in the local provisioning
   profile. Xcode needs to refresh the profile (Signing & Capabilities
   → Try Again, or delete derived data) before a real-device build
   succeeds. `xcodebuild ... CODE_SIGNING_ALLOWED=NO` builds clean in
   the simulator.

10. The free-tier daily limit in `UserSettings.swift` is still
    `freeDailyLimit = 5`. Yuhe's brief mentions "first launch gives 20
    + 5/day after". I didn't change this; it's a Pro-pricing decision
    we should align on first.

---

## Verification checklist for you (codex)

Run / check in order. I've already done #1–#3.

1. ✅ `xcodegen generate` ran clean.
2. ✅ `xcodebuild -scheme RoastMate -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds (only warning is an unrelated AppIntents metadata one).
3. ✅ `xcodebuild -scheme RoastMateTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test` → 30 tests passed.
4. Confirm the new files appear in the regenerated `.xcodeproj` (open the project navigator).
5. Read the four files in `Shared/Models/` and `Shared/AI/` and
   confirm the SwiftData model changes are additive — no existing
   field changed type, none removed, all new ones nullable with
   default reads.
6. Open `metadata/review_notes.txt` and verify the new POSITIONING
   section reads honestly about what the app actually does. If you
   spot anything that overclaims (e.g. "we never store..." but we now
   do, in Keychain), flag it.
7. Adversarial Vent test (manual): tweak `PromptBuilderTests` to add a
   case asserting that the vent system prompt for a malicious input
   ("I want to threaten my coworker with violence") would still
   produce text that fails the strict `validateOutput`. If we can
   prove the rewrite path catches things the vent path lets through,
   that's the safety story Apple needs.
8. Wire up the UI (gaps 1–3 above).
9. Add the tests in gap 6.
10. Re-run the test suite after wiring; it should still be green plus
    however many you add.

---

## Open product questions I'd like your call on

- **Pro pricing**: should `.savage` be Pro or free? `.vent` Pro feels
  obvious; `.savage` could go either way. I marked both as Pro for now.
- **Sendable rewrite cost on free tier**: the rewrite is a second LLM
  call. Should it count against the daily quota, or be free because the
  user already burned one quota point on the vent draft? I left it
  uncounted in the current code, which is generous; tighten if you
  want.
- **Auto-titling threads**: `ThreadService.autoTitle` is dumb (takes
  the first sentence up to 24 chars). A second small LLM call could
  produce something like "老板临时甩锅" reliably. Worth doing? It's
  another generation pass per thread creation.
- **Sample data**: should the first-launch seed include a paired
  vent-draft + sendable-reply demo, so the user sees the flow
  immediately? Currently the sample catalog is single-output only.
- **Apple Watch + Share Extension**: Vent intensity on watchOS is
  weird (small screen, can't easily type long vents). I'd keep Vent
  iPhone/iPad/Mac only and have watchOS default to `.sharp`. The Share
  Extension flow is one-shot, so I'd skip the intensity picker there
  too. Confirm or override.

---

## A reminder I'd appreciate you double-check

Yuhe asked me to make sure the new copy doesn't contradict the
Sign-in-with-Apple / iCloud / Keychain story from the previous
session. I updated `metadata/review_notes.txt` item 4 (ACCOUNTS /
SYNC) earlier and item 2 (POSITIONING) just now. If you can read both
items end-to-end and confirm they tell a single coherent privacy
story, that would be great.

End. Tell Yuhe what you found.
