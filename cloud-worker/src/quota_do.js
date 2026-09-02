import { DurableObject } from "cloudflare:workers";

/**
 * Atomic daily quota counter (v1.4, decision D2).
 *
 * WHY THIS EXISTS — measured, not theoretical. The previous KV counter used
 * get-then-put, which is not atomic. A same-key concurrent burst had every
 * request read the same pre-increment value:
 *
 *   55 concurrent requests, one fresh deviceId, cap 30
 *     -> 52 succeeded, and ALL of them reported remaining=29
 *
 * The over-grant scaled with burst size, i.e. a burst of N yielded ~N
 * generations regardless of the cap. Full write-up:
 * evals/runs/2026-09-02-d2-kv-quota-race.md
 *
 * WHY A DURABLE OBJECT FIXES IT. One DO instance per counter key
 * (`idFromName(key)`), and a DO serialises requests to a single instance. The
 * read and the write inside `consume()` are both SYNCHRONOUS `sql.exec` calls
 * with no `await` between them, so no other request can interleave. That is
 * the whole property KV could not give us.
 *
 * SQLite-backed, which is available on the Workers FREE plan (100k req/day,
 * 100k row writes/day) — far above current volume.
 *
 * RESERVE-THEN-REFUND, and why the shape had to change. The old flow checked
 * the quota up front but only charged it AFTER the upstream LLM call, so that
 * a failed generation would not eat a user's daily quota. Good intent, but it
 * put the entire ~2-3s model call inside the check->charge window, which is
 * precisely why every concurrent request saw the same count. Making the
 * counter atomic is not enough on its own; the charge has to happen at check
 * time. So `consume()` reserves immediately and the caller calls `refund()`
 * if the upstream fails. Same user-visible behaviour, no race window.
 */
export class QuotaCounter extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    // Schema setup only — the documented use for blockConcurrencyWhile. Never
    // hold it across a fetch or any external I/O.
    ctx.blockConcurrencyWhile(async () => {
      this.ctx.storage.sql.exec(
        "CREATE TABLE IF NOT EXISTS counter (id INTEGER PRIMARY KEY, n INTEGER NOT NULL)"
      );
    });
  }

  /** Current count without charging. */
  peek() {
    return { used: this.#read() };
  }

  /**
   * Atomically reserve one unit if the cap allows.
   * @returns {{allowed: boolean, used: number, remaining: number}}
   */
  async consume(limit, ttlSeconds = 172800) {
    const used = this.#read();
    if (used >= limit) {
      return { allowed: false, used, remaining: 0 };
    }
    const next = used + 1;
    // Synchronous, and adjacent to the read above — that adjacency IS the
    // atomicity guarantee. Do not introduce an await between them.
    this.#write(next);

    // Self-cleanup: the key already embeds the day, so this instance is dead
    // once the day rolls over. Only set the alarm on first use; setAlarm()
    // replaces any existing one, so re-setting per request would keep pushing
    // the deletion out. The await is AFTER the write, so it cannot interleave.
    if (used === 0) {
      try {
        await this.ctx.storage.setAlarm(Date.now() + ttlSeconds * 1000);
      } catch {
        // An un-set alarm costs a little stale storage, never correctness.
      }
    }
    return { allowed: true, used: next, remaining: Math.max(0, limit - next) };
  }

  /**
   * Give back one unit — used when the upstream call failed, so a provider
   * outage does not silently consume the user's daily allowance.
   */
  refund() {
    const used = this.#read();
    if (used <= 0) return { used: 0 };
    const next = used - 1;
    this.#write(next);
    return { used: next };
  }

  /** Drop storage once the counter's day has passed. */
  async alarm() {
    await this.ctx.storage.deleteAll();
  }

  #read() {
    const rows = this.ctx.storage.sql
      .exec("SELECT n FROM counter WHERE id = 0")
      .toArray();
    return rows.length ? Number(rows[0].n) : 0;
  }

  #write(n) {
    this.ctx.storage.sql.exec(
      "INSERT INTO counter (id, n) VALUES (0, ?) ON CONFLICT(id) DO UPDATE SET n = excluded.n",
      n
    );
  }
}
