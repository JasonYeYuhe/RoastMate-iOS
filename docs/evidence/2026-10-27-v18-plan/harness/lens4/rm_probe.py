#!/usr/bin/env python3
# Lens 4: roommate (mode=roommate) on the PRODUCTION Worker with locale zh_TW.
# Free tokenless lane (no Authorization header; nothing forged). 8 calls.
import json, sys, time, urllib.request, urllib.error
OUT = sys.argv[1]
URL = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent"
SITS = [
 ("roommate", "zh_TW", "室友每天半夜兩點還開外放打電動，我講了好幾次，他只回「你戴耳塞就好了啊」，還在群組說我很難相處。"),
 ("boss", "zh_TW", "慣老闆晚上十一點在 LINE 群組 @我，要我明天早上八點前改好簡報，還說「年輕人多學一點不吃虧」。"),
 ("money", "zh_TW", "朋友跟我借了五千塊說下個月還，三個月了都已讀不回，IG 限動還在發出國玩的照片。"),
 ("family", "zh-Hant_TW", "我媽在家族 LINE 群組把我的體重講給所有親戚聽，還說「女生要有點自覺」。"),
]
rows = []
for topic, loc, sit in SITS:
    for inten in ("vent", "feral"):
        body = json.dumps({"situation": sit, "intensity": inten, "locale": loc,
                           "deviceId": "audit-lens4-rm-zhtw-1027", "mode": "roommate"}).encode()
        req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json",
              "User-Agent": "RoastMate/26 CFNetwork/3826.400.120 Darwin/25.0.0"})
        t = time.time()
        try:
            r = urllib.request.urlopen(req, timeout=60); d = json.load(r); st = 200
        except urllib.error.HTTPError as e:
            d = {"body": e.read().decode()[:300]}; st = e.code
        rows.append({"topic": topic, "locale": loc, "intensity": inten, "situation": sit, "status": st,
                     "latency_s": round(time.time() - t, 2), "text": d.get("text"), "model": d.get("model"),
                     "provider": d.get("provider"), "remaining": d.get("remaining"), "raw": d if st != 200 else None,
                     "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z")})
        print(topic, inten, st, rows[-1]["latency_s"], (d.get("text") or "")[:60].replace("\n", " | "), flush=True)
json.dump(rows, open(OUT, "w"), ensure_ascii=False, indent=1)
