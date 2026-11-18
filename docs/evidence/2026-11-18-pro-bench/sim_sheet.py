#!/usr/bin/env python3
"""Blind sheet for Q4's opponent-voice count (the A4 rubric).

    sim_sheet.py make  <dir> <run.jsonl> [<run.jsonl> ...]   → <dir>/sheet.md, <dir>/key.json
    sim_sheet.py score <dir>                                  → reads <dir>/labels.json

Every zh_TW and en turn from every run goes into one shuffled sheet under a
random id. The sheet shows the setup, the user's last line and the turn — not
the persona, the style, the run or the turn number. The labeller writes
labels.json ({id: "OPP"|"USER"|"AMB"|"NG"}) before opening key.json.

Rubric (A4): OPP = speaks as the other party, from their side; USER = argues
the user's side (restates the user's complaint as its own, takes the user's
role); AMB = confused / both. A turn that was not generated is NG and is
pre-filled.
"""
import json
import random
import secrets
import sys
from collections import defaultdict
from pathlib import Path


def load(p):
    return [json.loads(l) for l in Path(p).read_text().splitlines() if l.startswith("{") and '"header"' not in l]


def make(d, runs):
    d = Path(d)
    d.mkdir(parents=True, exist_ok=True)
    items, key = [], {}
    for run in runs:
        tag = Path(run).stem
        for r in load(run):
            if r["locale"] not in ("zh_TW", "en_US"):
                continue
            i = secrets.token_hex(3)
            key[i] = {"run": tag, "locale": r["locale"], "scenario": r["scenario"], "style": r["style"],
                      "turn": r["turn"], "result": r["result"]}
            items.append((i, r))
    random.SystemRandom().shuffle(items)
    lines = ["# Blind sheet — who is speaking? (OPP / USER / AMB)", ""]
    prefill = {}
    for i, r in items:
        if r["result"] != "line":
            prefill[i] = "NG"
            continue
        lines += [f"## {i}", f"- setup: {r['setup']}", f"- user just said: {r['user_last'] or '(opening turn)'}",
                  f"- **turn:** {r['text']}", ""]
    (d / "sheet.md").write_text("\n".join(lines))
    (d / "key.json").write_text(json.dumps(key, ensure_ascii=False, indent=1))
    (d / "labels.json").write_text(json.dumps(prefill, indent=1))
    print(f"{len(items)} turns, {len(prefill)} not generated (pre-filled NG); sheet {d / 'sheet.md'}")


def score(d):
    d = Path(d)
    key = json.loads((d / "key.json").read_text())
    labels = json.loads((d / "labels.json").read_text())
    missing = [i for i in key if i not in labels]
    if missing:
        print(f"{len(missing)} turns unlabelled")
    agg = defaultdict(lambda: defaultdict(int))
    cells = defaultdict(list)
    for i, k in key.items():
        lab = labels.get(i, "?")
        agg[k["run"]][(k["locale"], lab)] += 1
        agg[k["run"]][lab] += 1
        cells[(k["run"], k["locale"], k["scenario"], k["style"])].append((k["turn"], lab))
    for run, c in sorted(agg.items()):
        zh, en = c[("zh_TW", "OPP")], c[("en_US", "OPP")]
        print(f"{run}: OPP {zh + en}/36 (zh_TW {zh}, en {en}); USER {c['USER']}, AMB {c['AMB']}, NG {c['NG']}")
    for (run, loc, sc, st), v in sorted(cells.items()):
        print(f"   {run} {loc} {sc:5s} {st:16s} " + "/".join(l for _, l in sorted(v)))


if __name__ == "__main__":
    if sys.argv[1] == "make":
        make(sys.argv[2], sys.argv[3:])
    else:
        score(sys.argv[2])
