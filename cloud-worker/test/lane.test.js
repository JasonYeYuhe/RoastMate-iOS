import { test } from "node:test";
import assert from "node:assert/strict";
import { resolveVentLane } from "../src/lane.js";
import { mintSessionToken, sha256Hex } from "../src/session.js";

const NOW = 1_800_000_000_000; // 2027-01-15T08:00:00Z
const DAY = new Date(NOW).toISOString().slice(0, 10);
const SECRET = "lane-test-secret";
const ENV = { SESSION_SIGNING_KEY: SECRET, DAILY_LIMIT_PER_DEVICE: "30", PRO_DAILY_LIMIT: "200" };
const DEVICE = "device-abc-123456";

async function proToken(overrides = {}) {
  const sub = await sha256Hex("1000000000000042");
  return {
    token: await mintSessionToken({ sub, pro: true, iat: NOW, exp: NOW + 60_000, ...overrides }, SECRET),
    sub,
  };
}

test("no Authorization header → free lane keyed on deviceId", async () => {
  const r = await resolveVentLane({ authorization: null, deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.lane, "free");
  assert.equal(r.isPro, false);
  assert.equal(r.rlKey, `rl:free:${DEVICE}:${DAY}`);
  assert.equal(r.limit, 30);
  assert.equal(r.day, DAY);
});

test("valid Pro token → pro lane keyed on the account sub + Pro cap", async () => {
  const { token, sub } = await proToken();
  const r = await resolveVentLane({ authorization: `Bearer ${token}`, deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.lane, "pro");
  assert.equal(r.isPro, true);
  assert.equal(r.rlKey, `rl:pro:${sub}:${DAY}`);
  assert.equal(r.limit, 200);
  // the deviceId does NOT appear in the Pro key (replay across devices shares one bucket)
  assert.ok(!r.rlKey.includes(DEVICE));
});

test("invalid (tampered) token → 401 token_invalid", async () => {
  const { token } = await proToken();
  const bad = token.slice(0, -2) + (token.slice(-2) === "AA" ? "BB" : "AA");
  const r = await resolveVentLane({ authorization: `Bearer ${bad}`, deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.error, "token_invalid");
  assert.equal(r.status, 401);
});

test("expired token → 401 (reason expired), never a silent downgrade to free", async () => {
  const { token } = await proToken({ exp: NOW - 1 });
  const r = await resolveVentLane({ authorization: `Bearer ${token}`, deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.error, "token_invalid");
  assert.equal(r.reason, "expired");
  assert.equal(r.status, 401);
});

test("non-Bearer Authorization → free lane (ignored)", async () => {
  const r = await resolveVentLane({ authorization: "Basic abc", deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.lane, "free");
});

test("valid token that is not a Pro grant → free lane (defensive)", async () => {
  const token = await mintSessionToken({ sub: "abc", pro: false, exp: NOW + 60_000 }, SECRET);
  const r = await resolveVentLane({ authorization: `Bearer ${token}`, deviceId: DEVICE, env: ENV, nowMs: NOW });
  assert.equal(r.lane, "free");
  assert.equal(r.rlKey, `rl:free:${DEVICE}:${DAY}`);
});

test("env caps are respected", async () => {
  const { token } = await proToken();
  const env2 = { SESSION_SIGNING_KEY: SECRET, DAILY_LIMIT_PER_DEVICE: "5", PRO_DAILY_LIMIT: "500" };
  const free = await resolveVentLane({ authorization: null, deviceId: DEVICE, env: env2, nowMs: NOW });
  assert.equal(free.limit, 5);
  const pro = await resolveVentLane({ authorization: `Bearer ${token}`, deviceId: DEVICE, env: env2, nowMs: NOW });
  assert.equal(pro.limit, 500);
});

test("token present but SESSION_SIGNING_KEY missing → 401 (fail closed, no Pro)", async () => {
  const { token } = await proToken();
  const r = await resolveVentLane({ authorization: `Bearer ${token}`, deviceId: DEVICE, env: {}, nowMs: NOW });
  assert.equal(r.error, "token_invalid");
  assert.equal(r.status, 401);
});
