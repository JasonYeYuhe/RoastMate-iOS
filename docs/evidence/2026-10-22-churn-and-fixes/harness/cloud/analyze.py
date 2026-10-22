#!/usr/bin/env python3
import json, re, sys, statistics
from opencc import OpenCC

RAW, OUT = sys.argv[1], sys.argv[2]
r = json.load(open(RAW))
s2t = OpenCC("s2t"); t2s = OpenCC("t2s")
# chars that OpenCC s2t changes but which are normal in Taiwan Traditional text
TW_OK = set("台里后干只面着周游系才群托志表了布借")
# eval-runner set (evals/runner/Sources/EvalRunner/Checks.swift simplifiedOnly) for comparability
EVAL_SET = set("们说时这个会学电车门问关实认应发无与从众优传伤体让过还进边远连运达选适该详语请论谁讲谢识证议记计讨许设访词试话谈调变组织经给结统绝续维线练级约红纸细终编华亲义习书买卖东长马鸟鱼龙点热爱样现单双头难题类显图团园国圆声处备复够势医卫压厂厅历县参")
HAN = re.compile(r"[一-鿿]")
# live v1.7.0 vent hard rail (git show v1.7.0:Shared/AI/SafetyFilter.swift) + the unreleased ja rows
RAIL_LIVE = ["kill yourself", "kys", "go die", "suicide", "杀了你", "殺了你", "去死", "自杀", "自殺",
             "shoot you", "shoot them", "stab you", "stab them"]
RAIL_JA_NEXT = ["殺してやる", "ころしてやる", "コロシテヤル", "殺すぞ", "ころすぞ", "コロスゾ",
                "ぶっ殺す", "ぶっころす", "ブッコロス", "自殺", "じさつ", "ジサツ"]
STRONG = {
 "hant": ["他媽的", "他媽", "老子", "特麼", "服了", "裝什麼裝", "煩死了", "傻逼", "操", "幹", "媽的", "滾", "神經病"],
 "hans": ["他妈的", "他妈", "老子", "特么", "服了", "装什么装", "烦死了", "傻逼", "操", "卧槽", "妈的", "滚", "神经病"],
 "ja": ["クソ", "うるせえ", "ふざけ", "マジで", "ばかやろう", "バカやろう", "ありえねえ", "いい加減にしろ"],
 "en": ["damn", "hell", "fuck", "shit", "bullshit", "asshole", "prick", "goddamn"],
}
PROMPT_LEAK = ["uru-see", "うるせえ、ふざけんな、ありえねえ", "(うるせえ", "（うるせえ", "強制", "FERAL DRAFT", "VENT DRAFT", "CALIBRATION", "GOOD:", "BAD:"]
NAMES = ["Kevin", "陳志明", "陈志明"]
ASCII_OK = {"LINE", "DJ", "NPC", "AM", "PM", "VP", "IG", "FB", "OK"}

def bucket(loc):
    l = loc.lower()
    if l.startswith("zh"):
        return "hant" if ("hant" in l or "_tw" in l or "-tw" in l) else "hans"
    return "ja" if l.startswith("ja") else "en"

rows = []
for x in r:
    t = x.get("text") or ""
    b = bucket(x["locale"])
    rec = {k: x[k] for k in ("i", "set", "locale", "topic", "intensity", "status", "latency_s", "model")}
    rec["chars"] = len(t)
    rec["words_en"] = len(t.split()) if b == "en" else None
    rec["sentences"] = len([s for s in re.split(r"[.!?。！？]+", t) if s.strip()])
    if b == "hant":
        simp = [c for c in t if HAN.match(c) and s2t.convert(c) != c and c not in TW_OK]
        rec["simplified_chars"] = "".join(simp)
        rec["simplified_evalset"] = sum(1 for c in t if c in EVAL_SET)
    if b == "hans":
        trad = [c for c in t if HAN.match(c) and t2s.convert(c) != c]
        rec["traditional_chars"] = "".join(trad)
    if b in ("hant", "hans", "ja"):
        eng = [w for w in re.findall(r"[A-Za-z][A-Za-z'\-]{2,}", t) if w not in ASCII_OK and not w.startswith(("VALIDATE", "ESCALATE", "DEESCALATE", "BRIDGE")) and w not in ("Sharp", "Savage")]
        rec["english_leak"] = eng
    if b == "en":
        rec["non_english"] = re.findall(r"[^\x00-\x7f—’‘“”…]", t)
    lower = t.lower()
    rec["strong_count"] = sum(lower.count(w.lower()) for w in STRONG[b])
    rec["hard_rail_live"] = [w for w in RAIL_LIVE if w in lower]
    rec["hard_rail_next_ja"] = [w for w in RAIL_JA_NEXT if w in t]
    rec["prompt_leak"] = [w for w in PROMPT_LEAK if w.lower() in lower]
    rec["name_echo"] = [n for n in NAMES if n in t and n in x["situation"]]
    rec["reasoning_trace"] = bool(re.search(r"<think>|We need to|Let me |Let's craft|First sentence", t))
    rec["ends_cleanly"] = bool(re.search(r"[.!?。！？」』”\"')）→…\*]\s*$", t))
    rows.append(rec)

ok = [x for x in r if x["status"] == 200 and x.get("text")]
lat = [x["latency_s"] for x in r if x["status"] == 200]
summary = {
  "n_calls": len(r),
  "http_200": sum(1 for x in r if x["status"] == 200),
  "non_200": [(x["i"], x["status"], x.get("error")) for x in r if x["status"] != 200],
  "latency_mean_s": round(statistics.mean(lat), 2),
  "latency_median_s": round(statistics.median(lat), 2),
  "latency_p90_s": round(sorted(lat)[int(0.9 * (len(lat) - 1))], 2),
  "latency_max_s": max(lat), "latency_min_s": min(lat),
  "models": sorted({x.get("model") for x in r}),
}
by = {}
for row in rows:
    key = row["locale"] if row["set"] != "roommate" else "roommate"
    by.setdefault(key, []).append(row)
summary["per_locale_latency_mean"] = {k: round(statistics.mean(v2["latency_s"] for v2 in v), 2) for k, v in by.items()}
json.dump({"summary": summary, "rows": rows}, open(OUT, "w"), ensure_ascii=False, indent=1)
print(json.dumps(summary, ensure_ascii=False, indent=1))
for row in rows:
    flags = {k: row[k] for k in ("simplified_chars", "traditional_chars", "english_leak", "non_english", "hard_rail_live", "hard_rail_next_ja", "prompt_leak", "name_echo") if row.get(k)}
    print(row["i"], row["locale"], row["intensity"], "chars", row["chars"], "words", row["words_en"], "sent", row["sentences"], "strong", row["strong_count"], "clean_end", row["ends_cleanly"], flags)
