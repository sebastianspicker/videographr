import Foundation

/// Single source of truth for the build identity shown in UI and written to artifacts.
struct BuildIdentity: Codable, Equatable, Sendable {
    let semanticVersion: String
    let buildNumber: String

    init(bundle: Bundle = .main) {
        semanticVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
        buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
    }

    var displayVersion: String {
        "\(semanticVersion) (\(buildNumber))"
    }

    static let current = BuildIdentity()
}
