# RoastMate — handoff for the v1.7 wave (start here)

You are picking up **RoastMate** (幫你罵 / 帮你骂 / `~/Documents/RoastMate`) —
Swift 6, iOS/macOS/watchOS, plus a Cloudflare Worker in `cloud-worker/`.
Chinese-language-first, Taiwan is the chosen market. Solo developer (Jason).
Branch `feature/v1.4-track-b` (yes, still — every release since v1.4 shipped
from it; `main` stopped at 2026-05-16 and is 177 commits behind. Don't merge or
rebase onto it as a side quest).

**Read in this order:** this file → `docs/DEV_PLAN_v1.7_2026-10.md` (the plan
you are executing, with its review synthesis in §9) → project `CLAUDE.md` →
from `docs/HANDOFF_v1.6_NEXT_SESSION.md` only these sections: "VERIFY BEFORE
YOU ACT", "Debug builds are always Pro", "Hard-won gotchas", "Design rules".
Everything else in the v1.6 handoff is history.

**Do not trust this document either.** The last three waves each found
10+ claims in their own docs that were false when checked. A claim about code
is not true until you open the file; a claim about production is not true
until you measure it.

## Status (measured 2026-10-07)

- **Live:** iOS + macOS v1.6.0 build 22 (released 2026-09-27). Tag `v1.6.0` →
  `d7efd49`. Worker **`90d8f1c5`** (P0.1, deployed 2026-10-07; rollback
  `200d240c`). Flags: see the plan §0.
- **Money:** 2 paying subscribers, both Pro Monthly at full price, both
  converted on download day — TW 2026-09-19, US 2026-10-04. Proceeds since
  09-15: $5.16 (the two subscriptions + one $0.39 CN credit pack). First renewals ~10-19 (TW),
  ~11-04 (US).
- **Funnel since v1.6.0 + CN delisting (09-28 → 10-04):** 96 impressions →
  3 page views → 2 first-time downloads. About half the impressions vanished
  with CN.
- **OpenRouter:** $9.95 left of $10, auto-top-up OFF (hard cap). It is the
  ONLY live model path; since P0.1 the Worker no longer tries Groq at all
  and has a second OpenRouter model (`FALLBACK_MODELS`). ≈45 cloud
  generations 09-28→10-07.
- **Creator outreach:** batch 1 (3 emails, 09-28) → 0 replies, 0 redemptions;
  one follow-up each sent 10-07 at Jason's confirmation. Never contact those
  three again. Decision on 10-21 (plan P2.2).
- **Interviews:** dropped. Research form closed.

## New since the v1.6 handoff

- `scripts/asc_analytics.py --since YYYY-MM-DD` — read-only readout
  (downloads, purchases, subscription events, impressions). Replaces the
  "no script exists" recipe. Every decision gate in the plan uses it.
- Three defects found on 10-07, none code-reviewed before (details and
  evidence in the plan §1): the product page shows Simplified-Chinese
  May-era screenshots with Vent locked to **every** storefront; the paywall
  header still sells Vent as Pro; Echoes + the roommate group are invisible to
  every paying user (zh-Hans-only gate).
- The 10-05 scheduled tasks (`roastmate-openrouter-balance`,
  `roastmate-creator-outreach-followup-1005`) **both failed** — the account
  had hit its weekly usage limit. The work was done by hand on 10-07. If a
  scheduled task's readout is ever missing, check `list_task_runs` for this
  before assuming the task logic is broken.

## Your job

Execute `docs/DEV_PLAN_v1.7_2026-10.md` in order: Phase 0 (Worker, 2-hour
timebox) → Phase 1 (v1.7.0: paywall header, card wordmark, delete the research
tile, **new screenshots in 4 locales + Taiwan keywords** — the centre of the
wave) → Phase 2 (distribution in Taiwan, starts the day 1.7.0 is live). There
is no Phase 3: both reviewers cut it, and §5 says what would revive it. Read
§9 before you start — it records what changed from the first draft and why.

The wave ends at the **stop rule in §7 (read on 11-15)**. If it fires, the
project goes to maintenance mode. Do not argue with it by finding new code to
write; that is the exact pattern it exists to stop.

**Known and deliberately NOT fixed** (so you don't rediscover them): Echoes and
the roommate group are invisible outside zh-Hans (`ExploreView.swift:138`), so
neither subscriber can see them; the wallet peek is not a reservation; shared
vent rule text still quotes Simplified examples. Reasons: plan §6.

**Autonomy.** Jason has fully delegated this project (「你全权负责」). Act
without asking on anything reversible: code, tests, local builds, Worker
previews (`wrangler dev --remote`), commits and pushes to the branch, ASC
metadata/screenshots on an editable version. For the outward-facing steps the
plan gates — a production Worker deploy, flipping a live flag, submitting to
App Review — verify the gate, say in one line what you are about to do and
what the rollback is, then do it. **Emails or messages in Jason's name always
wait for his explicit confirmation of the exact recipient and text,** every
time.

**Jason's, not yours:** topping up OpenRouter (do it by hand below ~$2); the
`pt=` provider token (ASC web UI); confirming any outreach send **and posting
(or confirming the exact text of) every community post in P2.1** — the
accounts are his; the App Privacy label's Purchases entry (not on the API).

## Cheap checks before you start

```bash
git -C ~/Documents/RoastMate log --oneline -3          # HEAD should include the v1.7 plan commit
sed -n '20,21p' ~/Documents/RoastMate/project.yml      # 1.6.0 / 22 until P1.6 bumps it
curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json
python3 ~/Documents/RoastMate/scripts/asc_analytics.py --since 2026-09-28
~/Documents/RoastMate/scripts/openrouter-balance.sh     # exit 0 = OK, 1 = low
```

Codesign under a locked screen: run the two-command probe from the global
CLAUDE.md before any archive. ASC API work (.p8) is lock-immune — sequence it
first.

## Machine rules that bite (from CLAUDE.md files — read them, these are reminders)

- Reuse simulators: `RoastMate-UITests` for preflight, `iPhone 17 Pro Max` for
  screenshots. iOS 18.5 devices are disposable — create, use by UDID, delete.
- Never stop a UI-test run without shutting its simulator down (orphaned
  daemons → load ~900).
- 16 GB Mac, other agent sessions: one heavy job at a time.
- Cleanup only through `/usr/bin/trash`; never `build/`, never
  `~/Documents/RoastMate-research/`, never a repo `node_modules`.
- Production (Worker, Pages config, ASC records) is never "cleanup".
