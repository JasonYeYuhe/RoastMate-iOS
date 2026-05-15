# Decision: Where to host the Vent / Feral cloud proxy?

Codex, I need you to pick. I'll be biased by my CF familiarity; I want
your read on this from cold context. Decision deadline is "before
v1.6 ships".

## Background (skim if you read the recent commits)

We just shipped the iOS plumbing for routing Vent + Feral private
drafts through a developer-owned cloud proxy. The proxy is the only
thing standing between v1.6 and a real ship-ready vent feature, since
Apple Foundation Models won't produce real vent output even after
heavy prompt engineering.

The proxy itself is tiny: validate request, KV-or-equivalent
per-device daily rate limit (default 30/day), build the vent/feral
system prompt server-side (so the OpenRouter key can't be exfiltrated
via a poisoned client prompt), forward to OpenRouter DeepSeek V3 free,
return text. Stateless beyond the rate-limit counter.

Worker code already written: `cloud-worker/src/index.js`. Targets the
Cloudflare Workers runtime. Roughly 190 lines.

Endpoint contract (already wired on the iOS side, don't break):

```
POST /v1/vent
{
  "situation": "<= 1500 chars",
  "styleName": "...",          // display name, used as hint
  "intensity": "vent" | "feral",
  "locale": "zh-Hans|zh-Hant|ja|en-US|...",
  "deviceId": "<UUID from Keychain>"
}
→ 200 { text, model, remaining }
→ 429 { error: "rate_limit_exceeded", remaining }
→ 502 { error: "upstream_error" | "empty_response" }
→ 400 { error: "invalid_*" }
```

iOS treats every non-200 as "fall back to local Apple Foundation
Models" — so the proxy's reliability requirements are "good enough
not to be embarrassing", not "five nines".

## User's existing infrastructure (NEW INFO since the worker was written)

The user already owns and pays for:

1. **DigitalOcean droplet, Singapore region.** Currently runs the
   backend for an unrelated project called `colorarchive`. Probably
   nginx or Caddy in front, SSL via Let's Encrypt or Caddy auto-TLS,
   maybe a small Node/Python backend already there. We don't know
   tier (likely $5–$10/mo basic droplet).
2. **Vercel account.** Currently hosts the colorarchive frontend.
   Free tier or Hobby tier, not sure.
3. **No Cloudflare account.** Hasn't signed up. Would have to register
   (30 seconds, email + password, no card needed).

User's preference signal: would prefer to **not add a fourth provider
to their stack** if a clean integration with what they already pay
for is possible. They asked me to write you this report and let you
decide.

## App's user geography

UI ships in 4 locales: `en`, `zh-Hans`, `zh-Hant`, `ja`. The localized
copy + the founder's network suggests the realistic launch user base
is overwhelmingly **Asia (CN / HK / TW / JP)** with English as the
international long-tail. Effectively a single-continent app at launch.

## Options on the table

### A. Cloudflare Workers (what's currently coded)

- Free tier: 100k req/day, KV 100k reads/day, 1k writes/day.
- 300+ edge POPs globally. For Asian users, latency typically < 30ms.
- Zero cold start, edge runtime.
- Zero ops — `wrangler deploy` is the entire deploy pipeline.
- KV is already used for rate-limit state.
- **Cost to user**: $0. Forever, at our likely scale.
- **Cost to user**: also a new account to manage.

### B. Vercel Edge Function (rewrite required, ~5 min)

- Free Hobby tier (current docs): **1M function invocations/month** and
  **1M edge requests/month**. Still materially less headroom than
  Cloudflare's 100k/day, but not the 100k/month figure in the first draft
  of this memo.
- Edge regions include HKG + HND, so Asian latency is fine.
- Already part of user's stack (colorarchive frontend lives there).
- Vercel KV exists but free tier is stingy (30k commands/day) — fine
  for now, would need migration if we scaled.
- Slight cold start on first hit (~30-100ms warm-up), then warm.
- **Real concern**: roughly 1M/month vs 100k/day. Not a launch blocker,
  but Cloudflare still leaves more free headroom if vent traffic spikes.

### C. Existing Singapore DO droplet, co-tenant with colorarchive

- Latency: Singapore → CN/HK/TW/JP is 30-150ms (varies by ISP / GFW
  routing). Singapore → EU/US 200-300ms (mostly irrelevant for us).
- No edge — single datacenter.
- **Operational coupling**: any RoastMate traffic spike, bug, or
  misconfiguration impacts colorarchive, which is the user's other
  shipped product.
- Already has SSL termination + nginx — adding `/v1/vent` is a
  reverse-proxy block + a systemd unit + a tiny Node Express server.
  ~30 min of work, plus ~5 min replicating the prompt logic in Node
  (currently in `src/index.js` as CF Workers JS — mostly portable).
- Rate limit state: SQLite or in-memory map (single instance, no
  cross-node sync needed since it's one droplet).
- **Cost to user**: $0 incremental (server already running and paid).
- **Cost to user**: blast-radius coupling with colorarchive, and
  ongoing OS/process maintenance the user already does for
  colorarchive anyway.

## What I'd lean toward and why (you can override)

My weak preference is **A (Cloudflare)** for one reason: I don't want
RoastMate's unpredictable launch traffic curve to share a fate with
colorarchive on the same Singapore droplet. The user is a one-person
team. The day RoastMate gets posted to Hacker News or a Chinese tech
forum, the droplet melts, and colorarchive — a separate, presumably
revenue-generating project — also goes dark. That's a real cost.

But I'm aware "register a new provider" has its own real cost too. And
A. user already trusts CF enough vs B. user might value
consolidating to "one platform per concern" (Vercel for everything
serverless, DO for everything stateful).

The case for C is "I already pay for it, why not". Real, but the
operational coupling risk is real too.

The case for B is "Vercel is already in my stack". The 100k/month
limit is the binding constraint — I genuinely don't know if RoastMate
will hit that. If it does, we're paying for Vercel Pro ($20/mo) which
suddenly makes "free CF" look smarter in retrospect.

## What I need from you

Pick one of A / B / C and tell me why. Specifically address:

1. The operational coupling risk on C — am I overweighting it?
2. The 1M/month limit on B — is that a real concern at launch, or
   am I solving a problem I don't have?
3. Anything I missed in the comparison (cold start tail latency under
   contention, free-tier rug-pull risk on any of these, etc.)
4. If A wins: any reason to NOT use Workers KV for rate limit state?
   (e.g. Durable Objects would be more accurate but adds complexity.)
5. If B or C wins: I'll port the worker code, just confirm the call.

Also worth flagging: this isn't an irreversible decision. The endpoint
contract is small enough that we could migrate hosts later with one
client-side `CloudConfig.swift` change + a redeploy. But "later" has a
cost too. Pick the one that's right enough today.

Speed > thoroughness. ~5 minute decision. Thanks.

## Addendum — the actual first bottleneck is upstream, not hosting

OpenRouter's current docs say a pure free account gets 50 free-model
requests/day total. A pay-as-you-go account with at least $10 in credits
gets up to 1000 free-model requests/day. That means the host choice above
matters less than the upstream policy: at 30 vent drafts/device/day, a
pure free OpenRouter account only serves about one heavy user, while the
pay-as-you-go allowance serves about 33. Treat free OpenRouter as a test
lane, not as durable production capacity.
