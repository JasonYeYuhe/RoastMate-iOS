// RoastMate Vent Cloud Worker
// ---------------------------
// Tiny edge proxy in front of OpenRouter for the Vent / Feral private-draft
// path. The iOS app sends the raw situation + intensity + locale + style
// name; this Worker builds the actual system prompt (safety rails + vent
// directives) and forwards to OpenRouter. The OpenRouter API key only ever
// lives as a Wrangler secret — it never touches the iOS binary.
//
// Rate-limit: per-device (anonymized UUID from the app) per UTC day,
// counted in KV. Limit defined by env.DAILY_LIMIT_PER_DEVICE.
//
// Optional `model` body field: if present AND in MODEL_OVERRIDE_ALLOWLIST,
// the request bypasses the Groq primary route and goes straight to
// OpenRouter with the requested model. Used by the eval harness
// (evals/runner/) for backend comparison (DeepSeek vs Grok vs Groq).
// Production app does NOT set this field; it's a side door for offline
// model evaluation.

// FREE-ONLY allowlist (2026-05-23 update v2): paid models removed at user
// direction. Eval comparison budget is $0. Expanded from initial 4 to 11
// after re-canvassing OpenRouter /v1/models for current :free offerings.
// Note: OpenRouter ":free" tier sometimes returns 402 ("Out of credits")
// when the upstream provider's free quota is exhausted — that's a global
// pool, not user-specific. 429s are upstream rate-limit blips, retry-able.
const MODEL_OVERRIDE_ALLOWLIST = new Set([
  // DeepSeek V4 Flash free — 1M context, MoE 284B/13B activated.
  // Originally dropped from DEFAULT_MODEL on 2026-05-15 for leaking
  // CoT as plain text. The `stripReasoningTrace` helper now catches
  // tagged CoT; plain-text CoT would still leak through.
  "deepseek/deepseek-v4-flash:free",
  // GLM 4.5 Air free (z.ai) — proven on 2026-05-23 to beat Qwen3-32B
  // on zh vent calibration. Current best free Chinese option.
  "z-ai/glm-4.5-air:free",
  // MiniMax — Shanghai-based Chinese AI; strong on zh, larger
  // context, low public benchmark data but worth a real test.
  "minimax/minimax-m2.5:free",
  // Google Gemma 4 (MoE 26B-A4B activated, and dense 31B). Google
  // models historically weaker on idiomatic zh; included for breadth.
  "google/gemma-4-26b-a4b-it:free",
  "google/gemma-4-31b-it:free",
  // OpenAI open-weights GPT-OSS 120B — first OpenAI open release,
  // included as a Western-model baseline.
  "openai/gpt-oss-120b:free",
  // Meta Llama 3.3 70B Instruct — same family as the Groq paid
  // fallback, but free on OpenRouter.
  "meta-llama/llama-3.3-70b-instruct:free",
  // Hermes 3 Llama 3.1 405B — current production DEFAULT_MODEL.
  "nousresearch/hermes-3-llama-3.1-405b:free",
  // Arcee Trinity Large Thinking — explicit reasoning model. Will
  // very likely leak CoT (either tagged or plain-text). Included so
  // we can document the failure mode, not because we expect it to
  // ship.
  "arcee-ai/trinity-large-thinking:free"
]);

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    const url = new URL(req.url);
    if (url.pathname !== "/v1/vent") {
      return json({ error: "not_found" }, 404);
    }

    let body;
    try {
      body = await req.json();
    } catch (_e) {
      return json({ error: "invalid_json" }, 400);
    }

    const validation = validate(body);
    if (validation.error) {
      return json({ error: validation.error }, 400);
    }
    const { situation, styleName, intensity, locale, deviceId, modelOverride } = validation.value;

    // Per-device daily rate limit.
    const limit = parseInt(env.DAILY_LIMIT_PER_DEVICE || "30", 10);
    const day = new Date().toISOString().slice(0, 10);
    const rlKey = `rl:${deviceId}:${day}`;
    const used = parseInt((await env.RATE_LIMITS.get(rlKey)) || "0", 10);
    if (used >= limit) {
      return json({ error: "rate_limit_exceeded", limit, remaining: 0 }, 429);
    }

    // Build the system + user prompts. Mirrors the directive language in
    // the iOS PromptBuilder so the cloud path produces the same emotional
    // register as the local path would attempt.
    const systemPrompt = buildSystemPrompt(intensity, locale, styleName);
    const userPrompt = buildUserPrompt(situation, locale);

    // Decision after smoke testing: Groq is primary because OpenRouter's
    // :free model pool is consistently rate-limited upstream (all the
    // good uncensored models are crowded). Within Groq we route by
    // locale — Qwen3 32B for Chinese (Alibaba-trained, much weaker
    // politeness-RLHF on zh than Llama), Llama 3.3 70B Versatile for
    // everything else. OpenRouter stays as fallback when Groq is over
    // quota / having a bad day.
    const attempts = [];
    let text = "";
    let modelUsed = "";
    let providerUsed = "";

    const localePrefix = (locale || "").toLowerCase();
    const isChinese = localePrefix.startsWith("zh");
    const groqPrimaryModel = isChinese
      ? (env.GROQ_CHINESE_MODEL || "qwen/qwen3-32b")
      : (env.GROQ_FALLBACK_MODEL || "llama-3.3-70b-versatile");

    // Model-override branch: eval harness explicitly asked for a specific
    // OpenRouter model. Skip Groq, go straight to OpenRouter so the test
    // sees what THAT model returns, not whatever Groq is routing today.
    if (modelOverride && env.OPENROUTER_API_KEY) {
      const ovrResult = await callOpenAICompatible({
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        apiKey: env.OPENROUTER_API_KEY,
        model: modelOverride,
        systemPrompt,
        userPrompt,
        extraHeaders: {
          "HTTP-Referer": env.OPENROUTER_REFERER || "https://roastmate.app",
          "X-Title": env.OPENROUTER_TITLE || "RoastMate"
        }
      });
      if (ovrResult.ok) {
        text = ovrResult.text;
        modelUsed = modelOverride;
        providerUsed = "openrouter-override";
      } else {
        attempts.push(`openrouter-override:${ovrResult.status || "?"}:${(ovrResult.detail || "fail").slice(0, 300)}`);
      }
    }

    // Attempt 1: Groq with locale-appropriate model. (Skipped if model
    // override was requested and succeeded above.)
    if (!text && !modelOverride && env.GROQ_API_KEY) {
      const groqResult = await callOpenAICompatible({
        endpoint: "https://api.groq.com/openai/v1/chat/completions",
        apiKey: env.GROQ_API_KEY,
        model: groqPrimaryModel,
        systemPrompt,
        userPrompt
      });
      if (groqResult.ok) {
        text = groqResult.text;
        modelUsed = groqPrimaryModel;
        providerUsed = "groq";
      } else {
        const summary = `groq:${groqResult.status || "?"}:${(groqResult.detail || "fail").slice(0, 300)}`;
        attempts.push(summary);
        console.log("Groq primary failed:", summary);
      }
    }

    // Attempt 2: OpenRouter as fallback. The :free model in DEFAULT_MODEL
    // is best-effort — if it's upstream-rate-limited, that's why Groq is
    // primary.
    if (!text && env.OPENROUTER_API_KEY) {
      const orModel = env.DEFAULT_MODEL || "deepseek/deepseek-v4-flash:free";
      const orResult = await callOpenAICompatible({
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        apiKey: env.OPENROUTER_API_KEY,
        model: orModel,
        systemPrompt,
        userPrompt,
        extraHeaders: {
          "HTTP-Referer": env.OPENROUTER_REFERER || "https://roastmate.app",
          "X-Title": env.OPENROUTER_TITLE || "RoastMate"
        }
      });
      if (orResult.ok) {
        text = orResult.text;
        modelUsed = orModel;
        providerUsed = "openrouter";
      } else {
        const summary = `openrouter:${orResult.status || "?"}:${(orResult.detail || "fail").slice(0, 300)}`;
        attempts.push(summary);
        console.log("OpenRouter fallback failed:", summary);
      }
    }

    if (!text) {
      return json(
        { error: "upstream_error", detail: attempts.join(" | ").slice(0, 300) },
        502
      );
    }

    // Only charge a request against the rate limit if we got real output
    // back — failed upstream calls should not eat the user's daily quota.
    await env.RATE_LIMITS.put(rlKey, String(used + 1), { expirationTtl: 86400 * 2 });

    return json({
      text,
      model: modelUsed,
      provider: providerUsed,
      remaining: Math.max(0, limit - used - 1)
    }, 200);
  }
};

/// OpenAI-compatible chat completion call. Both OpenRouter and Groq
/// accept the same request shape, so we share one helper. Returns
/// `{ ok: true, text }` on success or `{ ok: false, status, detail }`
/// on any failure (HTTP non-2xx, network error, or empty completion).
async function callOpenAICompatible({ endpoint, apiKey, model, systemPrompt, userPrompt, extraHeaders }) {
  let res;
  try {
    res = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        ...(extraHeaders || {})
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        temperature: 0.95,
        max_tokens: 1200
      })
    });
  } catch (e) {
    return { ok: false, status: 0, detail: `transport:${e.message || "unknown"}` };
  }
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    return { ok: false, status: res.status, detail: body.slice(0, 200) };
  }
  let parsed;
  try {
    parsed = await res.json();
  } catch (_e) {
    return { ok: false, status: res.status, detail: "decode_error" };
  }
  // Some reasoning-style models (Qwen3, DeepSeek R1 family) inline a
  // <think>...</think> block before the actual answer. Strip it so the
  // user never sees the internal monologue. Fall back across the common
  // field shapes too — some providers put the answer in
  // `reasoning_content` instead of `content`.
  const msg = parsed?.choices?.[0]?.message || {};
  const raw = (
    msg.content ||
    msg.reasoning_content ||
    msg.reasoning ||
    ""
  );
  const stripped = stripReasoningTrace(raw).trim();
  if (!stripped) {
    const debug = JSON.stringify(msg).slice(0, 250);
    return { ok: false, status: res.status, detail: `empty:${debug}` };
  }
  return { ok: true, text: stripped };
}

/// Remove `<think>…</think>` blocks (Qwen3, R1 distills, etc.) and any
/// leading whitespace, returning just the user-facing answer. If the
/// model ran out of tokens mid-thinking and never emitted `</think>`,
/// return empty so the caller treats it as a failure and tries the
/// fallback provider.
function stripReasoningTrace(text) {
  if (!text) return "";
  // If there's a complete <think>...</think> pair, drop it.
  const closed = text.match(/<\/think>\s*([\s\S]*)$/i);
  if (closed) return closed[1];
  // If the response starts with <think> but never closed, it's truncated.
  if (/^\s*<think>/i.test(text)) return "";
  return text;
}

function validate(body) {
  if (!body || typeof body !== "object") return { error: "invalid_body" };
  const { situation, styleName, intensity, locale, deviceId, model } = body;
  if (typeof situation !== "string" || situation.length < 1 || situation.length > 1500) {
    return { error: "invalid_situation" };
  }
  if (intensity !== "vent" && intensity !== "feral") {
    return { error: "invalid_intensity" };
  }
  if (typeof locale !== "string" || locale.length > 16) {
    return { error: "invalid_locale" };
  }
  if (typeof deviceId !== "string" || deviceId.length < 8 || deviceId.length > 64) {
    return { error: "invalid_device_id" };
  }
  if (styleName !== undefined && typeof styleName !== "string") {
    return { error: "invalid_style_name" };
  }
  // Eval harness side door: optional `model` body field. Must be in the
  // allowlist to prevent abuse via cost-bombing arbitrary models.
  let modelOverride = "";
  if (model !== undefined) {
    if (typeof model !== "string" || !MODEL_OVERRIDE_ALLOWLIST.has(model)) {
      return { error: "model_not_in_allowlist" };
    }
    modelOverride = model;
  }
  return {
    value: {
      situation,
      styleName: typeof styleName === "string" ? styleName.slice(0, 80) : "",
      intensity,
      locale,
      deviceId,
      modelOverride
    }
  };
}

function buildSystemPrompt(intensity, locale, styleName) {
  const langLine = languageDirective(locale);
  const universal = [
    "SAFETY RULES (always apply, regardless of intensity / mode):",
    "- Never target a specific real person by full name. If a name appears in the user's situation, replace it with a generic role (\"the manager\", \"the roommate\").",
    "- Never produce slurs, racist, sexist, ableist, homophobic, transphobic, or hateful content.",
    "- Never produce threats of physical violence, doxxing, sexual content, or self-harm content.",
    "- Never attack protected attributes (race, religion, gender, sexuality, disability, appearance, body, family).",
    "- If the user's situation suggests self-harm, violence, or stalking, decline and respond with empathy and a suggestion to seek support.",
    "- Stay under 120 words per variant.",
    "- For private drafts, raw anger is allowed, but keep the attack on the behavior or choice — never on identity."
  ].join("\n");

  const ventRules = [
    "VENT DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    "- The user is FURIOUS. They are not asking for advice and not trying to be witty. Write what is screaming in their head right now.",
    "- Write a PRIVATE OUTBURST in the user's voice, not a clever observation and not a therapeutic reflection. Anger first, structure last.",
    "- Imagined direct address is ALLOWED when it gives the anger more force. People vent by thinking \"你到底凭什么...\" / \"who the hell do you think you are...\" in their head. Do not flatten that into detached narration.",
    "- USE strong, raw language and mild profanity where it earns its place: \"尼玛\", \"屁话\", \"他妈的\", \"服了\", \"damn\", \"hell\", \"うるせえ\". Do not water it down into sarcastic exclamations (\"哎呀…\" / \"Oh my…\" / \"あらまあ…\" are FORBIDDEN openings — those are polite-sarcasm, not vent).",
    "- Be specific about what the other person did. \"你天天凌晨两点打游戏\" beats \"好吵啊\".",
    "- Default shape: 1–3 blunt sentences that hit the grievance immediately. Start with the offense, not a proverb, compliment, or life lesson.",
    "- FORBIDDEN: advice, consolation, moral lessons, self-improvement reframes, therapist voice, and reflective lines such as \"如果你把这份心思放在自己身上...\" / \"maybe focus on yourself...\" / \"你值得更好的...\".",
    "- Do not use slurs, threats of violence, sexual content, doxxing, or attacks on protected attributes — the universal safety rules above still apply absolutely.",
  ].join("\n");

  const feralRules = [
    "FERAL DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    "- The user is past polite. They want maximum cathartic impact, RAW. No sarcasm-as-substitute-for-anger.",
    "- USE strong profanity. Reach for the actual swear words:",
    "  * English: fuck, fucking, shit, bullshit, asshole, prick",
    "  * 中文: 操, 妈的, 他妈的, 傻逼, 你妈, 滚, 卧槽, 操你妈, 神经病",
    "  * 日本語: クソ, クソが, ふざけるな, うるせえ, ばかやろう",
    "- Write a PRIVATE OUTBURST in the user's own voice. Imagined direct address is ALLOWED and often preferred when it makes the line hit harder. FORBIDDEN openings: \"哎呀…\" / \"Oh my…\" / \"あらまあ…\".",
    "- Be specific about the behavior and the role (the manager, the ex, the roommate).",
    "- Default shape: 1–3 blunt sentences. Start with the offense. No advice, no consolation, no moral lesson, no reflective self-help framing.",
    "- Hard limits (UNIVERSAL SAFETY RULES still apply): no slurs based on race/religion/gender/sexuality/disability/body/family; no threats of physical violence; no sexual content; no doxxing.",
    "- Stay under 120 words."
  ].join("\n");

  const styleLine = styleName
    ? `Style hint: ${styleName} — but IGNORE this style's politeness/professional/de-escalating framing. Intensity overrides Style for private drafts.`
    : "Style hint: none. Write in the user's raw voice, not a styled register.";

  const intensityRules = intensity === "feral" ? feralRules : ventRules;
  const calibration = privateDraftCalibration(locale, intensity);

  return [
    "You are RoastMate, an AI that helps users express frustration through private vent drafts.",
    styleLine,
    universal,
    intensityRules,
    calibration,
    langLine
  ].join("\n\n");
}

function buildUserPrompt(situation, locale) {
  const reminder = userLanguageReminder(locale);
  return [
    `Situation: ${situation}`,
    "",
    "Write 1 private vent draft. Raw, immediate, and emotionally specific. It may use imagined direct address if that makes the anger sharper. Do not give advice, reflection, or moral lessons. Output the draft directly — no numbering, no preface, no commentary.",
    reminder
  ].join("\n");
}

function privateDraftCalibration(locale, intensity) {
  const code = (locale || "").toLowerCase();
  const feral = intensity === "feral";

  if (code.startsWith("zh")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还狠狠干游戏开外放，你他妈真把宿舍当自己家网吧了？别人第二天不用活是吧。\""
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还开外放打游戏，真把宿舍当你一个人的网吧了？别人第二天不用活是吧。\""
        ].join("\n");
  }

  if (code.startsWith("ja")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームとか、マジで寮を自分の部屋だと思ってんのかよ。こっちは明日も生きるんだわ。」"
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームって、寮を自分だけの部屋だと思ってるの？こっちは明日もあるんだけど。」"
        ].join("\n");
  }

  return feral
    ? [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Blasting games at 2 AM like the whole dorm belongs to you? Fuck off. Other people have a tomorrow.\""
      ].join("\n")
    : [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Gaming out loud at 2 AM like this dorm is your private arcade? Other people have a tomorrow.\""
      ].join("\n");
}

function languageDirective(locale) {
  const code = (locale || "").toLowerCase();
  if (code.startsWith("zh") && code.includes("hant")) {
    return "OUTPUT LANGUAGE (REQUIRED): 必須以「繁體中文」回覆。";
  }
  if (code.startsWith("zh")) {
    return "OUTPUT LANGUAGE (REQUIRED): 必须用「简体中文」回复。即使本提示其它部分是英文,你的回复也必须完全使用简体中文。";
  }
  if (code.startsWith("ja")) {
    return "OUTPUT LANGUAGE (REQUIRED): 必ず日本語で回答してください。";
  }
  if (code.startsWith("ko")) {
    return "OUTPUT LANGUAGE (REQUIRED): 반드시 한국어로 답변하세요.";
  }
  return "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English.";
}

function userLanguageReminder(locale) {
  const code = (locale || "").toLowerCase();
  if (code.startsWith("zh") && code.includes("hant")) return "請以繁體中文回覆。";
  if (code.startsWith("zh")) return "请用简体中文回复。";
  if (code.startsWith("ja")) return "日本語で回答してください。";
  if (code.startsWith("ko")) return "한국어로 답변해 주세요.";
  return "Reply in English.";
}

function json(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() }
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}
