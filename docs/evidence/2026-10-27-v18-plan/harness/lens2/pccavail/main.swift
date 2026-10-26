import Foundation
import FoundationModels
let sys = SystemLanguageModel.default
print("system availability:", sys.availability)
if #available(macOS 27.0, *) {
    print("system variant:", sys.variant.displayName)
    let pcc = PrivateCloudComputeLanguageModel()
    print("PCC availability:", pcc.availability, "isAvailable:", pcc.isAvailable)
    let q = pcc.quotaUsage
    print("PCC quota limitReached:", q.isLimitReached, "status:", q.status, "reset:", String(describing: q.resetDate))
    do {
        let langs = try await pcc.supportedLanguages
        print("PCC supported languages:", langs.map { $0.minimalIdentifier + "(" + ($0.script?.identifier ?? "-") + ")" }.sorted())
        print("PCC supportsLocale zh_TW:", try await pcc.supportsLocale(Locale(identifier: "zh_TW")), "ja_JP:", try await pcc.supportsLocale(Locale(identifier: "ja_JP")))
    } catch { print("PCC languages error:", type(of: error), String(describing: error).prefix(300)) }
}
