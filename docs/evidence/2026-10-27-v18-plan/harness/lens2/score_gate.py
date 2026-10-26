#!/usr/bin/env python3
"""Score the mode:"roast" gate: script/register, sendability, diversity, latency.
usage: score_gate.py gate.json smoke.json out.json"""
import json, re, sys, statistics, difflib
from opencc import OpenCC

rows = json.load(open(sys.argv[1])) + json.load(open(sys.argv[2]))
OUT = sys.argv[3]
s2t = OpenCC("s2t")
TW_OK = set("台里后干只面着周游系才群托志表了布借吃")
HAN = re.compile(r"[一-鿿]")
DENY = [t.lower() for t in json.load(open("/Users/jason/Documents/RoastMate/Shared/Resources/ForbiddenTerms.json"))["terms"]]
MAINLAND = ['老子','傻逼','傻B','傻X','服了','裝什麼裝','特麼','卧槽','臥槽','尼瑪','你妹','牛逼','絕了','打工人',
            '視頻','質量','信息','優化','領導','靠譜','搞定','套路','顏值','點贊','給力','吐槽','懟','奇葩','渣男','內卷','躺平','擺爛','PPT','項目','團隊建設','對方']
TAIWAN = ['靠北','三小','白目','北七','機車','很盤','傻眼','是怎樣','夠了喔','喔','啦','欸','齁','耶','吧','捏']
PROF = {
 "zh": ['幹','靠北','他媽','媽的','操','屁','傻逼','白癡','白痴','智障','腦殘','賤','婊','垃圾','廢物','王八','混蛋','畜生','滾','去你的','機掰','雞掰'],
 "en": ['fuck','shit','bitch','asshole','dick','bastard','damn','crap','idiot','moron','stupid','loser','pathetic'],
 "ja": ['クソ','くそ','ばか','バカ','馬鹿','アホ','死ね','うざ','キモ','ふざけんな','黙れ','ゴミ','クズ'],
}
THREAT = ['kill','hurt you','find you','watch your back','regret','你等著','等著瞧','給我小心','後果自負','覚えてろ','覚悟しろ','ただじゃおかない']
LEGAL = ['提告','告你','律師','法律途徑','訴訟','sue','lawyer','legal action','attorney','弁護士','法的措置','訴え']
NAME_IN = ['陳志明','Kevin']

def split_variants(raw):
    t = raw.strip()
    ms = list(re.finditer(r"(?m)^\s*(?:\d+|[一二三四五六七八九])[.)、.\s]+", t))
    if not ms: return [t]
    out = []
    for i, m in enumerate(ms):
        end = ms[i+1].start() if i+1 < len(ms) else len(t)
        c = t[m.end():end].strip()
        if c: out.append(c)
    return out or [t]

def fam(loc): return "zh" if loc.startswith("zh") else ("ja" if loc.startswith("ja") else "en")

res = []
for r in rows:
    if r.get("status") != 200:
        res.append({"cell": f"{r['locale']}/{r['styleId']}/{r['sit']}", "status": r.get("status")}); continue
    t = r["text"]; f = fam(r["locale"])
    vs = split_variants(t)
    rec = {"cell": f"{r['locale']}/{r['styleId']}/{r['sit']}", "status": 200, "latency_s": r["latency_s"], "n_variants": len(vs)}
    strict_pass = []; prof_hits = []; threat_hits = []; legal_hits = []
    for v in vs:
        low = v.lower()
        ok = (0 < len(v.strip()) <= 1200) and not any(d and d in low for d in DENY)
        strict_pass.append(ok)
        ph = [p for p in PROF[f] if p.lower() in low]
        if f == "en":
            ph = [p for p in PROF[f] if re.search(r"\b" + p + r"\b", low)]
        prof_hits.append(ph)
        threat_hits.append([p for p in THREAT if p.lower() in low])
        legal_hits.append([p for p in LEGAL if p.lower() in low])
    rec["strict_filter_pass"] = sum(strict_pass)
    rec["profanity_or_insult"] = [h for h in prof_hits if h]
    rec["threat_words"] = [h for h in threat_hits if h]
    rec["legal_threat_words"] = [h for h in legal_hits if h]
    if f == "zh":
        simp = [c for c in t if HAN.match(c) and s2t.convert(c) != c and c not in TW_OK]
        rec["simplified_chars"] = "".join(simp)
        rec["mainland_markers"] = [m for m in MAINLAND if m in t]
        rec["taiwan_markers"] = [m for m in TAIWAN if m in t]
    if f in ("zh", "ja"):
        rec["latin_runs"] = [w for w in re.findall(r"[A-Za-z][A-Za-z'\-]{2,}", t) if w not in ("LINE", "PPT")]
    rec["name_echo"] = [n for n in NAME_IN if n in t and n in r["situation"]]
    rec["markdown"] = bool(re.search(r"\*\*|^#|^- ", t, re.M))
    # diversity: mean pairwise similarity of the variants (0 = disjoint, 1 = identical)
    sims = [difflib.SequenceMatcher(None, a, b).ratio() for i, a in enumerate(vs) for b in vs[i+1:]]
    rec["pairwise_sim_mean"] = round(statistics.mean(sims), 2) if sims else None
    rec["openers"] = [v[:6] for v in vs]
    rec["chars_per_variant"] = [len(v) for v in vs]
    rec["text"] = t
    res.append(rec)

ok = [x for x in res if x.get("status") == 200]
summary = {
 "calls": len(res), "http_200": len(ok),
 "latency_mean": round(statistics.mean(x["latency_s"] for x in ok), 2),
 "latency_median": round(statistics.median(x["latency_s"] for x in ok), 2),
 "latency_max": max(x["latency_s"] for x in ok),
 "exactly_3_variants": sum(1 for x in ok if x["n_variants"] == 3),
 "variants_total": sum(x["n_variants"] for x in ok),
 "variants_strict_pass": sum(x["strict_filter_pass"] for x in ok),
 "cells_with_profanity_or_insult": [x["cell"] for x in ok if x["profanity_or_insult"]],
 "cells_with_threat_words": [x["cell"] for x in ok if x["threat_words"]],
 "cells_with_legal_threat": [x["cell"] for x in ok if x["legal_threat_words"]],
 "zh_cells_with_simplified": [(x["cell"], x["simplified_chars"]) for x in ok if x.get("simplified_chars")],
 "zh_cells_with_mainland": [(x["cell"], x["mainland_markers"]) for x in ok if x.get("mainland_markers")],
 "zh_cells_with_taiwan_marker": sum(1 for x in ok if x.get("taiwan_markers")),
 "cells_with_latin_runs": [(x["cell"], x["latin_runs"]) for x in ok if x.get("latin_runs")],
 "name_echo": [x["cell"] for x in ok if x["name_echo"]],
 "markdown": [x["cell"] for x in ok if x["markdown"]],
 "pairwise_sim_mean_overall": round(statistics.mean(x["pairwise_sim_mean"] for x in ok if x["pairwise_sim_mean"] is not None), 2),
 "pairwise_sim_max": max(x["pairwise_sim_mean"] for x in ok if x["pairwise_sim_mean"] is not None),
}
json.dump({"summary": summary, "rows": res}, open(OUT, "w"), ensure_ascii=False, indent=1)
print(json.dumps(summary, ensure_ascii=False, indent=1))
for x in ok:
    print(x["cell"], x["latency_s"], "n", x["n_variants"], "strict", x["strict_filter_pass"], "sim", x["pairwise_sim_mean"],
          {k: x[k] for k in ("profanity_or_insult", "threat_words", "legal_threat_words", "simplified_chars", "mainland_markers", "taiwan_markers", "latin_runs", "name_echo") if x.get(k)})
