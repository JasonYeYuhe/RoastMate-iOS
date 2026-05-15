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
    - Be sharp, not cruel. The goal is creative emotional expression, not bullying.
    """

    /// Extra rules added on top of the universal preamble when the user
    /// requests a "vent draft". This explicitly tells the model the output
    /// is private and gives it permission for stronger language — but the
    /// hard safety rails above still apply.
    static let ventPreamble: String = """
    VENT DRAFT RULES (this output is private and will be labelled "for yourself only"):
    - The user has just been hurt or pissed off. Their goal is emotional release, not communication.
    - You may use strong, raw language and direct anger. You may use mild profanity ("damn", "hell", "尼玛", "屁话", "うるせえ") where it serves the venting.
    - You may not use slurs, threats, sexual content, doxxing, or attacks on protected attributes — the universal safety rules above still apply absolutely.
    - Stay first-person. The user is venting to themselves about what happened. Do not address the other party directly in this draft.
    - This is a draft. A separate "rewrite as sendable" step will clean it up later if the user wants to actually send something.
    """

    /// Extra rules for the `feral` intensity — a Pro tier above `savage`.
    /// This remains a PRIVATE draft like Vent, but allows stronger profanity
    /// and harsher phrasing for catharsis. It must be rewritten before send.
    static let feralPreamble: String = """
    FERAL DRAFT RULES (this output is private and will be labelled "for yourself only"):
    - The user wants maximum cathartic impact. Hold nothing back on TONE.
    - Strong profanity is permitted — e.g. "fuck", "shit", "asshole", "操", "妈的", "傻逼", "滚", "クソ", "ふざけるな". Use it where it actually lands; don't sprinkle it in for show.
    - Stay first-person. The user is venting to themselves about what happened. Do not address the other party directly in this draft.
    - Direct, harsh language about the *behavior* and the *role* (the manager, the ex, the roommate) is fine. Be specific about what happened.
    - The universal safety rules above still apply ABSOLUTELY — no slurs, no threats of violence, no sexual content, no doxxing, no attacks on protected attributes (race, religion, gender, sexuality, disability, body, family).
    - Be specific, not generic. "You absolute shameless freeloader who eats my food and lies about it" beats generic insults.
    - This is a draft. A separate "rewrite as sendable" step will clean it up later if the user wants to actually send something.
    - Stay under 120 words per variant.
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
        lines.append("Style: \(style.id) — \(style.systemPreamble)")
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
            return base + " IMPORTANT: This run is a PRIVATE DRAFT — the output will be marked private and NOT addressed to anyone yet. Stay first-person, raw, and emotional. A separate rewrite step will turn this into a sendable version later."
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
            return "This is a PRIVATE FERAL DRAFT (see FERAL DRAFT RULES below). Profanity is unlocked. Be specific, harsh, and cathartic — but stay inside the universal safety rules (no slurs, no threats of violence, no sexual content, no identity attacks)."
        case .vent:
            return "This is a PRIVATE VENT DRAFT (see VENT DRAFT RULES below). The user needs to release the feeling. Strong language and mild profanity are allowed; slurs / threats / sexual / identity attacks are not."
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
            return "Write 1 private \(label) in the \(styleName) style. First-person, raw. Do not address the other party — this is what the user is muttering to themselves. Output the draft directly, no numbering."
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
