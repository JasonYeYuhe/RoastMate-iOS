// Per-IP attempt cap — Track M M.2 (v1.3).
// ---------------------------------------------------------------------------
// A PRE-CHARGED (non-refundable), per-IP daily cap on EVERY /v1/vent request — a
// coarse abuse backstop the per-user quota can't provide: deviceId is trivially
// rotatable, so one actor could otherwise cycle device IDs for unlimited free
// cloud. Charging BEFORE the upstream call also bounds retry-floods during a
// provider outage (each attempt counts, success or failure).
//
// CGNAT-aware: carrier-grade NAT puts many legit users behind one IP, so the
// NATIVE-app cap is deliberately GENEROUS — it bounds a single home-IP abuser
// without blocking mobile users. The WEB demo (browser Origin) keeps a strict
// cap (abuse-prone, and browsers are far less CGNAT-shared than mobile).
//
// The IP is HASHED (never stored raw) — a privacy improvement over the old
// raw-IP web key. (Plain SHA-256; an HMAC-with-rotating-secret is a later
// hardening if the KV substrate ever needed it.)

import { hmacHex, sha256Hex } from "./session.js";

// Keyed hash when the server secret is available (HMAC — an IPv4's 4B space is
// trivially rainbow-reversed from a plain SHA-256); plain-hash fallback so the
// cap still works if the secret is ever absent (the web demo needs no auth).
async function hashIp(ip, secret) {
  const full = secret ? await hmacHex(ip || "unknown", secret) : await sha256Hex(ip || "unknown");
  return full.slice(0, 16); // 64 bits — plenty to bucket an IP
}

/**
 * @returns {Promise<{ipKey:string, ipLimit:number, isWeb:boolean, day:string}>}
 */
export async function resolveIpAttemptCap({ origin, ip, env, nowMs = Date.now() }) {
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const isWeb = (origin || "").includes("jasonyeyuhe.github.io");
  const ipLimit = isWeb
    ? parseInt(env?.WEB_DAILY_LIMIT_PER_IP || "8", 10)
    : parseInt(env?.APP_DAILY_LIMIT_PER_IP || "200", 10);
  const h = await hashIp(ip, env?.SESSION_SIGNING_KEY);
  return { ipKey: `ipa:${isWeb ? "web" : "app"}:${h}:${day}`, ipLimit, isWeb, day };
}
