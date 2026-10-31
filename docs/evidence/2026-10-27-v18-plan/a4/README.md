# A4 gate — the Argument Simulator plays the other side (2026-10-31, macOS 27.2 26B123)

`main.swift` calls the PRODUCTION `RoastEngine.opponentTurn` (+ `opponentPersona`)
on lens 1's 36-turn set (zh_TW + en: 3 setups × 2 styles × 3 turns, the same
setups and user replies as `harness/audit/probe/main.swift`), plus a ja set I
wrote for the refusal gate. Each turn gets the real transcript so far. Rubric =
lens 1's (one reader, zh read non-natively): OPP = speaks as the other party,
USER = flips to the user's side, AMB = confused. Raw turns: `runs/roundN.jsonl`.

| round | change | generated | numbered | OPP of 36 (zh_TW / en) | median latency |
|---|---|---|---|---|---|
| lens 1 (10-22, 27.0.1) | the roast prompt | 26/36 (10 refused → canned) | 12/36 | 14 | — |
| 1 | own stateless prompt | 52/54 | 0 | ~18 (8 / 10) | 3.8 s |
| 2 | + persona call (two sentences) | 54/54 | 0 | **30** (16 / 14) | 3.3 s |
| 3 | persona rewritten with stricter rules | 53/54 | 0 | ~25; 4/9 personas empty | 3.6 s |
| 4 | round 2's persona + a landlord example | 54/54 | 0 | 28 (15 / 13) | 3.8 s |
| 5 | + persona restated last; repeat retry at T=1.0 | 53/54 | 0 | 28 (14 / 14) | 3.5 s |
| 6 | persona asks for the role only | 53/54 | 0 | 27 (14 / 13) | 3.9 s |

**Shipped: round 5's code** (persona v1 + recency + repeat retry). Gate (≥ 29/36)
met in 1 of the 3 runs of this persona (30, 28, 28); not reliably met. Refusals:
0–1 of 18 per locale every round (gate ≤ 1/8 met). 0 numbered lists (met).
Round 5 labels: zh_TW cold raise OPP/AMB/USER, savage raise OPP×3, cold trash
OPP×3, savage trash USER/AMB/OPP, cold mom OPP×3, savage mom OPP×3; en cold raise
OPP×3, savage raise USER/AMB/USER, cold trash OPP×3, savage trash OPP×3, cold mom
OPP×3, savage mom OPP/not generated/OPP.

What still fails: 硬核回擊 (savage_no_filter) on the raise and trash setups — its
preamble ("comebacks that name the behavior") pulls the model into attacking the
"excuse", the user's own complaint. The English raise persona inverts in every
run ("You are the employee"). The repeat retry fixed cold_violence repeating the
identical line three turns running (rounds 2 and 4).

Not measured here: the threat judge's false-positive rate on simulator turns
(the default guardrails accepted almost every turn, so the permissive path and
its judge rarely ran: 1–2 not-generated turns per round) and a C/E device
(needs a simulator boot; free disk < 30 GB).

## Reproduce

    S=<scratchpad>; scratchpad/a4/build.sh docs/evidence/2026-10-27-v18-plan/a4/main.swift $S/A4.app
    $S/A4.app/Contents/MacOS/realengine [zh_TW|en_US|ja_JP] [--no-persona] > run.jsonl

`build.sh` = swiftc of `Shared/` + `main.swift` into a minimal `.app` carrying
`Shared/Resources/*.json` and the four `Localizable.strings`.
