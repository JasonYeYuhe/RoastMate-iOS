import { test } from "node:test";
import assert from "node:assert/strict";
import { groqEnabled, openRouterModels, openRouterAttempts, modelSelection } from "../src/routing.js";

test("groq is opt-in: off unless GROQ_ENABLED is exactly \"true\" and a key exists", () => {
  assert.equal(groqEnabled({ GROQ_API_KEY: "k" }), false);
  assert.equal(groqEnabled({ GROQ_API_KEY: "k", GROQ_ENABLED: "false" }), false);
  assert.equal(groqEnabled({ GROQ_API_KEY: "k", GROQ_ENABLED: "TRUE" }), false);
  assert.equal(groqEnabled({ GROQ_ENABLED: "true" }), false);
  assert.equal(groqEnabled({ GROQ_API_KEY: "k", GROQ_ENABLED: "true" }), true);
  assert.equal(groqEnabled(undefined), false);
});

test("openRouterModels: primary first, then fallbacks, deduped, blanks dropped", () => {
  assert.deepEqual(
    openRouterModels({ DEFAULT_MODEL: "a/x", FALLBACK_MODELS: " b/y , ,a/x,c/z " }),
    ["a/x", "b/y", "c/z"]
  );
});

test("openRouterModels: no env → the built-in primary alone", () => {
  assert.deepEqual(openRouterModels({}), ["qwen/qwen3-30b-a3b-instruct-2507"]);
  assert.deepEqual(openRouterModels(undefined), ["qwen/qwen3-30b-a3b-instruct-2507"]);
});

test("the shipped wrangler.toml routes to two OpenRouter models and skips Groq", async () => {
  const { readFile } = await import("node:fs/promises");
  const toml = await readFile(new URL("../wrangler.toml", import.meta.url), "utf8");
  const v = (k) => (toml.match(new RegExp(`^${k}\\s*=\\s*"([^"]*)"`, "m")) || [])[1];
  assert.equal(v("GROQ_ENABLED"), "false");
  const models = openRouterModels({ DEFAULT_MODEL: v("DEFAULT_MODEL"), FALLBACK_MODELS: v("FALLBACK_MODELS") });
  assert.ok(models.length >= 2, `expected a fallback model, got ${models}`);
  for (const m of models) {
    assert.ok(!m.endsWith(":free"), `${m}: never a shared :free pool`);
    assert.ok(!/thinking|reason/i.test(m), `${m}: never a reasoning model`);
  }
});

test("modelSelection: one model → model; several → models; empty entries ignored", () => {
  assert.deepEqual(modelSelection("a/x"), { model: "a/x" });
  assert.deepEqual(modelSelection(["a/x"]), { model: "a/x" });
  assert.deepEqual(modelSelection(["a/x", "", "b/y"]), { models: ["a/x", "b/y"] });
});

test("openRouterAttempts: whole list first, then each tail — one call per model at most", () => {
  assert.deepEqual(openRouterAttempts(["a", "b"]), [["a", "b"], ["b"]]);
  assert.deepEqual(openRouterAttempts(["a", "b", "c"]), [["a", "b", "c"], ["b", "c"], ["c"]]);
  assert.deepEqual(openRouterAttempts(["a"]), [["a"]]);
  assert.deepEqual(openRouterAttempts([]), []);
});
