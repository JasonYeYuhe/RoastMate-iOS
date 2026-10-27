import { registerHooks } from "node:module";
import { readFileSync } from "node:fs";
registerHooks({ resolve(s, c, n) { if (s === "cloudflare:workers") return { url: "data:text/javascript,export class DurableObject {}", shortCircuit: true }; return n(s, c); } });
import { fileURLToPath } from "node:url";
// Repo root: $ROASTMATE_ROOT, else derived from this file (harness/worker-compare/ is 5 levels below it).
const REPO = process.env.ROASTMATE_ROOT || fileURLToPath(new URL("../../../../../", import.meta.url)).replace(/\/$/, "");
const HEAD = (await import(process.argv[2] + "/index.js")).default;
const CUR = (await import(REPO + "/cloud-worker/src/index.js")).default;
const { resolveStyleId, styleVoiceInstruction } = await import(REPO + "/cloud-worker/src/style_voice.js");
const { ventVoice } = await import(REPO + "/cloud-worker/src/vent_prompt.js");
const presets = JSON.parse(readFileSync(REPO + "/Shared/Resources/StylePresets.json", "utf8")).styles;
const names = [];
for (const l of ["en", "zh-Hans", "zh-Hant", "ja"]) {
  const t = readFileSync(`${REPO}/Shared/${l}.lproj/Localizable.strings`, "utf8");
  for (const m of t.matchAll(/^"style\.([a-z0-9_]+)\.name"\s*=\s*"((?:[^"\\]|\\.)*)"/gm)) names.push(m[2]);
}
function kv() { const m = new Map(); return { async get(k) { return m.has(k) ? m.get(k) : null; }, async put(k, v) { m.set(k, v); } }; }
const env = () => ({ OPENROUTER_API_KEY: "k", DEFAULT_MODEL: "a/primary", FALLBACK_MODELS: "b/fallback", RATE_LIMITS: kv(), ROAST_MODE_ENABLED: "true", DAILY_LIMIT_PER_DEVICE: "1000000", APP_DAILY_LIMIT_PER_IP: "1000000" });
async function run(worker, e, body, responder) {
  const calls = [];
  globalThis.fetch = async (_u, init) => { const b = JSON.parse(init.body); calls.push(b); return new Response(JSON.stringify({ model: "a/primary", choices: [{ message: { content: responder(calls.length - 1) } }] }), { status: 200, headers: { "Content-Type": "application/json" } }); };
  const res = await worker.fetch(new Request("https://w.test/v1/vent", { method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.7" }, body: JSON.stringify(body) }), e, { waitUntil() {} });
  return { status: res.status, body: await res.text(), calls: calls.map((c) => c.messages.map((m) => m.content)) };
}
const locales = ["en_US", "en_GB", "zh-Hans", "zh_CN", "zh_TW", "zh_HK", "zh-Hant_TW", "ja_JP", "ko_KR", "fr_FR", ""];
const styles = [{}, { styleName: "" }, { styleName: "Totally Unknown" }, { styleId: "nope" }, ...presets.map((p) => ({ styleId: p.id })), ...names.map((n) => ({ styleName: n })), ...presets.map((p) => ({ styleId: p.id, styleName: "x" }))];
const situations = ["My manager Kevin took credit for my report.", "我媽每次過年都問我薪水", "领导周五晚上十点在群里@我", "彼氏が私の誕生日を忘れてた。", "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。", "同事王强把我熬夜做的方案换了个封面就交给领导"];
const responders = [() => "好", (i) => i === 0 ? "fucking 又來？" : "又來？是怎樣。", () => "陳志明你真的很扯", () => "陳主管，你又在下班前丟案子。", (i) => i === 0 ? "陳主管欸，又丟案子。" : "又丟案子。到此為止。", () => "王总，你可真行。", (i) => i === 0 ? "那个王经理又抢功。" : "那个领导又抢功。"];
const EXPECT_CHANGED = process.env.EXPECT_CHANGED ? new Set(process.env.EXPECT_CHANGED.split(",")) : null;
const he = env(), ce = env();
let n = 0, same = 0, diff = 0, ventStyledDiff = 0, ventStyledExpectedSame = 0, bad = [];
for (const mode of ["roommate", "roast", "vent", undefined]) {
  const ints = mode === "roast" ? ["calm", "sharp", "savage"] : ["vent", "feral"];
  for (const intensity of ints) for (const locale of locales) for (const s of styles) for (const situation of situations) for (const [ri, r] of responders.entries()) {
    if (ri > 0 && ri < 3 && !(situation === situations[1] || situation === situations[0])) continue;
    if (ri >= 3 && !(situation === situations[4] || situation === situations[5])) continue;
    if (ri === 0 && situations.indexOf(situation) >= 4) {}
    n++;
    const body = { deviceId: `dev-compare-${n % 50}xx`, situation, intensity, locale, ...s, ...(mode ? { mode } : {}) };
    const h = await run(HEAD, he, body, r), c = await run(CUR, ce, body, r);
    const isVent = mode !== "roommate" && mode !== "roast";
    let styledVoice = false;
    if (isVent) styledVoice = !!styleVoiceInstruction(resolveStyleId(s.styleId, s.styleName), ventVoice(locale.replace(/@.*/, "")));
    // EXPECT_CHANGED=id1,id2 (2026-10-27): only these styles' styled prompts may differ from HEAD.
    if (styledVoice && EXPECT_CHANGED) styledVoice = EXPECT_CHANGED.has(resolveStyleId(s.styleId, s.styleName));
    const eq = JSON.stringify(h.calls) === JSON.stringify(c.calls) && h.status === c.status;
    if (eq) same++; else diff++;
    if (!isVent || !styledVoice) { if (!eq) bad.push({ mode, intensity, locale, s, situation, ri }); }
    else { if (eq) bad.push({ unexpectedSame: true, mode, intensity, locale, s }); else ventStyledDiff++; }
    // response body: compare text when both 200 and same number of calls
    if (h.status !== c.status) bad.push({ statusDiff: [h.status, c.status], body });
    if (!isVent || !styledVoice) { if (h.body.replace(/"remaining":\d+/, "") !== c.body.replace(/"remaining":\d+/, "")) bad.push({ respDiff: true, body, h: h.body, c: c.body }); }
  }
}
console.log({ n, same, diff, ventStyledDiff, bad: bad.length });
console.log(JSON.stringify(bad.slice(0, 5), null, 1));
const kinds = {}; for (const b of bad) { const k = JSON.stringify([b.respDiff?"resp":b.statusDiff?"status":b.unexpectedSame?"same":"prompt", b.mode ?? (b.body&&b.body.mode), b.ri ?? null]); kinds[k] = (kinds[k]||0)+1; } console.log(kinds);
