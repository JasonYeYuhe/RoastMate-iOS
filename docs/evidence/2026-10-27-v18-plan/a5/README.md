# A5 gate — Pro styles stop sounding templated (2026-10-31, macOS 27.2 26B123)

`main.swift` = lens 1's on-device probe (40 Savage + 12 Sharp-Pro calls, same
situations and styles) through the PRODUCTION `RoastEngine.generateDetailed`
(3 versions, A3's retry and screens). `score.py` scores a run. The control is
the same harness compiled against the v1.7.3 tag on the same Mac, so the
comparison is not against lens 1's 27.0.1 numbers.

| target (plan §2.2) | v1.7.3 control | 1.8.0 | gate |
|---|---|---|---|
| CJK in English output | 15 of 52 | **0 of 55** | 0 |
| "I'd have said" openers | 6 | **0** | 0 |
| Simplified-only characters in zh_TW output | 0 (喂 flagged; a false positive of the ICU round trip) | **0** | 0 |
| distinct 4-char openers in 12 Sharp-Pro first versions | 12 | 12 | ≥ 3 |
| near-duplicate calls (bigram Jaccard ≥ 0.6) | 0 of 51 | 0 of 52 | ≤ 1/30 |
| refused → curated | 0 of 52 | 0 of 52 | no regression vs A3 |
| median latency | 7.2 s | 6.0 s | — |

Copying check (`runs/run_180.jsonl`): 台劇腔 returned the zh-Hant Savage
calibration line 「第四頁頁尾還是我的檔名…」 verbatim on the "manager took
credit" situation — the calibration's own situation was credit theft. The
calibration was rewritten around uncommon situations (gym bench, borrowed
ladder, group chat) with "even when the user's situation looks like one of
them"; Savage rerun (`runs/run_180_newcalibration_savage.jsonl`): 0 verbatim
copies in 40 calls (one phrase echo, "Forty minutes of desk silence…").
Quality by hand: better than v1.7.3 (no English drama with Chinese particles,
no "I'd have said:" frame) but still mediocre; some zh lines are abstract
(「這不是一句代禱，是你的隔閡在呼叫」). Unit tests: `StyleScriptTests`.

Near-duplicate handling: duplicates are DROPPED (`droppingNearDuplicates`), not
regenerated — the plan's "regenerate once" was the first A5 item allowed to
drop; 0 duplicates in either run, so the drop never fired.
