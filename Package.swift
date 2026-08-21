// swift-tools-version: 5.9
//
// SwiftPM package for Videographr (scientific alpha; domain: Unterrichtsvideographie).
// Pure libraries (unit-testable without AVFoundation) live under Sources/;
// the iOS app target is App/Unterrichtsvideographie.xcodeproj (display name: Videographr).
import PackageDescription

let package = Package(
    // Package name retained for module path stability; product brand is Videographr.
    name: "Unterrichtsvideographie",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Pure capture observability plus protocol-gated, explicitly unvalidated hypotheses.
        .library(name: "GuidanceEngine", targets: ["GuidanceEngine"]),
        // In-app method / technology / external-device catalogue.
        .library(name: "LearnContent", targets: ["LearnContent"]),
        // Capture sessions, readiness, mid-take policy, reflection, local store.
        .library(name: "SessionCore", targets: ["SessionCore"])
    ],
    targets: [
        .target(
            name: "GuidanceEngine",
            path: "Sources/GuidanceEngine"
        ),
        .target(
            name: "LearnContent",
            path: "Sources/LearnContent"
        ),
        .target(
            name: "SessionCore",
            dependencies: ["GuidanceEngine"],
            path: "Sources/SessionCore"
        ),
        .testTarget(
            name: "GuidanceEngineTests",
            dependencies: ["GuidanceEngine"],
            path: "Tests/GuidanceEngineTests"
        ),
        .testTarget(
            name: "SessionCoreTests",
            dependencies: ["SessionCore", "GuidanceEngine"],
            path: "Tests/SessionCoreTests"
        )
    ]
)
