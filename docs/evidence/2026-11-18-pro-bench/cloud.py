#!/usr/bin/env python3
"""Q2 cloud bench: Vent / Feral drafts from a PREVIEW Worker (`npx wrangler dev
--remote --port 8799`), never production. Body shape = CloudVentRequest since
1.7.1 (situation, styleName in the UI language, intensity, locale, deviceId,
styleId); `variantCount` only when --takes > 1 (Q2a). Tokenless = the free
lane; the Vent/Feral prompt does not depend on the lane, so it is byte-identical
to a Pro user's (index.js: buildVentSystemPrompt takes no lane).

    cloud.py <out.jsonl> [--base http://localhost:8799] [--intensities vent,feral]
             [--locales zh_TW,en_US,ja_JP] [--takes N] [--token T] [--inputs inputs.json]
             [--max-calls N]

Spend: ≈ $0.00013 a call (handoff); every call is logged to stdout with its status.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent


def arg(name, default=None):
    a = sys.argv
    return a[a.index(name) + 1] if name in a else default


def main():
    out = Path(sys.argv[1])
    base = arg("--base", "http://localhost:8799")
    inputs = json.loads(Path(arg("--inputs", HERE / "inputs.json")).read_text())
    cloud = inputs["cloud"]
    intensities = arg("--intensities", "vent,feral").split(",")
    locales = arg("--locales", "zh_TW,en_US,ja_JP").split(",")
    takes = int(arg("--takes", "1"))
    token = arg("--token")
    max_calls = int(arg("--max-calls", "200"))
    rot = cloud["styles_rotation"]
    plan = []
    for loc in locales:
        for i, sit in enumerate(cloud["situations"][loc]):
            for k, inten in enumerate(intensities):
                st = rot[(i + k) % len(rot)]
                plan.append((loc, sit, inten, st))
    plan = plan[:max_calls]
    with out.open("a", encoding="utf-8") as f:
        for n, (loc, sit, inten, st) in enumerate(plan):
            body = {"situation": sit["text"], "styleName": cloud["ui_style_names"][loc][st], "intensity": inten,
                    "locale": loc, "deviceId": f"bench-q2-{time.strftime('%m%d')}-{n:03d}", "styleId": st}
            if takes > 1:
                body["variantCount"] = takes
            headers = {"Content-Type": "application/json", "User-Agent": "RoastMate-bench/1.9 (preview)"}
            if token:
                headers["Authorization"] = f"Bearer {token}"
            req = urllib.request.Request(f"{base}/v1/vent", data=json.dumps(body, ensure_ascii=False).encode(),
                                         method="POST", headers=headers)
            t0 = time.time()
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    status, j = r.status, json.loads(r.read().decode())
            except urllib.error.HTTPError as e:
                status, j = e.code, {"error": e.read().decode()[:300]}
            except Exception as e:  # noqa: BLE001
                status, j = 0, {"error": repr(e)}
            rec = {"mode": "cloud", "i": n, "locale": loc, "sit": sit["id"], "situation": sit["text"], "intensity": inten,
                   "styleId": st, "takes_requested": takes, "status": status, "latency_s": round(time.time() - t0, 2),
                   "text": j.get("text"), "takes": j.get("texts") or ([j["text"]] if j.get("text") else []),
                   "model": j.get("model"), "error": j.get("error"), "names": cloud["names"][loc]}
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            f.flush()
            print(f"{n:3d} {loc} {inten:5s} {st:28s} {status} {rec['latency_s']}s {(rec['text'] or rec['error'] or '')[:60]!r}", flush=True)
            time.sleep(0.5)


if __name__ == "__main__":
    main()
