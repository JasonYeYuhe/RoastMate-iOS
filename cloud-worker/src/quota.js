/**
 * Quota helpers — substrate selection and fallback logic.
 *
 * Deliberately free of any `cloudflare:` import so this file is unit-testable
 * under plain `node --test`. The Durable Object class itself lives in
 * `quota_do.js`, which cannot be imported outside the Workers runtime.
 */
/** True when the DO-backed counter is switched on AND bound. */
export function quotaBackendIsDO(env) {
  return (
    (env?.QUOTA_BACKEND || "kv").toLowerCase() === "do" && Boolean(env?.QUOTA)
  );
}

/**
 * Reserve one unit against `key`.
 *
 * Returns `{allowed, used, remaining, backend}`. On any DO failure it falls
 * back to the legacy KV path rather than erroring: a quota substrate outage
 * must degrade to the old (racy but working) behaviour, never to a 500 or to
 * blocking a paying user.
 *
 * @param {(env:any, ctx:any, fields:any) => void} log
 */
export async function consumeQuota(
  { env, ctx, key, limit, ttlSeconds = 172800, label },
  log
) {
  if (quotaBackendIsDO(env)) {
    try {
      const stub = env.QUOTA.get(env.QUOTA.idFromName(key));
      const r = await stub.consume(limit, ttlSeconds);
      return { ...r, backend: "do" };
    } catch (e) {
      log?.(env, ctx, {
        endpoint: "quota",
        outcome: "do_failed_fallback_kv",
        counter: label,
        detail: String((e && e.message) || e).slice(0, 120),
      });
    }
  }
  return consumeQuotaKV({ env, ctx, key, limit, label }, log);
}

/** Legacy non-atomic KV path. Kept as the fallback and the rollback target. */
async function consumeQuotaKV({ env, ctx, key, limit, label }, log) {
  let used = 0;
  try {
    used = parseInt((await env.RATE_LIMITS.get(key)) || "0", 10) || 0;
  } catch {
    used = 0;
  }
  if (used >= limit) {
    return { allowed: false, used, remaining: 0, backend: "kv" };
  }
  const next = used + 1;
  try {
    await env.RATE_LIMITS.put(key, String(next), { expirationTtl: 86400 * 2 });
  } catch (e) {
    // Cloudflare KV allows ~1 write/sec to the same key and throws beyond it.
    // Never surface that as a 500 (it 500'd real users before this was
    // wrapped); a dropped increment fits these counters' best-effort contract.
    log?.(env, ctx, {
      endpoint: "quota",
      outcome: "counter_write_failed",
      counter: label,
      detail: String((e && e.message) || e).slice(0, 120),
    });
  }
  return { allowed: true, used: next, remaining: Math.max(0, limit - next), backend: "kv" };
}

/** Return one reserved unit after an upstream failure. Best-effort. */
export async function refundQuota({ env, ctx, key, backend, label }, log) {
  try {
    if (backend === "do" && env?.QUOTA) {
      const stub = env.QUOTA.get(env.QUOTA.idFromName(key));
      await stub.refund();
      return;
    }
    const used = parseInt((await env.RATE_LIMITS.get(key)) || "0", 10) || 0;
    if (used > 0) {
      await env.RATE_LIMITS.put(key, String(used - 1), { expirationTtl: 86400 * 2 });
    }
  } catch (e) {
    log?.(env, ctx, {
      endpoint: "quota",
      outcome: "refund_failed",
      counter: label,
      detail: String((e && e.message) || e).slice(0, 120),
    });
  }
}
