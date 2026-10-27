#!/usr/bin/env python3
"""A1 gate (ARMS=savage,plain to limit arms; ROUND=<label> tags rows): 硬核回擊 (savage_no_filter) vs unstyled (app default high_eq) Feral, same situation.
usage: run_pairs.py <base_url> <cases.json> <out.json> [ids...]   (every request + response kept)"""
import json, os, sys, time, urllib.request, urllib.error
base, cases_path, out_path, *only = sys.argv[1:]
cases = json.load(open(cases_path))
try: rows = json.load(open(out_path))
except FileNotFoundError: rows = []
for c in cases:
    if only and c["id"] not in only: continue
    for arm, style in (("savage", "savage_no_filter"), ("plain", "high_eq")):
        if os.environ.get("ARMS") and arm not in os.environ["ARMS"].split(","): continue
        body = {"situation": c["situation"], "intensity": "feral", "locale": c["locale"], "styleId": style,
                "mode": "vent", "deviceId": f"eval-a1-20261027-{c['id']}"}
        req = urllib.request.Request(base.rstrip("/") + "/v1/vent", data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "RoastMate/26 eval-a1"})
        t = time.time()
        try:
            r = urllib.request.urlopen(req, timeout=90); d = json.load(r); status = r.status
        except urllib.error.HTTPError as e:
            d, status = {"error": e.read().decode()[:300]}, e.code
        rows.append({"id": f"{c['id']}/{arm}", "round": os.environ.get("ROUND", "gate"), "case": c["id"], "arm": arm, "request": body, "status": status,
                     "latency_s": round(time.time() - t, 2), "text": d.get("roast") or d.get("text") or "", "response": d})
        print(rows[-1]["id"], status, rows[-1]["latency_s"], (rows[-1]["text"] or str(d))[:160].replace("\n", " / "), flush=True)
json.dump(rows, open(out_path, "w"), ensure_ascii=False, indent=1)
