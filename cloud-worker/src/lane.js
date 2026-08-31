// Vent lane resolution — Track M M.1 v2 (v1.3).
// ---------------------------------------------------------------------------
// An `Authorization: Bearer <session token>` (minted by /v1/auth after Apple-JWS
// verification) upgrades a /v1/vent request to the authenticated PRO lane: the
// daily quota is keyed on the ACCOUNT (the token's `sub` = hash of
// originalTransactionId) with the Pro cap — so one Pro subscription shares one
// bucket across the user's devices, and a replayed token can't multiply quota by
// spoofing deviceIds. No token → the LEGACY per-device lane (live build 17 + free
// users), byte-for-byte unchanged. A token that's present but invalid/expired is
// REJECTED (401) so the client re-auths via /v1/auth — never silently downgraded,
// which would mask a broken auth path and hand Pro users the free cap.

import { verifySessionToken } from "./session.js";

/**
 * @param {object} p
 * @param {string|null} p.authorization  - the request Authorization header
 * @param {string} p.deviceId            - validated deviceId (legacy lane key)
 * @param {object} p.env                 - Worker env
 * @param {number} [p.nowMs]             - injectable clock
 * @returns {Promise<{lane,isPro,rlKey,limit,day} | {error,reason,status}>}
 */
export async function resolveVentLane({ authorization, deviceId, env, nowMs = Date.now() }) {
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const authz = typeof authorization === "string" ? authorization : "";

  if (authz.startsWith("Bearer ")) {
    const token = authz.slice(7).trim();
    const v = await verifySessionToken(token, env?.SESSION_SIGNING_KEY, nowMs);
    if (!v.valid) {
      return { error: "token_invalid", reason: v.reason, status: 401 };
    }
    if (v.claims?.pro === true && typeof v.claims.sub === "string" && v.claims.sub.length > 0) {
      return {
        lane: "pro",
        isPro: true,
        rlKey: `rl:pro:${v.claims.sub}:${day}`,
        limit: parseInt(env?.PRO_DAILY_LIMIT || "200", 10),
        day,
      };
    }
    // Valid token but not a Pro grant (defensive — /v1/auth only mints pro:true):
    // fall through to the free lane rather than granting the Pro cap.
  }

  return {
    lane: "free",
    isPro: false,
    // Namespaced `rl:free:` so a chosen deviceId can never collide with a Pro
    // key `rl:pro:<sub>` and eat a legit Pro user's quota (P2).
    rlKey: `rl:free:${deviceId}:${day}`,
    limit: parseInt(env?.DAILY_LIMIT_PER_DEVICE || "30", 10),
    day,
  };
}
