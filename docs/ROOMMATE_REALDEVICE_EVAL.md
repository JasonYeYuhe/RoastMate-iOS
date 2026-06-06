# 虚拟舍友群 (roommate group) — eval + 2026-06-06 finding

## What this gates
Like the Echoes eval: the on-device 3B model must emit a **parseable** tagged
transcript, or the parser rejects it and we serve a curated fallback (reads as
canned/broken). For the roommate group the contract is **stricter** than classic
Echoes — 8–10 messages, 3 voices A/B/C each speaking ≥2×, a single BRIDGE from C
last. The **parse-fallback rate** is the gate: enable < 15% / hard-kill ≥ 35%.

## How to run
Codified in `RoastMateTests/RoommateEvalTests`:
- `test_curatedRoommateFallback_satisfiesContract` — runs anywhere; proves the
  curated fallback always satisfies the strict contract.
- `test_roommateGroup_realDeviceParseFallbackRate` — the real-model eval.
  **Opt-in** (skips by default so it never burdens the regular suite) and
  FM-availability-gated:
  ```
  TEST_RUNNER_ROOMMATE_EVAL=1 [TEST_RUNNER_ROOMMATE_EVAL_N=6] \
  xcodebuild test -project RoastMate.xcodeproj -scheme RoastMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:RoastMateTests/RoommateEvalTests/test_roommateGroup_realDeviceParseFallbackRate
  ```

> **NEW vs the 2026-05-29 Echoes eval:** Foundation Models **IS** available on
> the iPhone 17 Pro / iOS 26 simulator under Xcode 26.5 — so this eval runs on
> the sim (a physical device is still the gold standard, but the sim is no
> longer a guaranteed 100%-fallback no-op).

## 2026-06-06 finding — NOT viable on-device-Apple-FM as specified (100% fallback)
Ran the eval on the sim's real FM. **100% parse-fallback** across every variant.
Two independent walls:

1. **Structure.** Without a few-shot example, the 3B model collapses to the
   classic **4-line** arc (validate→escalate→deescalate→bridge, one each)
   instead of the 8–10 group pile-on. It also sometimes emits `1/2/3` or
   `Echo A:` instead of `[…/A]`, and echoes the persona instructions back as
   message text.
2. **Apple's FM guardrail.** A few-shot example strong enough to fix the
   structure — *even softened to supportive-snark in the casual register* —
   trips Apple's on-device safety guardrail
   (`guardrailViolation: "May contain unsafe content"`) → 100% **instant** block.
   The roast / 毒舌室友 ("火力担当") framing reads as unsafe to Apple's FM.

So: drop the example → generates but wrong structure; add the example → Apple
blocks the whole prompt. **Apple's on-device FM is structurally hostile to a
harsh group-roast feature.** (Feral cursing register is blocked outright.)

## Decision needed — the generation path
The engine / parser / flag / telemetry / persistence (increments 1–2, shipped on
this branch) are **generation-path-agnostic** — they fully apply no matter where
the text comes from. Only the generation call changes.

- **A. Cloud generation.** Route the roommate scene through the existing Worker
  (Groq/OpenRouter), which already produces harsh zh roasting with no Apple
  guardrail. Roommate becomes cloud-only + 5.1.2(i)-consent-gated (like Echoes
  feral was meant to). This is the kill-criterion doc's own "force cloud for
  quality" path. Cost: leaves the on-device-only posture for THIS feature
  (consent-gated, so the privacy contract holds).
- **B. Soften to "supportive friends" (not roasters).** Drop the 毒舌/roast
  framing → 3 friends who validate + lightly reframe. May pass Apple's guardrail,
  but it stops being 替你骂 — loses the appeal.
- **C. Defer / cut.** Apple's on-device FM can't do it; not worth fighting now.
  Validates the advisors' "Echoes/roommate unproven — don't build on it yet."

**Do NOT build the roommate UI (increment 3) until the path is chosen** — it
would be built on a feature that currently shows the curated fallback 100% of
the time.

## 2026-06-06 (cont.): Option A chosen + VALIDATED — cloud, 10% parse-fallback
The Worker gained a `mode:"roommate"` branch (server-side roommate prompt; the
cloud Groq Qwen3-32B / OpenRouter models have **no Apple guardrail**). Ran the
same 20 zh-Hans scenarios against it (12 s spacing to stay under Groq's
free-tier TPM):

- **20/20 got a model response; parse-fallback = 2/20 = 10 %** → **under the
  < 15 % enable bar, far under the 35 % kill line.** Both on-device walls are
  gone: the cloud model nails the 8-line A/B/C structure AND the roast register.
- Quality is genuinely on-brand (护短/毒舌/清醒 dynamics, funny, cathartic —
  e.g. "借钱时喊爸爸，分手后喊渣滓，真·情感诈骗模板").
- Caveat (ops, NOT viability): a rapid 20-request BURST hits Groq's free-tier
  per-minute rate limit (429 → the Worker's OpenRouter fallback, itself a shared
  `:free` pool). Production traffic is spread out; if bursts matter, a paid Groq
  tier covers it. Reproduce: `python3 scripts/roommate_cloud_eval.py`.

**Verdict: Option A works.** Roommate generation routes through the cloud Worker
(`mode=roommate`), 5.1.2(i)-consent-gated like Echoes feral. Next: wire the
Swift client (EchoesEngine → cloud for the roommate scene + the consent gate),
re-eval end-to-end, then the UI. Increments 1–2 (parser / flag / telemetry /
persistence) apply unchanged.
