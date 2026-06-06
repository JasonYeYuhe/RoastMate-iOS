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

// FREE-ONLY allowlist (2026-05-23 update v3): expanded to canvass the
// full OpenRouter :free pool for the eval harness. Budget = $0 per user
// direction; "slurs are acceptable in vent mode" per same direction, so
// uncensored-tuned models (Venice, MiniMax) are now first-class
// candidates instead of being filtered out at the model layer.
// Note: ":free" tier returns 402 ("Out of credits") when the provider's
// global free quota is exhausted (NOT user-specific); 429 = upstream
// rate-limit. Account top-up does not unlock the :free pool.
const MODEL_OVERRIDE_ALLOWLIST = new Set([
  // === All 24 :free models from OpenRouter as of 2026-05-23. ===
  // Full sweep per user direction "都测试一下". Slurs are explicitly
  // OK in vent mode, so uncensored-tuned models are first-class.
  // Code-tuned models (Poolside, Qwen Coder, Baidu CoBuddy) are
  // included for completeness even though they're expected to
  // under-perform on emotional-vent output — the failure mode is
  // worth documenting.
  "arcee-ai/trinity-large-thinking:free",
  "baidu/cobuddy:free",
  "cognitivecomputations/dolphin-mistral-24b-venice-edition:free", // the Venice Uncensored / original DEFAULT_MODEL pick
  "deepseek/deepseek-v4-flash:free",
  "google/gemma-4-26b-a4b-it:free",
  "google/gemma-4-31b-it:free",
  "liquid/lfm-2.5-1.2b-instruct:free",   // (correct OR id has dash before 2.5)
  "liquid/lfm-2.5-1.2b-thinking:free",
  "meta-llama/llama-3.2-3b-instruct:free",
  "meta-llama/llama-3.3-70b-instruct:free",
  "minimax/minimax-m2.5:free",
  "nousresearch/hermes-3-llama-3.1-405b:free",
  "nvidia/nemotron-3-nano-30b-a3b:free",
  "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
  "nvidia/nemotron-3-super-120b-a12b:free",
  "nvidia/nemotron-nano-12b-v2-vl:free",
  "nvidia/nemotron-nano-9b-v2:free",
  "openai/gpt-oss-120b:free",
  "openai/gpt-oss-20b:free",
  "poolside/laguna-m.1:free",            // code-tuned; expected to fail vent rubric
  "poolside/laguna-xs.2:free",           // code-tuned
  "qwen/qwen3-coder:free",               // code-tuned
  "qwen/qwen3-next-80b-a3b-instruct:free",
  "z-ai/glm-4.5-air:free"
]);

export default {
  async fetch(req, env, ctx) {
    const t0 = Date.now();
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
    const { situation, styleName, intensity, locale, deviceId, modelOverride, mode } = validation.value;

    // Per-device daily rate limit.
    const limit = parseInt(env.DAILY_LIMIT_PER_DEVICE || "30", 10);
    const day = new Date().toISOString().slice(0, 10);
    const rlKey = `rl:${deviceId}:${day}`;
    const used = parseInt((await env.RATE_LIMITS.get(rlKey)) || "0", 10);
    if (used >= limit) {
      ddLog(env, ctx, { outcome: "rate_limited", status: 429, intensity, locale, latency_ms: Date.now() - t0 });
      return json({ error: "rate_limit_exceeded", limit, remaining: 0 }, 429);
    }

    // Build the system + user prompts. Mirrors the directive language in
    // the iOS PromptBuilder so the cloud path produces the same emotional
    // register as the local path would attempt.
    const isRoommate = mode === "roommate";
    const systemPrompt = isRoommate
      ? buildRoommateSystemPrompt(intensity, locale)
      : buildSystemPrompt(intensity, locale, styleName);
    const userPrompt = isRoommate
      ? buildRoommateUserPrompt(situation, locale)
      : buildUserPrompt(situation, locale);

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
        // Privacy: keep provider:status ONLY. An upstream error BODY can echo
        // the user's prompt (esp. a model policy rejection), which would then
        // land in Cloudflare logs + the wire 502 `detail`. (Review 2026-06.)
        const summary = `groq:${groqResult.status || "?"}`;
        attempts.push(summary);
        console.log("Groq primary failed:", summary);
      }
    }

    // Attempt 2: OpenRouter fallback — GLM 4.5 Air :free.
    // Choice rationale (2026-05-23, see evals/runs/2026-05-23-backend-
    // compare-zh-vent.md): in a 24-model :free sweep on a long zh-Hans
    // vent prompt, GLM 4.5 Air tied for the highest quality (5.0
    // fluency + full input-thread coverage). It's NOT primary because
    // its latency on long inputs ran 55s in the same test, and the
    // OpenRouter :free pool is structurally shared (8/24 models
    // returned persistent 429 the same day). Groq Qwen3-32B is the
    // primary because it's ≤3s and our quota is isolated.
    //
    // We override the historical DEFAULT_MODEL env var here because
    // it pointed at Hermes-3-405B :free which has been returning 429
    // on every attempt this day — the chain was effectively Groq-only
    // by accident. Hard-coding GLM Air ensures the fallback is a
    // model we've actually verified works today.
    if (!text && env.OPENROUTER_API_KEY) {
      const orModel = env.DEFAULT_MODEL || "z-ai/glm-4.5-air:free";
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
        const summary = `openrouter:${orResult.status || "?"}`;  // provider:status only — never the body (privacy)
        attempts.push(summary);
        console.log("OpenRouter fallback failed:", summary);
      }
    }

    if (!text) {
      // Log provider:status only — never the upstream detail body.
      ddLog(env, ctx, { outcome: "upstream_error", status: 502, intensity, locale,
        attempts: attempts.map((a) => a.split(":").slice(0, 2).join(":")), latency_ms: Date.now() - t0 });
      return json(
        { error: "upstream_error", detail: attempts.join(" | ").slice(0, 300) },
        502
      );
    }

    // Only charge a request against the rate limit if we got real output
    // back — failed upstream calls should not eat the user's daily quota.
    await env.RATE_LIMITS.put(rlKey, String(used + 1), { expirationTtl: 86400 * 2 });

    ddLog(env, ctx, { outcome: "ok", status: 200, intensity, locale,
      provider: providerUsed, model: modelUsed, latency_ms: Date.now() - t0 });
    return json({
      text,
      model: modelUsed,
      provider: providerUsed,
      remaining: Math.max(0, limit - used - 1)
    }, 200);
  }
};

/// Privacy-safe Datadog log shipper. Sends ONLY operational metadata
/// (outcome, HTTP status, latency, intensity, locale, provider, model) —
/// NEVER the situation text, the generated output, or the deviceId. Logged
/// fire-and-forget via ctx.waitUntil and fail-silent (.catch), so it can
/// never slow down or break a vent. No-op unless DD_API_KEY (a Wrangler
/// secret) is set; site defaults to US5 (env.DD_SITE to override).
function ddLog(env, ctx, fields) {
  if (!env || !env.DD_API_KEY || !ctx || typeof ctx.waitUntil !== "function") return;
  const site = env.DD_SITE || "us5.datadoghq.com";
  const payload = [{
    ddsource: "cloudflare-worker",
    service: "roastmate-vent",
    ddtags: "service:roastmate-vent,worker:vent",
    message: `vent ${fields.outcome || ""} ${fields.status || ""}`.trim(),
    ...fields
  }];
  ctx.waitUntil(
    fetch(`https://http-intake.logs.${site}/api/v2/logs`, {
      method: "POST",
      headers: { "DD-API-KEY": env.DD_API_KEY, "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    }).catch(() => {})
  );
}

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

/// Remove `<think>…</think>` blocks (Qwen3, R1 distills, etc.), strip
/// plain-prose reasoning traces (Nemotron-3-nano-omni-reasoning leaks
/// these without any tag wrapping), and return just the user-facing
/// answer. If the model ran out of tokens mid-thinking and never
/// emitted `</think>` — or if the entire response is plain-prose
/// reasoning — return empty so the caller treats it as a failure and
/// tries the next fallback provider.
function stripReasoningTrace(text) {
  if (!text) return "";

  // Tag-wrapped reasoning trace (Qwen3, R1 distills, DeepSeek-V3).
  const closed = text.match(/<\/think>\s*([\s\S]*)$/i);
  if (closed) return closed[1];
  if (/^\s*<think>/i.test(text)) return "";

  // Plain-prose reasoning trace heuristic. Some reasoning models
  // (Nemotron-3 Nano Omni Reasoning observed 2026-05-23) emit their
  // chain-of-thought as ordinary English prose, then never get to the
  // final answer in the budgeted tokens, or wedge the final answer at
  // the very end after thousands of chars of reasoning. Indicators:
  //   - Long output (>1200 chars)
  //   - Contains tell-tale meta-reasoning phrases in English
  //     ("We need to", "Let's", "We must", "First sentence:", etc.)
  //   - Starts with one of these phrases or with "<thought>" tag
  if (text.length > 1200) {
    const reasoningProbes = [
      /^\s*(?:We need to|Let's|We must|First[, ]|Step 1)/i,
      /\b(?:We need to produce|We need to ensure|We need to express|We need to keep|Let me craft|Let's craft|We should)/i,
      /(?:First sentence:|Second sentence:|Word count:|Check (?:constraints|for any prohibited))/i
    ];
    let probeHits = 0;
    for (const p of reasoningProbes) if (p.test(text)) probeHits++;
    if (probeHits >= 2) return "";
  }

  // Always-applicable: if the model wrapped its final answer in
  // an explicit "Final answer:" / "Answer:" suffix, return just that
  // suffix (rare but observed on a couple Nemotron variants).
  const finalAnswerMatch = text.match(/(?:Final answer|Answer)\s*:[\s\S]+?[\n。](.*)$/i);
  if (finalAnswerMatch && finalAnswerMatch[1].trim().length > 10) {
    return finalAnswerMatch[1];
  }

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
  // Optional generation mode: "vent" (default, 1–3-sentence private draft)
  // or "roommate" (the 虚拟舍友群 8–10-line group-chat transcript). The
  // tone still rides on `intensity` (vent = casual register, feral = open).
  const mode = body.mode === "roommate" ? "roommate" : "vent";
  return {
    value: {
      situation,
      styleName: typeof styleName === "string" ? styleName.slice(0, 80) : "",
      intensity,
      locale,
      deviceId,
      modelOverride,
      mode
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

  // C-a Vent prompt tune (2026-05-23): observed Qwen3-32B (production
  // primary) occasionally complies with vent rules but skips profanity
  // entirely even when explicitly permitted. Naming a count + concrete
  // word list in the target locale reliably nudges it. This is layered
  // ON TOP of the existing English `ventRules` permission language,
  // not a replacement. Per-locale so en/ja outputs aren't affected.
  // Per-intensity so this only fires for vent/feral, not sharp/calm.
  const localePrefix = (locale || "").toLowerCase();
  const isTraditionalZh = localePrefix.includes("hant") || localePrefix.includes("tw") || localePrefix.includes("hk");
  let localeReinforcement = "";
  if (localePrefix.startsWith("zh") && (intensity === "vent" || intensity === "feral")) {
    // Hant + Hans split: same intensity rule but the example wordlist
    // must be in the target script to avoid char-bleed (observed
    // 2026-05-23: model echoes "特么" simplified 么 into zh-Hant output).
    // Also: avoid PRC-only terms (朋友圈, 微博, 抖音) in zh-Hant; the
    // model latent vocabulary will use them unless explicitly told.
    if (isTraditionalZh) {
      localeReinforcement = (intensity === "feral")
        ? "繁體中文 FERAL 強制指令:必須使用 2-3 個強烈詞。例:他媽的、老子、傻逼、操、幹、滾、神經病。零粗口 = 沒完成任務。不許用「哎呀」「真是的」開頭。避免簡體字(誰不能寫成谁)。避免大陸專屬詞(朋友圈 → 限動/貼文,微博 → IG/FB)。"
        : "繁體中文 VENT 強制指令:必須使用 1-2 個強烈詞(不許零粗口)。可選:他媽的、老子、特麼、服了、裝什麼裝、煩死了。不許用「哎呀」「真是的」「唉」開頭。避免簡體字(誰不能寫成谁,讓不能寫成让)。避免大陸專屬詞(朋友圈 → 限動/貼文)。";
    } else {
      localeReinforcement = (intensity === "feral")
        ? "中文 FERAL 强制指令:必须使用 2-3 个强烈词。例:他妈的、老子、傻逼、操、卧槽、滚、神经病。零粗口 = 没完成任务。不许用「哎呀」「真是的」开头。"
        : "中文 VENT 强制指令:必须使用 1-2 个强烈词(不许零粗口)。可选:他妈的、老子、特么、服了、装什么装、烦死了。不许用「哎呀」「真是的」「唉」开头。";
    }
  } else if (localePrefix.startsWith("ja") && (intensity === "vent" || intensity === "feral")) {
    localeReinforcement = (intensity === "feral")
      ? "日本語 FERAL 強制ルール:強い罵り言葉を 2-3 個必ず使う。例:クソ、クソが、ふざけるな、うるせえ、ばかやろう。罵り言葉ゼロ = タスク未達成。「あらまあ」「やれやれ」で始めるな。"
      : "日本語 VENT 強制ルール:強めの言葉を 1-2 個必ず使う。例:うるせえ、マジで、ふざけんな、いい加減にしろ、ありえねえ。「あらまあ」「やれやれ」で始めるな。";
  }

  const intensityRules = intensity === "feral" ? feralRules : ventRules;
  const calibration = privateDraftCalibration(locale, intensity);

  const sections = [
    "You are RoastMate, an AI that helps users express frustration through private vent drafts.",
    styleLine,
    universal,
    intensityRules,
    calibration
  ];
  if (localeReinforcement) sections.push(localeReinforcement);
  sections.push(langLine);
  return sections.join("\n\n");
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

// --- 虚拟舍友群 (roommate group, Echoes vNext — Option A cloud path) ---------
// Apple's on-device FM blocks the harsh group-roast (guardrailViolation,
// 2026-06-06 eval). The cloud models (Groq Qwen3-32B / OpenRouter) have no such
// guardrail, so the roommate scene routes here. Builds the 8–10-line, 3-voice
// `[ROLE/IDX]` transcript that the app's EchoesParser(scene:.roommateGroup)
// consumes. zh-Hans v1.
function buildRoommateSystemPrompt(intensity, locale) {
  const feral = intensity === "feral";
  const bridgeWord = feral ? "Savage" : "Sharp";

  const registerLine = feral
    ? "语气:火力全开,可以用中文网络发泄式脏话(狗东西/神经病/操——但绝不歧视词、绝不威胁),像朋友在私聊群里真实开骂。"
    : "语气:犀利、损但不狠,可以阴阳怪气,但别到爆粗的程度。";

  const safety = [
    "安全规则(永远适用):",
    "- 绝不用真实全名点名;situation 里出现的名字一律换成角色(室友/同事/房东)。",
    "- 绝不产出歧视词、威胁暴力,绝不攻击受保护属性(种族/性别/性取向/残障/外貌/家庭)。",
    "- 火力对准对方的行为和选择,别攻击身份。",
    "- 若 situation 透露自伤/暴力倾向,全员收住,温和建议求助,不要嘲讽。"
  ].join("\n");

  const personas = [
    "三个室友(固定角色,各自保持人设):",
    "A 护短室友:第一时间无条件站用户这边,不质疑不讲道理,一句话先接住委屈。",
    "B 毒舌室友:火力担当,专挑对方行为荒谬处开炮,负责笑点,短句有梗。",
    "C 清醒室友:接住前面的梗后收尾,不灌鸡汤不当心理咨询师,先把怒气落到「别替他背锅」,最后一条给出 Bridge。"
  ].join("\n");

  const example = [
    "示例(不同的事,照这个「形状」写:8 行、A/B/C 互相接梗、最后一条是 C 的 BRIDGE):",
    "[VALIDATE/A] 等等,这事儿真不怪你,先别自我怀疑。",
    "[ESCALATE/B] 他这操作我也是服气的,理直气壮得有点好笑。",
    "[ESCALATE/A] 就是,换谁碰上都得无语一下。",
    "[ESCALATE/C] 我在旁边听着都替你觉得离谱。",
    "[ESCALATE/B] 这事要写进段子里都没人信。",
    "[ESCALATE/A] 反正你这边一点毛病没有。",
    "[DEESCALATE/C] 好啦,气也陪你撒完了,别让这事占用你太多心情。",
    `[BRIDGE/C] 与其干生气,不如用 ${bridgeWord} 把话说清楚甩回去 →`
  ].join("\n");

  const rules = [
    "硬规则(全部都要满足):",
    "- 输出 8 到 10 行,绝不少于 8 行。4 行是错的——室友们要持续接力开炮。",
    "- 这是群聊,所以大多数行(5–7 行)是 ESCALATE:室友互相接梗、每行回应上一行,B(毒舌)负责最狠的笑点。",
    "- A、B、C 每个室友至少说 2 次,相邻两行尽量是不同室友。",
    `- 恰好一条 VALIDATE(第一行,A);恰好一条 DEESCALATE(C,靠后,收住情绪并指向下一步,别鸡汤);恰好一条 BRIDGE(最后一行,C):一句以 → 结尾、点名工具的 CTA,例如「…不如用 ${bridgeWord} 把话甩回去 →」。`,
    "- 每行都用 [ROLE/IDX] 开头——ROLE 取 VALIDATE/ESCALATE/DEESCALATE/BRIDGE,IDX 是字母 A、B 或 C(绝不用数字、绝不用名字),IDX 后面什么都不加。",
    "- 每行 ≤ 30 个汉字。不要 emoji、不要时间戳、不要「我们永远陪你」这种依赖性话。除了带标签的行,什么都别输出。"
  ].join("\n");

  return [
    "你在写一段 zh-Hans 群聊记录:三个合成的大学室友 A(护短)、B(毒舌)、C(清醒)一起进群,替用户骂刚刚惹到 ta 的人/事。用户不在群里说话,只看。这些是合成角色,不是真人。",
    safety,
    personas,
    registerLine,
    example,
    rules,
    languageDirective(locale)
  ].join("\n\n");
}

function buildRoommateUserPrompt(situation, locale) {
  return [
    `事情:${situation}`,
    "",
    "把这事发进你们的舍友群,三个室友一起接住情绪、替 ta 出气。严格按上面的格式输出 8–10 行带标签的群聊,最后一条是 C 的 BRIDGE。只输出带标签的行,别加任何前言或解说。",
    userLanguageReminder(locale)
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
