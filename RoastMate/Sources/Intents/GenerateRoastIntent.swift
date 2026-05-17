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
        // Crisis preflight — parity with the in-app generator
        // (RoastGeneratorViewModel). A hard self-harm signal must NEVER
        // get a roast, not even head-lessly: return supportive copy
        // instead of generating. (RoastEngine.validateInput's denylist
        // is narrower than the crisis classifier, so this check is
        // load-bearing here.)
        if SafetyFilter.crisisSignal(situation) == .hard {
            let msg = AppLocalization.string("crisis.title") + " "
                + AppLocalization.string("crisis.body")
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }

        // Pro styles stay subscription-only — the headless path must not
        // bypass the in-app tier guard via an arbitrary styleId. Fall
        // back to the (free) default style instead.
        var style = StyleCatalog.shared.style(id: styleId)
            ?? StyleCatalog.shared.style(id: StyleCatalog.shared.defaultStyleId)!
        if style.tier == .pro {
            style = StyleCatalog.shared.style(id: StyleCatalog.shared.defaultStyleId)!
        }

        // This on-device path (free intensities + free styles only, no
        // cloud cost) is an intentional UNMETERED promotional surface:
        // it does not spend wallet credits. Credits gate the in-app /
        // cloud (Vent/Feral) path where the real variable cost lives.
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
