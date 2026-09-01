import Foundation

/// Extracted verbatim from `Shared/Models/RoastSession.swift` (the rest of that
/// file is a SwiftData `@Model` class the prompt path does not need). Only the
/// enum is required by `PromptBuilder`.
enum RoastMode: String, Codable, CaseIterable, Sendable {
    case roast
    case reply
    case argument
    case translate
    case social
}
