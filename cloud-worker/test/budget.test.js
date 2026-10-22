import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  UPSTREAM_BUDGET_MS, FIRST_ATTEMPT_MS, LONG_BUDGET_MS, LONG_FIRST_ATTEMPT_MS, LONG_MIN_TAIL_MS,
  QUALITY_RETRY_MS, QUALITY_RETRY_MIN_MS, MIN_ATTEMPT_MS,
  attemptTimeout, qualityRetryTimeout, budgetFor
} from "../src/budget.js";

test("attemptTimeout: capped by the cap and by what is left; 0 when too little is left", () => {
  const deadline = 18000;
  assert.equal(attemptTimeout(deadline, 0, FIRST_ATTEMPT_MS), 12000);
  assert.equal(attemptTimeout(deadline, 12000, Infinity), 6000);
  assert.equal(attemptTimeout(deadline, 17000, Infinity), 0, "under MIN_ATTEMPT_MS left");
  assert.equal(attemptTimeout(deadline, deadline - MIN_ATTEMPT_MS, Infinity), MIN_ATTEMPT_MS);
  assert.equal(attemptTimeout(deadline, 20000, Infinity), 0, "past the deadline");
  assert.equal(attemptTimeout(NaN, 0, Infinity), 0, "garbage never means unlimited");
});

test("qualityRetryTimeout: at most QUALITY_RETRY_MS, skipped below QUALITY_RETRY_MIN_MS", () => {
  const deadline = 18000;
  assert.equal(qualityRetryTimeout(deadline, 5000), QUALITY_RETRY_MS);   // typical: first draft at ~5 s
  assert.equal(qualityRetryTimeout(deadline, 11000), 7000);
  assert.equal(qualityRetryTimeout(deadline, deadline - QUALITY_RETRY_MIN_MS), QUALITY_RETRY_MIN_MS);
  assert.equal(qualityRetryTimeout(deadline, 13000), 0);
});

test("worst case: every call the Worker can make fits inside the one budget", () => {
  // First call times out at its cap, the tail retry uses the rest, and the
  // quality retry then has nothing left — the sum is the budget, never more.
  const deadline = UPSTREAM_BUDGET_MS;
  let now = 0;
  const first = attemptTimeout(deadline, now, FIRST_ATTEMPT_MS); now += first;
  const tail = attemptTimeout(deadline, now, Infinity); now += tail;
  const quality = qualityRetryTimeout(deadline, now); now += quality;
  assert.equal(first + tail + quality, UPSTREAM_BUDGET_MS);
  assert.equal(quality, 0);
  // A tail retry after a capped first call still gets more than the fallback
  // model's measured median (3.6–4.7 s, evals/runs/2026-10-07-p01-fallback.md).
  assert.ok(tail >= 5000, `tail gets ${tail} ms`);
});

test("the budget stays well under the app's request timeout (CloudConfig.swift)", async () => {
  // The app gives up at CloudConfig.requestTimeout and shows its labelled
  // fallback. Keep at least 5 s of it for the phone's network and the
  // Worker's quota round trips. Read from the app source so a change there
  // fails here instead of silently overlapping.
  let swift = "";
  try {
    swift = await readFile(new URL("../../Shared/Services/CloudConfig.swift", import.meta.url), "utf8");
  } catch {
    return; // Worker checked out on its own: nothing to compare against.
  }
  const m = swift.match(/static let requestTimeout:\s*TimeInterval\s*=\s*(\d+(?:\.\d+)?)/);
  assert.ok(m, "CloudConfig.requestTimeout not found");
  const appMs = parseFloat(m[1]) * 1000;
  for (const mode of ["vent", "roommate", "roast"]) {
    const { totalMs, firstMs } = budgetFor(mode);
    assert.ok(totalMs + 5000 <= appMs, `${mode}: budget ${totalMs} ms vs app ${appMs} ms`);
    assert.ok(firstMs < totalMs, mode);
  }
});

test("budgetFor: vent drafts get the short budget, the long transcripts the long one", () => {
  const short = { totalMs: UPSTREAM_BUDGET_MS, firstMs: FIRST_ATTEMPT_MS, minTailMs: MIN_ATTEMPT_MS };
  const long = { totalMs: LONG_BUDGET_MS, firstMs: LONG_FIRST_ATTEMPT_MS, minTailMs: LONG_MIN_TAIL_MS };
  assert.deepEqual(budgetFor("vent"), short);
  assert.deepEqual(budgetFor(undefined), short);
  assert.deepEqual(budgetFor("roommate"), long);
  assert.deepEqual(budgetFor("roast"), long);
  // Slowest roommate transcript measured: 10.66 s worker-side (gate
  // 2026-10-22). The cap keeps the same 1.5x margin the vent cap has over the
  // slowest vent (8.2 s).
  assert.ok(LONG_FIRST_ATTEMPT_MS >= 1.5 * 10660);
  assert.ok(FIRST_ATTEMPT_MS >= 1.45 * 8200);
});

test("long mode: a tail retry after a fast failure runs; after a capped first call it does not", () => {
  const { totalMs, firstMs, minTailMs } = budgetFor("roommate");
  // Retired primary: 400 after ~1 s → nearly the whole budget is left.
  assert.ok(attemptTimeout(totalMs, 1000, Infinity, minTailMs) >= 18000);
  // First call ran into its cap: what is left cannot produce a transcript.
  assert.equal(attemptTimeout(totalMs, firstMs + 50, Infinity, minTailMs), 0);
  // Vent keeps its 6 s tail after a capped first call.
  const v = budgetFor("vent");
  assert.equal(attemptTimeout(v.totalMs, v.firstMs, Infinity, v.minTailMs), 6000);
});
