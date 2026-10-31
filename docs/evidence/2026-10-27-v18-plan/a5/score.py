"""Scores an a5/main.swift run against the plan's §2.2 A5 targets.
Usage: python3 score.py run.jsonl"""
import json, re, sys, subprocess
from collections import Counter, defaultdict
rows = [json.loads(l) for l in open(sys.argv[1])]
cjk = re.compile(r'[぀-ヿ一-鿿]')
def simplified_only(text):
    # same round-trip rule as StyleScriptTests.simplifiedOnly, via ICU in a Swift one-liner
    han = ''.join(sorted({c for c in text if '一' <= c <= '鿿'}))
    if not han: return ''
    swift = 'import Foundation; let s = CommandLine.arguments[1]; print(String(s.filter { c in let o = String(c); guard let h = o.applyingTransform(StringTransform("Hans-Hant"), reverse: false), h != o, let b = h.applyingTransform(StringTransform("Hant-Hans"), reverse: false) else { return false }; return b == o }))'
    return subprocess.run(['swift', '-e', swift, han], capture_output=True, text=True).stdout.strip()
def bigrams(s):
    s = [c for c in s.lower() if not c.isspace() and c.isalnum()]
    return {''.join(s[i:i+2]) for i in range(len(s)-1)} or set(s)
def near_dup(texts):
    g = [bigrams(t) for t in texts]
    return any(len(g[i] & g[j]) / max(1, len(g[i] | g[j])) >= 0.6 for j in range(len(g)) for i in range(j))
said = re.compile(r"^(i'?d have said|i would have said|i'?d'?ve said|我會說|我会说|我當時|我当时)", re.I)
print("calls", len(rows), Counter(r['provenance'] for r in rows))
by = defaultdict(list)
for r in rows: by[(r['locale'], r['style'], r['intensity'])].append(r['provenance'])
print("curated per locale x style x intensity:")
for k, v in sorted(by.items()): print("  ", k, f"{v.count('curated')}/{len(v)}")
model = [r for r in rows if r['provenance'] == 'model']
en_cjk = sum(1 for r in model if r['locale'] == 'en_US' for t in r['texts'] if cjk.search(t))
print("CJK in en outputs:", en_cjk, "of", sum(len(r['texts']) for r in model if r['locale'] == 'en_US'))
hant = ''.join(t for r in model if r['locale'] == 'zh_TW' for t in r['texts'])
print("Simplified-only chars in zh_TW output:", repr(simplified_only(hant)))
print("'I'd have said' openers:", sum(1 for r in model for t in r['texts'] if said.search(t.strip())))
sharp = [t for r in model if r['part'] == 'sharp_pro' for t in r['texts'][:1]]
openers = Counter(t.strip()[:4].lower() for t in sharp)
print("Sharp-Pro first versions:", len(sharp), "distinct 4-char openers:", len(openers), "top:", openers.most_common(3))
multi = [r for r in model if len(r['texts']) >= 2]
print("near-duplicate calls:", sum(near_dup(r['texts']) for r in multi), "of", len(multi))
print("versions per model call:", Counter(len(r['texts']) for r in model))
ms = sorted(r['ms'] for r in rows); print("latency median", ms[len(ms)//2], "max", ms[-1])
