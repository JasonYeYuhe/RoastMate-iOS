// /v1/auth — Track M M.1 (v1.3).
// ---------------------------------------------------------------------------
// Exchanges the client's Apple-signed Pro transaction JWS
// (Transaction.jwsRepresentation) for a short-lived, account-bound session
// token. The heavy x5c/JWS verification happens ONCE here (not on every
// generation), so the hot /v1/vent path only checks a cheap HMAC token.
//
// `verifier` is injected: in production it's the real Apple SignedDataVerifier
// (see verifier.js); in tests it's a double exposing the same
// `verifyAndDecodeTransaction(jws)` contract. This keeps the handler's
// entitlement/token logic unit-testable without a real Apple JWS.

import { mintSessionToken, sha256Hex } from "./session.js";

// Pro product IDs — must stay in sync with StoreService.swift
// (monthlyProductId / yearlyProductId).
export const PRO_PRODUCT_IDS = new Set([
  "yyh.roastmate.app.pro.monthly",
  "yyh.roastmate.app.pro.yearly",
]);

// Session token lifetime cap. The token is additionally never valid past the
// subscription's own expiresDate, so a lapsed sub can't outlive its period even
// within this window.
export const SESSION_MAX_MS = 60 * 60 * 1000; // 1 hour

function authJson(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}

/**
 * Handle POST /v1/auth.
 * @param {Request} request
 * @param {object} env    - Worker env (needs SESSION_SIGNING_KEY secret).
 * @param {object} _ctx   - reserved (ddLog/waitUntil later).
 * @param {{verifyAndDecodeTransaction:(jws:string)=>Promise<object>}} verifier
 * @param {number} nowMs  - injectable clock for tests.
 */
export async function handleAuth(request, env, _ctx, verifier, nowMs = Date.now()) {
  let body;
  try { body = await request.json(); }
  catch { return authJson({ error: "invalid_json" }, 400); }

  const jws = body && body.jws;
  if (typeof jws !== "string" || jws.length < 20 || jws.length > 20000) {
    return authJson({ error: "invalid_jws" }, 400);
  }

  // Verify signature + x5c chain to Apple root + bundleId + environment.
  // Any failure → 401, details never echoed (they can contain identifiers).
  let tx;
  try { tx = await verifier.verifyAndDecodeTransaction(jws); }
  catch { return authJson({ error: "verification_failed" }, 401); }
  if (!tx || typeof tx !== "object") {
    return authJson({ error: "verification_failed" }, 401);
  }

  // Entitlement checks on the VERIFIED payload.
  if (!PRO_PRODUCT_IDS.has(tx.productId)) {
    return authJson({ error: "not_pro" }, 403);
  }
  const expiresMs = typeof tx.expiresDate === "number" ? tx.expiresDate : 0;
  if (expiresMs <= nowMs) {
    return authJson({ error: "expired" }, 403);
  }
  const originalTransactionId = tx.originalTransactionId;
  if (typeof originalTransactionId !== "string" || originalTransactionId.length === 0) {
    return authJson({ error: "verification_failed" }, 401);
  }

  const secret = env && env.SESSION_SIGNING_KEY;
  if (!secret) {
    // Never mint an unsigned/forgeable token — fail closed on misconfig.
    return authJson({ error: "server_misconfigured" }, 500);
  }

  // Key Pro quota on a HASH of the Apple account identity (originalTransactionId),
  // NOT the spoofable deviceId → replaying one JWS across cloned devices shares
  // one quota bucket. The raw Apple id never leaves this function.
  const sub = await sha256Hex(originalTransactionId);
  const exp = Math.min(expiresMs, nowMs + SESSION_MAX_MS);
  const token = await mintSessionToken({ sub, pro: true, iat: nowMs, exp }, secret);
  return authJson({ token, expiresAt: exp }, 200);
}
