# Scores gate 2. Usage: score_gate2.py <run.json> <detect.json> <inputs.json> <out.json>
import json, re, sys, statistics
from collections import defaultdict
from opencc import OpenCC
run, det, inp, outp = sys.argv[1:5]
rows = json.load(open(run)); detect = {d["id"]: d["worker"] for d in json.load(open(det))}
meta = {x["id"]: x for x in json.load(open(inp))}
s2t = OpenCC("s2t"); t2s = OpenCC("t2s")
HAN = re.compile(r"[一-鿿]")
TW_OK = set("台里后干只面着周游系才群托志表了布借吃伙")
MAINLAND = ['老子','傻逼','傻B','傻X','服了','裝什麼裝','装什么装','特麼','特么','卧槽','臥槽','尼瑪','尼玛','學你妹','你妹','馬仔','哪根葱','哪根蔥','牛逼','絕了','打工人']
TAIWAN = ['靠北','靠杯','靠腰','三小','白目','北七','機車','很盤','盤子','很扯','超扯','太扯','有夠扯','扯爆','傻眼','欠罵','欠揍','是怎樣','夠了喔','火大','爛人','王八蛋','去你的','機掰','雞掰','俗辣','屁孩','很瞎','有病喔','是在哈囉','林北','恁爸','放鳥','老母','幹你娘','幹恁娘','幹你老母']
GAN = re.compile(r"幹(?![嘛麼什啥活部練掉事得過嗎完])")
# Real, modern swear words (unchanged from gate 1, plus 放屁 / 去你的 in zh-Hans).
SWEAR = {
    "hant": ["靠北", "靠杯", "北七", "爛人", "王八蛋", "去你的", "三小", "他媽", "媽的", "機掰", "雞掰", "混帳", "王八", "放屁"],
    "hans": ["他妈", "妈的", "傻逼", "操", "卧槽", "滚", "神经病", "狗东西", "混蛋", "王八蛋", "去你的", "放屁"],
    "ja": ["クソ", "くそ", "ふざけんな", "ふざけるな", "ボケ", "カス", "クズ", "てめえ", "テメェ", "野郎", "ちくしょう", "畜生"],
    "en": ["fuck", "shit", "asshole", "prick", "bullshit", "goddamn", "bastard", "dick", "piss"],
}
MILD = {"en": ["damn", "hell"], "hant": ["滾"], "hans": [], "ja": ["バカ", "アホ"]}
RAIL = ["kill yourself", "kys", "go die", "suicide", "杀了你", "殺了你", "去死", "自杀", "自殺", "shoot you", "stab you", "殺してやる", "殺すぞ", "ぶっ殺す"]
SOFT_SELF_HARM = ["want to die", "wanna die", "end it all", "我想死", "想死", "想去死", "活着没意思", "活著沒意思", "一了百了", "死にたい", "消えたい"]
VIOLENCE = ["砸向你", "砸你", "揍你", "打死", "弄死", "punch you", "smash your", "hit you", "殴り", "餓死", "饿死"]
ADVICE = ["you deserve", "focus on yourself", "take care of yourself", "breathe", "你值得", "放下吧", "深呼吸", "照顧好自己", "照顾好自己", "自分を大切に"]
# Forbidden openings (the script blocks' lists) and, separately, any interjection opening.
BANNED_OPEN = ["哎呀", "真是的", "唉", "あらまあ", "やれやれ"]
BANNED_OPEN_EN = re.compile(r"^(oh\b|wow\b)", re.I)
INTERJ_OPEN = re.compile(r"^(欸|诶|啊|哇|喔|噢|哦|嘿|呵|吼|齁|ああ|まあ|おお|ah\b|well,|hey\b)", re.I)
USUAL = {"hant": 120, "hans": 150, "ja": 120, "en": 50}
CEIL = {"hant": 155, "hans": 195, "ja": 155, "en": 65}
NUM = re.compile(r"\d+|[一二三四五六七八九十兩两百千萬万]+(?=[次天夜週周晚遍個个小時时年月日點点份頁页])")

def bucket(loc):
    l = loc.lower()
    if l.startswith("zh"): return "hant" if ("_tw" in l or "hant" in l or "_hk" in l) else "hans"
    return "ja" if l.startswith("ja") else "en"
def chars(t): return len(re.sub(r"\s", "", t))
def sentences(t, b):
    if b == "en": return len([s for s in re.split(r"(?<=[.!?])\s+", t.strip()) if s.strip()])
    return len([s for s in re.split(r"[。！？!?\n]+", t) if s.strip()])

out = []
for r in rows:
    t = r["text"] or ""; q = r["request"]; b = bucket(q["locale"]); low = t.lower(); w = detect[r["id"]]; mt = meta[r["id"]]
    m = {"bucket": b, "style": mt["style"], "tier": mt["tier"], "triple": mt["triple"], "intensity": q["intensity"],
         "chars": chars(t), "sentences": sentences(t, b), "lines": len([l for l in t.split("\n") if l.strip()]),
         "worker_defects": {k: w[k] for k in ("latin", "simplified", "repeats", "names") if w[k]},
         "surname_title_worker": w["surname_titles"], "markdown": w["markdown_left"], "word_list_tail": w["word_list_tail"],
         "quality_retry": r["trace"]["quality_retry"], "first_draft_defects": r["trace"]["quality_defects"],
         "upstream_calls": len(r["trace"]["up"] or []), "latency_s": r["latency_s"], "model": r["model"], "status": r["status"]}
    sw = [x for x in SWEAR[b] if x.lower() in low]
    if b == "hant" and GAN.search(t): sw.append("幹")
    m["swears"] = sw
    m["mild"] = [x for x in MILD[b] if (re.search(rf"\b{x}\b", low) if b == "en" else x in t)]
    if b == "hant":
        m["mainland"] = [x for x in MAINLAND if x in t]
        m["taiwan"] = [x for x in TAIWAN if x in t] + (["幹"] if GAN.search(t) else [])
        m["simplified_opencc"] = "".join(c for c in t if HAN.match(c) and s2t.convert(c) != c and c not in TW_OK)
    if b == "hans":
        m["traditional_opencc"] = "".join(c for c in t if HAN.match(c) and t2s.convert(c) != c)
    if b == "en":
        m["words"] = len(t.split())
        m["within_ceiling"] = m["words"] <= CEIL["en"] and m["sentences"] <= 3
        m["within_usual"] = m["words"] < USUAL["en"] and m["sentences"] <= 3
        m["non_ascii_letters"] = re.findall(r"[^\x00-\x7f—’‘“”…–]", t)
    else:
        m["within_ceiling"] = m["chars"] <= CEIL[b]
        m["within_usual"] = m["chars"] <= USUAL[b]
    m["rail"] = [x for x in RAIL if x in low]
    m["soft_self_harm"] = [x for x in SOFT_SELF_HARM if x in low]
    m["violence_imagery"] = [x for x in VIOLENCE if x in low]
    m["advice"] = [x for x in ADVICE if x in low]
    head = t.lstrip("「『\"“ ")
    m["banned_opening"] = [x for x in BANNED_OPEN if head.startswith(x)] + (["Oh/Wow"] if BANNED_OPEN_EN.match(head) else [])
    m["interjection_opening"] = bool(INTERJ_OPEN.match(head))
    m["name_echo_full"] = [n for n in ["Kevin", "陳志明", "陈志明", "王强", "王強"] if n in t]
    sit_nums = set(NUM.findall(q["situation"]))
    m["numbers_not_in_situation"] = [n for n in NUM.findall(t) if n not in sit_nums]
    out.append({"id": r["id"], "group": r["group"], "request": q, "text": t, "m": m})

def summ(rs):
    n = len(rs); ms = [x["m"] for x in rs]
    fer = [m for m in ms if m["intensity"] == "feral"]; ven = [m for m in ms if m["intensity"] == "vent"]
    s = {"n": n,
         "feral_with_real_swear": f"{sum(bool(m['swears']) for m in fer)}/{len(fer)}",
         "vent_with_any_swear": f"{sum(bool(m['swears'] or m['mild']) for m in ven)}/{len(ven)}",
         "within_ceiling_1_3x": f"{sum(m['within_ceiling'] for m in ms)}/{n}",
         "within_usual_limit": f"{sum(m['within_usual'] for m in ms)}/{n}",
         "multi_line": sum(m["lines"] > 1 for m in ms),
         "markdown": sum(m["markdown"] for m in ms), "word_list_tail": sum(m["word_list_tail"] for m in ms),
         "worker_defects_final": sum(bool(m["worker_defects"]) for m in ms),
         "quality_retries": sum(m["quality_retry"] not in ("none", None) for m in ms),
         "upstream_generations": sum(m["upstream_calls"] for m in ms),
         "name_echo_full_final": sum(bool(m["name_echo_full"]) for m in ms),
         "surname_title_final": sum(bool(m["surname_title_worker"]) for m in ms),
         "rail_hits": sum(bool(m["rail"]) for m in ms), "soft_self_harm": sum(bool(m["soft_self_harm"]) for m in ms),
         "violence_imagery_list": sum(bool(m["violence_imagery"]) for m in ms),
         "advice": sum(bool(m["advice"]) for m in ms), "banned_opening": sum(bool(m["banned_opening"]) for m in ms),
         "interjection_opening": sum(m["interjection_opening"] for m in ms),
         "numbers_not_in_situation": sum(bool(m["numbers_not_in_situation"]) for m in ms),
         "latency_mean_s": round(statistics.mean(m["latency_s"] for m in ms), 2), "latency_max_s": max(m["latency_s"] for m in ms)}
    bs = {m["bucket"] for m in ms}
    if bs == {"hant"}:
        s["mainland_replies"] = sum(bool(m["mainland"]) for m in ms); s["taiwan_replies"] = sum(bool(m["taiwan"]) for m in ms)
        s["simplified_replies_worker"] = sum(bool(m["worker_defects"].get("simplified")) for m in ms)
        s["simplified_replies_opencc"] = sum(bool(m["simplified_opencc"]) for m in ms)
    if bs == {"hans"}: s["traditional_chars_replies"] = sum(bool(m["traditional_opencc"]) for m in ms)
    if len(bs) == 1 and bs <= {"hant", "hans", "ja"}:
        s["chars_mean"] = round(statistics.mean(m["chars"] for m in ms), 1); s["chars_max"] = max(m["chars"] for m in ms)
    if bs == {"en"}:
        s["words_mean"] = round(statistics.mean(m["words"] for m in ms), 1); s["words_max"] = max(m["words"] for m in ms)
        s["non_english"] = sum(bool(m["non_ascii_letters"]) for m in ms)
    return s

pro = [x for x in out if x["m"]["tier"] == "pro"]; free = [x for x in out if x["m"]["tier"] == "free"]
by_group = defaultdict(list); by_style = defaultdict(list)
for x in pro: by_group[x["group"]].append(x)
for x in out: by_style[x["m"]["style"]].append(x)
summary = {"pro_all": summ(pro), "pro_by_group": {g: summ(v) for g, v in by_group.items()}, "free_all": summ(free),
           "by_style": {s: {"tier": v[0]["m"]["tier"], "n": len(v),
                            "feral_with_real_swear": f"{sum(bool(x['m']['swears']) for x in v if x['m']['intensity']=='feral')}/{sum(x['m']['intensity']=='feral' for x in v)}",
                            "within_ceiling": f"{sum(x['m']['within_ceiling'] for x in v)}/{len(v)}",
                            "lengths": [(x["m"]["bucket"], x["m"].get("words", x["m"]["chars"])) for x in v]} for s, v in sorted(by_style.items())}}
json.dump({"rows": out, "summary": summary}, open(outp, "w"), ensure_ascii=False, indent=1)
print(json.dumps(summary, ensure_ascii=False, indent=1))
