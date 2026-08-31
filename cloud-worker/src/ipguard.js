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

const enc = new TextEncoder();

async function hashIp(ip) {
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(ip || "unknown"));
  // 64 bits is plenty to bucket an IP without collisions.
  return [...new Uint8Array(digest)].slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join("");
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
  const h = await hashIp(ip);
  return { ipKey: `ipa:${isWeb ? "web" : "app"}:${h}:${day}`, ipLimit, isWeb, day };
}
