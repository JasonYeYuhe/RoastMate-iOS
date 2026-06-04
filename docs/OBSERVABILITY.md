# Observability — Datadog (Cloudflare Workers)

_Set up 2026-06-04. Covers the two Cloudflare Workers only. The iOS/macOS app
keeps its on-device-only, no-3rd-party-SDK telemetry posture untouched — Datadog
is **never** embedded in the client. Privacy moat intact._

## What's instrumented

| Worker | URL | Datadog `service` |
|---|---|---|
| Vent proxy (`cloud-worker/`) | `roastmate-vent.yyyyy-yeyuhe.workers.dev` | `roastmate-vent` |
| Research recruit (`research/worker/`) | `roastmate-research.yyyyy-yeyuhe.workers.dev` | `roastmate-research` |

Each worker fires a single privacy-safe log per request via a `ddLog()` helper
(`ctx.waitUntil` + fail-silent, so it can never slow or break a response). It is
a **no-op unless `DD_API_KEY` is set**, so local/dev runs send nothing.

Datadog org: **YE Backpack**, site **US5** (`us5.datadoghq.com`). The workers
default `DD_SITE` to `us5.datadoghq.com`, so no `DD_SITE` var is required.

## Privacy posture — what is and is NOT logged

**Logged (operational metadata only):**
- `outcome` — `ok` / `rate_limited` / `upstream_error` (vent)
- `endpoint` — `answer` / `book` / `gate` (research)
- `status` — HTTP status code
- `latency_ms` — request duration
- `intensity`, `locale` — vent request shape (no content)
- `provider`, `model` — which LLM served a successful vent call
- `attempts` — `provider:status` pairs on upstream failure (no response bodies)

**NEVER logged:** situation text, generated output, `deviceId`, research answers,
emotional `locus` context, email, timezone, `participant_code`. The `message`
field is a fixed string (`"vent ok 200"` etc.), never user text. This is enforced
in code — `ddLog()` is only ever called with the fields above.

## Dashboard + monitor

- **Dashboard** `RoastMate Workers` — id `d9w-z46-dem`
  → https://us5.datadoghq.com/dashboard/d9w-z46-dem/roastmate-workers
  9 widgets: requests-by-outcome, upstream failures, rate-limited, provider mix,
  latency avg + p95, research-by-endpoint, research errors, + a privacy note.
- **Monitor** `RoastMate vent — upstream provider failures` — id `20291225`
  → https://us5.datadoghq.com/monitors/20291225
  Log alert: `@outcome:upstream_error` count over 1h — **warn ≥ 2, crit ≥ 5**.
  Fires when BOTH Groq and OpenRouter fail (users get a 502 / on-device fallback).
  - ⚠️ **No notification channel attached yet** — it only shows in the Datadog UI.
    To route to email/Slack, add an `@`-handle to the monitor message.

## Log index + cost

- Index `main`, 15-day retention, no exclusion filters (catches all org logs).
- Pre-launch traffic is near-zero, so ingestion/retention cost is effectively $0.
  Datadog is on the GitHub Student Pack plan. If volume ever grows, set a daily
  quota on the `main` index (Logs → Configuration → Indexes) to cap spend.

## Keys & secrets

- **`DD_API_KEY`** (send-only log-intake key) — stored as a **Wrangler secret**
  on both workers (`npx wrangler secret put DD_API_KEY`). Never committed.
  Rotate in Datadog → Organization Settings → API Keys, then re-`put` on both.
- **Application key** `roastmate-worker-observability` (key id
  `a7876327-37b1-473d-83f3-1f6677aae77a`, unscoped) — created only to build the
  dashboard/monitor via the management API. Not needed at runtime; not stored in
  the repo. Revoke or scope it in Datadog → Organization Settings → Application
  Keys if you don't plan to script further changes.

## How to extend

Dashboard/monitor were created via the Datadog management API (a log-alert query
+ a 9-widget dashboard JSON). To add widgets or monitors, POST to
`/api/v1/dashboard` / `/api/v1/monitor` on `https://api.us5.datadoghq.com` with
`DD-API-KEY` + `DD-APPLICATION-KEY` headers. Field facets available for queries:
`@outcome @status @latency_ms @intensity @locale @provider @model` (vent) and
`@endpoint @status @latency_ms` (research). `@latency_ms` is a numeric measure
(supports avg/pc95/etc.).

Verify logs are flowing:
```
curl -s -X POST https://api.us5.datadoghq.com/api/v2/logs/events/search \
  -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
  -H "Content-Type: application/json" \
  -d '{"filter":{"query":"service:roastmate-vent","from":"now-1d","to":"now"},"page":{"limit":10}}'
```
