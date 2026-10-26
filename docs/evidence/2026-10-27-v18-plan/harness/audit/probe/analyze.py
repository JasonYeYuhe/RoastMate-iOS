import json, sys, re, collections, difflib, itertools
rows = [json.loads(l) for l in open(sys.argv[1])]
CJK = re.compile(r"[぀-ヿ一-鿿]")
def opener(v, loc):
    v = v.strip("「」\"' ")
    if loc.startswith("en"):
        return " ".join(re.findall(r"[A-Za-z'’]+|[^\sA-Za-z]", v)[:2]).lower()
    return v[:3]
out = []
def P(*a): out.append(" ".join(str(x) for x in a))
for part in ["savage", "sharp_pro"]:
    P(f"\n### {part}")
    sub = [r for r in rows if r["part"] == part]
    by = collections.defaultdict(list)
    for r in sub: by[(r["locale"], r["style"])].append(r)
    tot = collections.Counter()
    for (loc, st), rs in sorted(by.items()):
        n = len(rs); thr = sum(r["status"] == "throw" for r in rs)
        model = [r for r in rs if r["appShows"] == "model"]
        kept = [v for r in model for v in r["keptVariants"]]
        full3 = sum(len(r["keptVariants"]) == 3 for r in model)
        neardup = 0
        for r in model:
            vs = r["keptVariants"]
            if len(vs) >= 2 and max(difflib.SequenceMatcher(None, a, b).ratio() for a, b in itertools.combinations(vs, 2)) >= 0.6: neardup += 1
        ops = collections.Counter(opener(v, loc) for v in kept)
        top, topn = (ops.most_common(1)[0] if ops else ("", 0))
        mixed = sum(1 for v in kept if loc.startswith("en") and CJK.search(v))
        latin = sum(1 for v in kept if not loc.startswith("en") and re.search(r"[A-Za-z]{4,}", v))
        idhave = sum(1 for v in kept if re.match(r"i'?d(’d)?( have|'ve|’ve) said", v.lower()))
        refusal_txt = sum(r["textRefusals"] for r in model)
        simp = "".join(r["simplifiedChars"] for r in model)
        P(f"{loc:6} {st:28} calls={n} refused->curated={thr} model={len(model)} full3={full3} versions={len(kept)} neardup_calls={neardup} top_opener={top!r}x{topn}/{len(kept)} cjk_in_en={mixed} latin_in_cjk={latin} id_have_said={idhave} text_refusals={refusal_txt} simplified={simp!r}")
        tot["calls"] += n; tot["refused"] += thr; tot["model"] += len(model); tot["versions"] += len(kept); tot["neardup"] += neardup
    P("TOTAL", dict(tot))
    for loc in sorted({r["locale"] for r in sub}):
        rs = [r for r in sub if r["locale"] == loc]
        P(f"  {loc}: refused {sum(r['status']=='throw' for r in rs)}/{len(rs)}; median latency (model) {sorted([r['latencyMs'] for r in rs if r['appShows']=='model'] or [0])[len([r for r in rs if r['appShows']=='model'])//2]} ms")
P("\n### argument")
arg = [r for r in rows if r["part"] == "argument"]
for loc in ["zh_TW", "en_US"]:
    rs = [r for r in arg if r["locale"] == loc]
    P(f"{loc}: turns={len(rs)} refused->curated={sum(r['status']=='throw' for r in rs)} multi_numbered_raw={sum(len(r['parsedVariants'])>1 for r in rs)} text_refusals={sum(r['textRefusals'] for r in rs)}")
    for st in ["cold_violence", "savage_no_filter"]:
        s2 = [r for r in rs if r["style"] == st]
        P(f"   {st}: refused {sum(r['status']=='throw' for r in s2)}/{len(s2)}")
print("\n".join(out))
