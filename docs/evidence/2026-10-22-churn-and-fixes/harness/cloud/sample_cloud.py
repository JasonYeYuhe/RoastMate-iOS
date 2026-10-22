#!/usr/bin/env python3
"""Cloud-output audit sampler (2026-10-22). Read-only w.r.t. the repo.

Calls the PRODUCTION Worker /v1/vent tokenless (free lane, exactly the shape
CloudVentRequest encodes for a vent: situation, styleName, intensity, locale,
deviceId; mode only for roommate). No Authorization header is sent.
"""
import json, time, sys, urllib.request, urllib.error

ENDPOINT = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent"
OUT = sys.argv[1]

G = {
  "en_US": [
    ("work", "My manager Kevin took credit for the report I spent my whole weekend on. In the team meeting he presented it like it was his idea and didn't mention me once. Then he asked me to 'tidy up the slides' for his VP presentation."),
    ("relationship", "My boyfriend forgot my birthday AGAIN and when I brought it up he said I'm 'too sensitive' and that birthdays are just a day. He remembered his fantasy football draft date down to the minute though."),
    ("roommate", "My roommate keeps eating the groceries I literally label with my name. Today she finished my leftover pad thai and put the empty container back in the fridge. When I asked she said 'oh I thought you didn't want it.'"),
  ],
  "zh_TW": [
    ("work", "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。上禮拜加班三天一毛加班費都沒有，還在LINE群組說年輕人要有責任感。"),
    ("relationship", "男友說好要陪我過紀念日，結果當天臨時說要跟朋友去打球，我訂好的餐廳只好取消。問他還說我很情勒，一個紀念日而已幹嘛這麼在意。"),
    ("family", "我媽每次過年都在親戚面前拿我跟表姊比，說人家在竹科年薪兩百萬，我只會領死薪水，還一直問我什麼時候要結婚，搞得我很想直接離席。"),
  ],
  "zh-Hans": [
    ("work", "领导周五晚上十点在群里@我，让我周末把整个方案重做，说客户不满意。结果周一开会他跟客户说是他亲自改的，一个字没提我。"),
    ("relationship", "我发烧三十九度让男朋友帮我下楼买个药，他在打游戏，说等这局打完。我又叫了两次，他直接来一句“你怎么这么烦”。"),
    ("roommate", "室友每天凌晨一两点开外放刷短视频，笑得整层楼都听得见。我跟她说了好几次，她说“你戴耳塞不就行了”，还在宿舍群里阴阳我矫情。"),
  ],
  "ja_JP": [
    ("work", "上司が金曜の定時直前に「月曜の朝までに資料作っといて」って丸投げしてきた。しかも先週私が作った企画書を、部長の前で自分の手柄みたいに発表してた。"),
    ("relationship", "彼氏が私の誕生日をまた忘れてた。指摘したら「誕生日なんてただの日でしょ、重いよ」って逆ギレ。自分の推しのライブの日程は完璧に覚えてるくせに。"),
    ("roommate", "ルームメイトが共用のシンクに洗い物を一週間放置して、コバエが湧いた。注意したら「気になる人が洗えばいいじゃん」って言われた。"),
  ],
}
LANG = {"en_US": "en", "zh_TW": "zhtw", "zh-Hans": "zhhans", "ja_JP": "ja"}

def call(body):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(ENDPOINT, data=data, method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "RoastMate-iOS"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            raw = r.read().decode("utf-8"); status = r.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace"); status = e.code
    except Exception as e:
        return {"status": 0, "latency_s": round(time.time() - t0, 2), "error": repr(e)}
    lat = round(time.time() - t0, 2)
    try:
        j = json.loads(raw)
    except Exception:
        j = {"raw": raw[:300]}
    return {"status": status, "latency_s": lat, **{k: j.get(k) for k in ("text", "model", "provider", "remaining", "error", "detail")}}

plan = []
for loc, items in G.items():
    for n, (topic, sit) in enumerate(items, 1):
        for inten in ("vent", "feral"):
            plan.append(dict(set="core", locale=loc, topic=topic, n=n, intensity=inten, situation=sit,
                             deviceId=f"audit-{LANG[loc]}-{n}-1022"))
# zh_TW repeats (target market) to estimate Simplified-bleed rate with n=12
for n, (topic, sit) in enumerate(G["zh_TW"], 1):
    for inten in ("vent", "feral"):
        plan.append(dict(set="zhtw_repeat", locale="zh_TW", topic=topic, n=n, intensity=inten, situation=sit,
                         deviceId=f"audit-zhtw-{n}-1022"))
# locale-identifier variants a Taiwan user can produce
plan.append(dict(set="locale_variant", locale="zh-Hant", topic="relationship", n=2, intensity="vent",
                 situation=G["zh_TW"][1][1], deviceId="audit-zhhant-2-1022"))
plan.append(dict(set="locale_variant", locale="zh_TW@calendar=roc", topic="family", n=3, intensity="vent",
                 situation=G["zh_TW"][2][1], deviceId="audit-zhtwroc-3-1022"))
# roommate group (zh-Hans only feature)
for inten in ("vent", "feral"):
    plan.append(dict(set="roommate", locale="zh-Hans", topic="roommate", n=3, intensity=inten, mode="roommate",
                     situation=G["zh-Hans"][2][1], deviceId="audit-zhhans-rm-1022"))

assert len(plan) <= 40, len(plan)
results = []
for i, p in enumerate(plan):
    STYLE = {"en_US": "High EQ", "ja_JP": "高EQ"}.get(p["locale"], "高 EQ")
    body = {"situation": p["situation"], "styleName": STYLE if p.get("mode") is None else None,
            "intensity": p["intensity"], "locale": p["locale"], "deviceId": p["deviceId"]}
    if p.get("mode"):
        body["mode"] = p["mode"]
    body = {k: v for k, v in body.items() if v is not None}
    r = call(body)
    rec = {"i": i, **p, "request": body, **r, "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    results.append(rec)
    print(i, p["set"], p["locale"], p["intensity"], r.get("status"), r.get("latency_s"), r.get("model"), (r.get("text") or r.get("error") or "")[:60].replace("\n", " "), flush=True)
    json.dump(results, open(OUT, "w"), ensure_ascii=False, indent=1)
    time.sleep(0.5)
print("calls:", len(results))
