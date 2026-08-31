import { test } from "node:test";
import assert from "node:assert/strict";
import { mintSessionToken, verifySessionToken, sha256Hex } from "../src/session.js";

const SECRET = "test-signing-secret-0123456789";
const NOW = 1_800_000_000_000; // fixed clock

test("sha256Hex matches a known vector", async () => {
  assert.equal(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  );
});

test("mint → verify round-trips and preserves claims", async () => {
  const claims = { sub: "deadbeef", pro: true, iat: NOW, exp: NOW + 60_000 };
  const token = await mintSessionToken(claims, SECRET);
  assert.match(token, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  const res = await verifySessionToken(token, SECRET, NOW);
  assert.equal(res.valid, true);
  assert.deepEqual(res.claims, claims);
});

test("rejects a token signed with a different secret", async () => {
  const token = await mintSessionToken({ sub: "x", pro: true, exp: NOW + 60_000 }, SECRET);
  const res = await verifySessionToken(token, "another-secret", NOW);
  assert.equal(res.valid, false);
  assert.equal(res.reason, "bad_signature");
});

test("rejects a tampered payload", async () => {
  const token = await mintSessionToken({ sub: "x", pro: true, exp: NOW + 60_000 }, SECRET);
  const [payload, sig] = token.split(".");
  // flip a character in the payload; signature no longer matches
  const bad = payload.slice(0, -1) + (payload.slice(-1) === "A" ? "B" : "A");
  const res = await verifySessionToken(`${bad}.${sig}`, SECRET, NOW);
  assert.equal(res.valid, false);
  assert.equal(res.reason, "bad_signature");
});

test("rejects an expired token", async () => {
  const token = await mintSessionToken({ sub: "x", pro: true, exp: NOW - 1 }, SECRET);
  const res = await verifySessionToken(token, SECRET, NOW);
  assert.equal(res.valid, false);
  assert.equal(res.reason, "expired");
});

test("treats exp == now as expired (boundary)", async () => {
  const token = await mintSessionToken({ sub: "x", pro: true, exp: NOW }, SECRET);
  const res = await verifySessionToken(token, SECRET, NOW);
  assert.equal(res.valid, false);
  assert.equal(res.reason, "expired");
});

test("rejects malformed tokens", async () => {
  for (const t of ["", "no-dot", ".", "abc.", ".abc", "a.b.c", 42, null, undefined]) {
    const res = await verifySessionToken(t, SECRET, NOW);
    assert.equal(res.valid, false, `token=${String(t)}`);
  }
});

test("missing secret fails closed (never valid)", async () => {
  const res = await verifySessionToken("a.b", "", NOW);
  assert.equal(res.valid, false);
  assert.equal(res.reason, "server_misconfigured");
});
