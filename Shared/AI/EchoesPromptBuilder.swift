import Foundation

/// Builds the combined-prompt for an Echoes transcript generation. The
/// output contract is the same `[ROLE/IDX(:intensity)]` ASCII-tag format
/// that `EchoesParser` consumes. We deliberately do NOT use JSON
/// because the response-token cap (600 on Apple Foundation Models) is
/// tight and JSON's overhead (`{"messages":[{"role":"…"`) eats budget
/// we need for actual content (zh chars are often 1 char = 1 token).
///
/// Token budget v1: 6 messages × ≤45 zh-chars + 6 tag headers × ~12
/// chars ≈ 340 output tokens. Comfortable under 600.
enum EchoesPromptBuilder {
    /// Universal safety preamble for Echoes — same hard rails as the
    /// existing `PromptBuilder.universalSafetyPreamble`, just phrased
    /// for the squad-chat context.
    static let safetyPreamble: String = """
    SAFETY RULES (always apply):
    - Never call the user's "opponent" out by full real name.
    - Never produce slurs, racism, threats of violence, calls to violence, or self-harm encouragement.
    - Never attack protected attributes (race, religion, gender identity, sexual orientation, disability).
    - If the user's situation suggests self-harm, ALL voices switch register: validate then steer toward a real human (crisis line / trusted friend). Do not roast.
    """

    /// Build the single combined prompt for a generation call. The
    /// model is told to emit 4–6 messages with the role/index tags
    /// the parser expects. Final message MUST be `.bridge` with a
    /// suggested register (savage / sharp).
    static func systemPrompt(
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        personas: [EchoSpec],
        locale: Locale
    ) -> String {
        let registerLine: String
        switch tone {
        case .casual:
            registerLine = "Register: sharp / light snark. Stay edgy but not feral. No profanity strong enough to need a Vent flag."
        case .feral:
            registerLine = "Register: fully open. Cursing OK in mandarin Internet vent style (狗东西 / 神经病 / 操 — but no slurs, no violence threats). Match how friends actually rant in private WeChat / 朋友圈 DMs."
        }

        let personaBlock: String = personas.enumerated().map { (idx, p) in
            "Echo \(["A", "B"][idx]): \(p.promptFragment)"
        }.joined(separator: "\n")

        let voiceCountLine: String = (voiceCount == .one)
            ? "There is ONE Echo (A) speaking the whole transcript."
            : "There are TWO Echoes (A and B) trading messages."

        let bridgeRegister: String = (tone == .feral) ? "savage" : "sharp"

        return """
        You are generating a 4–6 message group-chat transcript in mandarin Chinese (zh-Hans), where one or two synthetic voices ("Echoes") back the user up about a grievance they just typed. The user does NOT speak in this transcript; they only read it.

        \(safetyPreamble)

        \(voiceCountLine)
        \(registerLine)

        Persona definitions:
        \(personaBlock)

        Required transcript structure (in order):
        1. [VALIDATE/A] one short message acknowledging the user is right to be upset.
        2. [ESCALATE/<A or B>] one or two short messages doubling down on the grievance.
        3. [DEESCALATE/<A or B>] one short message offering a path out of the anger — DO NOT skip this; without it the user feels worse after closing.
        4. [BRIDGE/<A or B>:\(bridgeRegister)] one CTA message ending in an arrow `→`, suggesting they use the rewrite tool with the "\(bridgeRegister)" register. Example phrasing: "把这事用 \(bridgeRegister == "savage" ? "Savage" : "Sharp") 给他怼回去 →".

        Output format (NO JSON, NO markdown):
        - Each message on its own line.
        - Tag prefix EXACTLY: `[ROLE/IDX]` for VALIDATE / ESCALATE / DEESCALATE; `[BRIDGE/IDX:register]` for BRIDGE.
        - IDX is A or B (A for 1-voice mode).
        - Total messages: 4 minimum, 6 maximum. Last MUST be a BRIDGE.
        - Each message ≤ 45 Chinese characters. No emoji.
        - Do NOT include any commentary, headers, or explanations outside the tagged lines.
        """
    }

    /// User-side prompt: hands the situation to the model.
    static func userPrompt(situation: String) -> String {
        // Trim + clamp to 600 chars on the input side. RoastEngine's
        // SafetyFilter.validateInput already runs upstream of this.
        let clamped = String(situation.prefix(600))
        return "对方刚刚跟你说了这事——你和另一个 Echo (如果是双人模式) 在群里替 ta 出气：\n\n「\(clamped)」"
    }
}
