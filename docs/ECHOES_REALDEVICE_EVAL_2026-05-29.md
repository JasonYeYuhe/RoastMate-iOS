# Echoes — real-device eval protocol (2026-05-29)

**Why this exists.** Echoes' on-device 3B Foundation Model has to emit
parseable tagged output (`[ROLE/IDX] …`). When it doesn't, the parser (or
the new output-safety pass) rejects it and we serve a **curated static
fallback** — which reads as broken/cringe. The **parse-fallback rate** is
the gating unknown for whether Echoes is actually good. It **cannot** be
measured in the simulator (no Apple Intelligence → always fallback) or via a
cloud model (too strong to represent the 3B on-device model). It must be run
on a **physical iPhone with Apple Intelligence ON**.

This decides whether v1.0.6 ships Echoes **enabled** or **dark** (the
remote kill-switch makes "ship dark, flip on later" free — see
`Shared/Services/RemoteConfig.swift`).

**Kill-criterion (health audit §3):**
> `echoes_parse_fallback / (echoes_session_started − echoes_model_unavailable) > 35%`
> over a rolling window → the empathy illusion is broken → force cloud or disable.

## Setup (once)

1. Use a **physical iPhone** with **Apple Intelligence enabled**
   (Settings → Apple Intelligence & Siri). A18/A17-class device.
2. Install a build that contains Echoes: the **TestFlight build 14**
   (v1.0.6, once it finishes processing) or a local dev build of HEAD.
3. Device language must resolve to **zh-Hans** (Echoes is zh-Hans-only in
   v1; otherwise the tile is hidden).
4. In the app: **Settings → enable "Share usage data" (telemetry opt-in)**.
   The `echoes_*` counters only record when opted in. (Optional: tap Reset
   first so the run starts from zero.)
5. Be **Pro** (Echoes is Pro-gated). Use a sandbox Pro account or a DEBUG
   build (DEBUG forces `isPro = true`).

## Run (≈10 grievances, one generation per session)

For each grievance below: open Echoes → paste the situation → pick the
**tone** + **voice count** shown → Generate **once** → read the transcript →
record a row → tap "New" (back to setup) and continue. **One generation per
session** keeps `session_started ≈ attempts` so the rate math is clean (don't
hit Regenerate during the eval).

For each, judge by eye:
- **Parsed vs Fallback?** A *parsed* transcript is specific to the grievance
  and varied per voice. The *curated fallback* is generic and identical
  regardless of input (you'll recognize it after 2–3 runs). The telemetry
  cross-checks this, but your eye is the ground truth.
- **Quality 1–5** + a note. Watch the **DEESCALATE beat** especially — the
  known cringe risk (calm-therapist fortune-cookie = Mirror-Shock).

| # | Tone | Voices | Grievance (zh-Hans) |
|---|------|--------|---------------------|
| 1 | Casual | 2 | 室友半夜两点还在外放打游戏,说了三次都当耳旁风,今天又来。 |
| 2 | Casual | 1 | 同事把我做完的方案直接署上他自己的名字交给老板,一句话都没跟我说。 |
| 3 | Casual | 2 | 朋友又一次临时放我鸽子,我都到餐厅了他才发消息说来不了。 |
| 4 | Casual | 2 | 点的外卖洒了一半,客服只肯赔三块钱优惠券,还说是我自己不会拿。 |
| 5 | Casual | 1 | 妈又开始拿我和别人家孩子比,说我这个年纪还没买房就是没出息。 |
| 6 | Feral | 2 | 房东退押金扣东扣西,合同里根本没写的费用也硬塞进来,微信还不回。 |
| 7 | Feral | 2 | 组里那个人整个学期啥都没干,汇报的时候全程他在讲,功劳全揽过去。 |
| 8 | Feral | 1 | 网店发来的是货不对板的劣质货,要退货反被拉黑,还倒打一耙说我碰瓷。 |
| 9 | Feral | 2 | 相亲对象全程低头玩手机,临走还点评我"条件也就这样别太挑"。 |
| 10 | Feral | 1 | 加班到十一点把活赶完,领导第二天当着全组说"年轻人就该多奉献"。 |

Recording table (fill as you go):

| # | parsed / fallback | quality 1–5 | deescalate cringe? | note |
|---|---|---|---|---|
| 1 | | | | |
| … | | | | |

## Analyze + decide

1. **Settings → Share usage data → save the JSON** (e.g. AirDrop to the Mac).
2. Run:
   ```
   python3 scripts/echoes_eval_analyze.py ~/Downloads/roastmate-telemetry-<week>.json
   ```
   It prints the parse-fallback rate, the bridge-conversion rate, and a
   PASS/FAIL verdict vs the 35% criterion (with a small-sample caveat under
   ~10 attempts).
3. **Decision:**
   - **PASS (≤35%)** → ship Echoes **enabled** in v1.0.6 (keep/flip the live
     `echoes_enabled:true`).
   - **FAIL (>35%)** → ship **dark** (`echoes_enabled:false` live) and either
     tune the prompt/model or wire the cloud path before flipping on. The
     kill-switch means this needs **no Apple review cycle**.
   - Also eyeball the manual table: if the rate passes but the DEESCALATE
     beat is consistently cringe, that's a prompt-tuning task even on a PASS.

## Notes

- Reset the counters between distinct eval runs (Settings → Reset) so weeks
  don't blend.
- `echoes_parse_fallback` now also fires when a generated line trips the
  output safety hard-rail (self-harm / explicit violence) — that's correct:
  a safety-blocked line also yields the curated fallback. Such hits should be
  near-zero; if they're not, note it.
- The simulator will read 100% fallback (no Apple Intelligence) — that is
  expected and is NOT the eval. Physical device only.
