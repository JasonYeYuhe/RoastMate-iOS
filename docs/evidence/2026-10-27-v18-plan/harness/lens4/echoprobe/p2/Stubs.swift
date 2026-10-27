import Foundation

/// Repo root: $ROASTMATE_ROOT, else derived from this file's location
/// (harness/lens4/echoprobe/p2/ is 7 directories below the repo root).
let repoRoot: String = ProcessInfo.processInfo.environment["ROASTMATE_ROOT"] ?? {
    var u = URL(fileURLWithPath: #filePath)
    for _ in 0..<8 { u.deleteLastPathComponent() }
    return u.path
}()
enum AppLocalization { static func string(_ key: String) -> String { key } }
