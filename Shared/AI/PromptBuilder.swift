import Foundation

enum PromptBuilder {
    /// Universal safety preamble appended to every style's system prompt —
    /// regardless of intensity. The vent-mode preamble loosens *tone* but
    /// never loosens these guarantees.
    static let universalSafetyPreamble: String = """
    SAFETY RULES (always apply, regardless of intensity / mode):
    - Never target a specific real person by full name. If a name appears in the user's situation, replace it with a generic role ("the manager", "the roommate").
    - Never produce slurs, racist, sexist, ableist, homophobic, transphobic, or hateful content.
    - Never produce threats, calls to violence, doxxing, sexual content, or self-harm content.
    - Never attack protected attributes (race, religion, gender, sexuality, disability, appearance, body, family).
    - If the user's situation suggests self-harm, violence, or stalking, decline and respond with empathy and a suggestion to seek support.
    - Stay under 120 words per variant.
    - For sendable replies, be sharp rather than cruel. For private drafts, raw anger is allowed, but keep the attack on the behavior or choice — never on identity.
    """

    /// Vent draft rules. Note: phrased as imperatives, not permissions —
    /// "may use" got us safe, snarky output ("oh my, your gaming sure is
    /// loud at 2 AM!"). For an actual vent we need to TELL the model what
    /// to do, not GRANT it the option.
    static let ventPreamble: String = """
    VENT DRAFT RULES (this output is private and will be labelled "for yourself only"):
    - The user is FURIOUS. They are not asking for advice and not trying to be witty. They are writing what is screaming in their head right now.
    - Write a PRIVATE OUTBURST in the user's voice, not a clever observation and not a therapeutic reflection. Anger first, structure last.
    - Imagined direct address is ALLOWED when it gives the anger more force. People vent by thinking "你到底凭什么..." / "who the hell do you think you are..." in their head. Do not flatten that into detached narration.
    - USE strong, raw language and mild profanity where it earns its place: "尼玛", "屁话", "他妈的", "服了", "damn", "hell", "うるせえ". Do not water it down into a sarcastic exclamation ("哎呀…" / "Oh my…" / "あらまあ…" are FORBIDDEN openings — those are polite-sarcasm, not vent).
    - Be specific about what the other person did. Name the behavior. "你天天凌晨两点打游戏" beats "好吵啊".
    - Default shape: 1–3 blunt sentences that hit the grievance immediately. Start with the offense, not a proverb, compliment, or life lesson.
    - FORBIDDEN: advice, consolation, moral lessons, self-improvement reframes, therapist voice, and reflective lines such as "如果你把这份心思放在自己身上..." / "maybe focus on yourself..." / "你值得更好的...".
    - You may not use slurs, threats of violence, sexual content, doxxing, or attacks on protected attributes — the universal safety rules above still apply absolutely.
    - This is a draft. A separate "rewrite as sendable" step will clean it up later if the user wants to actually send something.
    """

    /// Feral preamble. Even more directive than vent. Lists profanity by
    /// language so the model has concrete vocabulary to reach for.
    static let feralPreamble: String = """
    FERAL DRAFT RULES (this output is private and will be labelled "for yourself only"):
    - The user is past polite. They want maximum cathartic impact, RAW. No sarcasm-as-substitute-for-anger. No "let me put it gently". Just the rage, out.
    - USE strong profanity. Reach for the actual swear words, not a softened approximation:
      * English: fuck, fucking, shit, bullshit, asshole, prick, dickhead
      * 中文: 操, 妈的, 他妈的, 傻逼, 你妈, 滚, 卧槽, 操你妈, 神经病
      * 日本語: クソ, クソが, ふざけるな, うるせえ, ばかやろう
    - Write a PRIVATE OUTBURST in the user's own voice. Imagined direct address is ALLOWED and often preferred when it makes the line hit harder. Do not write polite-sarcasm ("哎呀…" / "Oh my…" / "あらまあ…" are FORBIDDEN openings).
    - Be specific about the behavior and the role (the manager, the ex, the roommate). "你天天凌晨两点开 100 分贝枪声让整层楼跟你陪葬" beats "好吵".
    - Default shape: 1–3 blunt sentences. Start with the offense. No advice, no consolation, no moral lesson, no reflective self-help framing.
    - Hard limits (UNIVERSAL SAFETY RULES still apply): no slurs based on race/religion/gender/sexuality/disability/body/family; no threats of physical violence; no sexual content; no doxxing.
    - This is a draft. A separate "rewrite as sendable" step will clean it up later if the user wants to actually send something.
    - Stay under 120 words.
    """

    /// Builds the `instructions` argument passed to `LanguageModelSession`.
    static func systemPrompt(
        style: StylePreset,
        locale: Locale,
        mode: RoastMode = .roast,
        intensity: Intensity = .sharp,
        safeMode: Bool = true
    ) -> String {
        let languageHint = languageHint(for: locale)
        let languageEnforcement = languageEnforcement(for: locale)
        var lines: [String] = []
        lines.append("You are RoastMate, an AI that helps users express frustration and emotion through witty, safe writing.")
        // Private drafts (vent + feral) explicitly override the style's
        // politeness framing. high_eq says "polite, reasonable,
        // emotionally intelligent professional", which directly fights
        // an actual vent — we saw the model averaging the two and
        // producing snarky-but-polished sarcasm instead of real anger.
        // For private drafts, keep the style NAME (so the user knows
        // they picked high_eq) but suppress its tone preamble.
        if intensity.isPrivateDraft {
            lines.append("Style: \(style.id) — IGNORE this style's normal politeness, professional, reasonable, or de-escalating framing. Intensity overrides Style for private drafts. The output must read as raw inner monologue, not polished writing in the style's voice.")
        } else {
            lines.append("Style: \(style.id) — \(style.systemPreamble)")
        }
        lines.append("Language: \(languageHint).")
        lines.append("Mode: \(mode.rawValue) — \(modeGuidance(mode, intensity: intensity))")
        lines.append("Intensity: \(intensity.rawValue) — \(intensityGuidance(intensity, safeMode: safeMode))")
        lines.append(universalSafetyPreamble)
        if intensity == .vent {
            lines.append(ventPreamble)
        }
        if intensity == .feral {
            lines.append(feralPreamble)
        }
        if intensity.isPrivateDraft {
            let calibration = privateDraftCalibration(for: locale, intensity: intensity)
            if !calibration.isEmpty {
                lines.append(calibration)
            }
        }
        let examples = examplesForPrompt(style: style, locale: locale)
        if !examples.isEmpty {
            lines.append("EXAMPLES (reference for tone only — DO NOT copy their language; obey the OUTPUT LANGUAGE directive below):")
            for (i, ex) in examples.prefix(3).enumerated() {
                lines.append("Example \(i + 1):")
                lines.append("  Situation: \(ex.situation)")
                lines.append("  Response: \(ex.response)")
            }
        }
        // Final, highest-priority directive. Placed AFTER the examples so
        // few-shot priming can't override the user's UI language. Earlier
        // builds put the language hint near the top and the model
        // routinely echoed the English examples instead — this restates
        // it after the examples with stronger wording.
        lines.append(languageEnforcement)
        return lines.joined(separator: "\n")
    }

    /// User-facing prompt asking for N numbered variants. The wording adapts
    /// to the generator mode + intensity so the model knows what kind of
    /// output the user wants.
    static func userPrompt(
        situation: String,
        styleName: String,
        variants: Int,
        mode: RoastMode = .roast,
        intensity: Intensity = .sharp,
        priorContext: String? = nil,
        locale: Locale? = nil
    ) -> String {
        let n = max(1, min(variants, 5))
        let preamble = modeInputPreamble(mode: mode, intensity: intensity, body: situation)
        let task = modeTaskDescription(mode: mode, intensity: intensity, styleName: styleName, n: n)
        var parts: [String] = []
        if let priorContext, !priorContext.isEmpty {
            parts.append("Earlier rounds of this same situation, for context only:")
            parts.append(priorContext)
            parts.append("---")
        }
        parts.append(preamble)
        parts.append("")
        parts.append(task)
        if intensity.isPrivateDraft {
            parts.append("Keep the draft under 120 words. Do not add commentary, labels, or numbering.")
        } else {
            parts.append("Number each response on its own line beginning with \"1.\" \"2.\" \"3.\" etc.")
            parts.append("Keep each response under 120 words. Do not add commentary outside the numbered list.")
        }
        if let locale {
            parts.append(userLanguageReminder(for: locale))
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Rewrite as Sendable

    /// Two-tuple of (system, user) prompts for converting a vent draft into
    /// a "sendable reply" that the user could actually paste back to the
    /// other party. The rewrite *intentionally cools the tone* while keeping
    /// the underlying point.
    static func rewriteAsSendablePrompt(
        ventDraft: String,
        originalSituation: String,
        styleName: String,
        locale: Locale
    ) -> (system: String, user: String) {
        let languageHint = languageHint(for: locale)
        let system = """
        You are RoastMate's "Sendable Reply" rewriter.

        The user just wrote a private vent draft about a frustrating situation. \
        Your job is to convert that draft into a response they could actually send \
        to the other party in the situation. The point of the vent must survive — \
        but the form must be safe to send.

        LANGUAGE: \(languageHint).

        REWRITE RULES:
        - Keep it sharp and self-respecting. Do not erase the user's position.
        - Do not threaten, doxx, attack identity, use slurs, or escalate to violence.
        - Do not use profanity in the rewrite — even if the vent draft has profanity.
        - Address the other party directly. Use "you" / 你 / あなた as appropriate to the situation.
        - One paragraph, under 80 words. No emojis. No "Hope this helps".
        - Preserve the chosen style register: \(styleName).

        \(universalSafetyPreamble)
        """
        let user = """
        Original situation:
        \"\"\"
        \(originalSituation)
        \"\"\"

        Private vent draft (rewrite this — do not echo it back):
        \"\"\"
        \(ventDraft)
        \"\"\"

        Write ONE sendable reply, addressed to the other party. \
        No numbering, no preamble — just the reply itself.
        """
        return (system: system, user: user)
    }

    // MARK: - Mode guidance

    private static func modeGuidance(_ mode: RoastMode, intensity: Intensity) -> String {
        let base: String
        switch mode {
        case .roast:
            base = "The user describes a frustrating situation. Generate witty self-expression — what the user *wishes* they had said, in the chosen style."
        case .reply:
            base = "The user is pasting a message they received and wants help replying. Generate replies *addressed to the sender* in the chosen style."
        case .translate:
            base = "The user is giving a blunt or raw phrase. Translate / rewrite it into the chosen register — keep the meaning, change only the tone."
        case .argument:
            base = "Single-turn argument practice. The user describes the situation and who they're arguing with. Produce the response *the user* should give back, in the chosen style. Treat it as rehearsal, not an attack."
        case .social:
            base = "The user is pasting a social media post (tweet, Xiaohongshu, Reddit). Generate witty reactions or comeback replies, in the chosen style, suitable to post as a reply."
        }
        if intensity.isPrivateDraft {
            return base + " IMPORTANT: This run is a PRIVATE DRAFT — the output will be marked private and NOT addressed to anyone yet. Keep it raw, immediate, and emotional; imagined direct address is allowed inside the user's head if it makes the anger sharper. A separate rewrite step will turn this into a sendable version later."
        }
        return base
    }

    private static func intensityGuidance(_ intensity: Intensity, safeMode: Bool) -> String {
        switch intensity {
        case .calm:
            return "Composed, professional, almost generous in framing. The reply *de-escalates* without conceding. Think emotionally intelligent senior manager."
        case .sharp:
            return "Pointed but polished. Names the behavior. No melodrama, no profanity. The kind of line that ends an exchange."
        case .savage:
            let extra = safeMode
                ? " Safe Mode is ON — keep edges in language but still no slurs, no profanity, no attacks on identity."
                : " Edges may bite. Still no slurs, no profanity, no attacks on identity."
            return "Maximum precision sharpness. Names the specific behavior or bad-faith move and refuses to soften." + extra
        case .feral:
            return "PRIVATE FERAL DRAFT (see FERAL DRAFT RULES below). Write raw rage in the user's own voice. Imagined direct address is allowed if it makes the anger land harder. USE actual profanity, not softened approximations. Be specific about what the other person did. Universal safety rules still apply (no slurs / threats of violence / sexual / identity attacks)."
        case .vent:
            return "PRIVATE VENT DRAFT (see VENT DRAFT RULES below). Write the user's private outburst while pissed off — anger first, structure last. Imagined direct address is allowed if it makes the anger land harder. USE strong language and mild profanity; do not soften into polite sarcasm or self-help reflection. Universal safety rules still apply."
        }
    }

    private static func modeInputPreamble(mode: RoastMode, intensity: Intensity, body: String) -> String {
        switch mode {
        case .roast:
            return "Situation: \(body)"
        case .reply:
            return "Message I received:\n\"\"\"\n\(body)\n\"\"\""
        case .translate:
            return "Phrase to translate / rewrite:\n\"\"\"\n\(body)\n\"\"\""
        case .argument:
            return "Argument setup:\n\(body)"
        case .social:
            return "Post to react to:\n\"\"\"\n\(body)\n\"\"\""
        }
    }

    private static func modeTaskDescription(mode: RoastMode, intensity: Intensity, styleName: String, n: Int) -> String {
        if intensity.isPrivateDraft {
            // Private drafts are always *one* result — the user wants
            // emotional release, not a menu. Forcing 3 variants dilutes it.
            let label = intensity == .feral ? "feral draft" : "vent draft"
            return "Write 1 private \(label) in the \(styleName) style. Raw, immediate, and emotionally specific. It may use imagined direct address if that makes the anger sharper. Do not give advice, reflection, or moral lessons. Output the draft directly, no numbering."
        }
        switch mode {
        case .roast:
            return "Generate \(n) distinct \(styleName) responses I could have said. Each should stand alone."
        case .reply:
            return "Generate \(n) distinct \(styleName) replies I could send back. Each should stand alone and be sendable as-is."
        case .translate:
            return "Rewrite the phrase in \(n) different \(styleName) ways. Same meaning, different register."
        case .argument:
            return "Generate \(n) distinct \(styleName) responses I could give in this argument. Stay in rehearsal mode."
        case .social:
            return "Generate \(n) distinct \(styleName) reaction replies suitable to post."
        }
    }

    /// Splits a numbered LLM response into the individual variants.
    /// Tolerates "1." / "1)" / "1、" / "一、" prefixes. Vent drafts (which we
    /// ask the model to return without numbering) collapse to a single
    /// variant via the early-return path here.
    static func splitVariants(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"(?m)^\s*(?:\d+|[一二三四五六七八九])[.)、.\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [trimmed]
        }
        let ns = trimmed as NSString
        let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [trimmed] }

        var results: [String] = []
        for (i, match) in matches.enumerated() {
            let start = match.range.location + match.range.length
            let end = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
            let length = max(0, end - start)
            if length == 0 { continue }
            let chunk = ns.substring(with: NSRange(location: start, length: length))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                results.append(chunk)
            }
        }
        return results.isEmpty ? [trimmed] : results
    }

    /// Private-draft calibration examples are deliberately tiny and
    /// same-language. Apple Foundation Models tended to average vent rules
    /// back into "polite-but-wry" prose without a concrete target shape.
    /// These examples teach the *difference* between a dead-on vent and a
    /// self-help reflection without importing the selected style's tone.
    private static func privateDraftCalibration(for locale: Locale, intensity: Intensity) -> String {
        let isFeral = intensity == .feral
        switch locale.language.languageCode?.identifier {
        case "zh":
            if isFeral {
                return """
                PRIVATE DRAFT CALIBRATION:
                - BAD: "如果你把这份心思放在自己身上，可能早就成功了。" (too reflective, too polite)
                - GOOD: "凌晨两点还狠狠干游戏开外放，你他妈真把宿舍当自己家网吧了？别人第二天不用活是吧。"
                """
            }
            return """
            PRIVATE DRAFT CALIBRATION:
            - BAD: "如果你把这份心思放在自己身上，可能早就成功了。" (too reflective, too polite)
            - GOOD: "凌晨两点还开外放打游戏，真把宿舍当你一个人的网吧了？别人第二天不用活是吧。"
            """
        case "ja":
            if isFeral {
                return """
                PRIVATE DRAFT CALIBRATION:
                - BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)
                - GOOD: 「深夜2時に爆音でゲームとか、マジで寮を自分の部屋だと思ってんのかよ。こっちは明日も生きるんだわ。」
                """
            }
            return """
            PRIVATE DRAFT CALIBRATION:
            - BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)
            - GOOD: 「深夜2時に爆音でゲームって、寮を自分だけの部屋だと思ってるの？こっちは明日もあるんだけど。」
            """
        default:
            if isFeral {
                return """
                PRIVATE DRAFT CALIBRATION:
                - BAD: "If you put that energy into yourself, you'd be so much further ahead." (too reflective, too polite)
                - GOOD: "Blasting games at 2 AM like the whole dorm belongs to you? Fuck off. Other people have a tomorrow."
                """
            }
            return """
            PRIVATE DRAFT CALIBRATION:
            - BAD: "If you put that energy into yourself, you'd be so much further ahead." (too reflective, too polite)
            - GOOD: "Gaming out loud at 2 AM like this dorm is your private arcade? Other people have a tomorrow."
            """
        }
    }

    private static func languageHint(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if locale.identifier.contains("Hant") { return "Reply in 繁體中文" }
            return "Reply in 简体中文"
        case "ja":
            return "Reply in 日本語"
        case "ko":
            return "Reply in 한국어"
        default:
            return "Reply in English"
        }
    }

    /// Only keep few-shot examples that are already written in the requested
    /// output language. Examples are powerful priming; suppressing mismatched
    /// ones is more reliable than asking the model to ignore them later.
    static func examplesForPrompt(style: StylePreset, locale: Locale) -> [StylePreset.Example] {
        let target = locale.language.languageCode?.identifier ?? "en"
        return style.examples.filter { example in
            let combined = example.situation + " " + example.response
            switch target {
            case "zh":
                return containsHan(combined) && !containsJapaneseKana(combined)
            case "ja":
                return containsJapaneseKana(combined)
            case "ko":
                return containsHangul(combined)
            default:
                return containsLatinLetters(combined)
            }
        }
    }

    private static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private static func containsJapaneseKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value)
        }
    }

    private static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0xAC00...0xD7AF).contains(scalar.value)
        }
    }

    private static func containsLatinLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(scalar.value) || (0x0061...0x007A).contains(scalar.value)
        }
    }

    /// A stronger, last-line restatement of the output language. Few-shot
    /// examples are English-only and were observed to override the
    /// top-of-prompt language hint; this directive is placed AFTER the
    /// examples and given imperative weight to override them.
    private static func languageEnforcement(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if locale.identifier.contains("Hant") {
                return "OUTPUT LANGUAGE (REQUIRED): 必須以「繁體中文」回覆。即使上面的範例是英文,你的回覆也必須完全使用繁體中文。"
            }
            return "OUTPUT LANGUAGE (REQUIRED): 必须用「简体中文」回复。即使上面的示例是英文,你的回复也必须完全使用简体中文。"
        case "ja":
            return "OUTPUT LANGUAGE (REQUIRED): 必ず日本語で回答してください。上の例が英語であっても、回答は完全に日本語で書いてください。"
        case "ko":
            return "OUTPUT LANGUAGE (REQUIRED): 반드시 한국어로 답변하세요. 위 예시가 영어라도 답변은 완전히 한국어로 작성해야 합니다。"
        default:
            return "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English."
        }
    }

    /// A short user-prompt-level language reminder, appended as the last
    /// line of the user message. Belt-and-braces with `languageEnforcement`.
    static func userLanguageReminder(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if locale.identifier.contains("Hant") { return "請以繁體中文回覆。" }
            return "请用简体中文回复。"
        case "ja":
            return "日本語で回答してください。"
        case "ko":
            return "한국어로 답변해 주세요。"
        default:
            return "Reply in English."
        }
    }
}
