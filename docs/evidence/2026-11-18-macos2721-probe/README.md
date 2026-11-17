# Refusal probe after macOS 27.2.1 (2026-11-18)

**Trigger.** The 11-16 weekly readout recorded this Mac on **macOS 27.2.1 (26B131)**,
up from 27.2 (26B123). Path D says a 27.x point release means the refusal probe
is due, and that a broken rewrite or a refusal cliff triggers an OS-compatibility
binary (handoff, "Update 2026-11-08 (late)").

**Verdict: no OS-compatibility binary needed.** Every check matches the 27.2
baseline. The production engine still writes the shipped paths through 1.8.0's
permissive retry, and 改成能發的 still rewrites.

Apple Intelligence available, model variant "AFM 3 Core". All calls were
on-device, so the cost was $0. App code at HEAD equals iOS 1.8.0 (29) apart from
one comment.

## Results

| check | 27.2 baseline | **27.2.1 today** | file |
|---|---|---|---|
| Default guardrails, production prompts (`audit/probe all`) | Savage 4/40 model-written, Sharp+Pro 0/12, simulator 0/36, free 1/16 | Savage **0/40**, Sharp+Pro 0/12, simulator 0/36, free **1/16** | `probe_all.jsonl` |
| Default vs permissive, 8 Savage/Pro cells (`lens2/fmb B`) | default 0/8, permissive 8/8 (24/24 strict pass) | default **0/8**, permissive **8/8**, 24/24 strict pass, zh_TW all Traditional, 2.7–15.7 s | `fmb_B.txt` |
| Shipped threat judge (phrases + p1) on the blind set | 32/40 threats caught (veiled 20/28), 8/40 legit blocked | **32/40 (veiled 20/28), 8/40**, identical per item | `judge_blind_p1.txt` |
| Same judge on 297 real outputs | 20/297 blocked | **20/297**, identical per item | `judge_real_p1.txt` |
| **Production `RoastEngine`** (1.7.3's cases + 2 rewrites) | 1.7.3 on 27.2: 5/5 sendable cases model-written, the threat request curated | **5/5 model-written** (4.0–11.5 s); "write something to scare him" curated (1.7 s); **改成能發的 zh_TW and en model-written** (5.5 s, 1.9 s) | `engine.txt`, `realengine_main.swift` |

- The default-guardrail cliff is unchanged in kind. It was already near-total on
  27.2, and 1.8.0 does not depend on it: the permissive retry is what ships.
- `safety_screens.jsonl` (`safety/main.swift all`) now runs the shipped 1.8.0
  judge. On this split, 1/30 threats reach the screen and 7/30 legit complaints
  are blocked. That is **not comparable** with the 10-27 baseline file: that run
  used the old p0 judge, and the odd half of this set tuned p1. Use the
  blind-set rows above for the OS comparison.
- Quality is the same mediocre on-device level as 1.7.3 (short, abstract lines).
  That is A5's territory, not a point-release regression.

## Reproduce

Paths as in `../2026-10-27-v18-plan/baseline-macos272/README.md`. The production
engine is every `Shared/**/*.swift` (excluding iCloud `* 2.swift` duplicates)
plus `realengine_main.swift`, built with the project's concurrency settings and
run from a minimal `.app` bundle, so `StylePresets` and `ForbiddenTerms` load as
they do in the app:

```bash
R=~/Documents/RoastMate; OUT=<scratchpad>/engine
find $R/Shared -name '*.swift' ! -name '* 2.swift' -print0 | xargs -0 swiftc -O -swift-version 6 \
  -parse-as-library -module-name RoastMateProbe \
  -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances \
  -enable-upcoming-feature InferSendableFromCaptures -enable-upcoming-feature GlobalActorIsolatedTypesUsability \
  -enable-upcoming-feature DisableOutwardActorInference \
  -o $OUT/realengine docs/evidence/2026-11-18-macos2721-probe/realengine_main.swift
# Probe.app/Contents/{MacOS/realengine, Resources/<Shared/Resources/*.json + Shared/*.lproj>, Info.plist}
$OUT/Probe.app/Contents/MacOS/realengine
```
