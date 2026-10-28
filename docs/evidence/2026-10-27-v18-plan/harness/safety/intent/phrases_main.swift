import Foundation
struct I: Decodable { let id, locale, label, text: String }
struct F: Decodable { let inputs: [I] }
let ms = try! JSONDecoder().decode(F.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))).inputs
var tp = 0, t = 0, fp = 0, v = 0
var lines: [String] = []
for m in ms { let h = IntimidationRequest.matches(m.text)
  if m.label == "intimidate" { t += 1; if h { tp += 1 } else { lines.append("miss \(m.id) \(m.locale): \(m.text)") } }
  else { v += 1; if h { fp += 1; lines.append("FP \(m.id) \(m.locale): \(m.text)") } } }
print("intimidation requests caught \(tp)/\(t); venting caught \(fp)/\(v)")
if CommandLine.arguments.count > 2 { lines.forEach { print($0) } }
