import Foundation
import FoundationModels
let draft = "他媽的，你站在台上把我的血汗報告說成是你自己的，臉都不要了是吧？傻逼才信你那套，操你媽，滾！"
do {
    let s = LanguageModelSession(instructions: "You are a rewriter. Reply in 繁體中文. Do not use profanity.")
    let r = try await s.respond(to: "Rewrite this private vent draft into a sendable reply:\n\(draft)", options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 120))
    print("OK:", r.content)
} catch {
    print("type(of:):", type(of: error))
    print("String(reflecting:):", String(reflecting: error).prefix(400))
    print("String(describing:):", String(describing: error).prefix(200))
    print("is GenerationError:", error is LanguageModelSession.GenerationError)
    if let g = error as? LanguageModelSession.GenerationError {
        if case .guardrailViolation = g { print("case .guardrailViolation matched") }
    }
    let ns = error as NSError
    print("NSError domain/code:", ns.domain, ns.code, "localized:", ns.localizedDescription)
}
