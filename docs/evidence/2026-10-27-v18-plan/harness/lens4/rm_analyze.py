#!/usr/bin/env python3
# Port of Shared/AI/EchoesParser.swift (scene .roommateGroup, STRICT) + script/register scoring.
import json, re, sys
from opencc import OpenCC
s2t = OpenCC("s2t")
TW_OK = set("台里后干只面着周游系才群托志表了布借")
HAN = re.compile(r"[一-鿿]")
ROLES = {"VALIDATE", "ESCALATE", "DEESCALATE", "BRIDGE"}
def parse(raw):
    msgs = []
    for line in [l.strip() for l in raw.splitlines() if l.strip()]:
        m = None
        if line.startswith("[") and "]" in line:
            hdr, body = line[1:line.index("]")], line[line.index("]")+1:].strip()
            core = hdr.split(":", 1)[0]
            parts = core.split("/", 1)
            if body and len(parts) == 2 and parts[0].upper() in ROLES and parts[1].upper() in ("A","B","C") and len(body) <= 80:
                m = (parts[0].upper(), "ABC".index(parts[1].upper()), body)
            elif True:
                return None, f"bad tagged line: {line[:50]}"
        if m: msgs.append(m)
    if not msgs or msgs[-1][0] != "BRIDGE": return None, "last not BRIDGE"
    if not any(r=="VALIDATE" for r,_,_ in msgs) or not any(r=="DEESCALATE" for r,_,_ in msgs): return None, "missing validate/deescalate"
    if not (8 <= len(msgs) <= 10): return None, f"count {len(msgs)}"
    if sum(1 for r,_,_ in msgs if r=="BRIDGE") != 1: return None, "bridge count"
    for i in range(3):
        if sum(1 for _,x,_ in msgs if x==i) < 2: return None, f"voice {'ABC'[i]} <2"
    return msgs, "ok"
# SafetyFilter.ventHardRail subset (live terms, zh) — UNVERIFIED completeness; screen only.
RAIL = ["殺了你","杀了你","去死","自殺","自杀","了結自己","了结自己"]
MAINLAND = ["老子","傻逼","特麼","服了","裝什麼裝","臥槽","尼瑪","你妹","牛逼","絕了","視頻","信息","質量","網吧","微信","朋友圈","微博",
            "舍友","懟","陰陽","狗東西","背鍋","雞湯","群裡","群里","整挺好","賊","咋","啥","倆","甩回去","段子","吐槽"]
TAIWAN = ["靠北","白目","機車","很盤","傻眼","很扯","北七","是怎樣","夠了喔","三小","欸","啦","齁","群組","已讀不回","慣老闆","網咖","限動","爛人","幹"]
rows = json.load(open(sys.argv[1]))
tot = {"n":0,"parse_ok":0,"simplified_any":0,"mainland_any":0,"taiwan_any":0,"bridge_english":0,"rail":0}
for r in rows:
    t = r.get("text") or ""
    tot["n"] += 1
    msgs, why = parse(t)
    simp = "".join(c for c in t if HAN.match(c) and s2t.convert(c) != c and c not in TW_OK)
    ml = [w for w in MAINLAND if w in t]; tw = [w for w in TAIWAN if w in t]
    bridge = [l for l in t.splitlines() if l.strip().startswith("[BRIDGE")]
    be = bool(bridge and re.search(r"\b(Sharp|Savage)\b", bridge[-1]))
    rail = [w for w in RAIL if w in t]
    tot["parse_ok"] += msgs is not None; tot["simplified_any"] += bool(simp); tot["mainland_any"] += bool(ml)
    tot["taiwan_any"] += bool(tw); tot["bridge_english"] += be; tot["rail"] += bool(rail)
    r["auto"] = {"parse": why, "lines": len([l for l in t.splitlines() if l.strip()]), "simplified_chars": simp,
                 "mainland_markers": ml, "taiwan_markers": tw, "bridge_names_english_mode": be, "rail_hits": rail}
    print(f"--- {r['topic']}/{r['intensity']} {r['locale']} {r['status']} {r['latency_s']}s model={r['model']} | parse={why} simp='{simp}' mainland={ml} taiwan={tw} bridgeEN={be} rail={rail}")
    print(t)
print("\nSUMMARY", json.dumps(tot, ensure_ascii=False))
json.dump(rows, open(sys.argv[1].replace(".json", "_scored.json"), "w"), ensure_ascii=False, indent=1)
