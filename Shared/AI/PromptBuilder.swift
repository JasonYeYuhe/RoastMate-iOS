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
            lines.append("Style: \(style.id) — \(style.systemPreamble(for: locale))")
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
        if intensity == .sharp || intensity == .calm {
            let calibration = sharpCalmCalibration(for: locale, intensity: intensity)
            if !calibration.isEmpty {
                lines.append(calibration)
            }
        }
        if intensity == .savage {
            lines.append(savageCalibration(for: locale))
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
            if n > 1 {
                // Lens 1: the top opener appeared in 7 of 12 Sharp-Pro outputs.
                parts.append("Each response must open differently: no two start with the same words, and each takes a different angle on the situation.")
            }
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
        // POINT OF VIEW is the first rule because it was the most common
        // failure: on macOS 27 (permissive guardrails, 6 real production
        // drafts, 2026-10-22) 3/6 rewrites mixed up who "you" was (「完全忽略你的
        // 貢獻」 for the user's own work) and the English one narrated the
        // situation in the third person — not a message anyone could send.
        //
        // The retaliation clause on the threat rule is folded INTO that rule
        // on purpose. A draft that says "next time I'll delete the deck and
        // quit the group" came back as 「如果你繼續這樣，我會刪掉簡報，然後退出群組」
        // (1 of 3 rounds). Adding it as a separate bullet, or adding a "keep
        // who did what" bullet, flipped the point of view of that same draft in
        // 3/3 tries (「我半夜十一點在群組@你」); the in-place wording kept 6/6
        // correct with no ultimatum (macOS 27.0.1, scratchpad trackA2/exp,
        // 2026-10-22). This small model is sensitive to rule count — measure
        // before adding bullets here.
        let system = """
        You are RoastMate's "Sendable Reply" rewriter.

        The user just wrote a private vent draft about a frustrating situation. \
        Your job is to turn it into a message THE USER sends TO the other party \
        in that situation. The point of the vent must survive — \
        but the form must be safe to send.

        LANGUAGE: \(languageHint).

        POINT OF VIEW (most important rule):
        - You write AS the user, TO the other party. The user is the first person; the other party is the second person.
        - \(rewritePointOfView(for: locale))
        - In the situation and the draft, the user's own "I / 我 / 私" stays first person. The other party ("the manager", "my roommate", "he / she", 主管 / 室友 / 他 / 她, 上司 / 彼 / 彼女) becomes "you / 你 / あなた".
        - Never describe the user or the other party in the third person, never retell the situation as a story, and never talk to the user about their situation or feelings.

        REWRITE RULES:
        - Keep it sharp and self-respecting. Do not erase the user's position. Say what the other party did and what the user wants instead.
        - Do not threaten, doxx, attack identity, use slurs, or escalate to violence. If the draft contains a threat, including retaliation such as deleting work or walking out, leave it out entirely.
        - Do not use profanity in the rewrite — even if the vent draft has profanity.
        - One paragraph, under 80 words. No emojis. No greeting placeholders such as [name]. No "Hope this helps".
        - Preserve the chosen style register: \(styleName).

        \(universalSafetyPreamble)
        """
        let user = """
        Original situation (written by the user — "I" is the user):
        \"\"\"
        \(originalSituation)
        \"\"\"

        Private vent draft (rewrite this — do not echo it back):
        \"\"\"
        \(ventDraft)
        \"\"\"

        Write ONE message that I, the user, will send to the other party: \
        first person for me, second person for them. \
        No numbering, no preamble — just the message itself.
        \(userLanguageReminder(for: locale))
        """
        return (system: system, user: user)
    }

    /// The pronoun pair for the rewrite, in the output language. Structural
    /// placeholders only — a concrete example sentence gets copied into
    /// unrelated situations (see `sharpCalmCalibration`).
    private static func rewritePointOfView(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if AppLanguage.contentBucket(for: locale) == .traditionalChinese {
                return "用「我」稱呼使用者自己，用「你」稱呼對方。BAD: 「他……你的……」 GOOD: 「你……我的……」"
            }
            return "用「我」称呼用户自己，用「你」称呼对方。BAD: 「他……你的……」 GOOD: 「你……我的……」"
        case "ja":
            return "ユーザー自身は「私」、相手は「あなた」と書く。BAD: 「彼は……あなたの……」 GOOD: 「あなたは……私の……」"
        default:
            return "Use I / me / my for the user and you / your for the other party. BAD: \"They … your …\" GOOD: \"You … my …\""
        }
    }

    // MARK: - Mode guidance

    private static func modeGuidance(_ mode: RoastMode, intensity: Intensity) -> String {
        let base: String
        switch mode {
        case .roast:
            // Was "what the user *wishes* they had said": 9/12 Sharp-Pro
            // outputs then opened with "I'd have said:" (lens 1, 2026-10-22).
            base = "The user describes a frustrating situation. Write the lines the user could say to the other person, in the chosen style. Each line IS what gets said: start with the words themselves, never with a frame such as \"I'd have said:\"."
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
            return "Generate \(n) distinct \(styleName) lines I could say to them. Each should stand alone and start with the words themselves."
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
        return (results.isEmpty ? [trimmed] : results).map(stripSaidWrapper)
    }

    /// Backstop for the "I'd have said:" frame the roast prompt used to invite
    /// (lens 1: 9/12 Sharp-Pro outputs). Only strips the frame when a colon or
    /// an opening quote follows it, so "I'd say congrats, but…" is left alone.
    static func stripSaidWrapper(_ text: String) -> String {
        let frame = #"^(?:i'd have said|i would have said|i'd've said|what i should have said(?: was)?|i'd say|i would say|我會說|我会说|我會回|我会回|我當時應該說|我当时应该说|我想說|我想说|私ならこう言う|こう言ってやりたかった|言ってやりたかった)\s*(?:[:：]\s*|(?=["“「『]))"#
        let normalized = text.replacingOccurrences(of: "\u{2019}", with: "'")
        guard let r = normalized.range(of: frame, options: [.regularExpression, .caseInsensitive]) else { return text }
        var rest = String(normalized[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let pairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("「", "」"), ("『", "』")]
        for (open, close) in pairs where rest.count >= 2 && rest.first == open && rest.last == close {
            let inner = rest.dropFirst().dropLast()
            if !inner.contains(open) && !inner.contains(close) { rest = String(inner) }
            break
        }
        return rest.isEmpty ? text : rest
    }

    /// Indexes of versions that nearly repeat an earlier one (character-bigram
    /// Jaccard ≥ 0.6). Lens 1: 3/30 three-version calls had a near-duplicate.
    static func nearDuplicateIndexes(_ texts: [String], threshold: Double = 0.6) -> IndexSet {
        func bigrams(_ s: String) -> Set<String> {
            let chars = Array(s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation })
            guard chars.count > 1 else { return Set(chars.map { String($0) }) }
            return Set((0..<(chars.count - 1)).map { String(chars[$0...($0 + 1)]) })
        }
        let grams = texts.map(bigrams)
        var dupes = IndexSet()
        for j in grams.indices {
            for i in 0..<j where !dupes.contains(i) {
                let union = grams[i].union(grams[j]).count
                guard union > 0 else { continue }
                if Double(grams[i].intersection(grams[j]).count) / Double(union) >= threshold {
                    dupes.insert(j)
                    break
                }
            }
        }
        return dupes
    }

    /// `texts` without the near-duplicates, keeping the first of each pair.
    static func droppingNearDuplicates(_ texts: [String]) -> [String] {
        let dupes = nearDuplicateIndexes(texts)
        return texts.enumerated().filter { !dupes.contains($0.offset) }.map(\.element)
    }

    /// Private-draft calibration examples are deliberately tiny and
    /// same-language. Apple Foundation Models tended to average vent rules
    /// back into "polite-but-wry" prose without a concrete target shape.
    /// These examples teach the *difference* between a dead-on vent and a
    /// self-help reflection without importing the selected style's tone.
    private static func privateDraftCalibration(for locale: Locale, intensity: Intensity) -> String {
        let isFeral = intensity == .feral
        switch locale.language.languageCode?.identifier {
        case "zh" where AppLanguage.contentBucket(for: locale) == .traditionalChinese:
            // The GOOD lines are what the model imitates most closely, so they
            // have to be in the target script and in Taiwan usage. THREE
            // different situations, not one: with a single 凌晨兩點 example the
            // on-device model pasted it into unrelated situations (6/6 zh_TW
            // Sharp outputs on macOS 27, 2026-10-22). "Shape only" is stated
            // because the model otherwise reuses the nouns.
            if isFeral {
                return """
                PRIVATE DRAFT CALIBRATION (copy the SHAPE, never the situation or its words):
                - BAD: "如果你把這份心思放在自己身上，可能早就成功了。" (too reflective, too polite)
                - GOOD (roommate): "半夜還開外放狂打遊戲，你他媽真把宿舍當自己家網咖了？別人隔天不用活是吧。"
                - GOOD (work): "幹，又是最後一刻才把爛攤子丟給我，你的拖延憑什麼要我熬夜收拾？"
                - GOOD (money): "錢借了就裝死，訊息已讀不回，靠北喔，當我提款機？"
                """
            }
            return """
            PRIVATE DRAFT CALIBRATION (copy the SHAPE, never the situation or its words):
            - BAD: "如果你把這份心思放在自己身上，可能早就成功了。" (too reflective, too polite)
            - GOOD (roommate): "半夜還開外放打遊戲，真把宿舍當你一個人的網咖了？別人隔天不用上課是吧。"
            - GOOD (work): "又是最後一刻才丟工作過來，你的拖延憑什麼變成我的加班？"
            - GOOD (money): "借錢的時候說下週還，現在連訊息都已讀不回，當我提款機喔？"
            """
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

    /// Sharp/Calm tone calibration. Apple FM in zh + ja regularly drifts
    /// toward over-polite, hedge-creep, or apology-creep — Sharp loses its
    /// bite and Calm concedes the user's legitimate position. Same-language
    /// BAD/GOOD pairs anchor the model to the right shape. en stays untuned;
    /// the universal intensityGuidance line already works in English.
    /// Savage had no shape guidance, so it averaged into generic insults or
    /// into the same opener three times (lens 1). Three different situations,
    /// shape only, like Sharp/Calm; each language gets its own, because a
    /// single situation gets copied into unrelated outputs (2026-10-22). The
    /// situations are deliberately uncommon ones: the first draft used credit
    /// theft, and on the "manager took credit" input 台劇腔 returned that GOOD
    /// line verbatim (A5 gate, 2026-10-31).
    static func savageCalibration(for locale: Locale) -> String {
        switch AppLanguage.contentBucket(for: locale) {
        case .traditionalChinese:
            return """
            SAVAGE TONE CALIBRATION (Savage = 精準, 不是大聲). Copy the SHAPE only — never these situations, details, words or people, even when the user's situation looks like one of them:
            - BAD: 「你是我見過最爛的人。」 (空泛的罵, 沒點名任何事)
            - BAD: 「你會後悔的。」 (威脅, 絕對不行)
            - GOOD (健身房佔器材): 「你在臥推椅上坐了四十分鐘，真正在練的只有三分鐘，其他都在滑手機。」
            - GOOD (借梯子不還): 「梯子借走三個月了，你家的燈應該早就換好了吧。」
            - GOOD (群組已讀不回): 「群組已讀不回，限時動態倒是一小時發三則。」
            (點名具體行為, 用使用者情境裡的細節, 收在重點上, 不帶髒話)
            """
        case .simplifiedChinese:
            return """
            SAVAGE TONE CALIBRATION (Savage = 精准, 不是大声). Copy the SHAPE only — never these situations, details, words or people, even when the user's situation looks like one of them:
            - BAD: 「你是我见过最烂的人。」 (空泛的骂, 没点名任何事)
            - BAD: 「你会后悔的。」 (威胁, 绝对不行)
            - GOOD (健身房占器材): 「你在卧推凳上坐了四十分钟，真正在练的只有三分钟，其他都在刷手机。」
            - GOOD (借梯子不还): 「梯子借走三个月了，你家的灯应该早就换好了吧。」
            - GOOD (群里已读不回): 「群里已读不回，朋友圈倒是一小时发三条。」
            (点名具体行为, 用用户情境里的细节, 收在重点上, 不带脏话)
            """
        case .japanese:
            return """
            SAVAGE TONE CALIBRATION (Savage = 正確さであって、声の大きさではない). Copy the SHAPE only — never these situations, details, words or people, even when the user's situation looks like one of them:
            - BAD: 「あなたは最低な人間だ。」 (中身のない悪口)
            - BAD: 「後悔させてやる。」 (脅し。絶対に不可)
            - GOOD (ジムの器具占領): 「ベンチを四十分使って、実際に上げていたのは三分。残りはずっとスマホでしたね。」
            - GOOD (脚立を返さない): 「脚立を貸したのは三月です。電球、もうとっくに替え終わってますよね。」
            - GOOD (グループで既読無視): 「グループは既読無視なのに、ストーリーは一時間に三本。」
            (具体的な行動を名指しし、ユーザーの状況の細部を使い、要点で終える。下品な言葉は使わない)
            """
        case .english, .system:
            return """
            SAVAGE TONE CALIBRATION (Savage = precise, not loud). Copy the SHAPE only — never these situations, details, words or people, even when the user's situation looks like one of them:
            - BAD: "You're the worst person I've ever met." (a generic insult; names nothing)
            - BAD: "You'll regret this." (a threat — never)
            - GOOD (gym bench): "Forty minutes on the bench, three of them lifting. The rest was your phone."
            - GOOD (borrowed ladder): "You borrowed the ladder in March. Your lightbulbs must be very well changed by now."
            - GOOD (group chat): "Seen in the group chat at nine. Three stories posted by ten."
            (name the exact behavior, use a concrete detail from the user's situation, end on the point, no profanity)
            """
        }
    }

    private static func sharpCalmCalibration(for locale: Locale, intensity: Intensity) -> String {
        let isSharp = intensity == .sharp
        switch locale.language.languageCode?.identifier {
        case "zh":
            let isHant = AppLanguage.contentBucket(for: locale) == .traditionalChinese
            if isSharp {
                if isHant {
                    // Three situations, Taiwan usage (管委會, not 物管). The
                    // old single 凌晨兩點/物管 GOOD line was copied into 6/6
                    // unrelated zh_TW Sharp outputs on macOS 27 (2026-10-22).
                    return """
                    SHARP TONE CALIBRATION (Sharp ≠ 沒禮貌, Sharp ≠ vent, Sharp = 終結對話的那一句). Copy the SHAPE only — never these situations, times, places or people:
                    - BAD: 「不好意思，如果方便的話，下次能不能早點跟我說？謝謝。」 (太軟, hedge-creep, 在請求許可)
                    - BAD: 「唉，你又這樣，可不可以不要啦？」 (太情緒化, 還是在乞求)
                    - GOOD (朋友遲到): 「約好七點，你每次都八點才到。你的時間是時間，我的就不是？下次超過十五分鐘我就先走。」
                    - GOOD (同事丟工作): 「這份工作不在我的範圍，你上週也這樣丟過來。要我幫忙可以，先跟主管講好。」
                    - GOOD (樓上噪音): 「樓上拖椅子的聲音整棟都聽得到。十一點以後請收斂，不然我請管委會處理。」
                    (點名對方的行為, 給出底線, 不帶髒話, 只針對使用者描述的那件事)
                    """
                }
                // Same three situations as zh-Hant, mainland usage (物业,
                // 领导). The single 凌晨两点/物业 line was copied into 6 of 8
                // returned zh_CN Sharp outputs on macOS 27.0.1 (2026-10-22,
                // scratchpad trackA2/sharp) — the zh-Hant defect, unfixed here.
                return """
                SHARP TONE CALIBRATION (Sharp ≠ 没礼貌, Sharp ≠ vent, Sharp = 终结对话的那一句). Copy the SHAPE only — never these situations, times, places or people:
                - BAD: 「不好意思，如果方便的话，下次能不能早点跟我说？谢谢。」 (太软, hedge-creep, 在请求许可)
                - BAD: 「唉，你又这样，能不能别这样啊？」 (太情绪化, 还是在乞求)
                - GOOD (朋友迟到): 「约好七点，你每次都八点才到。你的时间是时间，我的就不是？下次超过十五分钟我就先走。」
                - GOOD (同事甩活): 「这活不在我的职责范围，你上周也这么甩过来。要我帮忙可以，先跟领导说好。」
                - GOOD (楼上噪音): 「楼上拖椅子的声音整栋楼都听得到。十一点以后请注意，不然我找物业处理。」
                (点名对方的行为, 给出底线, 不带脏话, 只针对用户描述的那件事)
                """
            }
            // .calm
            if isHant {
                return """
                CALM TONE CALIBRATION (Calm ≠ 道歉, Calm ≠ 退讓, Calm = 沉穩但立場清楚). Copy the SHAPE only — never these situations, times, places or people:
                - BAD: 「對不起打擾你了，方便的話下次可以早點說嗎？」 (concedes — 被冒犯的那方不該道歉)
                - BAD: 「我也理解你很忙，但是…」 (太寬宏, 退讓在前)
                - GOOD (朋友遲到): 「我們約七點，最近幾次都晚了快一小時。下次會遲到的話，請先跟我說一聲。」
                - GOOD (同事丟工作): 「這份工作不在我負責的範圍。需要我支援的話，請先跟主管確認分工，我們再排時間。」
                - GOOD (樓上噪音): 「樓上拖椅子的聲音已經影響到我們休息。十一點以後可以放輕一點嗎？有需要我們可以當面聊。」
                (沉穩, 點名行為, 不道歉, 不退讓, 只針對使用者描述的那件事)
                """
            }
            return """
            CALM TONE CALIBRATION (Calm ≠ 道歉, Calm ≠ 让步, Calm = 沉稳但立场清楚). Copy the SHAPE only — never these situations, times, places or people:
            - BAD: 「对不起打扰你了，方便的话下次可以早点说吗？」 (concedes — 被冒犯的那方不该道歉)
            - BAD: 「我也理解你很忙，但是…」 (太宽宏, 退让在前)
            - GOOD (朋友迟到): 「我们约的是七点，最近几次都晚了快一个小时。下次要迟到的话，请提前跟我说一声。」
            - GOOD (同事甩活): 「这项工作不在我负责的范围。需要我支援的话，请先跟领导确认分工，我们再排时间。」
            - GOOD (楼上噪音): 「楼上拖椅子的声音已经影响到我们休息了。十一点以后能不能轻一点？有需要我们可以当面聊。」
            (沉稳, 点名行为, 不道歉, 不让步, 只针对用户描述的那件事)
            """
        case "ja":
            // Three situations, as for Chinese. The single 深夜2時/管理人 line
            // was copied into 15 of 16 ja_JP Sharp outputs on macOS 27.0.1,
            // some verbatim into a family argument (2026-10-22, scratchpad
            // trackA2/sharp).
            if isSharp {
                return """
                SHARP TONE CALIBRATION (Sharp ≠ 失礼, Sharp ≠ vent, Sharp = やり取りを終わらせる一行). Copy the SHAPE only — never these situations, times, places or people:
                - BAD: 「すみません、もしよろしければ、次回は早めに教えていただけると助かります。」 (過度に丁寧, hedge-creep, 許可を求めている)
                - BAD: 「またそれ？もうやめてくれない？」 (感情的, 依然お願い口調)
                - GOOD (友人の遅刻): 「7時の約束なのに、毎回8時に来ますよね。あなたの時間は大事で、私の時間は大事じゃないんですか。次に15分以上遅れたら先に帰ります。」
                - GOOD (同僚の丸投げ): 「この仕事は私の担当ではありません。先週も同じように回してきましたよね。手伝うなら、まず上司に話を通してください。」
                - GOOD (上の階の騒音): 「椅子を引きずる音が建物中に響いています。11時以降は控えてください。続くなら管理会社に相談します。」
                (相手の行為を名指し, 線を引く, 罵倒なし, ユーザーが書いた件だけを扱う)
                """
            }
            // .calm
            return """
            CALM TONE CALIBRATION (Calm ≠ 謝罪, Calm ≠ 譲歩, Calm = 落ち着いた立場保持). Copy the SHAPE only — never these situations, times, places or people:
            - BAD: 「お忙しいところすみません、もしよければ次回は早めに連絡いただけますか…」 (過度な謝罪 — 困らされた側が謝るのは不自然)
            - BAD: 「お忙しいのは分かるんですけど…」 (寛大すぎる, 譲歩が先)
            - GOOD (友人の遅刻): 「7時の約束でしたが、最近は毎回1時間近く遅れています。遅れるときは、事前に連絡をください。」
            - GOOD (同僚の丸投げ): 「この仕事は私の担当範囲外です。手伝いが必要なら、まず上司と分担を確認してから時間を調整しましょう。」
            - GOOD (上の階の騒音): 「椅子を引きずる音で、こちらは休めていません。11時以降は少し静かにしていただけますか。必要なら直接お話しします。」
            (落ち着き, 行為を名指し, 謝らない, 譲歩しない, ユーザーが書いた件だけを扱う)
            """
        default:
            // en/ko/other: untuned. The universal intensityGuidance line
            // already produces clean Sharp/Calm output in English (verified
            // in baseline). ko has too few real-traffic samples to tune
            // confidently — defer until Phase 4 if A′ shows demand.
            return ""
        }
    }

    private static func languageHint(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if AppLanguage.contentBucket(for: locale) == .traditionalChinese { return "Reply in 繁體中文" }
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
        let target = AppLanguage.contentBucket(for: locale).rawValue
        return style.examples.filter { ($0.lang ?? inferredLanguage(of: $0)) == target }
    }

    /// Bucket of an untagged example, from its script. Han without kana
    /// counts as Simplified: every untagged Chinese example predates zh-Hant
    /// examples and is Simplified.
    private static func inferredLanguage(of example: StylePreset.Example) -> String {
        let combined = example.situation + " " + example.response
        if containsJapaneseKana(combined) { return AppLanguage.japanese.rawValue }
        if containsHan(combined) { return AppLanguage.simplifiedChinese.rawValue }
        if containsHangul(combined) { return "ko" }
        return AppLanguage.english.rawValue
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


    /// A stronger, last-line restatement of the output language. Few-shot
    /// examples are English-only and were observed to override the
    /// top-of-prompt language hint; this directive is placed AFTER the
    /// examples and given imperative weight to override them.
    private static func languageEnforcement(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            if AppLanguage.contentBucket(for: locale) == .traditionalChinese {
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
            if AppLanguage.contentBucket(for: locale) == .traditionalChinese { return "請以繁體中文回覆。" }
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

/// One line of an Argument Simulator transcript, as the prompt sees it.
/// Lives in Shared (not the app target's `ArgumentTurn`) so `RoastMateTests`
/// can check the prompt.
struct ArgumentLine: Sendable, Equatable {
    enum Speaker: Sendable, Equatable { case opponent, user }
    let speaker: Speaker
    let text: String
}

// MARK: - Argument Simulator (A4)

extension PromptBuilder {
    /// Turns the prompt carries; the simulator stops at 12 anyway.
    static let opponentTranscriptLimit = 12

    /// The Argument Simulator's own prompt: the model IS the other person.
    ///
    /// Until 1.8.0 the simulator reused the roast prompt, which told the model
    /// to write "the response *the user* should give back" and to number its
    /// replies, while the input asked for the other side. Lens 1 (2026-10-22,
    /// 36 turns): 14/26 model turns spoke as the opponent, 7 flipped to the
    /// user's side, 12/36 came back numbered.
    ///
    /// Stateless per turn: the setup and the transcript so far ride in the
    /// prompt instead of a cached session, so A3's fresh permissive retry
    /// keeps the context. No Sharp calibration and no examples: both are
    /// written as the user and pulled the model to the user's side.
    /// Instructions for the one call that names the other person before the
    /// first turn (`RoastEngine.opponentPersona`). Measured 2026-10-31 on lens
    /// 1's set (`docs/evidence/.../a4`): without it about half the turns mixed
    /// up who held which position. Asking for the other person's STANCE too
    /// inverted it on the raise setup in every run ("You are the employee"),
    /// so this asks for the role only; the setup carries the stance.
    static let opponentPersonaInstructions = """
        You read a short setup a user wrote about an argument they want to rehearse. "I" in the setup is the user. Name the person the user will argue WITH — never the user.
        If the user wants something from someone (a raise, a repair, a change), name the person being asked.

        Reply in English with only that person's role relative to the user, nothing else.

        Setup: "My neighbor parks in my reserved spot almost every night. I want to ask him to stop. He says it's only for a few minutes."
        the user's neighbor

        Setup: "I want to ask my landlord to fix the heater before winter. He keeps saying next month."
        the user's landlord

        Setup: 「朋友跟我借了五千塊，半年都沒還，我想跟她要回來。她說最近手頭很緊。」
        the user's friend who borrowed money from them
        """

    static func opponentPrompt(
        setup: String,
        transcript: [ArgumentLine],
        style: StylePreset,
        locale: Locale,
        persona: String? = nil
    ) -> (system: String, user: String) {
        let who = persona.map { clipTurn($0, maxWords: 60, maxCharacters: 200) }
            ?? "the other person described in the user's setup (the manager, the roommate, the parent…)."
        let system = """
        You play a character in an argument rehearsal. The user is practising a difficult conversation. You are THE OTHER PERSON in that conversation — not the user, not a coach, not an assistant.

        Language: \(languageHint(for: locale)).

        WHO YOU ARE: \(who) Speak in the first person as yourself, directly to the user ("you"). Argue from YOUR side: what you want, and why you think you are right. Never restate the user's complaint as if it were your own.

        YOUR VOICE: \(style.systemPreamble(for: locale))
        Apply that voice to how YOU, the other person, talk.

        HOW TO PLAY:
        - Push back the way this person plausibly would: defend yourself, give your reasons or excuses, deflect, ask for something in return. Do not give in after one line, do not agree to everything, and never take the user's side.
        - Answer the user's latest line directly. Do not repeat something you already said, and vary how you begin — not every line starts with "You".
        - Never give the user advice or tell them what to say. Never describe the scene.
        - One reply only, at most 80 words. No numbering, no name labels, no quotation marks, no stage directions.
        - Stay civil enough to argue with: no threats, no profanity, no slurs, no insults about who the user is.

        \(universalSafetyPreamble)
        \(languageEnforcement(for: locale))
        """

        var lines: [String] = []
        lines.append("Argument setup, written by the user (\"I\" is the user; you are the other person in it):")
        lines.append("\"\"\"")
        lines.append(clipTurn(setup, maxWords: 200, maxCharacters: 600))
        lines.append("\"\"\"")
        let recent = transcript.suffix(opponentTranscriptLimit)
        if recent.isEmpty {
            lines.append("")
            lines.append("The conversation is starting. Say the first thing you, the other person, would say to the user.")
        } else {
            lines.append("")
            lines.append("The conversation so far:")
            for line in recent {
                let who = line.speaker == .opponent ? "YOU (the other person)" : "USER"
                lines.append("\(who): \(clipTurn(line.text))")
            }
            lines.append("")
            lines.append("Write YOUR next line as the other person, answering the user's last line.")
        }
        // Restated last: this small model weighs the end of the prompt most,
        // and the 10-31 gate runs flipped to the user's side mid-argument.
        if let persona {
            lines.append("Remember who you are: \(clipTurn(persona, maxWords: 60, maxCharacters: 200))")
        }
        lines.append(userLanguageReminder(for: locale))
        return (system: system, user: lines.joined(separator: "\n"))
    }

    /// Caps one turn for the prompt: 80 words for spaced scripts, a
    /// character cap for text without word spaces (Chinese, Japanese).
    static func clipTurn(_ text: String, maxWords: Int = 80, maxCharacters: Int = 160) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        let spaced = words.count > 1 && trimmed.count / words.count < 15
        if spaced {
            return words.count > maxWords ? words.prefix(maxWords).joined(separator: " ") : trimmed
        }
        return trimmed.count > maxCharacters ? String(trimmed.prefix(maxCharacters)) : trimmed
    }

    /// Strips what the model sometimes wraps around a single line anyway: a
    /// speaker label, a list number, outer quotation marks.
    static func cleanOpponentLine(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = #"^(?:\*\*)?(?:you \(the other person\)|the other person|other person|opponent|them|對方|对方|相手)(?:\*\*)?\s*[:：]\s*"#
        let number = #"^(?:\d+|[一二三])[.)、．]\s*"#
        for pattern in [label, number] {
            if let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                s.removeSubrange(r)
            }
        }
        let pairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("「", "」"), ("『", "』"), ("'", "'")]
        for (open, close) in pairs where s.count >= 2 && s.first == open && s.last == close {
            let inner = s.dropFirst().dropLast()
            // Only an OUTER pair: 「我說了『不行』」 keeps its inner quote.
            if !inner.contains(open) && !inner.contains(close) {
                s = String(inner)
            }
            break
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
