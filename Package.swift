// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    // Retained for module-path compatibility; the public product name is Videographr.
    name: "Unterrichtsvideographie",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GuidanceEngine", targets: ["GuidanceEngine"]),
        .library(name: "ExperimentalResearch", targets: ["ExperimentalResearch"]),
        .library(name: "LearnContent", targets: ["LearnContent"]),
        .library(name: "SessionCore", targets: ["SessionCore"])
    ],
    targets: [
        .target(
            name: "GuidanceEngine",
            path: "Sources/GuidanceEngine"
        ),
        .target(
            name: "ExperimentalResearch",
            dependencies: ["GuidanceEngine", "SessionCore"],
            path: "Sources/ExperimentalResearch"
        ),
        .target(
            name: "LearnContent",
            path: "Sources/LearnContent"
        ),
        .target(
            name: "SessionCore",
            dependencies: ["GuidanceEngine"],
            path: "Sources/SessionCore"
        )
    ]
)
