# RoastMate research recruit Worker

Cloudflare Worker that receives form submissions from
`roastmate.app/research` and stores them in two separate KV namespaces
(answers + contacts) per the privacy posture in
`docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md` §1.

## One-time setup (solo dev, ~10 minutes)

Run from this directory (`research/worker/`):

```bash
# 1. Install wrangler if not present.
npm install --global wrangler

# 2. Authenticate to Cloudflare.
npx wrangler login

# 3. Create the two KV namespaces.
npx wrangler kv namespace create RESEARCH_ANSWERS
npx wrangler kv namespace create RESEARCH_CONTACTS

# Each command prints an `id = "…"` line. Paste those IDs into
# wrangler.toml (replacing the REPLACE_WITH_KV_ID_FROM_WRANGLER_CREATE
# placeholders).

# 4. Deploy.
npx wrangler deploy

# Wrangler prints the deployed URL (e.g.
# https://roastmate-research.<your-subdomain>.workers.dev).
# Copy that URL.

# 5. Wire the URL into the static page.
#    Edit research/web/research.html — add this <script> right BEFORE
#    the <script src="research.js"></script> line:
#
#      <script>window.RM_RESEARCH_WORKER_URL = "https://roastmate-research.<your-subdomain>.workers.dev";</script>
#
#    OR edit research/web/research.js line 11 directly.

# 6. Publish the static page.
#    Copy research/web/*.html research/web/*.css research/web/*.js into
#    the GH Pages repo (JasonYeYuhe/RoastMate) as research.html /
#    research.css / research.js (root level, alongside privacy.html and
#    terms.html). Commit and push. Pages auto-deploys.

# 7. Verify.
#    Open https://jasonyeyuhe.github.io/RoastMate/research.html in a
#    private window, fill out the form, hit Submit. Status banner should
#    show "Thanks. We will reach out within a week. Your reference: …".
#    Then verify storage:
#
#      npx wrangler kv key list --binding RESEARCH_ANSWERS
#      npx wrangler kv key list --binding RESEARCH_CONTACTS
#
#    You should see one key in each. The answer KV should NOT contain
#    the email; the contact KV is the only place email lives.
```

## Reading answers for analysis

```bash
# List every recruit.
npx wrangler kv key list --binding RESEARCH_ANSWERS

# Read one (no email visible — by design).
npx wrangler kv key get --binding RESEARCH_ANSWERS "participants:<CODE>"

# When you need to email a recruit, switch to the contacts binding.
npx wrangler kv key get --binding RESEARCH_CONTACTS "contacts:<CODE>"
```

Two KV bindings = two "tables." Reading answers never accidentally pulls
emails into the same query surface (Codex catch on v1 research protocol).

## Rotation

Both KV entries have a 30-day TTL set at write time — Cloudflare expires
them automatically. No manual deletion needed unless a recruit asks to
be removed sooner:

```bash
npx wrangler kv key delete --binding RESEARCH_ANSWERS "participants:<CODE>"
npx wrangler kv key delete --binding RESEARCH_CONTACTS "contacts:<CODE>"
```

## Costs

- Cloudflare Workers free tier: 100k requests/day. A 20-person recruit
  over 6 weeks is well within free.
- KV free tier: 1k writes / 100k reads per day. Same.

## Custom domain (optional)

Today the form lives at the GH Pages URL
`https://jasonyeyuhe.github.io/RoastMate/research.html`. To move to
`roastmate.app/research`:

1. Map the apex domain `roastmate.app` to GitHub Pages (CNAME + DNS) —
   one-time setup.
2. Add the new origin to `wrangler.toml` `ALLOWED_ORIGIN` (or extend the
   Worker to allow multiple origins).
3. Redeploy.

This step is NOT required for the W1 launch — the GH Pages URL is fine.

## Threat model

| Threat | Mitigation |
|---|---|
| CSRF from another origin posting fake submissions | CORS gate to `ALLOWED_ORIGIN` (`Origin` header check) |
| Spam / load attacks | CF Workers DDoS-shielded by default; rate-limit via CF dashboard if abuse appears |
| KV leak via Cloudflare account compromise | TTL bounds blast radius to 30 days; no PII beyond email; no app-state coupling |
| Email enrichment via account compromise | Email lives in a separate KV namespace — different IAM scope |
| Tracking pixels via static page | None embedded; CSP not required (no third-party origins called) |
| Form replay by malicious client | Each submit gets a fresh participant code; replays just create extra entries |
