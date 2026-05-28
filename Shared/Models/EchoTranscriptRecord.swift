import Foundation
import SwiftData

/// SwiftData persistence for a completed Echoes transcript. Mirrors the
/// `RoastSession`/`GeneratedRoast` pattern (parent + relationship to
/// child messages with cascade delete). CloudKit-syncable when the
/// underlying container is CloudKit-backed; CloudKit requires every
/// to-many relationship to have an inverse — `EchoMessageRecord.transcript`
/// points back here.
@Model
final class EchoTranscriptRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var situation: String = ""
    var localeRaw: String = ""
    var toneRaw: String = EchoTone.casual.rawValue
    var voiceCountRaw: Int = 1
    /// Pre-bridge intensity hint embedded by the model for the
    /// Bridge-to-Action deep link. Optional because curated-fallback
    /// transcripts may not set one.
    var bridgeIntensityRaw: String?
    var isFavorite: Bool = false
    /// True iff the actual generation routed via the cloud (Feral with
    /// granted consent succeeded). Casual transcripts always store false.
    var cloudUsed: Bool = false
    var isSampleData: Bool = false

    /// CloudKit requires `[]` initial + inverse on `EchoMessageRecord.transcript`.
    @Relationship(deleteRule: .cascade, inverse: \EchoMessageRecord.transcript)
    var messages: [EchoMessageRecord]? = []

    init(
        situation: String,
        locale: String = Locale.current.identifier,
        tone: EchoTone = .casual,
        voiceCount: EchoVoiceCount = .two,
        bridgeIntensity: Intensity? = nil,
        cloudUsed: Bool = false,
        isSampleData: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.situation = situation
        self.localeRaw = locale
        self.toneRaw = tone.rawValue
        self.voiceCountRaw = voiceCount.rawValue
        self.bridgeIntensityRaw = bridgeIntensity?.rawValue
        self.cloudUsed = cloudUsed
        self.isSampleData = isSampleData
        self.messages = []
    }

    var tone: EchoTone { EchoTone(rawValue: toneRaw) ?? .casual }
    var voiceCount: EchoVoiceCount { EchoVoiceCount(rawValue: voiceCountRaw) ?? .one }
    var bridgeIntensity: Intensity? {
        guard let raw = bridgeIntensityRaw else { return nil }
        return Intensity(rawValue: raw)
    }
}

@Model
final class EchoMessageRecord {
    var id: UUID = UUID()
    var echoIndex: Int = 0
    var roleRaw: String = EchoMessageRole.validate.rawValue
    var text: String = ""
    var deliveryDelayMs: Int = 600
    /// Position within the transcript. Insertion order is the canonical
    /// sort; this exists as a defensive integer in case SwiftData
    /// re-orders the relationship array under CloudKit sync.
    var orderIndex: Int = 0
    /// Bridge messages only; nil on the other three roles.
    var bridgeIntensityRaw: String?
    var transcript: EchoTranscriptRecord?

    init(
        echoIndex: Int,
        role: EchoMessageRole,
        text: String,
        deliveryDelayMs: Int = 600,
        orderIndex: Int,
        bridgeIntensity: Intensity? = nil
    ) {
        self.id = UUID()
        self.echoIndex = echoIndex
        self.roleRaw = role.rawValue
        self.text = text
        self.deliveryDelayMs = deliveryDelayMs
        self.orderIndex = orderIndex
        self.bridgeIntensityRaw = bridgeIntensity?.rawValue
    }

    var role: EchoMessageRole { EchoMessageRole(rawValue: roleRaw) ?? .validate }
    var bridgeIntensity: Intensity? {
        guard let raw = bridgeIntensityRaw else { return nil }
        return Intensity(rawValue: raw)
    }
}
