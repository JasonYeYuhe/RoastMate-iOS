import Foundation

/// Resolves bundled JSON resources across app target, test target, and other
/// hosts. When iOS/macOS/watchOS run the app, `Bundle.main` has the resource.
/// When XCTest runs, `Bundle.main` is the test runner, so we also search
/// `Bundle.allBundles`.
enum ResourceBundle {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let main = Bundle.main.url(forResource: name, withExtension: ext) {
            return main
        }
        for bundle in Bundle.allBundles {
            if let found = bundle.url(forResource: name, withExtension: ext) {
                return found
            }
        }
        for bundle in Bundle.allFrameworks {
            if let found = bundle.url(forResource: name, withExtension: ext) {
                return found
            }
        }
        return nil
    }
}
