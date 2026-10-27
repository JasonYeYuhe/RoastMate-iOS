import Foundation
import FoundationModels
let prompts: [(String, String?, String)] = [
  ("neutral_noinstr", nil, "Write a polite one-sentence note asking my roommate to wash the dishes."),
  ("neutral_zh", nil, "請寫一句客氣的話，請室友記得洗碗。"),
  ("complaint_instr", "You help people write short replies to annoying situations. Be witty, never cruel.", "My roommate leaves dishes in the sink for days and says I'm too uptight. Write one short reply I could send."),
  ("complaint_instr_zh", "你幫人寫簡短、機智但不刻薄的回覆。", "室友的碗可以放好幾天，還說我太計較。幫我寫一句可以傳給他的回覆。"),
]
for (tag, instr, p) in prompts {
  let t0 = Date()
  do {
    let s = instr == nil ? LanguageModelSession() : LanguageModelSession(instructions: instr!)
    let r = try await s.respond(to: p)
    print(tag, "OK", Int(Date().timeIntervalSince(t0)*1000), "ms |", r.content.prefix(120).replacingOccurrences(of: "\n", with: " "))
  } catch { print(tag, "THROW", Int(Date().timeIntervalSince(t0)*1000), "ms |", String(describing: error).prefix(120)) }
}
