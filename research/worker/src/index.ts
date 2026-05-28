/**
 * RoastMate research recruit endpoint — Cloudflare Worker.
 * P5 Q1 W1 distribution research, see docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md.
 *
 * Posture (privacy moat):
 *   - Answers (recency / availability / timezone / locus / locale) stored
 *     in `RESEARCH_ANSWERS` KV under key `participants:<code>`.
 *   - Email stored SEPARATELY in `RESEARCH_CONTACTS` KV under key
 *     `contacts:<code>`. Different binding = different "table" so an
 *     analyst working with answers cannot accidentally pull emails into
 *     the same query.
 *   - Both keys expire in 30 days (TTL set on PUT).
 *   - No request logs beyond CF's default. No analytics binding. No
 *     hostnames in logs beyond standard request metadata.
 *   - CORS locked to ALLOWED_ORIGIN (set in wrangler.toml [vars]).
 */

interface Env {
  RESEARCH_ANSWERS: KVNamespace;
  RESEARCH_CONTACTS: KVNamespace;
  ALLOWED_ORIGIN: string;
}

interface Submission {
  recency?: string;
  available?: string;
  timezone?: string;
  locus?: string;
  email?: string;
  locale?: string;
}

// 60 days: covers the 6-week Phase 5 Q1 recruit + interview window with
// ~2 weeks of buffer for scheduling-back-and-forth. Codex audit catch
// from v1: 30 days expired contacts WHILE interviews were still being
// scheduled.
const TTL_SECONDS = 60 * 24 * 60 * 60;

// CORS origin allow-list. Comma-separated values in env.ALLOWED_ORIGIN
// are split + matched exactly. Future-proofs the custom-domain move
// (roastmate.app) without code change.
function isAllowedOrigin(env: Env, origin: string): boolean {
  if (!origin) return false;
  const allowed = env.ALLOWED_ORIGIN.split(',').map(s => s.trim()).filter(Boolean);
  return allowed.includes(origin);
}

function corsAllowOrigin(env: Env, origin: string): string {
  return isAllowedOrigin(env, origin) ? origin : '';
}

const RECENCY_BUCKETS = new Set([
  'this_week', 'this_month', 'longer', 'cant_remember', 'prefer_not_say'
]);
const AVAIL_BUCKETS = new Set(['yes', 'no']);
const LOCALES = new Set(['en', 'zh-Hans', 'zh-Hant', 'ja']);

function corsHeaders(env: Env, origin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': corsAllowOrigin(env, origin),
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}

function badRequest(env: Env, origin: string, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(env, origin) }
  });
}

function validEmail(s: string): boolean {
  // Permissive but not lax — must have @ and a TLD-ish dot. We are not
  // verifying deliverability; that's the manual scheduling step.
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

function newParticipantCode(): string {
  // 12-char base36 — random enough that two recruits never collide in a
  // 20-person sample, short enough to read aloud.
  const buf = new Uint8Array(8);
  crypto.getRandomValues(buf);
  let acc = 0n;
  for (const byte of buf) acc = (acc << 8n) | BigInt(byte);
  return acc.toString(36).padStart(12, '0').slice(-12).toUpperCase();
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') || '';

    // CORS preflight.
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(env, origin) });
    }
    // Origin gate. Browser requests MUST carry an Origin matching the
    // allow-list. Codex audit catch from v1: previously requests with no
    // Origin header (e.g. curl, server-to-server) bypassed the gate.
    if (!isAllowedOrigin(env, origin)) {
      return new Response('Forbidden', { status: 403 });
    }
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: corsHeaders(env, origin)
      });
    }

    let body: Submission;
    try {
      body = await request.json();
    } catch {
      return badRequest(env, origin, 'invalid_json');
    }

    // Field validation.
    if (!body.recency || !RECENCY_BUCKETS.has(body.recency)) {
      return badRequest(env, origin, 'invalid_recency');
    }
    if (!body.available || !AVAIL_BUCKETS.has(body.available)) {
      return badRequest(env, origin, 'invalid_available');
    }
    if (!body.locus || typeof body.locus !== 'string' || body.locus.length < 2) {
      return badRequest(env, origin, 'invalid_locus');
    }
    if (!body.email || typeof body.email !== 'string' || !validEmail(body.email)) {
      return badRequest(env, origin, 'invalid_email');
    }
    const locale = body.locale && LOCALES.has(body.locale) ? body.locale : 'en';
    const timezone = (body.timezone || '').slice(0, 40);
    const locus = body.locus.slice(0, 200);
    const email = body.email.slice(0, 120);

    const code = newParticipantCode();
    const submittedAt = new Date().toISOString();

    // Write answers and contact email to SEPARATE namespaces. If either
    // PUT fails the client gets a generic error and the partial write
    // expires via TTL.
    try {
      await env.RESEARCH_ANSWERS.put(
        `participants:${code}`,
        JSON.stringify({
          code, submittedAt, locale,
          recency: body.recency,
          available: body.available,
          timezone,
          locus
        }),
        { expirationTtl: TTL_SECONDS }
      );
      await env.RESEARCH_CONTACTS.put(
        `contacts:${code}`,
        JSON.stringify({ code, submittedAt, email }),
        { expirationTtl: TTL_SECONDS }
      );
    } catch (err) {
      return new Response(JSON.stringify({ error: 'storage_failed' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(env, origin) }
      });
    }

    return new Response(
      JSON.stringify({ participant_code: code }),
      {
        status: 201,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(env, origin) }
      }
    );
  }
};
