import Foundation
import SwiftData
import os.log

struct ArgumentTurn: Identifiable, Hashable, Sendable {
    enum Role: String, Sendable { case ai, user }
    let id: UUID
    let role: Role
    let text: String

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }
}

@MainActor
@Observable
final class ArgumentSimulatorViewModel {
    enum Phase {
        case setup
        case running
    }

    var setup: String = ""
    var styleId: String = "cold_violence"
    var phase: Phase = .setup
    var turns: [ArgumentTurn] = []
    var isThinking: Bool = false
    var error: String? = nil

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "ArgumentSim")
    private let maxTurns = 12

    func startArgument(context: ModelContext, locale: Locale) async {
        let setupText = setup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !setupText.isEmpty else { return }
        guard let style = StyleCatalog.shared.style(id: styleId) else {
            error = String(localized: "error.generic")
            return
        }
        error = nil
        isThinking = true
        defer { isThinking = false }

        await RoastEngine.shared.resetConversation()
        let consent = HistoryService.userSettings(context: context).cloudConsent
        let opening = await generateAIOpening(setup: setupText, style: style, locale: locale, consent: consent)
        guard let opening else { return }
        turns = [ArgumentTurn(role: .ai, text: opening)]
        phase = .running

        HistoryService.saveSession(
            situation: setupText,
            mode: .argument,
            styleId: style.id,
            locale: locale,
            variants: [opening],
            context: context,
            isPro: StoreService.shared.isPro
        )
    }

    func userReply(text: String, context: ModelContext, locale: Locale) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try SafetyFilter.validateInput(trimmed)
        } catch let err as SafetyError {
            error = err.errorDescription
            return
        } catch {
            self.error = error.localizedDescription
            return
        }
        turns.append(ArgumentTurn(role: .user, text: trimmed))
        guard turns.count < maxTurns else {
            turns.append(ArgumentTurn(
                role: .ai,
                text: String(localized: "argument.turn_limit_reached")
            ))
            return
        }

        guard let style = StyleCatalog.shared.style(id: styleId) else { return }
        isThinking = true
        defer { isThinking = false }

        let consent = HistoryService.userSettings(context: context).cloudConsent
        let response = await generateAIResponse(style: style, locale: locale, consent: consent)
        if let response {
            turns.append(ArgumentTurn(role: .ai, text: response))
        }
    }

    func endArgument() {
        phase = .setup
        turns = []
        Task { await RoastEngine.shared.resetConversation() }
    }

    // MARK: - Generation

    private func generateAIOpening(setup: String, style: StylePreset, locale: Locale,
                                   consent: CloudConsent) async -> String? {
        let opener = """
        I want to rehearse the following argument:

        \(setup)

        Play the OTHER side. Give the first thing the other person would say to me in this argument. Keep it under 80 words. Stay in character. One reply only — no commentary, no quotation marks.
        """
        return await runEngine(input: opener, style: style, locale: locale, consent: consent)
    }

    private func generateAIResponse(style: StylePreset, locale: Locale,
                                    consent: CloudConsent) async -> String? {
        let myLast = turns.last { $0.role == .user }?.text ?? ""
        let input = """
        The other person (me) just said: "\(myLast)"

        Continue playing the OTHER side. Reply to my last line, in character, in the same style. Keep it under 80 words. One reply only — no commentary, no quotation marks.
        """
        return await runEngine(input: input, style: style, locale: locale, consent: consent)
    }

    private func runEngine(input: String, style: StylePreset, locale: Locale,
                           consent: CloudConsent) async -> String? {
        do {
            // Track 0.2 fix: this surface never resolved cloud permission, so
            // on an iOS-18 device with no on-device model it failed rather than
            // falling back to cloud. `.argument` uses the default sendable
            // intensity, so the sendable-cloud flag governs. No consent PROMPT
            // here (that UI lives in the generator tab) — without a prior grant
            // this resolves false and stays on-device, as before.
            let cloud = CloudPermission.resolve(intensity: .sharp, consent: consent)
            let variants = try await RoastEngine.shared.generate(
                situation: input,
                style: style,
                locale: locale,
                variantCount: 1,
                mode: .argument,
                keepSession: true,
                cloudVentEnabled: cloud.cloudAllowed
            )
            let first = variants.first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if first == nil || first?.isEmpty == true {
                error = String(localized: "roast.error.no_variants")
                return nil
            }
            return first
        } catch let err as RoastError {
            error = err.errorDescription
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
