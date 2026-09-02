import test from "node:test";
import assert from "node:assert/strict";
import { consumeQuota, refundQuota, quotaBackendIsDO } from "../src/quota.js";

/** Minimal KV double. `putFails` reproduces KV's same-key 429. */
function fakeKV(initial = {}, { putFails = false } = {}) {
  const store = new Map(Object.entries(initial));
  return {
    puts: 0,
    async get(k) { return store.has(k) ? store.get(k) : null; },
    async put(k, v) {
      this.puts++;
      if (putFails) throw new Error("KV PUT failed: 429 Too Many Requests");
      store.set(k, v);
    },
    _store: store,
  };
}

/** DO namespace double backed by an in-process counter, so `consume` is
 *  genuinely serialised the way a real DO instance would be. */
function fakeDO({ throws = false } = {}) {
  const counts = new Map();
  return {
    calls: 0,
    idFromName(name) { return { name }; },
    get(id) {
      const ns = this;
      return {
        async consume(limit) {
          ns.calls++;
          if (throws) throw new Error("DO unreachable");
          const used = counts.get(id.name) || 0;
          if (used >= limit) return { allowed: false, used, remaining: 0 };
          counts.set(id.name, used + 1);
          return { allowed: true, used: used + 1, remaining: limit - (used + 1) };
        },
        async refund() {
          if (throws) throw new Error("DO unreachable");
          const used = counts.get(id.name) || 0;
          if (used > 0) counts.set(id.name, used - 1);
        },
      };
    },
    _counts: counts,
  };
}

test("quotaBackendIsDO requires BOTH the flag and the binding", () => {
  assert.equal(quotaBackendIsDO({ QUOTA_BACKEND: "do", QUOTA: {} }), true);
  assert.equal(quotaBackendIsDO({ QUOTA_BACKEND: "do" }), false, "flag without a binding must not claim DO");
  assert.equal(quotaBackendIsDO({ QUOTA_BACKEND: "kv", QUOTA: {} }), false);
  assert.equal(quotaBackendIsDO({ QUOTA: {} }), false, "default is kv");
  assert.equal(quotaBackendIsDO({ QUOTA_BACKEND: "DO", QUOTA: {} }), true, "case-insensitive");
  assert.equal(quotaBackendIsDO(undefined), false);
});

test("DO path: concurrent same-key consumes never exceed the cap", async () => {
  // The whole point of D2. Under KV this over-granted ~73%.
  const env = { QUOTA_BACKEND: "do", QUOTA: fakeDO(), RATE_LIMITS: fakeKV() };
  const results = await Promise.all(
    Array.from({ length: 55 }, () =>
      consumeQuota({ env, ctx: null, key: "rl:dev:2026-09-02", limit: 30, label: "t" }))
  );
  const allowed = results.filter((r) => r.allowed);
  assert.equal(allowed.length, 30, "an atomic counter must allow exactly the cap");
  assert.equal(results.length - allowed.length, 25);
  assert.ok(results.every((r) => r.backend === "do"));

  // Every granted unit must have a DISTINCT position — the KV bug was that
  // all of them reported the same `remaining`.
  const used = allowed.map((r) => r.used).sort((a, b) => a - b);
  assert.deepEqual(used, Array.from({ length: 30 }, (_, i) => i + 1));
});

test("DO path: separate keys get separate buckets", async () => {
  const env = { QUOTA_BACKEND: "do", QUOTA: fakeDO(), RATE_LIMITS: fakeKV() };
  for (let i = 0; i < 30; i++) {
    await consumeQuota({ env, ctx: null, key: "a", limit: 30, label: "t" });
  }
  const a = await consumeQuota({ env, ctx: null, key: "a", limit: 30, label: "t" });
  const b = await consumeQuota({ env, ctx: null, key: "b", limit: 30, label: "t" });
  assert.equal(a.allowed, false, "key a is exhausted");
  assert.equal(b.allowed, true, "key b is untouched");
});

test("DO failure falls back to KV instead of erroring or blocking", async () => {
  const logs = [];
  const kv = fakeKV();
  const env = { QUOTA_BACKEND: "do", QUOTA: fakeDO({ throws: true }), RATE_LIMITS: kv };
  const r = await consumeQuota(
    { env, ctx: null, key: "k", limit: 5, label: "vent_quota" },
    (_e, _c, f) => logs.push(f));
  assert.equal(r.allowed, true, "a substrate outage must not block a paying user");
  assert.equal(r.backend, "kv");
  assert.equal(logs[0].outcome, "do_failed_fallback_kv");
  assert.equal(logs[0].counter, "vent_quota");
});

test("KV path still enforces the cap sequentially", async () => {
  const env = { QUOTA_BACKEND: "kv", RATE_LIMITS: fakeKV({ k: "5" }) };
  const r = await consumeQuota({ env, ctx: null, key: "k", limit: 5, label: "t" });
  assert.equal(r.allowed, false);
  assert.equal(r.remaining, 0);
});

test("KV put failure is logged, not thrown — it used to 500 real users", async () => {
  const logs = [];
  const env = { QUOTA_BACKEND: "kv", RATE_LIMITS: fakeKV({}, { putFails: true }) };
  const r = await consumeQuota(
    { env, ctx: null, key: "ipa:app:h:2026-09-02", limit: 200, label: "vent_ip" },
    (_e, _c, f) => logs.push(f));
  assert.equal(r.allowed, true, "a dropped increment beats a 500");
  assert.equal(logs[0].outcome, "counter_write_failed");
  assert.match(logs[0].detail, /429/);
});

test("refund returns a reserved unit on the DO path", async () => {
  const env = { QUOTA_BACKEND: "do", QUOTA: fakeDO(), RATE_LIMITS: fakeKV() };
  const a = await consumeQuota({ env, ctx: null, key: "k", limit: 2, label: "t" });
  const b = await consumeQuota({ env, ctx: null, key: "k", limit: 2, label: "t" });
  assert.equal(b.allowed, true);
  assert.equal((await consumeQuota({ env, ctx: null, key: "k", limit: 2, label: "t" })).allowed,
               false, "cap reached");

  await refundQuota({ env, ctx: null, key: "k", backend: "do", label: "t" });
  assert.equal((await consumeQuota({ env, ctx: null, key: "k", limit: 2, label: "t" })).allowed,
               true, "a refunded unit becomes available again");
  assert.ok(a.allowed);
});

test("refund on the KV path decrements and never goes below zero", async () => {
  const kv = fakeKV({ k: "1" });
  const env = { RATE_LIMITS: kv };
  await refundQuota({ env, ctx: null, key: "k", backend: "kv", label: "t" });
  assert.equal(kv._store.get("k"), "0");
  await refundQuota({ env, ctx: null, key: "k", backend: "kv", label: "t" });
  assert.equal(kv._store.get("k"), "0", "must not go negative");
});

test("refund failure is swallowed and logged", async () => {
  const logs = [];
  const env = { QUOTA: fakeDO({ throws: true }) };
  await refundQuota({ env, ctx: null, key: "k", backend: "do", label: "t" },
                    (_e, _c, f) => logs.push(f));
  assert.equal(logs[0].outcome, "refund_failed", "a failed refund must never break the response");
});
