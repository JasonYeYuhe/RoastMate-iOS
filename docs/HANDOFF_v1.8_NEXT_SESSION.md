# RoastMate — handoff for the v1.8 wave (start here)

You are picking up **RoastMate** (幫你罵 / 帮你骂 / RoastMate AI, `~/Documents/RoastMate`) —
Swift 6, iOS 18+ / macOS 14+, plus a Cloudflare Worker in `cloud-worker/`.
Taiwan is the target market. Solo developer (Jason). Branch
`feature/v1.4-track-b` (every release since v1.4 shipped from it; `main` stopped
in May and is far behind — don't merge or rebase onto it as a side quest).

**Read in this order:**
1. this file
2. `docs/DEV_PLAN_v1.8_2026-11.md` — the plan you are executing. Read §2.1 (how it
   relates to the stop rule), §3 (scope), §6 (guardrails) and §9 (what the two
   reviews changed) before writing code.
3. project `CLAUDE.md` and the global `~/.claude/CLAUDE.md` (signing, simulators,
   build roots, cleanup)
4. `docs/evidence/2026-10-27-v18-plan/lens-1..4-*.md` — the measurements behind
   the plan, when an item needs its detail
5. `docs/HANDOFF_v1.7_NEXT_SESSION.md` — only the "Update 2026-10-23" and
   "Update 2026-10-22" sections and "Machine rules that bite"
6. `docs/HANDOFF_v1.6_NEXT_SESSION.md` — only "VERIFY BEFORE YOU ACT", "Debug
   builds are always Pro", "Hard-won gotchas", "Design rules"

**Do not trust this document either.** Every recent wave found 10+ claims in its
own docs that were false when checked; the 10-27 review of this plan found more
(plan §9). A claim about code is not true until you open the file; a claim about
production is not true until you measure it.

## Status (verified 2026-10-27 unless dated)

- **Live:** iOS + macOS **1.7.2 build 26** since 2026-10-23 20:45Z (Traditional
  幫你罵 icon, app-owned plan copy). Tags `v1.7.0`, `v1.7.1`, `v1.7.2` (→ `64c4867`).
  `project.yml` is 1.7.2 / 26. HEAD `b737392`.
- **Worker:** `046f2134` (rollback `7846ac95`). Taiwan register for zh-Hant; Pro
  styles shape the voice of Vent/Feral (free styles unchanged); names never used
  to address the person. `wrangler.toml`: `ROAST_MODE_ENABLED="false"`,
  `CLOUD_DISABLED="false"`, `GROQ_ENABLED="false"`, `ALLOW_SANDBOX_RECEIPTS="false"`,
  `DAILY_LIMIT_PER_DEVICE=30`, `PRO_DAILY_LIMIT=200`.
- **Remote config** (`roastmate-config.json`, fetched 10-27): `vent_cloud_enabled`,
  `echoes_enabled`, `roommate_group_enabled`, `share_card_enabled` (since 10-23)
  true; `cloud_sendable_enabled` false and RETIRED forever; `force_local_only` false.
- **Money:** two payers ever, both Pro Monthly at full price, both on download day.
  TW cancelled day 0 (09-19, v1.5.0, iOS 27), lapsed 10-19. **US active, renews
  ~11-04** (iOS 26.6 at purchase; no 1.7.x update seen on a US iPhone — only Worker
  changes can reach them before renewal). **0 purchases since 10-04.** First-time
  downloads 10-07 → 10-24: 7 (4 iPhone, 3 Mac; TW 1). Impressions 301, page views 26.
- **Yearly plan** NT$690 / US$19.99 has a 7-day free trial in all 175 territories
  that the app never shows (`paywall.yearly.trial` is read by no Swift file).
- **OpenRouter:** $9.88 left (balance log 10-26), auto-top-up OFF (hard cap). The
  only live model path (`qwen/qwen3-30b-a3b-instruct-2507`, fallback
  `qwen/qwen3-next-80b-a3b-instruct`).
- **Distribution:** no P2.1 post logged as of 10-27 (drafts:
  `docs/distribution/2026-10-23-p21-posts.md`). The stop rule's T has not started,
  so on **11-15** the rule's first branch fires unless three posts go up first.
- **Live privacy policy** (`jasonyeyuhe.github.io/RoastMate/privacy.html`, "Last
  updated October 20, 2026"; source = the separate Pages repo
  `JasonYeYuhe/RoastMate`, **not** this repo's stale `docs/site/`): still says
  declining cloud gives a "gentler" on-device Vent/Feral (false — labelled
  examples) and that cloud is used "by default" (consent comes first); omits the
  roommate group and the style id. Fixing it is plan item A9.
- **ASC subscription descriptions** still say "Unlimited generations" (shown on the
  StoreKit purchase sheet). The API refuses edits while ACTIVE; Jason edits them in
  the ASC web UI before 1.8.0 is submitted (plan A2 submit gate).
- **In the working tree, untracked on 10-27:** `docs/DEV_PLAN_v1.8_2026-11.md`,
  this file, `docs/evidence/2026-10-27-v18-plan/` (lens reports, both Gemini
  reviews, the next-session prompt). If `git status` still shows them untracked,
  commit them first (docs only).
- **Disk:** 50 GB free on 10-27.

## Owner decisions already made (with dates)

- **2026-10-27:** "make all our current paid features better, because paying
  users keep shrinking." Invest in paid-feature quality now, as a bounded
  exception to the v1.7 stop rule (plan §2.1). The formal B0 confirmation of the
  plan's bounds is still due by 10-29.
- **2026-10-27 (from the plan as reviewed):** 1.8.1 is **not** pre-approved. On
  11-15 Jason reads the stop rule and fills at most one slot (B1-R, B1-S, B2 or
  B8) or none; if the rule fired, the default is none.
- **2026-10-23:** P2.1 posts go up after the 1.7.2 icon is live (it is). PTT
  [廣宣] only on Mondays. T = the date of the third post; log each post's URL and
  time. Creator batch 2 waits for Jason's confirmation of each send.
- **2026-10-23:** `share_card_enabled` ON (rollback: set it false).
- **2026-10-22:** Lifetime Pro — decide after 11-15.
- **2026-10-07:** never contact the three batch-1 creators again.
- **2026-09-30:** keep the iOS 18.5 simulator runtime while the deployment target
  is iOS 18.
- **2026-09-26:** mainland China delisted; Taiwan first; `cloud_sendable_enabled`
  retired forever (CI-enforced). Any new cloud path needs a new flag and a new
  versioned consent.

## Your job

Execute `docs/DEV_PLAN_v1.8_2026-11.md`: **A1** on the Worker in the first week,
then binary **1.8.0** (A2–A9 plus whichever of B3/B4/B5 Jason approves by 10-31),
**submitted by 11-12** so it is live before the 11-15 read. Then the 11-15 brief.
Do not start any 11-15 slot item before Jason picks one. Nothing outside plan §3
gets built; new ideas go to §8.

### First three steps

**Step 1 — verify, preserve the harness, rebuild the safety set (day 1).**

```bash
cd ~/Documents/RoastMate
git status --short && git log --oneline -3          # plan docs untracked? commit them (docs only)
sed -n 20,21p project.yml                           # 1.7.2 / 26
curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json
python3 scripts/asc_analytics.py --since 2026-10-24 # any purchase? US still active?
scripts/openrouter-balance.sh 5                     # exit 1 = below $5 → stop evals, tell Jason

# The 10-27 lens harness (sources + results, no binaries, no raw ASC TSVs — the lens3
# scripts re-fetch those) was copied into the repo on 10-27:
H=~/Documents/RoastMate/docs/evidence/2026-10-27-v18-plan/harness
grep -rn "/private/tmp\|scratchpad" "$H" | head    # fix these absolute paths at the top of each file
```

Then write `harness/safety_set.json` (plan §7.1): ≥ 24 threats (12 veiled), ≥ 24
legitimate complaints describing harassment/racism/violence, self-harm, PII and
slur bait, zh_TW + en (+ ja for A3). The 10-22 held-out set is gone with its
scratchpad; seed it from `RoastMateTests/RewriteThreatScreenTests.swift` and the
examples in `Shared/AI/RoastEngine.swift:528-531, 576-591`.

Baselines on this Mac (macOS 27, Apple Intelligence on). The probe compiles
production files (its header comment names them); build output goes to your own
scratchpad, never the repo:

```bash
R=~/Documents/RoastMate; OUT=<your scratchpad>/build; mkdir -p "$OUT"
swiftc -O -o "$OUT/lens1probe" "$H/audit/probe/main.swift" "$H/audit/probe/Stubs.swift" \
  $R/Shared/AI/PromptBuilder.swift $R/Shared/Models/Intensity.swift $R/Shared/AI/StylePreset.swift \
  $R/Shared/AI/SafetyFilter.swift $R/Shared/AI/ModelRefusal.swift
"$OUT/lens1probe" > "$OUT/baseline.jsonl" && python3 "$H/audit/probe/analyze.py" "$OUT/baseline.jsonl"
```

(Check `main.swift` for arguments first; if the compile list is incomplete, the
error names the missing file.) Store the summary in the evidence dir. Start the
evaluation-spend ledger there (plan §7.4).

**Step 2 — A1 in preview, then production (plan §3 A1).**

```bash
cd ~/Documents/RoastMate/cloud-worker
# edit src/style_voice.js STYLE_VOICES.savage_no_filter (en/hans/hant/ja) + test/style_voice.test.js
npm test
node ../docs/evidence/2026-10-22-churn-and-fixes/harness/worker-compare/compare_ext.mjs  # fix paths first; no diff outside savage_no_filter
npx wrangler dev --remote --port 8799               # preview; nothing deployed
# style gate: score_gate2.py / detect.mjs against the preview (≤ 20 calls), blind pairs ≥ 5/6
npx wrangler deploy                                 # only after the gate
npx wrangler deployments list                       # record the new version id here and in the plan
# rollback: npx wrangler rollback <full id of 046f2134…>
```

Say in one line what you are deploying and the rollback before `wrangler deploy`
(that is the autonomy rule below). A9's optional `provider.data_collection` change
rides this deploy only if Jason has checked the OpenRouter account setting and ≤ 6
preview calls show both models still route.

**Step 3 — start 1.8.0 with the Shared-code items (A3, A4, A5).**
Order: A4's stateless opponent prompt and A3's refusal → `respondFresh(guardrails:
.permissiveContentTransformations)` retry with per-variant screens (both in
`Shared/`, unit-tested), then A5's preambles/examples, then re-run the probe and
the safety set against the §2.2 targets. Then A2, A6, A7, A9, A8, and B3/B4/B5 as
decided. Tests:

```bash
ROASTMATE_TEST_DEVICE=RoastMate-UITests scripts/preflight.sh
```

Paywall, trial line, hand-off, preview and consent are checked **only in Release**
(`ENABLE_TESTABILITY=YES`) with a v1.7.2 control, on a disposable iOS 18.5 device
(class C) and on this Mac (class D).

## What is Jason's (not yours)

- **Decisions:** B0 by **10-29**; B3 (retire classic Echoes), B4 (two zh-Hant style
  names), B5 (one 痛罵 preview for free users) by **10-31**; the 11-15 slot on
  **11-15**. Remind him; don't decide for him.
- **Before 1.8.0 is submitted:** edit the Pro subscription descriptions in the ASC
  web UI (no "Unlimited generations" / 「無限生成」); approve the privacy-policy
  diff (A9) before it is pushed; check the OpenRouter account privacy setting.
- **Device and reader checks:** a native Taiwanese reader (~1 h, about 11-08; the
  agent prepares blind sheets, Jason asks); a 10-minute iOS 27 iPhone check of the
  1.8.0 TestFlight build (A3/A4/A5), plus iOS 26 if a device is at hand.
- **If a cloud slot item is chosen:** verify that production Pro tokens mint (plan
  §3 owner tasks); App Privacy answers.
- **Distribution:** P2.1 posts and creator batch 2 — his accounts; each send
  confirmed by him.
- **Money:** topping up OpenRouter by hand (below $5 while this plan evaluates);
  the Retention Messaging API access request (B7) if he wants it.
- Fixing the Datadog connector (optional).

**Autonomy.** Act without asking on anything reversible: code, tests, local
builds, Worker previews (`wrangler dev --remote`), commits and pushes to the
branch, ASC metadata on an editable version (dry run first). For outward-facing
steps the plan gates — a production Worker deploy, flipping a live flag,
submitting to App Review — verify the gate, say in one line what you are about to
do and what the rollback is, then do it. **The privacy policy push waits for
Jason's approval of the diff. Emails, messages and posts in Jason's name always
wait for his explicit confirmation of the exact recipient and text,** every time.

## Hazards (each has cost a session before)

- **Debug builds are always Pro** (`StoreService.isPro`). Every Debug test of the
  paywall, trial, credits, preview or hand-off passes vacuously. Release +
  `ENABLE_TESTABILITY=YES`, against a control on the previous tag.
- **`$ASC_APP_ID` may hold another app's id** (it was 6761163709 on 10-23). Never
  default an app id from the environment; pass `--app-id 6769317103` explicitly
  (`scripts/asc_product_page.py` no longer reads the env var). Filter every ASC
  report to App Apple ID 6769317103 so ColorArchive doesn't mix in.
- **New ASC versions don't inherit the promotional text.** Re-set it on 1.8.0 (and
  1.8.1) with `scripts/asc_product_page.py` (dry run first).
- **xcodebuild sometimes hangs after the tests finish.** Kill only the PID you
  started (never `pkill` by name), then `xcrun simctl shutdown <UDID>` for that
  run's device and check for orphaned `simruntime` daemons (ppid 1). Never stop a
  UI-test run without shutting its simulator down (load ~900 otherwise).
- **Trash and disk.** Cleanup only through `/usr/bin/trash`; the Trash frees nothing
  until Jason empties it. On "No space left on device", stop and ask him to empty
  it — don't trash more.
- **Datadog connector is not set up** (it failed on 10-22 and 10-27 with an
  unresolved "not-setup" host). Worker logs can't be read through it; use
  `npx wrangler tail` only for a live smoke test, and never read one person's
  `lane=pro` lines.
- **The harness is in the repo** (`docs/evidence/2026-10-27-v18-plan/harness/`,
  copied 10-27); its scripts still carry absolute scratchpad paths — fix them before
  running. The 10-22 threat held-out set is gone; plan §7.1 rebuilds a safety set.
- **`respondCached` reuses the default-guardrail session** (key has no guardrail
  part). A permissive retry goes through `respondFresh`; never through the cache.
- **Sandbox receipts get 403 in production** (`ALLOW_SANDBOX_RECEIPTS=false`). Test
  any Pro-only cloud path against a preview Worker with the sandbox var on.
- **`docs/site/` is stale.** The live marketing/privacy site is the separate repo
  `JasonYeYuhe/RoastMate`.
- **Unpaired CJK terms** have shipped three times. Every new string, preamble,
  example and style name is paired in 4 locales and guarded by the parity test.
- **`RoastMateTests` is hostless** — it can't see app-target types. Put logic under
  test in `Shared/`.
- **Codesign under a locked screen:** run the two-command probe from the global
  CLAUDE.md before any archive; sequence ASC API (.p8) work first, it is lock-immune.
- **Never flip `cloud_sendable_enabled`** (CI rejects it). New cloud paths get new
  keys read only by new binaries.
- **This Mac (macOS 27.0.1) is the only proxy for iOS 27.** iPhone behaviour is
  UNVERIFIED until Jason's TestFlight check.

## Keep / never clean up

- iOS 18.5 simulator **runtime** (22F77, ~8.8 GB). Devices on it are disposable:
  create one for a check, use it by UDID, delete it afterwards.
- `RoastMate-UITests` simulator (preflight); shared `iPhone 17 Pro` / `iPhone 17 Pro
  Max` (screenshots) — reuse, don't delete, don't shut down another session's.
- `build/` in this repo (shipped `.xcarchive`s, dSYMs, gitignored release notes that
  `scripts/asc_bind_version.py` reads) and `~/Library/Developer/Xcode/Archives`.
- `cloud-worker/node_modules`, `research/worker/node_modules`.
- `~/Documents/RoastMate-research/` (offer codes, outreach and balance logs; no git
  backup).
- `docs/evidence/**` (harnesses and gate results — the regression set).
- Keys and secrets: `~/private_keys/AuthKey_DMMFP6XTXX.p8`, `~/.appstoreconnect`,
  `~/Library/Application Support/CLI-Pulse-Secrets`.
- Production is never "cleanup": the `roastmate-vent` Worker, the Pages config
  (`research/web/roastmate-config.json` → mirrored), App Store Connect records.

## Cheap checks before you start

```bash
git -C ~/Documents/RoastMate log --oneline -3
sed -n 20,21p ~/Documents/RoastMate/project.yml
curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json
python3 ~/Documents/RoastMate/scripts/asc_analytics.py --since 2026-10-24
~/Documents/RoastMate/scripts/openrouter-balance.sh 5
xcrun simctl list devices available | grep -E "RoastMate-UITests|iPhone 17 Pro|18\.5"
```
