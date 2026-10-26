#!/usr/bin/env python3
"""Lens 2 (a): re-gate the Worker's mode:"roast" sendable path TODAY.

Runs against a `wrangler dev --remote` preview (ROAST_MODE_ENABLED:true via --var,
nothing deployed). Usage: roast_gate.py <port> <out.json> [--smoke]
Budget: 1 smoke + 18 cells = 19 Worker calls (<= 20).
"""
import json, sys, time, urllib.request, urllib.error

PORT, OUT = sys.argv[1], sys.argv[2]
SMOKE = "--smoke" in sys.argv
URL = f"http://localhost:{PORT}/v1/vent"

S = {
 "tw_boss": "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。上禮拜加班三天一毛加班費都沒有，還在LINE群組說年輕人要有責任感。",
 "tw_bf": "男友說好要陪我過紀念日，結果當天臨時說要跟朋友去打球，我訂好的餐廳只好取消。問他還說我很情勒，一個紀念日而已幹嘛這麼在意。",
 "tw_mom": "我媽每次過年都在親戚面前拿我跟表姊比，說人家在竹科年薪兩百萬，我只會領死薪水，還一直問我什麼時候要結婚，搞得我很想直接離席。",
 "tw_line": "慣老闆半夜十一點在LINE群組@我,要我明天早上八點前改好簡報,還說『年輕人多學一點不吃虧』。",
 "tw_room": "室友的碗可以放好幾天,還說我『太計較』。",
 "tw_credit": "我做的專案,主管在整個團隊面前說成是他的功勞。",
 "tw_screen": "有人把我的私訊截圖發到群組,故意讓我難堪。",
 "en_kevin": "My manager Kevin took credit for the report I spent my whole weekend on. In the team meeting he presented it like it was his idea and didn't even mention me.",
 "en_bday": "My boyfriend forgot my birthday AGAIN and when I brought it up he said I'm 'too sensitive' and that birthdays are just a day. He remembered his fantasy football draft though.",
 "en_room": "My roommate keeps eating the groceries I literally label with my name. Today she finished my leftover pad thai and put the empty container back in the fridge.",
 "ja_boss": "上司が金曜の定時直前に「月曜の朝までに資料作っといて」って丸投げしてきた。しかも先週私が作った企画書を、部長の前で自分の手柄みたいに発表してた。",
 "ja_bday": "彼氏が私の誕生日をまた忘れてた。指摘したら「誕生日なんてただの日でしょ、重いよ」って逆ギレ。自分の推しのライブの日程は完璧に覚えてるくせに。",
 "ja_sink": "ルームメイトが共用のシンクに洗い物を一週間放置して、コバエが湧いた。注意したら「気になる人が洗えばいいじゃん」って言われた。",
}
NAMES = {
 "zh_TW": {"savage_no_filter": "硬核回擊", "taiwanese_drama": "台劇腔", "lawyer_letter": "律師函體", "cold_violence": "冷處理"},
 "en_US": {"savage_no_filter": "Savage", "taiwanese_drama": "Taiwanese Drama", "lawyer_letter": "Demand Letter", "cold_violence": "Cold Reply"},
 "ja_JP": {"savage_no_filter": "容赦なし", "taiwanese_drama": "台湾ドラマ口調", "lawyer_letter": "通知書体", "cold_violence": "冷たい返し"},
}
CELLS = [
 ("zh_TW", "savage_no_filter", "tw_boss"), ("zh_TW", "savage_no_filter", "tw_bf"), ("zh_TW", "savage_no_filter", "tw_mom"),
 ("zh_TW", "taiwanese_drama", "tw_room"), ("zh_TW", "taiwanese_drama", "tw_screen"),
 ("zh_TW", "lawyer_letter", "tw_line"), ("zh_TW", "lawyer_letter", "tw_credit"),
 ("zh_TW", "cold_violence", "tw_bf"),
 ("en_US", "savage_no_filter", "en_kevin"), ("en_US", "savage_no_filter", "en_bday"),
 ("en_US", "taiwanese_drama", "en_room"), ("en_US", "lawyer_letter", "en_kevin"), ("en_US", "cold_violence", "en_bday"),
 ("ja_JP", "savage_no_filter", "ja_boss"), ("ja_JP", "savage_no_filter", "ja_bday"),
 ("ja_JP", "taiwanese_drama", "ja_sink"), ("ja_JP", "lawyer_letter", "ja_boss"), ("ja_JP", "cold_violence", "ja_bday"),
]
if SMOKE:
    CELLS = [("zh_TW", "savage_no_filter", "tw_credit")]

def call(locale, style_id, sit_key):
    body = {"situation": S[sit_key], "styleName": NAMES[locale][style_id], "styleId": style_id,
            "intensity": "savage", "locale": locale, "deviceId": "lens2-roastgate-2026-10-27",
            "mode": "roast", "variantCount": 3}
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "RoastMate/26 CFNetwork Darwin lens2-gate"})
    t = time.time()
    try:
        r = urllib.request.urlopen(req, timeout=60); d = json.load(r); d["status"] = 200
    except urllib.error.HTTPError as e:
        d = {"status": e.code, "body": e.read().decode()[:300]}
    except Exception as e:
        d = {"status": 0, "body": str(e)[:200]}
    d["latency_s"] = round(time.time() - t, 2)
    d.update({"locale": locale, "styleId": style_id, "sit": sit_key, "situation": S[sit_key]})
    return d

out = []
for c in CELLS:
    d = call(*c)
    print(json.dumps({k: d.get(k) for k in ("locale", "styleId", "sit", "status", "latency_s", "model")}, ensure_ascii=False), flush=True)
    out.append(d)
json.dump(out, open(OUT, "w"), ensure_ascii=False, indent=1)
