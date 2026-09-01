# v1.3 handoff prompt (paste into a fresh session)

Copy everything in the block below.

---

You are picking up RoastMate (帮你骂 / `~/Documents/RoastMate`, Swift 6, iOS/macOS/watchOS) to start the **v1.3 development wave**. A prior session wrote and advisor-reviewed the plan; your job is to execute it.

**Read first, in order:**
1. `docs/DEV_PLAN_v1.3_2026-08.md` — the plan you are executing (tracks, sequencing, §7 Gemini review synthesis, §6 non-goals). This is the source of truth.
2. `evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md` — why the cloud Vent chain stays (Apple FM refuses/neuters vent; PCC is a quality no-go). Do not re-litigate this.
3. `docs/DEV_PLAN_iOS18_NO_APPLE_FM_2026-06.md` §12 — the v1.2 state you're building on.

**Before writing any code, do these two things:**
1. **Verify current reality** (the plan was written 2026-08-30; confirm it still holds): App Store status of iOS+macOS v1.2.0 (is it live? use the ASC API key flow / `scripts/`); the live RemoteConfig JSON (`cloud_sendable_enabled`, kill-switches) at the GH Pages config URL; and the deployed Worker model (reconcile the drift noted in plan §0 — `wrangler.toml` routes zh→`qwen/qwen3-32b`, but `DEFAULT_MODEL`=Hermes-3-405B is likely dead, and the README disagrees).
2. **Confirm the 5 open decisions in plan §5 with Jason** — especially: (2) the shareable Comeback Card ships the *sendable comeback*, not the raw named vent (safety/moat); and (4) whether to build the consumable server ledger now or ship paywall+sub first.

**Then execute in this order (order is load-bearing — see plan §4 blind spot):**
- **Track M FIRST** (cost/monetization dam): StoreKit-2 JWS Pro receipt verification on the Worker → free-tier cloud cap + breaker → native (no 3rd-party SDK) intent paywall + consumable boost-pack with an atomic anti-double-spend ledger. Nothing viral or any `cloud_sendable` flip ships before this is live and load-tested.
- Then **Track 0** (voice smoke, sendable go/no-go eval, privacy labels, Worker config reconcile), then **Track B** (Comeback Card — PII-masked, redaction preview, `SafetyFilter` before render, static `ImageRenderer`, no video), with **Track D** (distribution/research) in parallel.
- **Do NOT** do the killed Track A.2 (permissive-guardrails on-device migration) — it's a trap (plan §2, §7).

**Hard guardrails (plan §6):** don't move Vent/Feral off the cloud; don't weaken `SafetyFilter` / the "private draft, never sent" framing / the 5.1.2(i) consent gate / non-companion positioning; no 3rd-party SDKs; branch + DARK-gate + eval-before-flip; never invalidate the live build; the byte-faithful `evals/runner` harness is the source of truth for any model/prompt change.

**House workflow:** for any major product/arch decision, consult BOTH advisors (Codex + Gemini 3.1 Pro via `mcp__gemini__ask_gemini model:pro`) and synthesize before building. Verify claims against real code, not memory. Update `docs/` + auto-memory as you land increments.

Start by reading the three docs, verifying current state, and reporting back the confirmed state + your proposed Week-1 task breakdown for Track M before you start coding.

---

_Source: `docs/DEV_PLAN_v1.3_2026-08.md` (advisor-reviewed 2026-08-30). Regenerate this handoff if the plan changes._
