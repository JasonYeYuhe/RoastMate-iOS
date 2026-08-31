// App Store Server API — subscription status check (Track M, refund hardening).
// ---------------------------------------------------------------------------
// The offline JWS check at /v1/auth can't see a refund/revocation that happens
// AFTER the JWS was minted (a refunded yearly sub would keep Pro for up to a
// year). This adds a CURRENT-status check via Apple's App Store Server API
// (GET /inApps/v1/subscriptions/{transactionId}) so a revoked/expired sub is
// rejected. Workers-native: the ASC JWT is signed with Web Crypto (ECDSA P-256 —
// which returns raw r||s, exactly JWS ES256 format) and Apple is called with the
// platform `fetch`; no node libraries. Result cached briefly to bound round-trips.
//
// GATED (ASS_API_ENABLED) + FAIL-OPEN: if the check can't run (no key, Apple
// error, network), it returns null and the caller keeps the JWS-only decision —
// it never blocks a legitimately-verified Pro user. Only an explicit
// revoked/expired status denies.

import { sha256Hex } from "./session.js";

const te = new TextEncoder();

function b64url(bytes) {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
const b64urlJson = (obj) => b64url(te.encode(JSON.stringify(obj)));

async function importP8(pem) {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

/** Mint an App Store Server API JWT (ES256, with the required `bid` claim). */
export async function signAscJwt(env, nowSec = Math.floor(Date.now() / 1000)) {
  const key = await importP8(env.ASC_SIGNING_KEY);
  const header = { alg: "ES256", kid: env.ASC_KEY_ID, typ: "JWT" };
  const payload = {
    iss: env.ASC_ISSUER_ID,
    iat: nowSec,
    exp: nowSec + 600,
    aud: "appstoreconnect-v1",
    bid: env.APP_BUNDLE_ID || "yyh.roastmate.app",
  };
  const signingInput = `${b64urlJson(header)}.${b64urlJson(payload)}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, te.encode(signingInput));
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

// Apple subscription status codes.
const STATUS_ACTIVE = 1;
const STATUS_GRACE = 4;

/**
 * PURE: given a Get-All-Subscription-Statuses response body + the transaction's
 * originalTransactionId, is the subscription currently active (or in billing
 * grace)? Returns true/false, or null if the response has no matching entry.
 */
export function subscriptionActiveFromStatus(data, originalTransactionId) {
  if (!data || !Array.isArray(data.data)) return null;
  let seen = false;
  for (const group of data.data) {
    for (const t of group.lastTransactions || []) {
      if (t.originalTransactionId === originalTransactionId) {
        seen = true;
        if (t.status === STATUS_ACTIVE || t.status === STATUS_GRACE) return true;
      }
    }
  }
  return seen ? false : null;
}

/**
 * Check current subscription status against Apple. Returns:
 *   true  → active/grace, false → revoked/expired, null → couldn't determine
 * (missing config, Apple error, no matching entry) → caller FAILS OPEN.
 * Result cached in KV for `ASS_API_CACHE_SEC` (default 300s).
 */
export async function checkSubscriptionActive(originalTransactionId, env, ctx) {
  if (!env || !env.ASC_SIGNING_KEY || !env.ASC_KEY_ID || !env.ASC_ISSUER_ID) return null;
  const cacheKey = `substat:${await sha256Hex(originalTransactionId)}`;
  try {
    const cached = env.RATE_LIMITS ? await env.RATE_LIMITS.get(cacheKey) : null;
    if (cached === "active") return true;
    if (cached === "inactive") return false;
  } catch (_e) { /* cache miss/err → query */ }

  let active;
  try {
    const jwt = await signAscJwt(env);
    const host = (env.ASC_ENV || "production") === "sandbox"
      ? "api.storekit-sandbox.itunes.apple.com"
      : "api.storekit.itunes.apple.com";
    const res = await fetch(`https://${host}/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    if (!res.ok) return null; // fail open
    active = subscriptionActiveFromStatus(await res.json(), originalTransactionId);
  } catch (_e) {
    return null; // network/crypto error → fail open
  }
  if (active === null) return null;
  const ttl = parseInt(env.ASS_API_CACHE_SEC || "300", 10);
  const write = env.RATE_LIMITS
    ? env.RATE_LIMITS.put(cacheKey, active ? "active" : "inactive", { expirationTtl: Math.max(60, ttl) })
    : Promise.resolve();
  if (ctx && typeof ctx.waitUntil === "function") ctx.waitUntil(write.catch(() => {}));
  else await write.catch(() => {});
  return active;
}
