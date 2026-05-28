/**
 * RoastMate research recruit endpoint — Cloudflare Worker.
 * P5 Q1 W1 distribution research, see docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md.
 *
 * Two endpoints, dispatched by URL path:
 *   POST /          — Step 1, anonymous answers ONLY (recency / available /
 *                     locus / locale). No email, no timezone. Returns
 *                     `{ participant_code }`.
 *   POST /book      — Step 2, contact info (email / timezone) keyed by a
 *                     prior participant_code. Validates code exists in
 *                     RESEARCH_ANSWERS before writing.
 *
 * Posture (privacy moat):
 *   - Answers (recency / available / locus / locale) stored in
 *     `RESEARCH_ANSWERS` KV under key `participants:<code>`.
 *   - Email + timezone stored SEPARATELY in `RESEARCH_CONTACTS` KV under
 *     key `contacts:<code>`. Different binding = different "table" so an
 *     analyst working with answers cannot accidentally pull emails into
 *     the same query.
 *   - **NEW (Gemini audit 2026-05-28):** email and emotional locus
 *     context NEVER travel in the same HTTP request. Step 1 captures
 *     answers anonymously; Step 2 captures email tied to the code. Even
 *     if the Worker is compromised at a single point in time, the
 *     in-flight payloads don't co-locate sensitive context with PII.
 *   - Both keys expire in 60 days (TTL set on PUT).
 *   - No request logs beyond CF's default. No analytics binding.
 *   - CORS locked to ALLOWED_ORIGIN (set in wrangler.toml [vars]).
 */

interface Env {
  RESEARCH_ANSWERS: KVNamespace;
  RESEARCH_CONTACTS: KVNamespace;
  ALLOWED_ORIGIN: string;
}

interface AnswerSubmission {
  recency?: string;
  available?: string;
  locus?: string;
  locale?: string;
}

interface BookSubmission {
  code?: string;
  email?: string;
  timezone?: string;
}

// 60 days: covers the 6-week Phase 5 Q1 recruit + interview window with
// ~2 weeks of buffer for scheduling-back-and-forth. Codex audit catch
// from v1: 30 days expired contacts WHILE interviews were still being
// scheduled.
const TTL_SECONDS = 60 * 24 * 60 * 60;

const RECENCY_BUCKETS = new Set([
  'this_week', 'this_month', 'longer', 'cant_remember', 'prefer_not_say'
]);
const AVAIL_BUCKETS = new Set(['yes', 'no']);
const LOCALES = new Set(['en', 'zh-Hans', 'zh-Hant', 'ja']);
const PARTICIPANT_CODE_RE = /^[A-Z0-9]{12}$/;

// --- helpers ---------------------------------------------------------

function isAllowedOrigin(env: Env, origin: string): boolean {
  if (!origin) return false;
  const allowed = env.ALLOWED_ORIGIN.split(',').map(s => s.trim()).filter(Boolean);
  return allowed.includes(origin);
}

function corsAllowOrigin(env: Env, origin: string): string {
  return isAllowedOrigin(env, origin) ? origin : '';
}

function corsHeaders(env: Env, origin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': corsAllowOrigin(env, origin),
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}

function jsonResponse(env: Env, origin: string, status: number, body: object): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(env, origin) }
  });
}

function validEmail(s: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

function newParticipantCode(): string {
  // 12-char base36 → uppercase → A-Z0-9 only.
  const buf = new Uint8Array(8);
  crypto.getRandomValues(buf);
  let acc = 0n;
  for (const byte of buf) acc = (acc << 8n) | BigInt(byte);
  return acc.toString(36).padStart(12, '0').slice(-12).toUpperCase();
}

// --- handlers --------------------------------------------------------

async function handleAnswer(request: Request, env: Env, origin: string): Promise<Response> {
  let body: AnswerSubmission;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(env, origin, 400, { error: 'invalid_json' });
  }

  if (!body.recency || !RECENCY_BUCKETS.has(body.recency)) {
    return jsonResponse(env, origin, 400, { error: 'invalid_recency' });
  }
  if (!body.available || !AVAIL_BUCKETS.has(body.available)) {
    return jsonResponse(env, origin, 400, { error: 'invalid_available' });
  }
  if (!body.locus || typeof body.locus !== 'string' || body.locus.length < 2) {
    return jsonResponse(env, origin, 400, { error: 'invalid_locus' });
  }
  const locale = body.locale && LOCALES.has(body.locale) ? body.locale : 'en';
  const locus = body.locus.slice(0, 200);

  const code = newParticipantCode();
  const submittedAt = new Date().toISOString();

  try {
    await env.RESEARCH_ANSWERS.put(
      `participants:${code}`,
      JSON.stringify({ code, submittedAt, locale, recency: body.recency, available: body.available, locus }),
      { expirationTtl: TTL_SECONDS }
    );
  } catch {
    return jsonResponse(env, origin, 500, { error: 'storage_failed' });
  }

  return jsonResponse(env, origin, 201, { participant_code: code });
}

async function handleBook(request: Request, env: Env, origin: string): Promise<Response> {
  let body: BookSubmission;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(env, origin, 400, { error: 'invalid_json' });
  }

  if (!body.code || !PARTICIPANT_CODE_RE.test(body.code)) {
    return jsonResponse(env, origin, 400, { error: 'invalid_code' });
  }
  if (!body.email || typeof body.email !== 'string' || !validEmail(body.email)) {
    return jsonResponse(env, origin, 400, { error: 'invalid_email' });
  }

  // Code must already exist as an answer (anti-spam: nobody can stuff
  // contacts KV with arbitrary codes).
  const existing = await env.RESEARCH_ANSWERS.get(`participants:${body.code}`);
  if (!existing) {
    return jsonResponse(env, origin, 404, { error: 'code_not_found' });
  }

  const timezone = (body.timezone || '').slice(0, 40);
  const email = body.email.slice(0, 120);
  const submittedAt = new Date().toISOString();

  try {
    await env.RESEARCH_CONTACTS.put(
      `contacts:${body.code}`,
      JSON.stringify({ code: body.code, submittedAt, email, timezone }),
      { expirationTtl: TTL_SECONDS }
    );
  } catch {
    return jsonResponse(env, origin, 500, { error: 'storage_failed' });
  }

  return jsonResponse(env, origin, 201, { booked: true });
}

// --- entry -----------------------------------------------------------

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') || '';

    // CORS preflight.
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(env, origin) });
    }
    // Origin gate (no-Origin requests are rejected — Codex audit catch).
    if (!isAllowedOrigin(env, origin)) {
      return new Response('Forbidden', { status: 403 });
    }
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: corsHeaders(env, origin)
      });
    }

    const url = new URL(request.url);
    if (url.pathname === '/book') return handleBook(request, env, origin);
    return handleAnswer(request, env, origin);
  }
};
