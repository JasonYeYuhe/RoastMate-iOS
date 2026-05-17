import Foundation

/// On-device PII masking for text the user *explicitly opts in* to
/// share publicly (the vent side of a Vent→Sent card). Runs locally;
/// nothing is sent anywhere. Errs toward over-masking — a false mask
/// is harmless, a leaked email/phone is not.
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
