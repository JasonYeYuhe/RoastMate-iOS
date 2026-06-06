import Foundation

/// Builds the combined-prompt for an Echoes transcript generation. The
/// output contract is the same `[ROLE/IDX(:intensity)]` ASCII-tag format
/// that `EchoesParser` consumes. We deliberately do NOT use JSON because
/// the response-token cap (600 on Apple Foundation Models) is tight and
/// JSON's overhead eats budget we need for actual content (zh chars are
/// often 1 char = 1 token).
///
/// Two scenes:
///   - `.classic`       : 1–2 voices, 4–6 messages (the shipped 替你出气).
///   - `.roommateGroup` : 3 voices (护短 / 毒舌 / 清醒), 8–10 messages —
///                        the 虚拟舍友群. Reuses the SAME four role tags
///                        (no new persisted role); multiple `escalate`
///                        lines carry the group pile-on, `deescalate` is
///                        the reframe, the single `bridge` (from C) is last.
enum EchoesPromptBuilder {
    /// Universal safety preamble for Echoes — same hard rails as the
    /// existing `PromptBuilder.universalSafetyPreamble`, phrased for the
    /// squad-chat context.
    static let safetyPreamble: String = """
    SAFETY RULES (always apply):
    - Never call the user's "opponent" out by full real name.
    - Never produce slurs, racism, threats of violence, calls to violence, or self-harm encouragement.
    - Never attack protected attributes (race, religion, gender identity, sexual orientation, disability).
    - If the user's situation suggests self-harm, ALL voices switch register: validate then steer toward a real human (crisis line / trusted friend). Do not roast.
    """

    /// Build the single combined prompt for a generation call.
    static func systemPrompt(
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        personas: [EchoSpec],
        locale: Locale,
        scene: EchoScene = .classic
    ) -> String {
        switch scene {
        case .classic:
            return classicPrompt(tone: tone, voiceCount: voiceCount, personas: personas)
        case .roommateGroup:
            return roommatePrompt(tone: tone, personas: personas)
        }
    }

    /// User-side prompt: hands the situation to the model.
    static func userPrompt(situation: String, scene: EchoScene = .classic) -> String {
        // Trim + clamp to 600 chars on the input side. SafetyFilter.validateInput
        // already ran upstream of this.
        let clamped = String(situation.prefix(600))
        switch scene {
        case .classic:
            return "对方刚刚跟你说了这事——你和另一个 Echo (如果是双人模式) 在群里替 ta 出气：\n\n「\(clamped)」"
        case .roommateGroup:
            return "ta 把这事发进了你们的舍友群——你们三个室友一起接住情绪、替 ta 出气：\n\n「\(clamped)」"
        }
    }

    // MARK: - Per-scene prompts

    private static let letters = ["A", "B", "C"]

    private static func personaBlock(_ personas: [EchoSpec]) -> String {
        personas.enumerated().map { (idx, p) in
            "Echo \(idx < letters.count ? letters[idx] : "?"): \(p.promptFragment)"
        }.joined(separator: "\n")
    }

    private static func registerLine(_ tone: EchoTone) -> String {
        switch tone {
        case .casual:
            return "Register: sharp / light snark. Stay edgy but not feral. No profanity strong enough to need a Vent flag."
        case .feral:
            return "Register: fully open. Cursing OK in mandarin Internet vent style (狗东西 / 神经病 / 操 — but no slurs, no violence threats). Match how friends actually rant in private WeChat / 朋友圈 DMs."
        }
    }

    /// The classic 1–2 voice prompt (unchanged contract: 4–6 msgs, A/B).
    private static func classicPrompt(
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        personas: [EchoSpec]
    ) -> String {
        let voiceCountLine: String = (voiceCount == .one)
            ? "There is ONE Echo (A) speaking the whole transcript."
            : "There are TWO Echoes (A and B) trading messages."

        // The bridge's suggested rewrite register is a deterministic
        // function of tone — the app injects it after parsing, so the model
        // never emits a `:register` tag suffix (that schema shift was the #1
        // parse-failure trigger for the small on-device model — Gemini eval
        // 2026-05-29). The register word still appears in the message BODY.
        let bridgeWord: String = (tone == .feral) ? "Savage" : "Sharp"

        return """
        You are generating a 4–6 message group-chat transcript in mandarin Chinese (zh-Hans), where one or two synthetic voices ("Echoes") back the user up about a grievance they just typed. The user does NOT speak in this transcript; they only read it.

        \(safetyPreamble)

        \(voiceCountLine)
        \(registerLine(tone))

        Persona definitions:
        \(personaBlock(personas))

        Required transcript structure (in order):
        1. [VALIDATE/A] one short message acknowledging the user is right to be upset.
        2. [ESCALATE/<A or B>] one or two short messages doubling down on the grievance.
        3. [DEESCALATE/<A or B>] one short message that does NOT switch to calm-therapist mode — stay the snarky friend, but redirect the anger toward a next move. e.g. start with "与其在这干生气…".
        4. [BRIDGE/<A or B>] the PAYOFF of message 3 — a CTA ending in an arrow `→` that turns "stop stewing" into "say it", naming the rewrite tool. e.g. "…不如用 \(bridgeWord) 把话甩回去 →". Messages 3 and 4 must read as ONE continuous beat (don't-just-suffer → here's-how-to-hit-back), not a calm-down followed by a separate ad.

        Output format (NO JSON, NO markdown):
        - Each message on its own line.
        - Tag prefix EXACTLY `[ROLE/IDX]` for ALL FOUR roles (VALIDATE / ESCALATE / DEESCALATE / BRIDGE). Put NOTHING after the IDX.
        - IDX is A or B (A for 1-voice mode).
        - Total messages: 4 minimum, 6 maximum. Last MUST be a BRIDGE.
        - Keep each message short — aim for ≤ 40 Chinese characters. No emoji.
        - Do NOT include any commentary, headers, or explanations outside the tagged lines.
        """
    }

    /// The 虚拟舍友群 3-voice prompt: 8–10 msgs, A/B/C each ≥2×, single
    /// BRIDGE from C last. Same four role tags as classic.
    private static func roommatePrompt(
        tone: EchoTone,
        personas: [EchoSpec]
    ) -> String {
        let bridgeWord: String = (tone == .feral) ? "Savage" : "Sharp"

        return """
        You are generating an 8–10 message GROUP-CHAT transcript in mandarin Chinese (zh-Hans). Three synthetic college "roommates" (A / B / C) jump into a group chat to take the user's side about a grievance the user just typed. The user does NOT speak in this transcript — they only read it. These are SYNTHETIC characters, never real people.

        \(safetyPreamble)

        The three roommates (fixed roles — keep each in character):
        \(personaBlock(personas))

        \(registerLine(tone))

        Required transcript (in order):
        1. [VALIDATE/A] 护短室友 immediately takes the user's side — no questioning, no "but".
        2. [ESCALATE/<A|B|C>] several short messages where the roommates pile on and riff off EACH OTHER — each line should react to the previous one, NOT three separate monologues. 毒舌室友 (B) lands the sharpest jokes.
        3. [DEESCALATE/C] 清醒室友 catches the banter and starts to wrap it — does NOT turn into a therapist or give 鸡汤; just stops the spiral and points at a next move (e.g. 别替他背锅，把时间线留好).
        4. [BRIDGE/C] 清醒室友 delivers the payoff — a CTA ending in `→` that turns "stop stewing" into "say it", naming the rewrite tool, e.g. "…不如用 \(bridgeWord) 把话甩回去 →". The DEESCALATE and BRIDGE read as ONE continuous beat.

        Output format (NO JSON, NO markdown, NO commentary):
        - Each message on its own line.
        - Tag prefix EXACTLY `[ROLE/IDX]` using ONLY these four roles: VALIDATE / ESCALATE / DEESCALATE / BRIDGE. Put NOTHING after the IDX.
        - IDX is A, B, or C — which roommate is speaking.
        - Total messages: 8 minimum, 10 maximum. Each roommate (A, B AND C) MUST speak at least twice. The LAST message MUST be a single BRIDGE from C.
        - Keep each message short — aim for ≤ 30 Chinese characters. No emoji, no timestamps, no "我们永远陪你 / 以后都来找我们" dependency talk.
        - Make adjacent messages come from DIFFERENT roommates where you can, and have later messages clearly react to earlier ones.
        """
    }
}
