# D2 — same-key concurrent race test against the live Worker

_Run 2026-09-02 against production `roastmate-vent` (version `963db07f`).
Decision input for v1.4 §6.2 (Durable Object: build now vs defer)._

## Why this test and not a "load test"

The v1.4 plan called for a load test. A generic surge test would have **passed
while missing the defect entirely**: viral traffic spreads across many different
deviceIds, and the race is per-key. The failure only appears when many requests
share ONE key — which is exactly what a single abusive client does, and what
CGNAT does to the per-IP key.

Method: N simultaneous `POST /v1/vent` sharing one fresh `deviceId`.
`DAILY_LIMIT_PER_DEVICE = 30`, so an atomic counter permits at most 30.

## Result: the cap provides essentially no protection under concurrency

| N | HTTP 200 | cap | over-grant | distinct `remaining` |
|---|---|---|---|---|
| 40 | 38 | 30 | +8 (27%) | 1 of 38 — all `29` |
| 55 | 52 | 30 | +22 (73%) | 1 of 52 — all `29` |
| 55 | 51 | 30 | +21 (70%) | — |
| 55 (post-fix) | 55 | 30 | +25 (83%) | — |

**Every successful response reported `remaining: 29`.** All N requests read
count = 0 and wrote 1. The reads did not merely overlap — they collided
completely.

The over-grant scales with burst size, so the practical rule is: **a burst of N
yields ~N generations regardless of the cap.** The daily limit constrains
sequential use only. It is not a meaningful bound on a client that chooses to
be concurrent.

## Second, separate defect found: same-key bursts were returning HTTP 500

4 of 55 requests returned HTTP 500 (Cloudflare 1101). Captured via `wrangler tail`:

```
Error: KV PUT failed: 429 Too Many Requests
    at async Object.fetch (index.js:27282:5)
```

Cloudflare KV permits ~**1 write per second to the same key**. Every counter
here is same-key by construction (one key per device / account / IP per day), so
a burst makes the `put` throw, and the throw was uncaught.

This one is not only an abuse concern. **The per-IP key is shared**: under CGNAT
many legitimate mobile users write the same `ipa:app:<hash>:<day>` key. A hot key
would have thrown 500s at users who did nothing wrong.

**Fixed and deployed** (version `dc5d1133`): the three counter writes now go
through `safePut()`, which catches the failure, logs it to Datadog as
`counter_write_failed`, and continues. A dropped increment is consistent with
these counters' documented best-effort contract and is strictly better than a
500. Re-ran the identical 55-way burst afterwards: **0 × 500** (was 4).

Note this deliberately does **not** fix the race — confirmed by the post-fix row
above, where all 55 still succeeded. Crash and race are separate problems.

## Incidental finding: Cloudflare's bot filter is a real first layer

The first attempt returned `403 error code 1010` for all 40 requests —
Cloudflare blocked Python's default `urllib` User-Agent at the edge, before the
Worker ran. A naive scripted attacker is bounced for free. Every number above
required spoofing a plausible `CFNetwork` UA, which is a low bar but not zero.

## What this means for D2

The v1.4 plan's own conditional was: *build the DO before full rollout **if** the
test shows the race is exploitable.* It does, by a wide margin, so **that
conditional is now triggered**.

Weighing it honestly:

- **Direct cost exposure is small.** At roughly $0.0002 per Groq call, even
  10,000 over-granted generations is a few dollars. This is not a
  bankruptcy risk.
- **Quota exhaustion is the real risk, not the bill.** The upstream dev tier is
  250K TPM / 1K RPM. A burst that over-grants also burns shared upstream
  capacity, and when that runs out *paying Pro users* lose the cloud path. That
  is the same "surge 502s everyone" failure the whole Track M dam exists to
  prevent.
- **Cost per unit of protection is now low.** SQLite-backed Durable Objects are
  on the Workers **free** plan (100k requests/day, 100k row writes/day) — well
  beyond current volume. The earlier "$60/year" objection was simply wrong.
- **A DO also fixes the 1-write-per-second ceiling**, because a DO serialises
  writes to its own storage instead of hammering one KV key. It resolves both
  defects, not just the race.

**Recommendation: build the DO before `share_card_enabled` is flipped on.**
Not before shipping v1.4 with the card dark — the card does not itself touch the
cloud, so a dark card adds no risk. The trigger is the flip, because that is when
traffic and the incentive to abuse both rise.

**Do first, regardless — hard provider spend ceilings at Groq and OpenRouter.**
They cost nothing, cap the true worst case, and do not depend on our own code
being correct. No amount of edge logic substitutes for a limit the provider
enforces.

## Outcome — DO built, deployed, and re-measured the same day

`QuotaCounter` (SQLite-backed Durable Object, one instance per counter key)
shipped behind `QUOTA_BACKEND`, deployed as version `85531706`. Re-ran the
identical test:

| N | HTTP 200 | 429 | cap | distinct `remaining` | over-grant |
|---|---|---|---|---|---|
| 40 | **30** | 10 | 30 | **30 / 30** | none |
| 55 | **30** | 25 | 30 | **30 / 30** | none |
| 70 | **30** | 40 | 30 | **30 / 30** | none |

Exactly the cap at every burst size, and every granted unit received a
**distinct** position (29 down to 0) instead of all reporting `remaining=29`.
Zero 500s. Single-request latency unchanged (1.8s end-to-end, dominated by the
model call — the DO hop is not measurable against it).

### One design change the DO alone would not have fixed

The old flow checked the quota up front but only charged it **after** the
upstream call, so a failed generation would not eat a user's daily quota. Good
intent, but it placed the entire ~2-3s model call inside the check→charge
window — which is *why* every concurrent request read the same count. Making
the counter atomic would not have closed that on its own.

So the shape changed to **reserve-then-refund**: `consume()` reserves at check
time, and `refundQuota()` returns the unit if every upstream fails. Same
user-visible behaviour, no window. The per-IP attempt cap is deliberately *not*
refunded — it exists to bound retry floods, so a failed attempt should still
count.

### Rollback

`QUOTA_BACKEND = "kv"` and redeploy. The DO path also falls back to KV on its
own if a call throws (covered by a test), so a Durable Objects outage degrades
to the old racy-but-working behaviour rather than 500ing or blocking a paying
user.

## Reproduce

`python3 evals/d2_race_test.py N` — set a browser-plausible User-Agent or Cloudflare
1010s the client. Each run costs ~N Groq calls; it hits production, so keep N
modest and use a fresh deviceId.
