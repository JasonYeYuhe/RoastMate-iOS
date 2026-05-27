# Phase 5 Q1 research — operational artifacts

This directory holds the artifacts that execute the protocol in
`docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md`. **Not app code** — these
are research deliverables that drive Q1 work outside the iOS / macOS
binary itself.

## Layout

```
research/
├── README.md                       ← this file
├── web/                            ← static page for roastmate.app/research
│   ├── research.html               ← Arm A pre-interview screen
│   ├── research.css                ← styling, no third-party fonts
│   └── research.js                 ← locale switcher (4 locales) + POST handler
├── worker/                         ← Cloudflare Worker (POST endpoint)
│   ├── README.md                   ← deploy instructions (10-min one-time setup)
│   ├── wrangler.toml               ← CF config with placeholder KV IDs
│   └── src/index.ts                ← POST handler, answers/contacts in SEPARATE KV
└── arm-c-recruit-copy/             ← Arm C non-user outreach scripts
    ├── wechat-zh.md                ← WeChat DM templates (zh)
    ├── line-ja.md                  ← LINE DM templates (ja)
    └── xiaohongshu-zh.md           ← Xiaohongshu post template (zh)
```

## Arm A — execution checklist

1. Deploy the Worker per `worker/README.md` (~10 min, one-time).
2. Copy `web/research.html` + `research.css` + `research.js` into the
   GH Pages repo `JasonYeYuhe/RoastMate` (root level). Edit `research.js`
   line 11 to hard-code the deployed Worker URL, OR add a `<script>` tag
   to `research.html` setting `window.RM_RESEARCH_WORKER_URL` before
   `research.js` loads.
3. Verify at `https://jasonyeyuhe.github.io/RoastMate/research.html`
   in a private window.
4. Ship the in-app "Help us improve" Settings tile in v1.0.6 (already
   added to `SettingsView.swift` this session, behind the same v1.0.6
   binary as the Tier-1 A′ counters).
5. As recruits come in, schedule via the email from the contacts KV.

## Arm B — counter wishlist already shipped

The five Tier-1 counters (`feature_usage_share_extension`,
`app_open_from_keyboard_handoff`, `output_destination_sent_share_tap`,
`output_destination_copied`) + boolean flag
(`has_successful_output_before_purchase`) + pay-timing pair
(`purchase_before_first_output` / `purchase_after_first_output`) are
landed in this same commit on `EventLedger.Counter` end-of-enum +
`EventLedger`. See `docs/A_PRIME_TELEMETRY.md` for the wire-format
table.

## Arm C — execution checklist

1. Use `arm-c-recruit-copy/wechat-zh.md` as the zh DM template.
2. Use `arm-c-recruit-copy/line-ja.md` as the ja DM template.
3. Post the Xiaohongshu template once. Iterate caption based on
   first-week reach.
4. Target N = 10 zh non-users + 5 ja non-users.
5. **No app demo. No download link.** Showing the app contaminates the
   conversation from "what would you search for?" to "what do you think
   of this?" — same reason Codex's silent-churn catch fixed v1's
   research protocol.

## What this directory is NOT

- Not shipped inside the iOS / macOS binary.
- Not Pages-published verbatim — `web/*` files are copied into the
  separate GH Pages site repo.
- Not a Cloudflare Worker monorepo — `worker/` is a single-Worker
  project, deployed independently via `wrangler`.
- Not a CRM / scheduling product — Calendly / a shared spreadsheet
  handle the day-to-day. KV is for the form submission only.

## Privacy posture (load-bearing)

- Answers and contact email live in separate KV namespaces.
- 30-day TTL on both — Cloudflare expires automatically.
- No third-party scripts in the static page (no fonts.googleapis.com,
  no analytics, no captcha).
- Locale preference is in-memory only on the page — no localStorage,
  no cookies, no `Set-Cookie`.
- Participant identifiers in qualitative notes are `P01`–`P20` (Arm A)
  and `P01`–`P15` (Arm C). The recruitment list is destroyed at Q1 close.

See `docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md` §1 and §1.5 for the
full posture and the advisor catches that drove it.
