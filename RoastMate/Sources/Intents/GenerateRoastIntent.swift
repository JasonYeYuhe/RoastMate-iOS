import AppIntents
import Foundation

/// Lets Siri / Shortcuts / Spotlight invoke RoastMate without opening the
/// app. Surfaces under the system "Apps" screen and in Shortcuts. Adds
/// real App Store value (App Intents support is checked during review)
/// and works entirely on-device.
struct GenerateRoastIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.generate_roast.title"
    static let description = IntentDescription("intent.generate_roast.description")

    @Parameter(
        title: "intent.param.situation",
        description: "intent.param.situation.description"
    )
    var situation: String

    @Parameter(
        title: "intent.param.style",
        description: "intent.param.style.description",
        default: "high_eq"
    )
    var styleId: String

    @Parameter(
        title: "intent.param.intensity",
        description: "intent.param.intensity.description",
        default: .sharp
    )
    var intensity: RoastIntensityAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$styleId) roast for \(\.$situation)")
    }

    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let style = StyleCatalog.shared.style(id: styleId) ?? {
            // Style id not recognised — fall back to default.
            return StyleCatalog.shared.style(id: StyleCatalog.shared.defaultStyleId)!
        }()
        let locale = Locale.current
        let variants = try await RoastEngine.shared.generate(
            situation: situation,
            style: style,
            locale: locale,
            variantCount: 1,
            mode: .roast,
            intensity: intensity.resolved
        )
        let response = variants.first ?? String(localized: "roast.error.no_variants")
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

/// The headless intent only exposes the free intensities. Savage /
/// Feral / Vent are Pro-only, safety-sensitive private drafts — they
/// must go through the app (where entitlement gating, the credit wallet
/// and the crisis safety net live), so they are deliberately not
/// reachable from a no-UI Siri/Shortcuts run. Vent is offered instead
/// via `QuickVentIntent`, which opens the app.
enum RoastIntensityAppEnum: String, AppEnum {
    case calm
    case sharp

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "intent.param.intensity"
    )

    static let caseDisplayRepresentations: [RoastIntensityAppEnum: DisplayRepresentation] = [
        .calm: DisplayRepresentation(title: "intensity.calm.name"),
        .sharp: DisplayRepresentation(title: "intensity.sharp.name")
    ]

    var resolved: Intensity {
        switch self {
        case .calm: return .calm
        case .sharp: return .sharp
        }
    }
}

struct RoastMateShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateRoastIntent(),
            phrases: [
                "Generate a roast with \(.applicationName)",
                "Roast this with \(.applicationName)",
                "用\(.applicationName)写一句",
                "\(.applicationName)で返しを作って"
            ],
            shortTitle: "intent.shortcut.short_title",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: QuickVentIntent(),
            phrases: [
                "Vent with \(.applicationName)",
                "Vent about this with \(.applicationName)",
                "用\(.applicationName)发泄一下",
                "\(.applicationName)で吐き出す"
            ],
            shortTitle: "intent.quick_vent.short_title",
            systemImageName: "flame.fill"
        )
    }
}
