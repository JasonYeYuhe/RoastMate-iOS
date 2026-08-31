import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { subscriptionActiveFromStatus, signAscJwt } from "../src/appstore_status.js";

test("subscriptionActiveFromStatus: active/grace→true, revoked/expired→false, no-match→null", () => {
  const mk = (status) => ({ data: [{ lastTransactions: [{ originalTransactionId: "T1", status }] }] });
  assert.equal(subscriptionActiveFromStatus(mk(1), "T1"), true);   // active
  assert.equal(subscriptionActiveFromStatus(mk(4), "T1"), true);   // billing grace
  assert.equal(subscriptionActiveFromStatus(mk(2), "T1"), false);  // expired
  assert.equal(subscriptionActiveFromStatus(mk(3), "T1"), false);  // billing retry
  assert.equal(subscriptionActiveFromStatus(mk(5), "T1"), false);  // revoked (refund)
  assert.equal(subscriptionActiveFromStatus(mk(1), "OTHER"), null); // no matching txn → unknown
  assert.equal(subscriptionActiveFromStatus({}, "T1"), null);
  assert.equal(subscriptionActiveFromStatus(null, "T1"), null);
});

const decode = (seg) =>
  JSON.parse(Buffer.from(seg.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString());

test("signAscJwt produces a valid ES256 JWT with the required App Store Server claims", async () => {
  const { privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" });
  const env = {
    ASC_SIGNING_KEY: pem, ASC_KEY_ID: "KID123",
    ASC_ISSUER_ID: "issuer-x", APP_BUNDLE_ID: "yyh.roastmate.app",
  };
  const jwt = await signAscJwt(env, 1000);
  const [h, p, s] = jwt.split(".");
  assert.equal(decode(h).alg, "ES256");
  assert.equal(decode(h).kid, "KID123");
  const payload = decode(p);
  assert.equal(payload.iss, "issuer-x");
  assert.equal(payload.aud, "appstoreconnect-v1");
  assert.equal(payload.bid, "yyh.roastmate.app");
  assert.equal(payload.iat, 1000);
  assert.equal(payload.exp, 1600);
  // JWS ES256 signature is raw r||s = 64 bytes (NOT DER) — the common gotcha.
  const sigLen = Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64").length;
  assert.equal(sigLen, 64);
});
