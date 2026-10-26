#!/usr/bin/env python3
"""Lens-1 cloud audit, 2026-10-27. 20 Feral calls to the PRODUCTION Worker, tokenless.
The Worker accepts intensity=feral on the free lane (index.js validate(): lane only sets the
quota; buildVentSystemPrompt takes no lane), so the prompt is byte-identical to a Pro user's.
Same body shape as CloudVentRequest since 1.7.1: situation, styleName (UI language), intensity,
locale, deviceId, styleId."""
import json, time, sys, urllib.request, urllib.error
EP = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent"
OUT = sys.argv[1]
NAMES = {
 "zh-Hant": {"savage_no_filter": "硬核回擊", "taiwanese_drama": "台劇腔", "cold_violence": "冷處理", "corporate_passive_violence": "職場冷暴力", "high_eq": "高 EQ"},
 "en": {"savage_no_filter": "Savage", "taiwanese_drama": "Taiwanese Drama", "cold_violence": "Cold Reply", "corporate_passive_violence": "Corporate Passive Violence", "high_eq": "High EQ"},
 "ja": {"savage_no_filter": "容赦なし", "taiwanese_drama": "台湾ドラマ口調", "cold_violence": "冷たい返し", "corporate_passive_violence": "ビジネス冷たい暴力", "high_eq": "高EQ"},
}
S = {
 "zh_TW": [("work", "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。上禮拜加班三天一毛加班費都沒有，還在LINE群組說年輕人要有責任感。"),
           ("family", "我媽每次過年都在親戚面前拿我跟表姊比，說人家在竹科年薪兩百萬，我只會領死薪水，還一直問我什麼時候要結婚，搞得我很想直接離席。")],
 "en_US": [("work", "My manager Kevin took credit for the report I spent my whole weekend on. In the team meeting he presented it like it was his idea and didn't mention me once. Then he asked me to 'tidy up the slides' for his VP presentation."),
           ("roommate", "My roommate keeps eating the groceries I literally label with my name. Today she finished my leftover pad thai and put the empty container back in the fridge. When I asked she said 'oh I thought you didn't want it.'")],
 "ja_JP": [("work", "上司が金曜の定時直前に「月曜の朝までに資料作っといて」って丸投げしてきた。しかも先週私が作った企画書を、部長の前で自分の手柄みたいに発表してた。"),
           ("roommate", "ルームメイトが共用のシンクに洗い物を一週間放置して、コバエが湧いた。注意したら「気になる人が洗えばいいじゃん」って言われた。")],
}
UI = {"zh_TW": "zh-Hant", "en_US": "en", "ja_JP": "ja"}
plan = []
for topic, sit in S["zh_TW"]:
    for st in ["savage_no_filter", "taiwanese_drama", "cold_violence", "corporate_passive_violence", "high_eq"]:
        plan.append(("zh_TW", topic, sit, st))
for topic, sit in S["en_US"]:
    for st in ["savage_no_filter", "taiwanese_drama", "corporate_passive_violence"]:
        plan.append(("en_US", topic, sit, st))
for topic, sit in S["ja_JP"]:
    for st in ["savage_no_filter", "cold_violence"]:
        plan.append(("ja_JP", topic, sit, st))
assert len(plan) == 20, len(plan)
res = []
for i, (loc, topic, sit, st) in enumerate(plan):
    body = {"situation": sit, "styleName": NAMES[UI[loc]][st], "intensity": "feral", "locale": loc,
            "deviceId": "audit-lens1-2026-10-27", "styleId": st}
    req = urllib.request.Request(EP, data=json.dumps(body, ensure_ascii=False).encode(), method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "RoastMate/26 CFNetwork/3826.400.120 Darwin/25.0.0"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            st_code = r.status; j = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        st_code = e.code; j = {"error": e.read().decode()[:300]}
    except Exception as e:
        st_code = 0; j = {"error": repr(e)}
    rec = {"i": i, "locale": loc, "topic": topic, "styleId": st, "intensity": "feral", "situation": sit,
           "status": st_code, "latency_s": round(time.time() - t0, 2), **{k: j.get(k) for k in ("text", "model", "remaining", "error")}}
    res.append(rec)
    print(json.dumps(rec, ensure_ascii=False), flush=True)
    time.sleep(1.0)
json.dump(res, open(OUT, "w"), ensure_ascii=False, indent=1)
