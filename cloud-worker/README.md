# RoastMate Vent Cloud Worker

Tiny Cloudflare Worker that fronts OpenRouter for the Vent / Feral
private-draft path in the iOS app. The Worker owns the OpenRouter API key
(it never ships in the iOS binary), enforces a per-device daily rate limit,
and serves both the iOS production traffic and any future macOS / Android
clients.

## Why this exists

Apple's on-device Foundation Models is too gentle for real venting — even
with directive prompts, it returns "wise reframing" instead of raw anger.
We route only the **Vent** and **Feral** intensities through a less
RLHF'd model (DeepSeek V3 free via OpenRouter). Calm / Sharp / Savage
stay 100% on-device.

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

### Set your OpenRouter API key as a secret

```bash
npx wrangler secret put OPENROUTER_API_KEY
# paste your sk-or-v1-... key from openrouter.ai/settings/keys
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
  "remaining": 29
}
```

Errors:
- 400 `invalid_*` — request validation failed
- 429 `rate_limit_exceeded` — device hit daily cap (default 30/day)
- 502 `upstream_error` / `empty_response` — OpenRouter failed
- iOS falls back to local Apple Foundation Models in any error case

## Cost / limits (current free tier)

- Cloudflare Workers: 100k requests/day free, plenty
- KV: 100k reads + 1k writes/day free (we use ~30 writes per active user)
- OpenRouter DeepSeek V3 free: 1000 requests/day per OpenRouter key
- DAILY_LIMIT_PER_DEVICE: 30 (controlled in wrangler.toml)

Math: ~33 users hitting their daily limit fills the OpenRouter free key.
For early launch this is fine. If you outgrow it:

1. Bump to OpenRouter paid (DeepSeek V3 ~$0.30/M tokens — ~$3/day at 10k req)
2. Or switch to a different OpenRouter free model in `wrangler.toml`
3. Or gate cloud vent behind Pro entitlement (you'd send a signed
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
