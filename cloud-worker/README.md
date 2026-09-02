# RoastMate Vent Cloud Worker

Tiny Cloudflare Worker that fronts two upstream LLM providers (**Groq
primary, OpenRouter fallback**) for the Vent / Feral private-draft path
and the 虚拟舍友群 roommate scene. The Worker owns both API keys (they never
ship in the app binary), enforces daily quotas, verifies Pro
entitlement, and serves iOS + macOS production traffic.

Endpoints:
- `POST /v1/vent` — generation. Modes: `vent` (default), `roommate`, and
  `roast` (sendable; gated off by `ROAST_MODE_ENABLED`).
- `POST /v1/auth` — exchange an Apple StoreKit 2 transaction JWS for a
  short-lived Pro session token (see "Pro lane" below).

## Why this exists

Apple's on-device Foundation Models is too gentle for real venting — even
with directive prompts, it returns "wise reframing" instead of raw anger.
We route only the **Vent** and **Feral** intensities (plus the roommate
scene, which the on-device model structurally refuses) through a less
RLHF'd model. Calm / Sharp / Savage stay on-device where Foundation
Models is available.

**Current models — `wrangler.toml` is the source of truth, not this file.**
As of 2026-09: Groq `qwen/qwen3.6-27b` for every locale, with OpenRouter
`qwen/qwen3-30b-a3b-instruct-2507` as fallback. Both are current,
non-reasoning (instruct) models — never a `*-thinking` variant, which
stalls 17-31s on these prompts, and never a `:free` variant, whose shared
pool 404s when the provider retires the tier. That is exactly what took
the cloud path down on 2026-08-31, when the previous primaries
(`qwen/qwen3-32b`, deprecated; `llama-3.3-70b-versatile`, moved to
Enterprise) and the old `hermes-3-llama-3.1-405b:free` all died at once.

The Worker tries **Groq first** (lower latency, isolated quota); on any
non-2xx or empty completion it transparently retries on OpenRouter. The
client sees one endpoint and one response shape — the `provider` field
tells you which upstream actually answered.

## One-time setup (do this once, then forget)

You'll need:
- Free Cloudflare account
- Free OpenRouter account ([openrouter.ai](https://openrouter.ai))
- Node 18+ locally

```bash
cd cloud-worker
npm install
npx wrangler login       # opens browser, signs you in to your CF account
```

### Create the KV namespace (for per-device rate limits)

```bash
npx wrangler kv namespace create rate_limits
```

It prints something like:

```
🌀  Creating namespace with title "roastmate-vent-rate_limits"
✨  Add the following to your configuration file:
[[kv_namespaces]]
binding = "RATE_LIMITS"
id = "abc123..."
```

Copy that `id` into `wrangler.toml`, replacing `REPLACE_ME_AFTER_KV_NAMESPACE_CREATE`.

### Set the upstream API keys as secrets

The Worker will use OpenRouter first, then Groq as a fallback. Either one
alone is enough to deploy a working Worker, but having both gives you a
real safety net when one provider rate-limits or has an outage.

```bash
# Primary upstream — required.
# Paste your sk-or-v1-... key from https://openrouter.ai/settings/keys
npx wrangler secret put OPENROUTER_API_KEY

# Fallback upstream — optional but recommended.
# Paste your gsk_... key from https://console.groq.com/keys
npx wrangler secret put GROQ_API_KEY
```

### Deploy

```bash
npx wrangler deploy
```

Output will include your Worker URL, something like:

```
https://roastmate-vent.YOUR-CF-SUBDOMAIN.workers.dev
```

That's your endpoint. The iOS app sends POSTs to `/v1/vent` on it.

### Point the iOS app at your Worker

In `Shared/Services/CloudConfig.swift`, replace the placeholder URL with
your deployed Worker URL. Rebuild + ship.

## Request shape

```
POST https://your-worker.workers.dev/v1/vent
Content-Type: application/json

{
  "situation": "我室友每天凌晨两点打游戏,声音很大。",
  "styleName": "高 EQ",
  "intensity": "vent",       // "vent" or "feral"
  "locale": "zh-Hans",
  "deviceId": "uuid-from-keychain"
}
```

Response (200):

```
{
  "text": "凌晨两点打 fuck...",
  "model": "qwen/qwen3.6-27b",
  "provider": "groq",            // or "openrouter" if the primary failed
  "remaining": 29
}
```

Errors:
- 400 `invalid_*` — request validation failed
- 401 `token_invalid` — the Pro session token expired/was rejected; the
  client drops it and retries on the free lane
- 403 `mode_unavailable` — `mode:"roast"` while `ROAST_MODE_ENABLED=false`
- 429 `rate_limit_exceeded` — hit a daily cap (free device 30/day, Pro
  account 200/day, or the per-IP attempt backstop)
- 503 `service_unavailable` — `CLOUD_DISABLED=true` (global kill-switch)
- 502 `upstream_error` with a `detail` listing whichever upstream(s) the
  Worker tried (e.g. "openrouter:429 ... | groq:500 ..."). iOS falls
  back to local Apple Foundation Models in any error case.

## Pro lane, quotas and breakers (Track M, v1.3)

`POST /v1/auth` takes `{"jws": "<StoreKit 2 transaction JWS>"}`, verifies
Apple's signature offline (ECDSA P-256 over the x5c chain), and returns a
short-lived session token. `POST /v1/vent` with
`Authorization: Bearer <token>` resolves to the **Pro lane**, whose quota
is keyed on a keyed HASH of the Apple account id — so one subscription
shares one bucket across a user's devices and replaying one JWS on cloned
devices does not multiply quota. No token → the legacy per-device lane.

Every cloud caller in the app must go through
`CloudVentService.generate(_:auth:)`. Calling `generate(req)` directly
sends the request tokenless, which silently bills a paying subscriber
against the free cap — that shipped once already (v1.4 M-b).

Caps and switches, all in `wrangler.toml`:

| var | meaning |
|---|---|
| `DAILY_LIMIT_PER_DEVICE` | free lane, per deviceId (30) |
| `PRO_DAILY_LIMIT` | Pro lane, per account (200) |
| `APP_DAILY_LIMIT_PER_IP` | native per-IP attempt backstop (200) — generous, because CGNAT puts many legitimate mobile users behind one IP |
| `WEB_DAILY_LIMIT_PER_IP` | the public web demo, strict (8) |
| `CLOUD_DISABLED` | **global kill-switch** — 503s all generation |
| `ROAST_MODE_ENABLED` | gates the sendable `mode:"roast"` path |
| `ALLOW_SANDBOX_RECEIPTS` | keep FALSE in prod: a sandbox purchase is free, so accepting one would mint real Pro for $0 |
| `ASS_API_ENABLED` | App Store Server API refund/revocation check (fail-open) |

**These caps are cost controls, not a security boundary.** They are
best-effort KV counters, not transactional. The real backstops are
`CLOUD_DISABLED` and provider-side spend limits configured at Groq and
OpenRouter — set those, and keep them set.

## Cost / limits

- Cloudflare Workers: 100k requests/day free
- KV: 100k reads + 1k writes/day free
- The proxy host is not the bottleneck; the upstream model quota is.
  Groq's dev tier for `qwen/qwen3.6-27b` is 250K TPM / 1K RPM.

If you outgrow it: raise the upstream tier, switch model in
`wrangler.toml` (keep it current, non-reasoning, non-`:free`), or tighten
the free cap. Pro entitlement gating is already built — that is the Pro
lane above.

## Local development

```bash
npx wrangler dev
```

Boots a local edge runtime on `localhost:8787`. Point the iOS app at
`http://localhost:8787` for testing (only works on simulator due to ATS).

## Tail logs

```bash
npx wrangler tail
```

Useful when debugging "why did my request return 502".

## Updating

Edit `src/index.js` (prompts, validation, model), then:

```bash
npx wrangler deploy
```

No need to update the iOS app for prompt changes — the Worker owns the
prompts. iOS app changes are only needed for new fields in the
request/response contract.
