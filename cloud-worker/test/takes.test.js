// 1.9.0 Q2a: Pro 痛罵 (Feral) gets up to 3 takes. Only the authenticated Pro
// lane; the free lane, Vent and old binaries (no variantCount) keep 1 draft
// and the exact response shape they had.
import { registerHooks } from "node:module";
import { test, afterEach } from "node:test";
import assert from "node:assert/strict";

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "cloudflare:workers") {
      return { url: "data:text/javascript,export class DurableObject {}", shortCircuit: true };
    }
    return nextResolve(specifier, context);
  }
});
const worker = (await import("../src/index.js")).default;
const { mintSessionToken } = await import("../src/session.js");
const { nearDuplicate, takeNudge } = await import("../src/postprocess.js");

const SECRET = "takes-test-secret";
const realFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = realFetch; });

function kv() {
  const m = new Map();
  return { async get(k) { return m.has(k) ? m.get(k) : null; }, async put(k, v) { m.set(k, v); } };
}
const env = () => ({ OPENROUTER_API_KEY: "k", DEFAULT_MODEL: "a/primary", FALLBACK_MODELS: "b/fallback",
                     RATE_LIMITS: kv(), SESSION_SIGNING_KEY: SECRET });
async function proToken() {
  return mintSessionToken({ sub: "acct", pro: true, iat: Date.now(), exp: Date.now() + 600_000 }, SECRET);
}
function stub(replies) {
  const calls = [];
  globalThis.fetch = async (_u, init) => {
    const body = JSON.parse(init.body);
    calls.push(body);
    const content = typeof replies === "function" ? replies(calls.length - 1, body) : replies[calls.length - 1] ?? replies.at(-1);
    return new Response(JSON.stringify({ model: "a/primary", choices: [{ message: { content } }] }),
                        { status: 200, headers: { "Content-Type": "application/json" } });
  };
  return calls;
}
async function post(body, { token, e = env() } = {}) {
  const headers = { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.8" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const req = new Request("https://worker.test/v1/vent", { method: "POST", headers,
    body: JSON.stringify({ deviceId: "takes-test-device", styleName: "Savage", styleId: "savage_no_filter", locale: "en_US", ...body }) });
  const res = await worker.fetch(req, e, { waitUntil() {} });
  return { status: res.status, json: await res.json() };
}
const SIT = "My coworker took credit for my slides in the team meeting and my manager praised him.";
const TAKES = [
  "You stood up in that meeting and called my slides yours, you lying prick.",
  "You told the manager it was your idea, like I wasn't sitting right there. Bullshit.",
  "Two weeks of my nights went into those slides and you cashed them in for a pat on the head, asshole.",
];

test("Pro lane + Feral + variantCount 3: three upstream calls, texts has three takes, text is the first", async () => {
  const calls = stub((i, body) => {
    const u = body.messages[1].content;
    return u.includes("second, separate take") ? TAKES[1] : u.includes("third, separate take") ? TAKES[2] : TAKES[0];
  });
  const { status, json } = await post({ situation: SIT, intensity: "feral", variantCount: 3 }, { token: await proToken() });
  assert.equal(status, 200);
  assert.equal(calls.length, 3);
  assert.deepEqual(json.texts, TAKES, "the single-draft prompt's answer first, then takes 2 and 3");
  assert.equal(json.text, json.texts[0]);
  // takes 2 and 3 carry their own angle; the first prompt is the single-draft prompt
  const users = calls.map((c) => c.messages[1].content);
  assert.equal(users.filter((u) => !u.includes("separate take")).length, 1, "one single-draft prompt");
  assert.equal(new Set(calls.map((c) => c.messages[0].content)).size, 1, "one system prompt for every take");
  assert.equal(users.filter((u) => u.includes("separate take")).length, 2);
});

test("free lane (no token): variantCount is ignored — one call, no texts field", async () => {
  const calls = stub(TAKES);
  const { status, json } = await post({ situation: SIT, intensity: "feral", variantCount: 3 });
  assert.equal(status, 200);
  assert.equal(calls.length, 1);
  assert.equal(json.texts, undefined);
  assert.equal(json.text, TAKES[0]);
});

test("Pro lane + Vent (發洩): still one draft", async () => {
  const calls = stub(TAKES);
  const { json } = await post({ situation: SIT, intensity: "vent", variantCount: 3 }, { token: await proToken() });
  assert.equal(calls.length, 1);
  assert.equal(json.texts, undefined);
});

test("Pro lane + Feral without variantCount (1.8.0 clients): one draft, unchanged shape", async () => {
  const calls = stub(TAKES);
  const { json } = await post({ situation: SIT, intensity: "feral" }, { token: await proToken() });
  assert.equal(calls.length, 1);
  assert.deepEqual(Object.keys(json).sort(), ["model", "provider", "remaining", "text"]);
});

test("a take with a defect or a near-duplicate of an earlier take is dropped, never retried", async () => {
  const zhSit = "同事陳志明在週會上說我做的簡報是他做的。";
  const first = "你在週會上把我做了兩個禮拜的簡報說成你的，臉皮是有多厚，王八蛋。";
  const calls = stub((i, body) => {
    const u = body.messages[1].content;
    if (u.includes("second, separate take")) return "你这个烂人，简报明明是我做的，还好意思领功劳。";  // Simplified in zh-Hant → dropped
    if (u.includes("third, separate take")) return first + "幹。";                         // near-duplicate → dropped
    return first;
  });
  const { json } = await post({ situation: zhSit, intensity: "feral", variantCount: 3, locale: "zh_TW", styleName: "硬核回擊" },
                              { token: await proToken() });
  assert.equal(calls.length, 3, "no retry for a dropped take");
  assert.deepEqual(json.texts, [first]);
});

test("variantCount is capped at 3 for vent mode", async () => {
  const calls = stub((i) => TAKES[i % 3] + ` (${i})`);
  await post({ situation: SIT, intensity: "feral", variantCount: 5 }, { token: await proToken() });
  assert.equal(calls.length, 3);
});

test("nearDuplicate uses the bench thresholds", () => {
  assert.ok(nearDuplicate("梯子借走三個月了，你家的燈應該早就換好了吧。", "梯子借走三個月了，你家的燈應該早就換好了吧！", "zh_TW"));
  assert.ok(!nearDuplicate("梯子借走三個月了，你家的燈應該早就換好了吧。", "群組已讀不回，限時動態倒是一小時發三則。", "zh_TW"));
  assert.ok(nearDuplicate("You borrowed the ladder in March and never brought it back.",
                          "You borrowed the ladder in March and never returned it.", "en_US"));
  assert.ok(!nearDuplicate("You borrowed the ladder in March and never brought it back.",
                           "Three stories posted by ten, but my message is still unread.", "en_US"));
  assert.equal(takeNudge(1, "en_US"), "");
  assert.ok(takeNudge(2, "zh_TW") && takeNudge(3, "ja_JP"));
});

test("extra takes are told not to write a name the situation contains (and still dropped if they do)", async () => {
  const calls = stub(() => "你在週會上把我做了兩個禮拜的簡報說成你的，臉皮是有多厚，王八蛋。");
  await post({ situation: "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。", intensity: "feral", variantCount: 3,
               locale: "zh_TW", styleName: "硬核回擊" }, { token: await proToken() });
  const extras = calls.map((c) => c.messages[1].content).filter((u) => u.includes("separate take"));
  assert.equal(extras.length, 2);
  for (const u of extras) assert.match(u, /不要寫出任何人名/);
});
