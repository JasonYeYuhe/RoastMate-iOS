import json, re, sys, collections
from opencc import OpenCC
s2t = OpenCC("s2t")
TW_OK = set("台里后干只面着周游系才群托志表了布借")
HAN = re.compile(r"[一-鿿]")
MAINLAND = ["老子", "傻逼", "服了", "裝什麼裝", "特麼", "卧槽", "臥槽", "尼瑪", "你妹", "牛逼", "妈的", "媽的"]
TAIWAN = ["幹", "靠北", "三小", "白目", "北七", "機車", "很盤", "喔", "欸", "齁", "王八蛋", "去你的", "爛人"]
SWEAR = {"hant": ["幹", "靠北", "王八蛋", "去你的", "他媽", "媽的", "爛人", "三小"], "en": ["fuck", "shit", "asshole", "prick", "bastard"], "ja": ["クソ", "ふざけんな", "ふざけるな", "くそ"]}
LIMIT = {"hant": 155, "en": 65, "ja": 155}
r = json.load(open(sys.argv[1]))
rows = []
for x in r:
    t = x.get("text") or ""
    b = "hant" if x["locale"] == "zh_TW" else ("en" if x["locale"].startswith("en") else "ja")
    length = len(t.split()) if b == "en" else len(re.sub(r"\s", "", t))
    rec = dict(i=x["i"], locale=x["locale"], topic=x["topic"], style=x["styleId"], status=x["status"], lat=x["latency_s"],
               length=length, over_styled_limit=length > LIMIT[b] if x["styleId"] != "high_eq" else None,
               swear=[w for w in SWEAR[b] if w.lower() in t.lower()])
    if b == "hant":
        rec["simplified"] = "".join(c for c in t if HAN.match(c) and s2t.convert(c) != c and c not in TW_OK)
        rec["mainland"] = [w for w in MAINLAND if w in t]
        rec["taiwan"] = [w for w in TAIWAN if w in t]
    if b in ("hant", "ja"):
        rec["latin"] = re.findall(r"[A-Za-z]{3,}", t)
    rec["opener"] = t[:6]
    rec["name_echo"] = [n for n in ("陳志明", "Kevin", "陳主管") if n in t]
    rows.append(rec)
for row in rows: print(json.dumps(row, ensure_ascii=False))
print("http200", sum(1 for x in r if x["status"] == 200), "/", len(r))
print("swear present", sum(1 for x in rows if x["swear"]), "/", len(rows))
print("over styled limit (pro styles)", sum(1 for x in rows if x["over_styled_limit"]), "/", sum(1 for x in rows if x["over_styled_limit"] is not None))
hant = [x for x in rows if x["locale"] == "zh_TW"]
print("zh_TW simplified chars", sum(len(x["simplified"]) for x in hant), "mainland markers", sum(1 for x in hant if x["mainland"]), "/", len(hant), "taiwan term", sum(1 for x in hant if x["taiwan"]), "/", len(hant))
print("names echoed", sum(1 for x in rows if x["name_echo"]))
