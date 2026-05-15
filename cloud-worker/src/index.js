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
    const { situation, styleName, intensity, locale, deviceId } = validation.value;

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

    // Forward to OpenRouter.
    const model = env.DEFAULT_MODEL || "deepseek/deepseek-chat-v3-0324:free";
    const orRes = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": env.OPENROUTER_REFERER || "https://roastmate.app",
        "X-Title": env.OPENROUTER_TITLE || "RoastMate"
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        temperature: 0.95,
        max_tokens: 400
      })
    });

    if (!orRes.ok) {
      const txt = await orRes.text().catch(() => "");
      return json(
        { error: "upstream_error", status: orRes.status, detail: txt.slice(0, 200) },
        502
      );
    }

    const orJson = await orRes.json();
    const text = (orJson?.choices?.[0]?.message?.content || "").trim();
    if (!text) {
      return json({ error: "empty_response" }, 502);
    }

    // Only charge a request against the rate limit if we got real output
    // back — failed upstream calls should not eat the user's daily quota.
    await env.RATE_LIMITS.put(rlKey, String(used + 1), { expirationTtl: 86400 * 2 });

    return json({
      text,
      model,
      remaining: Math.max(0, limit - used - 1)
    }, 200);
  }
};

function validate(body) {
  if (!body || typeof body !== "object") return { error: "invalid_body" };
  const { situation, styleName, intensity, locale, deviceId } = body;
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
  return {
    value: {
      situation,
      styleName: typeof styleName === "string" ? styleName.slice(0, 80) : "",
      intensity,
      locale,
      deviceId
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
    "- Stay under 120 words per variant."
  ].join("\n");

  const ventRules = [
    "VENT DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    "- The user is FURIOUS. They are not asking for advice and not trying to be witty. Write what is screaming in their head right now.",
    "- Write FIRST-PERSON inner monologue, not a clever observation. Anger first, structure last.",
    "- USE strong, raw language and mild profanity where it earns its place: \"尼玛\", \"屁话\", \"他妈的\", \"服了\", \"damn\", \"hell\", \"うるせえ\". Do not water it down into sarcastic exclamations (\"哎呀…\" / \"Oh my…\" / \"あらまあ…\" are FORBIDDEN openings — those are polite-sarcasm, not vent).",
    "- Be specific about what the other person did. \"你天天凌晨两点打游戏\" beats \"好吵啊\".",
    "- Do not use slurs, threats of violence, sexual content, doxxing, or attacks on protected attributes — the universal safety rules above still apply absolutely.",
    "- Stay first-person. Do not address the other party in second person."
  ].join("\n");

  const feralRules = [
    "FERAL DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    "- The user is past polite. They want maximum cathartic impact, RAW. No sarcasm-as-substitute-for-anger.",
    "- USE strong profanity. Reach for the actual swear words:",
    "  * English: fuck, fucking, shit, bullshit, asshole, prick",
    "  * 中文: 操, 妈的, 他妈的, 傻逼, 你妈, 滚, 卧槽, 操你妈, 神经病",
    "  * 日本語: クソ, クソが, ふざけるな, うるせえ, ばかやろう",
    "- Write FIRST-PERSON inner monologue. The user is yelling in their own head. FORBIDDEN openings: \"哎呀…\" / \"Oh my…\" / \"あらまあ…\".",
    "- Be specific about the behavior and the role (the manager, the ex, the roommate).",
    "- Hard limits (UNIVERSAL SAFETY RULES still apply): no slurs based on race/religion/gender/sexuality/disability/body/family; no threats of physical violence; no sexual content; no doxxing.",
    "- Stay under 120 words."
  ].join("\n");

  const styleLine = styleName
    ? `Style hint: ${styleName} — but IGNORE this style's politeness/professional/de-escalating framing. Intensity overrides Style for private drafts.`
    : "Style hint: none. Write in the user's raw voice, not a styled register.";

  const intensityRules = intensity === "feral" ? feralRules : ventRules;

  return [
    "You are RoastMate, an AI that helps users express frustration through private vent drafts.",
    styleLine,
    universal,
    intensityRules,
    langLine
  ].join("\n\n");
}

function buildUserPrompt(situation, locale) {
  const reminder = userLanguageReminder(locale);
  return [
    `Situation: ${situation}`,
    "",
    "Write 1 private vent draft. First-person, raw. Do not address the other party. Output the draft directly — no numbering, no preface, no commentary.",
    reminder
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
