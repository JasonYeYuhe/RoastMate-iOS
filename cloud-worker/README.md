# RoastMate Vent Cloud Worker

Tiny Cloudflare Worker that fronts two upstream LLM providers (OpenRouter
primary, Groq fallback) for the Vent / Feral private-draft path in the
iOS app. The Worker owns both API keys (they never ship in the iOS
binary), enforces a per-device daily rate limit, and serves both the iOS
production traffic and any future macOS / Android clients.

## Why this exists

Apple's on-device Foundation Models is too gentle for real venting — even
with directive prompts, it returns "wise reframing" instead of raw anger.
We route only the **Vent** and **Feral** intensities through a less
RLHF'd model (DeepSeek V4 Flash free via OpenRouter, with Groq Llama 3.3
70B as the fallback). Calm / Sharp / Savage stay 100% on-device.

The Worker tries OpenRouter first; on any non-2xx response or empty
completion, it transparently retries on Groq. The client sees a single
endpoint and (for now) a single response shape — only the new
`provider` field tells you which upstream actually answered.

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
  "model": "deepseek/deepseek-chat-v3-0324:free",
  "provider": "openrouter",      // or "groq" if primary failed
  "remaining": 29
}
```

Errors:
- 400 `invalid_*` — request validation failed
- 429 `rate_limit_exceeded` — device hit daily cap (default 30/day)
- 502 `upstream_error` with a `detail` listing whichever upstream(s) the
  Worker tried (e.g. "openrouter:429 ... | groq:500 ..."). iOS falls
  back to local Apple Foundation Models in any error case.

## Cost / limits (current tiers)

- Cloudflare Workers: 100k requests/day free, plenty
- KV: 100k reads + 1k writes/day free (we use ~30 writes per active user)
- OpenRouter free account: 50 free-model requests/day total
- OpenRouter pay-as-you-go account with at least $10 in credits:
  1000 free-model requests/day total
- DAILY_LIMIT_PER_DEVICE: 30 (controlled in wrangler.toml)

Math: the proxy host is not the bottleneck; the upstream model quota is.
At 30 drafts/device/day, a pure free OpenRouter account supports only
about one heavy user. A pay-as-you-go account with the 1000/day
free-model allowance supports about 33 heavy users.

For product testing this is fine. If you outgrow it:

1. Keep a small OpenRouter credit balance so the account has the
   1000/day free-model allowance
2. Bump to a paid OpenRouter model when you need reliability
3. Or switch to a different upstream provider / model in `wrangler.toml`
4. Or gate cloud vent behind Pro entitlement (you'd send a signed
   StoreKit transaction with each request and have the Worker validate it)

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
