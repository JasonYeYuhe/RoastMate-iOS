# Echoes (替你出气) — eval findings 2026-05-29

Two-phase post-ship verification of the Echoes feature (committed
5e2cec4). Phase 1 = runtime verification in the simulator. Phase 2 =
prompt/content eval via Gemini 3.1 Pro.

## Phase 1 — runtime verification (PASS)

`RoastMateUITests/EchoesFlowUITests` drives the real SwiftUI views in
the simulator. Both tests pass (iPhone 17 Pro Max / iOS 26.5):

- `test_echoes_setup_generate_bridge_deeplink`: tile appears (zh-Hans
  gate) → setup renders → type grievance → generate → transcript
  reveals message-by-message → bridge bubble renders → **tap bridge →
  app switches to Generator tab → situation pre-filled** (the
  Bridge-to-Action deep link works end-to-end).
- `test_echoes_feral_triggers_consent_sheet`: Feral tone → dedicated
  5.1.2(i) consent sheet → deny → app stays alive.

Two TEST-HARNESS bugs were found + fixed during this (not feature bugs):
1. SwiftUI `TextEditor` doesn't surface its accessibilityIdentifier to
   XCUITest → use `app.textViews.firstMatch`.
2. The message-reveal animation stalls `waitForExistence` ("app idle not
   received") → sleep past the reveal, then assert.

**Caveat:** the simulator can't run Apple Intelligence, so generation
takes the curated-fallback path. Phase 1 verifies UI + wiring, NOT real
model output. That's Phase 2 + the still-pending real-device eval.

## Phase 2 — prompt/content eval (Gemini 3.1 Pro, 2026-05-29)

Gemini ran the exact `EchoesPromptBuilder` casual/2-voice system prompt
against 5 zh-Hans grievances and critiqued. Findings:

### Content quality
- **Lands** where it's sharp: "脸皮厚到能当防弹衣", "把宿舍当自己网吧",
  "排序很清晰嘛" — reads like a real friend with a sharp tongue.
- **Cringe risk is the DEESCALATE beat specifically** — it broke
  character into "calm-therapist mode" (fortune-cookie: "忍出内伤的只有
  你自己"). That whiplash is exactly where the user remembers it's an AI
  (the Mirror-Shock failure the advisors warned about).

### Parse risk for the ~3B on-device model (ranked)
1. **`≤45 字` constraint** — small models can't count chars while being
   witty; wit wins, length overflows. (Mitigated already: the parser's
   hard cap is 100 chars, not 45 — moderate overflow still parses. The
   prompt target was also tightened to "aim ≤40".)
2. **`[BRIDGE/IDX:register]` schema shift** — the last tag changes shape
   (adds `:sharp`); 3B models forget it or hallucinate it onto other
   lines → parse failure → canned fallback. **FIXED — see below.**
3. **A/B speaker coherence + 4–6 count drift.**

### Fixes applied this session (2 of Gemini's high-leverage recs)

1. **Killed the `:register` tag suffix.** The contract is now uniform
   `[ROLE/IDX]` for all four roles. The bridge's rewrite register is a
   deterministic function of tone (casual→sharp, feral→savage) injected
   by `EchoesEngine` after parsing, via the new `EchoTone.bridgeIntensity`
   computed. The model never has to emit the schema-shifting suffix —
   removing the #2 parse-failure trigger. The parser stays
   backward-compatible (honors a suffix if a model still emits one).
2. **Merged de-escalate into the bridge arc.** Prompt items 3+4 reworded
   so DEESCALATE stays the snarky friend ("与其在这干生气…") and BRIDGE is
   its payoff ("…不如用 Sharp 把话甩回去 →") — ONE continuous beat
   (don't-just-suffer → here's-how-to-hit-back) instead of a calm-down
   followed by a tacked-on ad. Fixes both the cringe AND the
   bridge-feels-like-an-ad problem.

Also: `EchoesViewModel.tapBridge` now defaults to `.sharp` if the bridge
intensity is ever nil, so a bridge bubble can never be a silent dead tap.

All 32 Echoes unit tests still pass after these changes.

## STILL PENDING — real-device eval (the one that matters)

The parse-risk findings are about the **on-device 3B model**, which
neither the simulator nor Gemini can stand in for (Gemini is far
stronger and follows the format trivially; the sim can't run Apple
Intelligence at all). The real question — *what fraction of on-device
generations actually parse vs. fall back to canned lines* — can only be
answered on a physical iPhone with Apple Intelligence.

**Action for the user (or a TestFlight build on a real device):** run
~10 grievances through Echoes on a real device, count how many produce
a fresh transcript vs. the canned fallback (the `echoes_parse_fallback`
A′ counter measures exactly this in aggregate). If the fallback rate is
high:
- Further simplify the contract (Gemini's deeper rec: consider dropping
  the per-message role tags entirely and inferring roles by position,
  or reducing to 1 voice for on-device).
- Or accept a higher fallback rate and invest in making the curated
  fallback catalog larger/more varied so repetition is less obvious.

Until that real-device number exists, treat Echoes' live-generation
value as **unproven** — the wiring works, the prompt is as small-model-
friendly as we can make it without a device, but the actual on-device
follow-through rate is the gating unknown.

## Build status

The prompt improvements are committed but NOT in the uploaded build 13
(which carries the original `:register` prompt). Since build 13 sits
unbound behind v1.0.4 + v1.0.5 in Apple's review queue (days out), the
next build (at v1.0.6 bind time, or build 14 if a real-device eval is
run first) will carry the improved prompt. No rush to rebuild now —
better to batch any further real-device-driven prompt fixes into one
build.
