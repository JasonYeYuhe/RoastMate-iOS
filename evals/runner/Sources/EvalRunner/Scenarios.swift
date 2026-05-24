import Foundation

/// Mirror of `evals/scenarios/base.json` and `additions-*.json` schema.
struct Scenario: Decodable, Sendable {
    let id: String
    let category: String
    let defaultStyleId: String
    let defaultIntensity: String
    let prompt: [String: String]  // locale → text
}

struct ScenarioFile: Decodable {
    let version: Int
    let scenarios: [Scenario]
}

enum ScenarioLoader {
    static func load(path: URL) throws -> [Scenario] {
        let data = try Data(contentsOf: path)
        let file = try JSONDecoder().decode(ScenarioFile.self, from: data)
        return file.scenarios
    }

    /// Loads + concatenates base + en + ja additions if they exist in the
    /// same directory. Caller can pass any one of the three; the others
    /// are inferred siblings.
    static func loadAll(baseDir: URL) throws -> [Scenario] {
        var all: [Scenario] = []
        for name in ["base.json", "additions-en.json", "additions-ja.json"] {
            let f = baseDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: f.path) {
                all.append(contentsOf: try load(path: f))
            }
        }
        return all
    }
}
