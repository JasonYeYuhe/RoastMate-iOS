// End-to-end tests of the /v1/vent handler with the upstream stubbed: the
// request / response contract, the vent-only post-processing and quality
// retry, the roommate / roast paths left untouched, and the time budget.
//
// index.js imports quota_do.js, which imports "cloudflare:workers" (only the
// Workers runtime has it). The resolve hook below swaps in a one-line stub so
// the real handler can run under plain `node --test`. Each test file runs in
// its own process, so the hook does not leak into the others.
import { registerHooks } from "node:module";
import { test, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "cloudflare:workers") {
      return { url: "data:text/javascript,export class DurableObject {}", shortCircuit: true };
    }
    return nextResolve(specifier, context);
  }
});
const worker = (await import("../src/index.js")).default;

const realFetch = globalThis.fetch;
const realTimeout = AbortSignal.timeout;
let timeouts = [];

beforeEach(() => {
  timeouts = [];
  AbortSignal.timeout = (ms) => { timeouts.push(ms); return realTimeout.call(AbortSignal, ms); };
});
afterEach(() => {
  globalThis.fetch = realFetch;
  AbortSignal.timeout = realTimeout;
});

function fakeKV() {
  const store = new Map();
  return {
    async get(k) { return store.has(k) ? store.get(k) : null; },
    async put(k, v) { store.set(k, v); },
    _store: store
  };
}

function makeEnv(extra = {}) {
  return {
    OPENROUTER_API_KEY: "test-key",
    DEFAULT_MODEL: "a/primary",
    FALLBACK_MODELS: "b/fallback",
    RATE_LIMITS: fakeKV(),
    ...extra
  };
}

const ctx = { waitUntil() {} };

/// Replace fetch with `responder(index, body)`; returns the recorded calls.
function stubUpstream(responder) {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    const body = JSON.parse(init.body);
    calls.push({ url: String(url), body, hasSignal: Boolean(init.signal) });
    return responder(calls.length - 1, body);
  };
  return calls;
}

function completion(content, model) {
  return new Response(JSON.stringify({ model, choices: [{ message: { content } }] }), {
    status: 200, headers: { "Content-Type": "application/json" }
  });
}

function timeoutError() {
  return new DOMException("The operation was aborted due to timeout", "TimeoutError");
}

async function vent(body, env = makeEnv()) {
  const req = new Request("https://worker.test/v1/vent", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.7" },
    body: JSON.stringify({ deviceId: "handler-test-device", styleName: "High EQ", ...body })
  });
  const res = await worker.fetch(req, env, ctx);
  return { status: res.status, json: await res.json(), env };
}

const sha = (s) => createHash("sha256").update(s).digest("hex");
const userPromptOf = (call) => call.body.messages[1].content;
const systemPromptOf = (call) => call.body.messages[0].content;

test("vent zh_TW: English words trigger ONE retry on the model that answered, and the clean draft wins", async () => {
  const calls = stubUpstream((i) => i === 0
    ? completion("fucking 下班前十分鐘丟案子，還在群組講責任感是怎樣？", "a/primary")
    : completion("下班前十分鐘丟案子，還在群組講責任感是怎樣？靠北。", "a/primary"));
  const { status, json } = await vent({ situation: "慣老闆下班前十分鐘丟案子", intensity: "feral", locale: "zh_TW" });
  assert.equal(status, 200);
  assert.deepEqual(Object.keys(json).sort(), ["model", "provider", "remaining", "text"], "response contract unchanged");
  assert.equal(json.text, "下班前十分鐘丟案子，還在群組講責任感是怎樣？靠北。");
  assert.equal(json.model, "a/primary");
  assert.equal(json.provider, "openrouter");
  assert.equal(json.remaining, 29);
  assert.equal(calls.length, 2);
  assert.deepEqual(calls[0].body.models, ["a/primary", "b/fallback"]);
  assert.equal(calls[1].body.model, "a/primary", "not the fallback model (it names people; gate 2026-10-22)");
  assert.match(userPromptOf(calls[1]), /不要夾英文單字/);
  assert.ok(!userPromptOf(calls[1]).includes("fucking"), "the nudge never quotes the draft");
  assert.equal(systemPromptOf(calls[1]), systemPromptOf(calls[0]));
  assert.deepEqual(timeouts, [12000, 8000], "first call capped at 12 s, quality retry at 8 s");
});

test("vent zh_TW: Simplified characters trigger the retry too", async () => {
  const calls = stubUpstream((i) => i === 0
    ? completion("紀念日說好的，結果臨時放我鸽子去打球？", "a/primary")
    : completion("紀念日說好的，結果臨時放我鳥去打球？是怎樣啦。", "b/fallback"));
  const { json } = await vent({ situation: "男友紀念日放我鳥", intensity: "vent", locale: "zh-Hant" });
  assert.equal(calls.length, 2);
  assert.match(userPromptOf(calls[1]), /繁體字/);
  assert.equal(json.text, "紀念日說好的，結果臨時放我鳥去打球？是怎樣啦。");
});

test("a retry that is no better, or that fails, keeps the first draft", async () => {
  stubUpstream((i) => completion(i === 0 ? "fucking 又來？" : "shit 又來？", i === 0 ? "a/primary" : "b/fallback"));
  let r = await vent({ situation: "又來了", intensity: "feral", locale: "zh_TW" });
  assert.equal(r.json.text, "fucking 又來？");
  assert.equal(r.json.model, "a/primary");

  stubUpstream((i) => i === 0 ? completion("**又來？** whatever", "a/primary") : new Response("no", { status: 500 }));
  r = await vent({ situation: "又來了", intensity: "feral", locale: "zh_TW" });
  assert.equal(r.status, 200);
  assert.equal(r.json.text, "又來？ whatever", "markdown still removed when the retry fails");
  assert.equal(r.json.model, "a/primary");
});

test("en vent: markdown is removed in place and English is never retried", async () => {
  const calls = stubUpstream(() => completion("You think I’m gonna *label* my food for **fun**?", "a/primary"));
  const { json } = await vent({ situation: "Roommate eats my food", intensity: "vent", locale: "en_US" });
  assert.equal(calls.length, 1);
  assert.equal(json.text, "You think I’m gonna label my food for fun?");
});

test("zh-Hans: allowed Latin words (NPC) cause no retry", async () => {
  const calls = stubUpstream(() => completion("你当我是你游戏里可有可无的NPC？", "a/primary"));
  await vent({ situation: "发烧了男朋友还在打游戏", intensity: "vent", locale: "zh-Hans" });
  assert.equal(calls.length, 1);
});

test("an eval-harness model override is never retried", async () => {
  const calls = stubUpstream(() => completion("fucking 又來？", "deepseek/deepseek-chat"));
  const { json } = await vent({ situation: "又來了", intensity: "feral", locale: "zh_TW", model: "deepseek/deepseek-chat" });
  assert.equal(calls.length, 1);
  assert.equal(json.provider, "openrouter-override");
});

test("roommate transcripts come back untouched, are never retried, and their prompt is unchanged", async () => {
  // Tags, the bridge word and even stray asterisks are Latin / markdown by
  // the post-processor's rules; none of it may be touched here, because the
  // app's EchoesParser reads these lines.
  const transcript = [
    "[VALIDATE/A] 凌晨一点多开外放，真当自己是直播主了？",
    "[ESCALATE/B] 还好意思说“戴耳塞不就行了”？",
    "[ESCALATE/A] 别人睡觉她嗨，说一句还被怼矫情。",
    "[ESCALATE/C] 你睡不着是你的事，别人睡不着也是你的错？",
    "[ESCALATE/B] 群里阴阳人矫情，自己才是 **真** 神经病。",
    "[ESCALATE/A] 公共空间搞私人派对，脸呢。",
    "[DEESCALATE/C] 行了，气也气了，这锅别替她背。",
    "[BRIDGE/C] 与其忍着，不如用 Sharp 把话甩回去 →"
  ].join("\n");
  const calls = stubUpstream(() => completion(transcript, "a/primary"));
  const { json } = await vent({ situation: "室友半夜外放", intensity: "vent", locale: "zh-Hans", mode: "roommate" });
  assert.equal(calls.length, 1);
  assert.equal(json.text, transcript);
  // sha256 of the prompts HEAD 029ca48 built for this exact request.
  assert.equal(sha(systemPromptOf(calls[0])), "05754402315360f1be6eaa0673df1fba5155924afd300d80e9bd134557ce0bf9");
  assert.equal(sha(userPromptOf(calls[0])), "7679dbdab113cc82fd8d1ee276d5a67a258ae68fbe67af9df94809efd5c4ba96");
});

test("roommate feral and zh_TW prompts are unchanged too", async () => {
  const calls = stubUpstream(() => completion("[VALIDATE/A] x", "a/primary"));
  await vent({ situation: "室友半夜外放", intensity: "feral", locale: "zh-Hans", mode: "roommate" });
  await vent({ situation: "室友半夜外放", intensity: "vent", locale: "zh_TW", mode: "roommate" });
  assert.equal(sha(systemPromptOf(calls[0])), "db9ba11f21a5bd2cd971394de1d69313cfaaae5060a0bf3f4ca341b2dbefdd8c");
  assert.equal(sha(systemPromptOf(calls[1])), "9c7c5f000d41679d5070d5ed081aade8c38dd9bf02666a415023af1f1128e4c9");
  assert.equal(sha(userPromptOf(calls[1])), "3091b30e8ac7d4549479b496337922f8a4ac65d0edcaa68857d135958806a036");
});

test("roast (sendable) prompt and numbered output are unchanged", async () => {
  const out = "1. 第一条\n2. 第二条\n3. 第三条";
  const calls = stubUpstream(() => completion(out, "a/primary"));
  const env = makeEnv({ ROAST_MODE_ENABLED: "true" });
  const { json } = await vent({ situation: "x", intensity: "sharp", locale: "zh-Hans", mode: "roast",
                                styleName: "高 EQ", styleId: "high_eq", variantCount: 3 }, env);
  assert.equal(json.text, out);
  assert.equal(calls.length, 1);
  assert.equal(sha(systemPromptOf(calls[0])), "4b5b7daa70933ac27bfbc8ee62e1fe3efc3d9be753807ce5903c100780c1fc96");
  assert.equal(sha(userPromptOf(calls[0])), "c802b6b1db5a3b4305cbf52f8b38ad66f365dc10639c44aa52214cc855c76752");
});

test("a hung first call is cut at 12 s and the tail retry gets the rest of the 18 s budget", async () => {
  const calls = stubUpstream((i) => {
    if (i === 0) throw timeoutError();
    return completion("下班前十分鐘丟案子是怎樣？", "b/fallback");
  });
  const { status, json } = await vent({ situation: "慣老闆", intensity: "vent", locale: "zh_TW" });
  assert.equal(status, 200);
  assert.equal(json.model, "b/fallback");
  assert.equal(calls.length, 2);
  assert.ok(calls.every((c) => c.hasSignal), "every upstream call carries an abort signal");
  assert.equal(timeouts[0], 12000);
  assert.ok(timeouts[1] > 17000 && timeouts[1] <= 18000, `tail timeout ${timeouts[1]}`);
});

test("when every attempt times out: 502 with timeout statuses, and the reserved unit is refunded", async () => {
  stubUpstream(() => { throw timeoutError(); });
  const { status, json, env } = await vent({ situation: "慣老闆", intensity: "vent", locale: "zh_TW" });
  assert.equal(status, 502);
  assert.equal(json.error, "upstream_error");
  assert.equal(json.detail, "openrouter:timeout | openrouter:timeout");
  const counts = [...env.RATE_LIMITS._store.entries()].filter(([k]) => k.startsWith("rl:free:"));
  assert.deepEqual(counts.map(([, v]) => v), ["0"]);
});

test("after a failed first call, the quality retry stays on the model that answered", async () => {
  // Review 2026-10-22: the retry used to go back to the primary that had just
  // 400'd (a retired id), costing a fast failure and keeping the first draft.
  const calls = stubUpstream((i) => {
    if (i === 0) return new Response("unknown model", { status: 400 });
    if (i === 1) return completion("fucking 下班前十分鐘丟案子是怎樣？", "b/fallback");
    return completion("下班前十分鐘丟案子是怎樣？", "b/fallback");
  });
  const { status, json } = await vent({ situation: "慣老闆", intensity: "feral", locale: "zh_TW" });
  assert.equal(status, 200);
  assert.equal(calls.length, 3);
  assert.deepEqual(calls[0].body.models, ["a/primary", "b/fallback"]);
  assert.equal(calls[1].body.model, "b/fallback", "tail retry");
  assert.equal(calls[2].body.model, "b/fallback", "quality retry: not the primary that just failed");
  assert.equal(json.text, "下班前十分鐘丟案子是怎樣？");
});

test("the Taiwan calibration lines follow the situation, and the retry reuses the same system prompt", async () => {
  const calls = stubUpstream((i) => completion(i === 0 ? "fucking 又來？" : "又來？是怎樣。", "a/primary"));
  await vent({ situation: "分組報告的組員又消失了", intensity: "feral", locale: "zh_TW" });
  await vent({ situation: "房東又說要漲房租", intensity: "feral", locale: "zh_TW" });
  const goods = (c) => systemPromptOf(c).split("\n").filter((l) => l.startsWith("- GOOD:")).join("|");
  assert.equal(goods(calls[0]), goods(calls[1]), "retry: same examples");
  assert.notEqual(goods(calls[0]), goods(calls[2]), "another situation: other examples");
  for (const c of calls) assert.ok(!systemPromptOf(c).includes("組員") && !systemPromptOf(c).includes("房東"), "the situation itself is never in the system prompt");
});

test("a word stuck on repeat triggers the retry with its own nudge", async () => {
  const calls = stubUpstream((i) => i === 0
    ? completion("你根本是根本根本根本不在乎我！", "a/primary")
    : completion("你根本不在乎我，連一晚都守不住。", "b/fallback"));
  const { json } = await vent({ situation: "男友紀念日放我鳥", intensity: "feral", locale: "zh_TW" });
  assert.equal(calls.length, 2);
  assert.match(userPromptOf(calls[1]), /同一個詞不要連著重複/);
  assert.equal(json.text, "你根本不在乎我，連一晚都守不住。");
});

test("roommate gets the long budget: 16 s first call, a fast-failure tail retry inside 20 s", async () => {
  const calls = stubUpstream((i) => {
    if (i === 0) throw timeoutError();
    return completion("[VALIDATE/A] x", "b/fallback");
  });
  const { status } = await vent({ situation: "室友半夜外放", intensity: "vent", locale: "zh-Hans", mode: "roommate" });
  assert.equal(status, 200);
  assert.equal(calls.length, 2);
  assert.equal(timeouts[0], 16000);
  assert.ok(timeouts[1] > 19000 && timeouts[1] <= 20000, `tail timeout ${timeouts[1]}`);
});

test("a call our own signal aborted counts as a timeout whatever the error is called", async () => {
  // Review 2026-10-22: only TimeoutError / AbortError were recognised, so a
  // runtime that rejected with another error name would have logged a
  // timeout as "transport". Here every signal fires after 5 ms and the
  // stubbed fetch rejects with a plain Error once it has.
  AbortSignal.timeout = (ms) => { timeouts.push(ms); return realTimeout.call(AbortSignal, 5); };
  globalThis.fetch = (_url, init) => new Promise((_resolve, reject) => {
    init.signal.addEventListener("abort", () => reject(new Error("socket closed")));
  });
  const { status, json } = await vent({ situation: "慣老闆", intensity: "vent", locale: "zh_TW" });
  assert.equal(status, 502);
  assert.equal(json.detail, "openrouter:timeout | openrouter:timeout");
});

test("the operational log names the retry outcome, the defect kinds and failed attempts — never the text", async () => {
  const logs = [];
  const pending = [];
  globalThis.fetch = async (url, init) => {
    if (String(url).startsWith("https://http-intake.logs.")) {
      logs.push(...JSON.parse(init.body));
      return new Response("{}", { status: 202 });
    }
    const n = globalThis.__calls = (globalThis.__calls || 0) + 1;
    if (n === 1) return new Response("unknown model", { status: 400 });
    if (n === 2) return completion("fucking 又來？", "b/fallback");
    return completion("又來？是怎樣。", "b/fallback");
  };
  globalThis.__calls = 0;
  const env = makeEnv({ DD_API_KEY: "test-dd" });
  const req = new Request("https://worker.test/v1/vent", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.8" },
    body: JSON.stringify({ deviceId: "handler-test-device-log", situation: "又來了 secret-situation", intensity: "feral", locale: "zh_TW" })
  });
  const res = await worker.fetch(req, env, { waitUntil(p) { pending.push(p); } });
  await Promise.all(pending);
  delete globalThis.__calls;
  assert.equal(res.status, 200);
  const ok = logs.find((l) => l.outcome === "ok");
  assert.ok(ok, JSON.stringify(logs));
  assert.equal(ok.quality_retry, "used");
  assert.deepEqual(ok.quality_defects, ["latin"]);
  assert.deepEqual(ok.attempts, ["openrouter:400"]);
  assert.equal(ok.model, "b/fallback");
  const raw = JSON.stringify(logs);
  for (const secret of ["secret-situation", "fucking", "又來", "handler-test-device-log"]) {
    assert.ok(!raw.includes(secret), `log carries ${secret}`);
  }
});

const BOSS_SITUATION = "慣老闆陳志明又在下班前十分鐘丟一個案子給我，還在LINE群組說年輕人要有責任感。";

test("a draft that opens by addressing the person by name loses the name, with no retry", async () => {
  const calls = stubUpstream(() => completion("陳志明你真的夠了喔，下班前十分鐘丟案子是怎樣？", "a/primary"));
  const { json } = await vent({ situation: BOSS_SITUATION, intensity: "vent", locale: "zh_TW" });
  assert.equal(calls.length, 1);
  assert.equal(json.text, "你真的夠了喔，下班前十分鐘丟案子是怎樣？");
});

test("a name anywhere else triggers the retry; the draft without it wins", async () => {
  const calls = stubUpstream((i) => i === 0
    ? completion("你那個主管陳志明又在下班前丟案子，是怎樣？", "a/primary")
    : completion("那個主管又在下班前丟案子，whatever，是怎樣？", "a/primary"));
  const { json } = await vent({ situation: BOSS_SITUATION, intensity: "vent", locale: "zh_TW" });
  assert.equal(calls.length, 2);
  assert.match(userPromptOf(calls[1]), /不要寫出任何人名/);
  assert.equal(calls[1].body.model, "a/primary");
  assert.equal(json.text, "那個主管又在下班前丟案子，whatever，是怎樣？", "no name beats one stray English word");
});

test("English: a closing vocative name is removed in place and logged as a kind, never as the name", async () => {
  const logs = [];
  const pending = [];
  globalThis.fetch = async (url, init) => {
    if (String(url).startsWith("https://http-intake.logs.")) { logs.push(...JSON.parse(init.body)); return new Response("{}", { status: 202 }); }
    return completion("You took my weekend and called it yours. Fuck you, Kevin.", "a/primary");
  };
  const env = makeEnv({ DD_API_KEY: "test-dd" });
  const req = new Request("https://worker.test/v1/vent", {
    method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.9" },
    body: JSON.stringify({ deviceId: "handler-test-device-en", situation: "My manager Kevin took credit for my report", intensity: "feral", locale: "en_US" })
  });
  const res = await worker.fetch(req, env, { waitUntil(p) { pending.push(p); } });
  await Promise.all(pending);
  const json = await res.json();
  assert.equal(json.text, "You took my weekend and called it yours. Fuck you.");
  const ok = logs.find((l) => l.outcome === "ok");
  assert.deepEqual(ok.quality_defects, ["name_address_removed"]);
  assert.equal(ok.quality_retry, "none");
  assert.ok(!JSON.stringify(logs).includes("Kevin"));
});
