// Provider routing for /v1/vent (v1.7 P0.1).
//
// Two decisions live here so they can be unit-tested without a Worker runtime:
// whether the Groq hop runs at all, and which OpenRouter models a request may
// fall through to.

const DEFAULT_PRIMARY = "qwen/qwen3-30b-a3b-instruct-2507";

/// Groq is OPT-IN. Its model has 404'd on every request since ~2026-09-15, so
/// running it by default only adds a failed round trip before OpenRouter. The
/// code is kept; set GROQ_ENABLED="true" (with a live GROQ_*_MODEL) to bring
/// it back.
export function groqEnabled(env) {
  return Boolean(env && env.GROQ_ENABLED === "true" && env.GROQ_API_KEY);
}

/// The OpenRouter models to try, in order: DEFAULT_MODEL, then
/// FALLBACK_MODELS (comma-separated). Deduplicated, blanks dropped. Sent as
/// OpenRouter's native `models` array, so a retired or failing primary falls
/// through inside the same request instead of taking every cloud feature down
/// with it — which is what one Groq retirement did.
export function openRouterModels(env) {
  const primary = ((env && env.DEFAULT_MODEL) || DEFAULT_PRIMARY).trim();
  const extra = String((env && env.FALLBACK_MODELS) || "")
    .split(",")
    .map((m) => m.trim())
    .filter(Boolean);
  return [...new Set([primary, ...extra])];
}

/// The OpenRouter calls to make, in order, for a model list: the whole list
/// first (OpenRouter falls through internally on rate limits / downtime), then
/// each remaining tail. OpenRouter validates every id before routing, so a
/// retired id 400s the whole list — the tail retry is what survives that.
/// [a, b, c] → [[a, b, c], [b, c], [c]]: never more calls than models.
export function openRouterAttempts(models) {
  const list = (models || []).filter(Boolean);
  return list.map((_m, k) => list.slice(k));
}

/// The model-selection part of an OpenAI-compatible request body. One model →
/// `model`; several → OpenRouter's `models` (it tries them in order and bills
/// the one that answered, reported back in the response's `model`).
export function modelSelection(models) {
  const list = Array.isArray(models) ? models.filter(Boolean) : [models].filter(Boolean);
  if (list.length <= 1) return { model: list[0] };
  return { models: list };
}
