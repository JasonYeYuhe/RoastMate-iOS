import { test } from "node:test";
import assert from "node:assert/strict";
import { resolveIpAttemptCap } from "../src/ipguard.js";

const NOW = 1_800_000_000_000;
const DAY = new Date(NOW).toISOString().slice(0, 10);
const ENV = { WEB_DAILY_LIMIT_PER_IP: "8", APP_DAILY_LIMIT_PER_IP: "200" };

test("native app (no browser Origin) → generous app cap", async () => {
  const g = await resolveIpAttemptCap({ origin: null, ip: "203.0.113.7", env: ENV, nowMs: NOW });
  assert.equal(g.isWeb, false);
  assert.equal(g.ipLimit, 200);
  assert.match(g.ipKey, new RegExp(`^ipa:app:[0-9a-f]{16}:${DAY}$`));
});

test("web demo (github.io Origin) → strict web cap", async () => {
  const g = await resolveIpAttemptCap({ origin: "https://jasonyeyuhe.github.io", ip: "203.0.113.7", env: ENV, nowMs: NOW });
  assert.equal(g.isWeb, true);
  assert.equal(g.ipLimit, 8);
  assert.match(g.ipKey, /^ipa:web:[0-9a-f]{16}:/);
});

test("IP is hashed — never appears raw in the key", async () => {
  const ip = "198.51.100.42";
  const g = await resolveIpAttemptCap({ origin: null, ip, env: ENV, nowMs: NOW });
  assert.ok(!g.ipKey.includes(ip), "raw IP must not be stored in the KV key");
});

test("same IP → same key; different IP → different key", async () => {
  const a = await resolveIpAttemptCap({ origin: null, ip: "1.2.3.4", env: ENV, nowMs: NOW });
  const a2 = await resolveIpAttemptCap({ origin: null, ip: "1.2.3.4", env: ENV, nowMs: NOW });
  const b = await resolveIpAttemptCap({ origin: null, ip: "5.6.7.8", env: ENV, nowMs: NOW });
  assert.equal(a.ipKey, a2.ipKey);
  assert.notEqual(a.ipKey, b.ipKey);
});

test("env caps override the defaults", async () => {
  const env2 = { WEB_DAILY_LIMIT_PER_IP: "3", APP_DAILY_LIMIT_PER_IP: "500" };
  const web = await resolveIpAttemptCap({ origin: "x.jasonyeyuhe.github.io", ip: "1.1.1.1", env: env2, nowMs: NOW });
  const app = await resolveIpAttemptCap({ origin: null, ip: "1.1.1.1", env: env2, nowMs: NOW });
  assert.equal(web.ipLimit, 3);
  assert.equal(app.ipLimit, 500);
  // same IP, different lane → different bucket (web vs app)
  assert.notEqual(web.ipKey, app.ipKey);
});

test("missing IP falls back to a stable 'unknown' bucket", async () => {
  const g = await resolveIpAttemptCap({ origin: null, ip: null, env: ENV, nowMs: NOW });
  const g2 = await resolveIpAttemptCap({ origin: null, ip: undefined, env: ENV, nowMs: NOW });
  assert.equal(g.ipKey, g2.ipKey);
});

test("defaults apply when env is empty (8 web / 200 app)", async () => {
  const web = await resolveIpAttemptCap({ origin: "https://jasonyeyuhe.github.io", ip: "1.1.1.1", env: {}, nowMs: NOW });
  const app = await resolveIpAttemptCap({ origin: null, ip: "1.1.1.1", env: {}, nowMs: NOW });
  assert.equal(web.ipLimit, 8);
  assert.equal(app.ipLimit, 200);
});
