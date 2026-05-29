#!/usr/bin/env python3
"""Analyze a RoastMate A′ telemetry export for the Echoes on-device
parse-fallback RATE vs the 35% kill-criterion (health audit 2026-05-29 §3).

The on-device 3B model's parse-vs-fallback rate is the gating unknown for
Echoes' live-generation quality — it cannot be measured in the simulator
(no Apple Intelligence) or via a cloud model (too strong to be
representative). Run the real-device protocol in
docs/ECHOES_REALDEVICE_EVAL_2026-05-29.md, export the telemetry JSON from
Settings, then feed it here.

Usage:
    python3 scripts/echoes_eval_analyze.py <telemetry-export.json>

The export is the JSON shared from Settings → "Share usage data". The
echoes_* counters live under the top-level `counters` key.
"""
import json
import sys

KILL_THRESHOLD = 0.35  # audit §3: > 35% over a 7-day window → empathy illusion broken
MIN_ATTEMPTS = 10      # below this the read is directional, not decisive


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: echoes_eval_analyze.py <telemetry-export.json>")
        return 2
    with open(sys.argv[1]) as f:
        data = json.load(f)
    c = data.get("counters", data)  # tolerate a bare counters dict too

    started = c.get("echoes_session_started", 0)
    completed = c.get("echoes_completed", 0)
    fallback = c.get("echoes_parse_fallback", 0)
    unavail = c.get("echoes_model_unavailable", 0)
    bridge = c.get("echoes_bridge_tap", 0)

    # Denominator = sessions where the on-device model WAS available and a
    # generation was attempted. Subtracting model-unavailable keeps AI-off /
    # unsupported-device runs from polluting the rate — that separation is
    # exactly why echoes_model_unavailable exists (audit 2026-05-29 fix).
    attempts = started - unavail

    print(f"export week: {data.get('exported_at_week', '?')}  schema v{data.get('schema_version', '?')}")
    print(f"echoes_session_started   = {started}")
    print(f"echoes_model_unavailable = {unavail}  (AI off / unsupported — excluded from the rate)")
    print(f"echoes_completed         = {completed}")
    print(f"echoes_parse_fallback    = {fallback}")
    print(f"echoes_bridge_tap        = {bridge}")
    print("-" * 52)

    if attempts <= 0:
        print("No model-available Echoes sessions yet. Run the protocol on a PHYSICAL")
        print("iPhone with Apple Intelligence ON (the simulator only serves curated")
        print("fallback, which would read as 100% fallback and tell you nothing).")
        return 1

    rate = fallback / attempts
    print(f"parse-fallback RATE = {fallback}/{attempts} = {rate:.0%}")
    print(f"kill-criterion      = > {KILL_THRESHOLD:.0%}")
    if completed > 0:
        print(f"bridge conversion   = {bridge}/{completed} = {bridge / completed:.0%}  (the core strategic metric)")
    print("-" * 52)

    if rate > KILL_THRESHOLD:
        print(f"VERDICT: FAIL — {rate:.0%} > 35%. The empathy illusion breaks too often")
        print("(canned fallback reads as broken/cringe). Action: either force Echoes")
        print("through the cloud path (sacrifice margin/privacy for quality), or disable")
        print("it via the kill-switch (echoes_enabled:false) while the prompt/model is")
        print("tuned. Do NOT flip the live config to enabled for the store build.")
    else:
        print(f"VERDICT: PASS — {rate:.0%} <= 35%. On-device parse quality is acceptable.")
        print("Action: ship Echoes ENABLED in v1.0.6 (keep/flip echoes_enabled:true live).")

    if attempts < MIN_ATTEMPTS:
        print(f"\nNOTE: only {attempts} model-available attempts — under the ~{MIN_ATTEMPTS} minimum")
        print("for a stable read. Treat this as directional; run more before deciding.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
