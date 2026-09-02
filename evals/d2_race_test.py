#!/usr/bin/env python3
"""D2: same-key concurrent race test against the live Worker.

Fires N simultaneous /v1/vent requests sharing ONE deviceId. The daily cap
is DAILY_LIMIT_PER_DEVICE=30. With an atomic counter at most 30 can succeed.
The counter is KV get-then-put, so concurrent readers can all observe the
same pre-increment value and over-grant.

Two independent signals:
  1. successes > cap                -> over-grant, quantified
  2. duplicate `remaining` values   -> proves reads collided (the race itself)

Deliberately bounded: N requests, one device, one run. Cost is N Groq calls.
"""
import json, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor
from collections import Counter

URL = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent"
N   = int(sys.argv[1]) if len(sys.argv) > 1 else 40
CAP = 30
DEV = sys.argv[2] if len(sys.argv) > 2 else f"d2-race-{int(time.time())}"

def fire(i):
    body = json.dumps({"situation": f"并发竞态测试 {i}", "locale": "zh-Hans",
                       "intensity": "vent", "deviceId": DEV}).encode()
    r = urllib.request.Request(URL, data=body, method="POST",
                               headers={"Content-Type": "application/json",
                                        # Cloudflare 1010s urllib's default UA at the
                                        # edge. Mimic the app's URLSession client so we
                                        # test the WORKER's counter, not the bot filter.
                                        "User-Agent": "RoastMate/1.3.1 CFNetwork/1494 Darwin/24.0.0"})
    t0 = time.time()
    try:
        resp = urllib.request.urlopen(r, timeout=90)
        d = json.loads(resp.read())
        return (resp.status, d.get("remaining"), round(time.time()-t0, 2))
    except urllib.error.HTTPError as e:
        try:    err = json.loads(e.read()).get("error")
        except Exception: err = "?"
        return (e.code, err, round(time.time()-t0, 2))
    except Exception as e:
        return (0, type(e).__name__, round(time.time()-t0, 2))

print(f"deviceId={DEV}  N={N}  cap={CAP}")
t0 = time.time()
with ThreadPoolExecutor(max_workers=N) as ex:
    results = list(ex.map(fire, range(N)))
wall = round(time.time()-t0, 1)

codes = Counter(r[0] for r in results)
ok    = [r for r in results if r[0] == 200]
rem   = [r[1] for r in ok if isinstance(r[1], int)]
dupes = {v: c for v, c in Counter(rem).items() if c > 1}

print(f"\nwall={wall}s  status: {dict(codes)}")
print(f"200s = {len(ok)}  (atomic counter would allow at most {CAP})")
if rem:
    print(f"remaining seen: min={min(rem)} max={max(rem)} distinct={len(set(rem))}/{len(rem)}")
if dupes:
    print(f"DUPLICATE remaining values (collided reads): {dupes}")
print()
if len(ok) > CAP:
    print(f"RACE EXPLOITABLE: {len(ok)} succeeded vs cap {CAP} -> over-grant of {len(ok)-CAP} ({(len(ok)-CAP)/CAP*100:.0f}% over)")
elif dupes:
    print(f"RACE PRESENT but bounded this run: {len(ok)} <= cap, yet reads collided")
else:
    print(f"No over-grant observed at N={N}")
