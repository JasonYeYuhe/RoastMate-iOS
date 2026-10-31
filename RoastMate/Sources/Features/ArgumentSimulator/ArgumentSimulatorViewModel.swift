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
    /// The user's setup or reply signalled self-harm (`SafetyFilter.crisisSignal`
    /// `.hard`): the view shows crisis support instead of continuing the
    /// argument, as the generators do. Nothing is generated for that text.
    var crisis: Bool = false
    /// `.soft` signal: the argument continues, with the supportive banner.
    var crisisBanner: Bool = false
    /// The other side is played by the on-device model only. Without it (no
    /// Apple Intelligence, or an iOS 18 device) the view explains that
    /// instead of starting; until 1.8.0 it played canned roast lines as the
    /// "opponent" there.
    var needsOnDeviceModel: Bool = !RoastEngine.isOnDeviceModelAvailable

    /// Who the other person is, from their side (`RoastEngine.opponentPersona`),
    /// asked once when the argument starts and passed to every turn.
    private var persona: String?

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "ArgumentSim")
    private let maxTurns = 12

    func startArgument(context: ModelContext, locale: Locale) async {
        let setupText = setup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !setupText.isEmpty else { return }
        guard !routeToCrisis(setupText) else { return }
        guard let style = StyleCatalog.shared.style(id: styleId) else {
            error = String(localized: "error.generic")
            return
        }
        error = nil
        isThinking = true
        defer { isThinking = false }

        persona = await RoastEngine.shared.opponentPersona(setup: setupText)
        guard let opening = await nextOpponentLine(setup: setupText, transcript: [], style: style, locale: locale) else { return }
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
        guard !routeToCrisis(trimmed) else { return }
        do {
            try SafetyFilter.validateInput(trimmed)
        } catch let err as SafetyError {
            error = err.errorDescription
            return
        } catch {
            self.error = error.localizedDescription
            return
        }
        error = nil
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

        let transcript = turns.map {
            ArgumentLine(speaker: $0.role == .ai ? .opponent : .user, text: $0.text)
        }
        let setupText = setup.trimmingCharacters(in: .whitespacesAndNewlines)
        if let response = await nextOpponentLine(setup: setupText, transcript: transcript, style: style, locale: locale) {
            turns.append(ArgumentTurn(role: .ai, text: response))
        }
    }

    func endArgument() {
        phase = .setup
        turns = []
        persona = nil
        error = nil
        crisisBanner = false
    }

    /// Same two-tier self-harm handoff as `RoastGeneratorViewModel`: `.hard`
    /// stops before anything is generated; `.soft` keeps going and sets the
    /// banner. Until 1.8.0 this surface only ran `validateInput`, so
    /// 「我不想活了」 in a reply got an opponent's answer and no resources
    /// (safety set a03, 2026-10-27).
    private func routeToCrisis(_ text: String) -> Bool {
        switch SafetyFilter.crisisSignal(text) {
        case .hard:
            crisis = true
            return true
        case .soft:
            crisisBanner = true
        case .none:
            break
        }
        return false
    }

    // MARK: - Generation

    /// On-device only, stateless per turn (`RoastEngine.opponentTurn`). A turn
    /// that can't be written shows a message, never a canned line.
    private func nextOpponentLine(setup: String, transcript: [ArgumentLine],
                                  style: StylePreset, locale: Locale) async -> String? {
        do {
            switch try await RoastEngine.shared.opponentTurn(
                setup: setup, transcript: transcript, style: style, locale: locale, persona: persona) {
            case .line(let text):
                return text
            case .unavailable:
                needsOnDeviceModel = true
                return nil
            case .notGenerated:
                error = String(localized: "argument.turn_unavailable")
                return nil
            }
        } catch let err as RoastError {
            error = err.errorDescription
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
