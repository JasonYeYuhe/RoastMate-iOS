# RoastMate — project rules for Claude sessions

Read these first, in order:
1. `docs/HANDOFF_v1.8_NEXT_SESSION.md`: current state, the plan being executed,
   what is Jason's.
2. `docs/DEV_PLAN_PRO_QUALITY_2026-11.md`: binary 1.9.0, "make the paid features
   better". Chosen 2026-11-18; Jason overrode the 11-15 stop rule on purpose.
   Scope Q0 → Q4 → Q1 → Q5 → Q2b → Q2a; no C/E cloud lane; submit 12-07.
3. `docs/DEV_PLAN_v1.9_2026-11.md`: D+ maintenance. Its maintenance duties still
   apply.
4. `docs/DEV_PLAN_v1.8_2026-11.md`: it still governs the 01-31 payer read.

Verify their claims before acting on them. The v1.7 handoff and plan are history,
except the sections the v1.8 handoff names.

## Keep / never clean up

- **iOS 18.5 simulator RUNTIME (22F77, ~8.8 GB): keep while the app's deployment
  target is iOS 18.** It is the only way on this Mac to test a device with no
  Apple on-device model (curated output, cloud-only Vent). It is used rarely, so
  it looks idle — do not delete it in a disk cleanup. Devices on it are
  disposable: create one when needed and delete it after (recipe in the handoff,
  "DEBUG builds are always Pro" section). Decided by Jason 2026-09-30.
- `RoastMate-UITests` simulator — the isolated device `scripts/preflight.sh` uses.
- `build/` in this repo — `scripts/build-upload-asc.sh` writes the shipped
  `.xcarchive`s there (dSYMs), and the gitignored `build/v*-release-notes*.md`
  that `scripts/asc_bind_version.py` reads.
- `cloud-worker/node_modules`, `research/worker/node_modules` — reused by every
  `npx wrangler` deploy.
- `~/Documents/RoastMate-research/` — offer codes, outreach and balance logs;
  private, no git backup.
- Production is never "cleanup": the `roastmate-vent` Worker, the GitHub Pages
  config (`research/web/`), App Store Connect records.

## Hard-won rules

- Debug builds are always Pro (`StoreService.isPro`); verify credits/paywall only
  in Release with `ENABLE_TESTABILITY=YES`, against a control on the previous tag.
- Never stop a UI-test run without shutting its simulator down — it orphans
  ~160 simulator daemons and pins the load average near 900.
- Never send a message in Jason's name without his confirmation of the exact
  recipient and text.
