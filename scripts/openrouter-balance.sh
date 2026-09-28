#!/bin/bash
# Read-only OpenRouter balance check for the RoastMate Worker.
#
# Why this exists: OpenRouter is the ONLY working model path (the Groq primary
# died 2026-09-15) and auto-top-up is OFF (confirmed 2026-09-28), so the prepaid
# balance is both a hard spend cap and the point where cloud Vent / Feral / the
# roommate group stop. When it hits zero the app degrades to labelled curated
# examples and charges nothing — gracefully, but silently. This makes it loud.
#
# How: a throwaway `wrangler dev --remote` preview whose config shares the
# deployed worker's NAME, which is what binds the deployed secrets. It calls
# OpenRouter's GET /api/v1/credits with the Worker's own key and prints only
# numbers — never the key. Nothing is deployed; production is untouched.
# Deliberately NOT the OpenRouter management key: that one can create and
# delete keys, and a balance read needs none of that.
#
# Usage:  scripts/openrouter-balance.sh [threshold_usd]   (default 2)
# Prints: OPENROUTER total=<usd> used=<usd> remaining=<usd> threshold=<usd> status=<OK|LOW>
# Exit:   0 = OK, 1 = LOW (remaining below threshold), 2 = the check itself failed
set -uo pipefail

THRESHOLD="${1:-2}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKER_DIR="$PROJECT_DIR/cloud-worker"
PORT=$((20000 + RANDOM % 20000))
TMP="$(mktemp -d "${TMPDIR:-/tmp}/roastmate-orbalance.XXXXXX")"
DEV_PID=""

cleanup() {
  if [ -n "$DEV_PID" ]; then
    pkill -P "$DEV_PID" 2>/dev/null
    kill "$DEV_PID" 2>/dev/null
  fi
  pkill -f "wrangler dev --remote --port $PORT" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

cat > "$TMP/probe.js" <<'EOF'
export default {
  async fetch(req, env) {
    const r = await fetch("https://openrouter.ai/api/v1/credits", {
      headers: { Authorization: `Bearer ${env.OPENROUTER_API_KEY}` },
    });
    if (!r.ok) return Response.json({ error: `openrouter ${r.status}` }, { status: 502 });
    const d = (await r.json()).data || {};
    return Response.json({ total: d.total_credits, used: d.total_usage });
  },
};
EOF
cat > "$TMP/wrangler.toml" <<'EOF'
name = "roastmate-vent"
main = "probe.js"
compatibility_date = "2025-01-01"
EOF

( cd "$TMP" && exec npx --prefix "$WORKER_DIR" wrangler dev --remote --port "$PORT" \
    > "$TMP/dev.log" 2>&1 ) &
DEV_PID=$!

for _ in $(seq 1 60); do
  grep -q "Ready on" "$TMP/dev.log" 2>/dev/null && break
  sleep 2
done
if ! grep -q "Ready on" "$TMP/dev.log" 2>/dev/null; then
  echo "OPENROUTER check_failed reason=preview_never_started (is wrangler logged in? npx wrangler whoami)"
  exit 2
fi

JSON="$(curl -s -m 60 -A "RoastMate-balance-check" "http://localhost:$PORT/")"
python3 - "$JSON" "$THRESHOLD" <<'EOF'
import json, sys
raw, threshold = sys.argv[1], float(sys.argv[2])
try:
    d = json.loads(raw)
    total, used = float(d["total"]), float(d["used"])
except Exception:
    print(f"OPENROUTER check_failed reason=bad_response body={raw[:120]!r}")
    sys.exit(2)
remaining = total - used
status = "LOW" if remaining < threshold else "OK"
print(f"OPENROUTER total={total:.2f} used={used:.4f} remaining={remaining:.2f} "
      f"threshold={threshold:.2f} status={status}")
sys.exit(1 if status == "LOW" else 0)
EOF
