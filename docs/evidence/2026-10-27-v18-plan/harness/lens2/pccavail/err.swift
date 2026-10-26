import Foundation
import FoundationModels
if #available(macOS 27.0, *) {
    let s = LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: "Reply in one word.")
    do { let r = try await s.respond(to: "Say hello."); print("OK", r.content) }
    catch { print("type:", type(of: error)); print("reflect:", String(reflecting: error).prefix(800)); let ns = error as NSError; print("domain/code:", ns.domain, ns.code, ns.userInfo.keys.map{"\($0)"}); print("debug:", (ns.userInfo[NSDebugDescriptionErrorKey] as? String) ?? "-") }
}
