// Session token — Track M M.1 (v1.3).
// ---------------------------------------------------------------------------
// A compact, stateless, HMAC-signed bearer minted by /v1/auth after the client's
// Apple Pro transaction JWS is verified. The client then sends it on the v2 cloud
// path; the Worker validates it (HMAC + expiry) with NO KV/DO lookup. It carries
// only a HASH of the Apple originalTransactionId (never the raw Apple id), so the
// Pro quota can be keyed on a stable account identity instead of the spoofable
// deviceId — without the Worker persisting any Apple identifier.
//
// Format: base64url(JSON payload) + "." + base64url(HMAC-SHA256 over the payload
// segment). Web Crypto only → identical on the Workers runtime and under
// `node --test`.

const enc = new TextEncoder();
const dec = new TextDecoder();

function b64urlFromBytes(bytes) {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlToBytes(s) {
  if (typeof s !== "string") throw new Error("not a string");
  let t = s.replace(/-/g, "+").replace(/_/g, "/");
  const pad = t.length % 4;
  if (pad) t += "=".repeat(4 - pad);
  const bin = atob(t);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function hmacKey(secret) {
  return crypto.subtle.importKey(
    "raw", enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]
  );
}

/** Hex SHA-256 of a string (used to hash the Apple originalTransactionId). */
export async function sha256Hex(str) {
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(str));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Mint a signed session token. `claims` is a plain object; callers set at least
 * `{ sub, pro, iat, exp }` where `exp` is a ms-epoch expiry.
 */
export async function mintSessionToken(claims, secret) {
  if (!secret) throw new Error("missing signing secret");
  const payload = b64urlFromBytes(enc.encode(JSON.stringify(claims)));
  const key = await hmacKey(secret);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(payload)));
  return `${payload}.${b64urlFromBytes(sig)}`;
}

/**
 * Verify a session token: constant-time HMAC check (via SubtleCrypto.verify) +
 * expiry. Returns { valid, claims?, reason? }. Never throws.
 */
export async function verifySessionToken(token, secret, nowMs = Date.now()) {
  if (!secret) return { valid: false, reason: "server_misconfigured" };
  if (typeof token !== "string") return { valid: false, reason: "malformed" };
  const dot = token.indexOf(".");
  if (dot <= 0 || dot === token.length - 1) return { valid: false, reason: "malformed" };
  const payload = token.slice(0, dot);
  const sigPart = token.slice(dot + 1);
  let sigBytes;
  try { sigBytes = b64urlToBytes(sigPart); } catch { return { valid: false, reason: "malformed" }; }
  const key = await hmacKey(secret);
  let ok;
  try { ok = await crypto.subtle.verify("HMAC", key, sigBytes, enc.encode(payload)); }
  catch { return { valid: false, reason: "malformed" }; }
  if (!ok) return { valid: false, reason: "bad_signature" };
  let claims;
  try { claims = JSON.parse(dec.decode(b64urlToBytes(payload))); }
  catch { return { valid: false, reason: "malformed" }; }
  if (typeof claims.exp !== "number" || claims.exp <= nowMs) {
    return { valid: false, reason: "expired" };
  }
  return { valid: true, claims };
}
