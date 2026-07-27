import Foundation

func repositorySwiftSources(
    _ relativePath: String,
    additionalPrefixes: [String] = []
) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let requestedFile = repositoryRoot.appendingPathComponent(relativePath)
    let directory = requestedFile.deletingLastPathComponent()
    let primaryPrefix = requestedFile.deletingPathExtension().lastPathComponent
    let prefixes = [primaryPrefix] + additionalPrefixes
    let sourceFiles = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { candidate in
        candidate.pathExtension == "swift"
            && prefixes.contains { candidate.lastPathComponent.hasPrefix($0) }
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !sourceFiles.isEmpty else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try sourceFiles.map {
        try String(contentsOf: $0, encoding: .utf8)
    }.joined(separator: "\n")
}
