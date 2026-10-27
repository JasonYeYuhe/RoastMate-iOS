import Foundation

/// Repo root: $ROASTMATE_ROOT, else derived from this file's location
/// (harness/safety/ is 5 directories below the repo root).
let repoRoot: String = ProcessInfo.processInfo.environment["ROASTMATE_ROOT"] ?? {
    var u = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { u.deleteLastPathComponent() }
    return u.path
}()
enum ResourceBundle {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/\(name).\(ext)")
    }
}
