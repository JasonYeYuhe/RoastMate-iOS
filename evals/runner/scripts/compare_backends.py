#!/usr/bin/env python3
"""Three-way backend comparison for a single RoastMate prompt.

Mirrors `Shared/AI/PromptBuilder.swift` so the system + user prompts
sent to DeepSeek / xAI Grok / Groq Qwen3 are byte-equivalent to what
RoastMate would have produced on-device (modulo Apple FM idiosyncrasies).

Usage:
    1. Drop your keys in /tmp/api_keys.env (KEY=VALUE per line):
         DEEPSEEK_API_KEY=sk-...
         XAI_API_KEY=xai-...
         GROQ_API_KEY=gsk_...
    2. python3 evals/runner/scripts/compare_backends.py
    3. The script wipes /tmp/api_keys.env after reading.

The default scenario is "我的舍友半夜打游戏非常吵" / zh-Hans /
passive_aggressive / sharp / roast — i.e. closest to the
`roommate_mess` scenario the existing Scenarios.json ships.
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

KEYS_PATH = "/tmp/api_keys.env"

# ---- Configurable test case --------------------------------------------------
SITUATION = "我的舍友半夜打游戏非常吵"
LOCALE = "zh-Hans"              # used only for the language hints
STYLE_ID = "passive_aggressive"
STYLE_PREAMBLE = (
    "You write replies that sound calm and agreeable on the surface but "
    "contain a clear undertone of dissatisfaction. Subtle, never explicit. "
    "The goal is for the reader to feel mildly uncomfortable without being "
    "able to point to a specific insult."
)
MODE = "roast"
INTENSITY = "sharp"
N_VARIANTS = 3
SAFE_MODE = True


# ---- PromptBuilder mirror (Shared/AI/PromptBuilder.swift) --------------------
UNIVERSAL_SAFETY_PREAMBLE = """SAFETY RULES (always apply, regardless of intensity / mode):
- Never target a specific real person by full name. If a name appears in the user's situation, replace it with a generic role ("the manager", "the roommate").
- Never produce slurs, racist, sexist, ableist, homophobic, transphobic, or hateful content.
- Never produce threats, calls to violence, doxxing, sexual content, or self-harm content.
- Never attack protected attributes (race, religion, gender, sexuality, disability, appearance, body, family).
- If the user's situation suggests self-harm, violence, or stalking, decline and respond with empathy and a suggestion to seek support.
- Stay under 120 words per variant.
- For sendable replies, be sharp rather than cruel. For private drafts, raw anger is allowed, but keep the attack on the behavior or choice — never on identity."""


def language_hint(locale: str) -> str:
    if locale.startswith("zh"):
        if "Hant" in locale:
            return "Reply in 繁體中文"
        return "Reply in 简体中文"
    if locale.startswith("ja"):
        return "Reply in 日本語"
    return "Reply in English"


def language_enforcement(locale: str) -> str:
    if locale.startswith("zh"):
        if "Hant" in locale:
            return "OUTPUT LANGUAGE (REQUIRED): 必須以「繁體中文」回覆。即使上面的範例是英文,你的回覆也必須完全使用繁體中文。"
        return "OUTPUT LANGUAGE (REQUIRED): 必须用「简体中文」回复。即使上面的示例是英文,你的回复也必须完全使用简体中文。"
    if locale.startswith("ja"):
        return "OUTPUT LANGUAGE (REQUIRED): 必ず日本語で回答してください。上の例が英語であっても、回答は完全に日本語で書いてください。"
    return "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English."


def user_language_reminder(locale: str) -> str:
    if locale.startswith("zh"):
        return "請以繁體中文回覆。" if "Hant" in locale else "请用简体中文回复。"
    if locale.startswith("ja"):
        return "日本語で回答してください。"
    return "Reply in English."


def mode_guidance(mode: str, intensity: str) -> str:
    base = {
        "roast": "The user describes a frustrating situation. Generate witty self-expression — what the user *wishes* they had said, in the chosen style.",
        "reply": "The user is pasting a message they received and wants help replying. Generate replies *addressed to the sender* in the chosen style.",
        "translate": "The user is giving a blunt or raw phrase. Translate / rewrite it into the chosen register — keep the meaning, change only the tone.",
        "argument": "Single-turn argument practice. The user describes the situation and who they're arguing with. Produce the response *the user* should give back, in the chosen style. Treat it as rehearsal, not an attack.",
        "social": "The user is pasting a social media post (tweet, Xiaohongshu, Reddit). Generate witty reactions or comeback replies, in the chosen style, suitable to post as a reply.",
    }[mode]
    if intensity in ("vent", "feral"):
        base += " IMPORTANT: This run is a PRIVATE DRAFT — the output will be marked private and NOT addressed to anyone yet. Keep it raw, immediate, and emotional; imagined direct address is allowed inside the user's head if it makes the anger sharper. A separate rewrite step will turn this into a sendable version later."
    return base


def intensity_guidance(intensity: str, safe_mode: bool) -> str:
    if intensity == "calm":
        return "Composed, professional, almost generous in framing. The reply *de-escalates* without conceding. Think emotionally intelligent senior manager."
    if intensity == "sharp":
        return "Pointed but polished. Names the behavior. No melodrama, no profanity. The kind of line that ends an exchange."
    if intensity == "savage":
        extra = (" Safe Mode is ON — keep edges in language but still no slurs, no profanity, no attacks on identity."
                 if safe_mode else
                 " Edges may bite. Still no slurs, no profanity, no attacks on identity.")
        return "Maximum precision sharpness. Names the specific behavior or bad-faith move and refuses to soften." + extra
    return ""  # vent/feral handled separately, omitted here


def build_system_prompt() -> str:
    lines = [
        "You are RoastMate, an AI that helps users express frustration and emotion through witty, safe writing.",
        f"Style: {STYLE_ID} — {STYLE_PREAMBLE}",
        f"Language: {language_hint(LOCALE)}.",
        f"Mode: {MODE} — {mode_guidance(MODE, INTENSITY)}",
        f"Intensity: {INTENSITY} — {intensity_guidance(INTENSITY, SAFE_MODE)}",
        UNIVERSAL_SAFETY_PREAMBLE,
        # passive_aggressive has only an English example — PromptBuilder
        # filters that out for zh because it lacks Han characters. So no
        # EXAMPLES block for this combo.
        language_enforcement(LOCALE),
    ]
    return "\n".join(lines)


def build_user_prompt() -> str:
    n = max(1, min(N_VARIANTS, 5))
    return "\n".join([
        f"Situation: {SITUATION}",
        "",
        f"Generate {n} distinct {STYLE_ID} responses I could have said. Each should stand alone.",
        'Number each response on its own line beginning with "1." "2." "3." etc.',
        "Keep each response under 120 words. Do not add commentary outside the numbered list.",
        user_language_reminder(LOCALE),
    ])


# ---- Backends ---------------------------------------------------------------
def call_openai_compatible(base_url: str, api_key: str, model: str,
                           system: str, user: str, timeout: float = 60.0) -> dict:
    """One-shot, max_tokens=512, temperature=0.7."""
    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.7,
        "max_tokens": 512,
        "stream": False,
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
        elapsed_ms = int((time.time() - t0) * 1000)
        parsed = json.loads(body)
        text = parsed.get("choices", [{}])[0].get("message", {}).get("content", "")
        return {
            "ok": True,
            "elapsed_ms": elapsed_ms,
            "text": text,
            "raw_meta": {
                "model": parsed.get("model"),
                "usage": parsed.get("usage"),
            },
        }
    except urllib.error.HTTPError as e:
        return {"ok": False, "elapsed_ms": int((time.time() - t0) * 1000),
                "text": "", "error": f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:500]}"}
    except Exception as e:
        return {"ok": False, "elapsed_ms": int((time.time() - t0) * 1000),
                "text": "", "error": f"{type(e).__name__}: {e}"}


BACKENDS = [
    {
        "name": "DeepSeek (deepseek-chat / V3)",
        "key_env": "DEEPSEEK_API_KEY",
        "base_url": "https://api.deepseek.com",
        "model": "deepseek-chat",
    },
    {
        "name": "xAI Grok (grok-4-latest)",
        "key_env": "XAI_API_KEY",
        "base_url": "https://api.x.ai/v1",
        "model": "grok-4-latest",
    },
    {
        "name": "Groq Qwen3-32B (current cloud-worker zh path)",
        "key_env": "GROQ_API_KEY",
        "base_url": "https://api.groq.com/openai/v1",
        "model": "qwen/qwen3-32b",
    },
]


def load_keys():
    if not os.path.exists(KEYS_PATH):
        print(f"ERROR: {KEYS_PATH} not found. Create it with KEY=VALUE per line.", file=sys.stderr)
        sys.exit(1)
    keys = {}
    with open(KEYS_PATH) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, _, v = line.partition("=")
                keys[k.strip()] = v.strip().strip('"').strip("'")
    return keys


def wipe_keys():
    try:
        os.remove(KEYS_PATH)
        print(f"\n[security] wiped {KEYS_PATH}", file=sys.stderr)
    except OSError:
        pass


def main():
    keys = load_keys()
    system = build_system_prompt()
    user = build_user_prompt()

    print("=" * 78)
    print(f"SCENARIO: {SITUATION}")
    print(f"locale={LOCALE}  style={STYLE_ID}  mode={MODE}  intensity={INTENSITY}  n={N_VARIANTS}")
    print("=" * 78)
    print("--- SYSTEM PROMPT (sent to all backends) ---")
    print(system)
    print("--- USER PROMPT (sent to all backends) ---")
    print(user)
    print("=" * 78)

    results = []
    for b in BACKENDS:
        key = keys.get(b["key_env"])
        if not key:
            print(f"\n>>> {b['name']}: SKIPPED ({b['key_env']} not set)")
            results.append({"backend": b["name"], "status": "skipped"})
            continue
        print(f"\n>>> {b['name']} ({b['model']})  ... ", end="", flush=True)
        r = call_openai_compatible(b["base_url"], key, b["model"], system, user)
        if r["ok"]:
            print(f"OK {r['elapsed_ms']}ms")
            print(r["text"])
            results.append({"backend": b["name"], "model": b["model"], "ok": True,
                            "elapsed_ms": r["elapsed_ms"], "text": r["text"],
                            "raw_meta": r["raw_meta"]})
        else:
            print(f"FAIL ({r['elapsed_ms']}ms): {r['error']}")
            results.append({"backend": b["name"], "ok": False,
                            "elapsed_ms": r["elapsed_ms"], "error": r["error"]})

    # Dump structured results
    out_path = "/tmp/roastmate_backend_compare.json"
    with open(out_path, "w") as f:
        json.dump({
            "situation": SITUATION,
            "locale": LOCALE,
            "style": STYLE_ID,
            "mode": MODE,
            "intensity": INTENSITY,
            "n_variants": N_VARIANTS,
            "results": results,
        }, f, ensure_ascii=False, indent=2)
    print(f"\n[saved] {out_path}")

    wipe_keys()


if __name__ == "__main__":
    main()
