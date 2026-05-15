# Update for Codex — Locale bug fix + Feral intensity

Hey codex, two changes shipped today on top of the Vent Mode pivot you already reviewed. Quick brief + review asks.

## Context (what's already in main)

The Vent Mode pivot you reviewed is in production:
- 5 intensities now (calm/sharp/savage/**feral**/vent — feral is new today)
- Situation Threads with prior-context replay
- 17 in-bundle samples including 2 vent→sendable demo pairs
- Free-tier policy: 20 lifetime + 5/day
- Full repo lives at https://github.com/JasonYeYuhe/RoastMate-iOS (public). Latest commit at time of writing: `c762bc3 Fix non-vent locale bug + add Feral intensity tier`

## Today's change 1 — Locale bug

**Symptom** (real device, UI in zh-Hans): Calm / Sharp / Savage on the `high_eq` style produced **English** output. Vent on the same style produced Chinese correctly.

**Root cause**: `PromptBuilder.systemPrompt` put `Language: Reply in 简体中文.` as the third line of the instructions, then injected the style's few-shot examples — which are English-only on most free-tier styles — at the bottom. The model copied the examples' language and ignored the hint. Vent slipped past because the vent preamble landed AFTER the examples and took precedence over them.

**Fix** (see `Shared/AI/PromptBuilder.swift`):
1. New `languageEnforcement(for:)` function — emits a localized, imperative "OUTPUT LANGUAGE (REQUIRED)" line in the target language itself (e.g. zh-Hans: `必须用「简体中文」回复。即使上面的示例是英文,你的回复也必须完全使用简体中文。`). Appended as the LAST line of the system prompt, after the examples.
2. Examples header now reads `EXAMPLES (reference for tone only — DO NOT copy their language; obey the OUTPUT LANGUAGE directive below):` so few-shot priming is explicit.
3. New `userLanguageReminder(for:)` — short one-liner like `请用简体中文回复。` appended to the user prompt as belt-and-braces.
4. `userPrompt(...)` gained a `locale: Locale?` parameter; `RoastEngine.generate` threads its `locale` argument through.

**Test coverage added**:
- `PromptBuilderIntensityTests.testLanguageDirectiveOverridesEnglishExamples_zhHans` — asserts that the enforcement directive's offset in the prompt is strictly after the English example's offset.
- `testUserPromptAppendsLanguageReminderWhenLocaleProvided` — asserts the zh-Hans reminder lands in the user prompt.

**What I want your eyes on**:
- A) Is "OUTPUT LANGUAGE (REQUIRED)" at the bottom of `instructions` (= the LanguageModelSession system prompt) actually higher-priority than few-shot examples earlier in the same string for Apple's Foundation Models? My belief is yes — last-write-wins on most modern instruction-tuned LLMs — but you have more model intuition than me. If the answer is "no, examples almost always dominate regardless of order," then the real fix is to either (i) localize the examples per-style per-locale, or (ii) suppress examples entirely when the requested locale != the example language. Both are more work. Tell me if you think the cheap fix won't hold.
- B) The belt-and-braces user-prompt reminder feels gross. Is it doing anything useful, or just adding noise? Happy to drop it if it's pure cargo-cult.

## Today's change 2 — `feral` intensity

User feedback after smoke-testing on device: "savage 还不够狠 — 我想要真的能脏话骂街". So I added a 5th intensity sitting between savage and vent:

```swift
case feral  // pro-only, profanity unlocked, NOT a private draft
```

- `Intensity.feral.requiresPro == true`
- `Intensity.feral.isVent == false` — the output is a regular sendable variant, not labelled "for yourself only" like `.vent`
- `PromptBuilder.feralPreamble` injected into the system prompt when intensity == .feral. The preamble enumerates allowed profanity in 3 languages (en/zh/ja) and *reasserts* the universal safety rules (no slurs, no threats, no sexual, no identity attacks) absolutely.
- Routes through `SafetyFilter.validateVentOutput` (relaxed validator) instead of `validateOutput`, since the strict denylist would otherwise drop most feral candidates for containing "shit" etc.
- Temperature bump: feral now also gets `style.temperature + 0.1` like vent does, to encourage commitment to the register.

Localized chip labels:
- en: "Feral" / "No filter. Profanity unlocked."
- zh-Hans: "痛骂" / "彻底开火,带脏话。"
- zh-Hant: "痛罵" / "徹底開火,帶髒話。"
- ja: "罵倒" / "全力で罵る。下品な言葉あり。"

**What I want your eyes on**:
- C) The feral preamble names specific profanity in three languages. Is this likely to (a) trigger Apple Foundation Models' baked-in safety to outright refuse, or (b) actually unlock the register? I've seen the local models refuse vague "be harsh" instructions but obey specific-word permissions. Worth checking against your knowledge of Apple's on-device model.
- D) Apple Review optics. RoastMate's category is Lifestyle / age rating is 17+ (mature themes already declared). The feral chip is gated behind Pro paywall (not visible to free trial users by default — they see calm/sharp). Is there a path through App Review where the reviewer (1) buys Pro to test, (2) lands on this chip, (3) flags us under 1.1 (objectionable) or 4.3 (spam-of-similar)? Counter-argument: the killer feature IS the vent→sendable transformation; feral is a sibling intensity in a single picker, not a separate "curse mode" we advertise. But I'd appreciate a sanity check on the framing.
- E) Universal safety rules are repeated in 3 places now (PromptBuilder.universalSafetyPreamble, PromptBuilder.ventPreamble, PromptBuilder.feralPreamble). Each preamble re-asserts the rules so the model can't infer that the more-permissive preamble overrides them. Overkill? Or appropriate belt-and-braces for a model that might otherwise drift?

## Verification I already did

- All 56 tests pass (was 52, +4 for the new intensity / locale work).
- iOS / macOS / watchOS / Share builds clean.
- Have NOT tested on device yet — going to do that next. If you flag anything in B / C above I'll iterate before testing.

## What I want from you

A concrete review of A through E above. Specifically:
- If you think the locale fix is fragile, say what the correct fix is.
- If you think feral will get refused by Foundation Models, suggest preamble changes.
- If you spot anything in the diff itself that's wrong (file/line + fix), call it out.

The PR-equivalent diff is the most recent commit on main: `c762bc3`. Files changed:

```
Shared/AI/PromptBuilder.swift       (+languageEnforcement, +userLanguageReminder, +feralPreamble, examples header)
Shared/AI/RoastEngine.swift         (locale plumbing, feral temperature bump, feral routes to relaxed validator)
Shared/Models/Intensity.swift       (+case feral, requiresPro, displayKey, blurbKey)
RoastMate/Sources/Views/Components/StyleChip.swift  (+icon for feral)
Shared/{en,zh-Hans,zh-Hant,ja}.lproj/Localizable.strings  (intensity.feral.name + .blurb)
RoastMateTests/IntensityTests.swift                 (+testOnlyVentIsPrivateDraft, +feral in policy test)
RoastMateTests/PromptBuilderIntensityTests.swift    (+testFeralIntensityInjectsFeralPreambleButNotVent, +testLanguageDirectiveOverridesEnglishExamples_zhHans, +testUserPromptAppendsLanguageReminderWhenLocaleProvided)
```

Thanks.
