import { test } from "node:test";
import assert from "node:assert/strict";
import { handleAuth } from "../src/auth.js";
import { verifySessionToken, sha256Hex } from "../src/session.js";

const NOW = 1_800_000_000_000;
const ENV = { SESSION_SIGNING_KEY: "unit-test-secret" };
const OTX = "1000000000000042";

// A verified Pro transaction as the real SignedDataVerifier would decode it.
function proTx(overrides = {}) {
  return {
    productId: "yyh.roastmate.app.pro.monthly",
    originalTransactionId: OTX,
    expiresDate: NOW + 30 * 24 * 60 * 60 * 1000,
    type: "Auto-Renewable Subscription",
    ...overrides,
  };
}

// Verifier doubles matching the injected contract.
const okVerifier = (tx = proTx()) => ({ async verifyAndDecodeTransaction() { return tx; } });
const throwingVerifier = { async verifyAndDecodeTransaction() { throw new Error("bad signature"); } };

function authReq(bodyObj, { raw } = {}) {
  return new Request("https://w/v1/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: raw !== undefined ? raw : JSON.stringify(bodyObj),
  });
}
const JWS = "x".repeat(120); // opaque; the fake verifier ignores it

async function bodyOf(res) { return JSON.parse(await res.text()); }

test("valid Pro JWS → 200 + a token bound to hash(originalTransactionId)", async () => {
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(), NOW);
  assert.equal(res.status, 200);
  const { token, expiresAt } = await bodyOf(res);
  assert.ok(typeof token === "string" && token.includes("."));
  // capped at 1h even though the sub lasts 30 days
  assert.equal(expiresAt, NOW + 60 * 60 * 1000);
  const v = await verifySessionToken(token, ENV.SESSION_SIGNING_KEY, NOW);
  assert.equal(v.valid, true);
  assert.equal(v.claims.pro, true);
  assert.equal(v.claims.sub, await sha256Hex(OTX)); // hashed, never the raw id
});

test("token expiry is min(sub expiry, +1h)", async () => {
  const soon = NOW + 5 * 60 * 1000; // sub expires in 5 min
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(proTx({ expiresDate: soon })), NOW);
  const { expiresAt } = await bodyOf(res);
  assert.equal(expiresAt, soon);
});

test("invalid JSON body → 400", async () => {
  const res = await handleAuth(authReq(null, { raw: "not json" }), ENV, null, okVerifier(), NOW);
  assert.equal(res.status, 400);
  assert.equal((await bodyOf(res)).error, "invalid_json");
});

test("missing / too-short jws → 400 invalid_jws", async () => {
  for (const jws of [undefined, "", "short", 12345]) {
    const res = await handleAuth(authReq({ jws }), ENV, null, okVerifier(), NOW);
    assert.equal(res.status, 400, `jws=${String(jws)}`);
    assert.equal((await bodyOf(res)).error, "invalid_jws");
  }
});

test("verifier throws (bad signature/chain/bundle) → 401, no detail leaked", async () => {
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, throwingVerifier, NOW);
  assert.equal(res.status, 401);
  const b = await bodyOf(res);
  assert.equal(b.error, "verification_failed");
  assert.ok(!("detail" in b));
});

test("non-Pro productId → 403 not_pro", async () => {
  const tx = proTx({ productId: "yyh.roastmate.app.credits.70" });
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(tx), NOW);
  assert.equal(res.status, 403);
  assert.equal((await bodyOf(res)).error, "not_pro");
});

test("expired subscription → 403 expired", async () => {
  const tx = proTx({ expiresDate: NOW - 1 });
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(tx), NOW);
  assert.equal(res.status, 403);
  assert.equal((await bodyOf(res)).error, "expired");
});

test("missing expiresDate → 403 expired (fail closed)", async () => {
  const tx = proTx({ expiresDate: undefined });
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(tx), NOW);
  assert.equal(res.status, 403);
});

test("missing originalTransactionId → 401", async () => {
  const tx = proTx({ originalTransactionId: "" });
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(tx), NOW);
  assert.equal(res.status, 401);
});

test("missing SESSION_SIGNING_KEY → 500 (never mint an unsigned token)", async () => {
  const res = await handleAuth(authReq({ jws: JWS }), {}, null, okVerifier(), NOW);
  assert.equal(res.status, 500);
  assert.equal((await bodyOf(res)).error, "server_misconfigured");
});

test("a yearly Pro sub is also accepted", async () => {
  const tx = proTx({ productId: "yyh.roastmate.app.pro.yearly" });
  const res = await handleAuth(authReq({ jws: JWS }), ENV, null, okVerifier(tx), NOW);
  assert.equal(res.status, 200);
});
