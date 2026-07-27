import Foundation
import XCTest
@testable import GuidanceEngine

extension EvidenceBoundaryTests {
    func testEvidenceRegistryRejectsMalformedSourcesAndSelfContradictoryCopy() {
        let original = EvidenceClaimRegistry.claims[0]
        let malformed = EvidenceClaim((
            id: original.id,
            sourceURL: "http://example.invalid/evidence",
            construct: original.construct,
            requiredObservable: original.requiredObservable,
            allowedWordingDE: "Die Aufnahme ist forschungstauglich.",
            prohibitedWordingDE: original.prohibitedWordingDE,
            validationTier: original.validationTier
        ))

        let failures = EvidenceClaimRegistry.validate([malformed, malformed])
        XCTAssertTrue(failures.contains("duplicate-or-empty-id"))
        XCTAssertTrue(failures.contains("invalid-source:\(original.id)"))
        XCTAssertTrue(failures.contains("forbidden-wording:\(original.id):forschungstaug"))
    }

    func testPublicClaimSurfacesAvoidUnsupportedPositiveClaims() throws {
        let root = repositoryRoot
        let releaseVersion = try String(
            contentsOf: root.appendingPathComponent("RELEASE_VERSION"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let swiftRoots = [
            root.appendingPathComponent("App/Unterrichtsvideographie", isDirectory: true),
            root.appendingPathComponent("Sources/LearnContent", isDirectory: true),
            root.appendingPathComponent("Sources/GuidanceEngine", isDirectory: true)
        ]
        let surfacedCoreFiles = [
            "Sources/SessionCore/AudioReadiness.swift",
            "Sources/SessionCore/FilmingGuidancePolicy.swift",
            "Sources/SessionCore/ReadinessAggregator.swift",
            "Sources/SessionCore/ReflectionScaffold.swift"
        ].map { root.appendingPathComponent($0) }
        let normativeDocuments = [
            "README.md",
            "RELEASE_STATUS.md",
            "SECURITY.md",
            "docs/README.md",
            "docs/SCIENTIFIC_ALPHA.md",
            "docs/RESEARCH_GAP_INVENTORY.md",
            "docs/EVALUATION.md",
            "docs/ARCHITECTURE.md",
            "docs/releases/\(releaseVersion).md",
            "docs/screenshots/README.md"
        ].map { root.appendingPathComponent($0) }

        let swiftFiles = try swiftRoots.flatMap { try swiftFilesRecursively(in: $0) } + surfacedCoreFiles
        var failures: [String] = []

        for file in swiftFiles.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: file, encoding: .utf8)
            let activeSource = removingLegacyUnvalidatedBlocks(from: source)
            let displaySource = removingEvidenceClaimRegistryMetadata(from: activeSource)
            let userFacingCopy = extractSwiftStringLiterals(from: displaySource).joined(separator: "\n")
            let documentationCopy = extractSwiftDocumentationComments(from: displaySource).joined(separator: "\n")
            failures.append(contentsOf: formattedViolations(in: userFacingCopy, file: file, root: root))
            failures.append(contentsOf: formattedSuitabilityViolations(in: userFacingCopy, file: file, root: root))
            failures.append(contentsOf: formattedViolations(in: documentationCopy, file: file, root: root))
            failures.append(contentsOf: formattedSuitabilityViolations(in: documentationCopy, file: file, root: root))
        }

        for file in normativeDocuments {
            let copy = try String(contentsOf: file, encoding: .utf8)
            failures.append(contentsOf: formattedViolations(in: copy, file: file, root: root))
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Unsupported positive evidence claims:\n\(failures.sorted().joined(separator: "\n"))"
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func swiftFilesRecursively(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func formattedViolations(in copy: String, file: URL, root: URL) -> [String] {
        let relativePath = file.path.replacingOccurrences(of: root.path + "/", with: "")
        return EvidenceClaimRegistry.positiveClaimViolations(in: copy).map { violation in
            "\(relativePath): [\(violation.claimID)] \(violation.prohibitedPattern) -> \(violation.excerpt)"
        }
    }

    private func formattedSuitabilityViolations(in copy: String, file: URL, root: URL) -> [String] {
        let relativePath = file.path.replacingOccurrences(of: root.path + "/", with: "")
        let normalized = copy.lowercased()
        let prohibitedPhrases = [
            "analysis-grade",
            "research-aligned",
            "research-usable",
            "ipn-taug",
            "analysestabil",
            "analysequalität",
            "für kodierung ungeeignet",
            "für analyse ungeeignet",
            "für analyse unbrauchbar",
            "für kodierung/analyse unbrauchbar",
            "geeignet für kooperations- und unterstützungsanalysen",
            "analysevideos brauchen",
            "vor analyse anpassen"
        ]
        return prohibitedPhrases.compactMap { phrase in
            normalized.contains(phrase)
                ? "\(relativePath): unsupported analysis-suitability wording -> \(phrase)"
                : nil
        }
    }

    private func extractSwiftDocumentationComments(from source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("///") else { return nil }
            return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
    }

    private func removingLegacyUnvalidatedBlocks(from source: String) -> String {
        var result: [Substring] = []
        var excludedDepth = 0

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if excludedDepth == 0, trimmed.hasPrefix("#if LEGACY_UNVALIDATED_UI") {
                excludedDepth = 1
                continue
            }
            if excludedDepth > 0 {
                excludedDepth += legacyDirectiveDepthDelta(for: trimmed)
                continue
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    private func legacyDirectiveDepthDelta(for trimmedLine: String) -> Int {
        if trimmedLine.hasPrefix("#if ") { return 1 }
        if trimmedLine == "#endif" { return -1 }
        return 0
    }

    /// The registry deliberately stores prohibited phrases as policy metadata.
    /// Registry-specific tests validate that data; the display-copy scan excludes only its declaration.
    private func removingEvidenceClaimRegistryMetadata(from source: String) -> String {
        guard let start = source.range(of: "public static let claims: [EvidenceClaim] = ["),
              let end = source.range(of: "\n    ]", range: start.upperBound..<source.endIndex)
        else {
            return source
        }
        return source.replacingCharacters(in: start.lowerBound..<end.upperBound, with: "")
    }

    /// Extract app-visible Swift string contents without scanning identifiers,
    /// comments, or the source spelling of implementation-only code.
    private func extractSwiftStringLiterals(from source: String) -> [String] {
        extractSwiftStringLiteralsImplementation(source)
    }
}

private let extractSwiftStringLiteralsImplementation: @Sendable (String) -> [String] = { source in
    func has(_ needle: String, at index: Int, in characters: [Character]) -> Bool {
        let target = Array(needle)
        guard index + target.count <= characters.count else { return false }
        return Array(characters[index..<(index + target.count)]) == target
    }
        let characters = Array(source)
        var strings: [String] = []
        var current = ""
        var index = 0
        var blockCommentDepth = 0

        while index < characters.count {
            if blockCommentDepth > 0 {
                if has("/*", at: index, in: characters) {
                    blockCommentDepth += 1
                    index += 2
                } else if has("*/", at: index, in: characters) {
                    blockCommentDepth -= 1
                    index += 2
                } else {
                    index += 1
                }
                continue
            }

            if has("//", at: index, in: characters) {
                while index < characters.count, characters[index] != "\n" { index += 1 }
                continue
            }
            if has("/*", at: index, in: characters) {
                blockCommentDepth = 1
                index += 2
                continue
            }
            if has("\"\"\"", at: index, in: characters) {
                index += 3
                current = ""
                while index < characters.count, !has("\"\"\"", at: index, in: characters) {
                    current.append(characters[index])
                    index += 1
                }
                strings.append(current)
                index = min(index + 3, characters.count)
                continue
            }
            if characters[index] == "\"" {
                index += 1
                current = ""
                while index < characters.count {
                    if characters[index] == "\\", index + 1 < characters.count {
                        current.append(characters[index + 1])
                        index += 2
                    } else if characters[index] == "\"" {
                        index += 1
                        break
                    } else {
                        current.append(characters[index])
                        index += 1
                    }
                }
                strings.append(current)
                continue
            }
            index += 1
        }
        return strings
}
