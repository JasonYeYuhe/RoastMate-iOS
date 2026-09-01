// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EvalRunner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "eval-runner", targets: ["EvalRunner"]),
        .executable(name: "apple-fm-guardrail", targets: ["AppleFMGuardrail"])
    ],
    targets: [
        .executableTarget(
            name: "EvalRunner",
            path: "Sources/EvalRunner"
        ),
        // On-device Apple Foundation Models guardrail experiment (macOS 26+,
        // Apple Intelligence enabled). Self-contained so the existing
        // worker-eval target above is untouched.
        .executableTarget(
            name: "AppleFMGuardrail",
            path: "Sources/AppleFMGuardrail",
            exclude: ["README.md"]
        )
    ]
)
