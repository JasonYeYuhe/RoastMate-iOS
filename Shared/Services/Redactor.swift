import Foundation

/// On-device PII masking. Runs locally; nothing is sent anywhere. Errs
/// toward over-masking — a false mask is harmless, a leaked email/phone is not.
///
/// ⚠️ **Currently has no production call site.** Its only caller was the
/// share-card vent reveal, removed in v1.3.1. It is retained because v1.4
/// (Track B.2) will expand it — `NLTagger(.nameType)` NER plus Chinese
/// contact/name patterns — and run it on the *sendable* text.
///
/// Do not treat this as an active control, and do not reintroduce it as a
/// *sole* one: these four ASCII regexes miss Chinese PII almost entirely —
/// 2-character names (张伟), titles (张总), WeChat/QQ handles (vx: / v信 /
/// 企鹅号), and Chinese-numeral phone runs all pass through untouched.
enum Redactor {
    private static let rules: [(pattern: String, replacement: String)] = [
        // Email
        ("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", "[email]"),
        // URLs
        ("https?://[^\\s]+", "[link]"),
        // @handles
        ("(^|\\s)@[A-Za-z0-9_]{2,}", "$1@—"),
        // Phone / long digit runs (7+ digits, optional separators)
        ("\\+?\\d[\\d\\s().\\-]{5,}\\d", "[number]")
    ]

    static func redact(_ text: String) -> String {
        var out = text
        for rule in rules {
            guard let re = try? NSRegularExpression(
                pattern: rule.pattern, options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(out.startIndex..., in: out)
            out = re.stringByReplacingMatches(
                in: out, options: [], range: range, withTemplate: rule.replacement
            )
        }
        return out
    }
}
