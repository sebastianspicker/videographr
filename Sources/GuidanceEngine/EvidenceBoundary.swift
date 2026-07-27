import Foundation

public enum EvidenceValidationTier: String, Codable, CaseIterable, Sendable {
    case documented
    case implemented
    case unitTested
    case deviceTested
    case humanValidated
    case effectivenessTested
}

public struct EvidenceClaim: Equatable, Sendable, Identifiable {
    public typealias Values = (
        id: String,
        sourceURL: String,
        construct: String,
        requiredObservable: String,
        allowedWordingDE: String,
        prohibitedWordingDE: [String],
        validationTier: EvidenceValidationTier
    )

    public var id: String
    public var sourceURL: String
    public var construct: String
    public var requiredObservable: String
    public var allowedWordingDE: String
    public var prohibitedWordingDE: [String]
    public var validationTier: EvidenceValidationTier

    public init(_ values: Values) {
        id = values.id
        sourceURL = values.sourceURL
        construct = values.construct
        requiredObservable = values.requiredObservable
        allowedWordingDE = values.allowedWordingDE
        prohibitedWordingDE = values.prohibitedWordingDE
        validationTier = values.validationTier
    }
}

public struct EvidenceClaimViolation: Equatable, Sendable {
    public var claimID: String
    public var prohibitedPattern: String
    public var excerpt: String

    public init(claimID: String, prohibitedPattern: String, excerpt: String) {
        self.claimID = claimID
        self.prohibitedPattern = prohibitedPattern
        self.excerpt = excerpt
    }
}

public extension EvidenceClaimRegistry {
    /// Deterministic schema and wording validation for app-facing evidence copy.
    static func validate(_ claims: [EvidenceClaim] = EvidenceClaimRegistry.claims) -> [String] {
        var failures: [String] = []
        var IDs = Set<String>()
        for claim in claims {
            failures += validationFailures(for: claim, registeredIDs: &IDs)
        }
        return failures.sorted()
    }

    private static func validationFailures(
        for claim: EvidenceClaim,
        registeredIDs: inout Set<String>
    ) -> [String] {
        let failures = [
            identityFailure(for: claim, registeredIDs: &registeredIDs),
            sourceFailure(for: claim),
            contractFailure(for: claim),
            prohibitedWordingFailure(for: claim),
            emptyPatternFailure(for: claim)
        ].compactMap { $0 }
        return failures + positiveWordingFailures(for: claim)
    }

    private static func identityFailure(
        for claim: EvidenceClaim,
        registeredIDs: inout Set<String>
    ) -> String? {
        guard !claim.id.isEmpty, registeredIDs.insert(claim.id).inserted else {
            return "duplicate-or-empty-id"
        }
        return nil
    }

    private static func sourceFailure(for claim: EvidenceClaim) -> String? {
        let source = URLComponents(string: claim.sourceURL)
        guard source?.scheme == "https", source?.host?.isEmpty == false else {
            return "invalid-source:\(claim.id)"
        }
        return nil
    }

    private static func contractFailure(for claim: EvidenceClaim) -> String? {
        let complete = !claim.construct.isEmpty
            && !claim.requiredObservable.isEmpty
            && !claim.allowedWordingDE.isEmpty
        return complete ? nil : "missing-contract:\(claim.id)"
    }

    private static func prohibitedWordingFailure(for claim: EvidenceClaim) -> String? {
        claim.prohibitedWordingDE.isEmpty ? "missing-prohibited-wording:\(claim.id)" : nil
    }

    private static func emptyPatternFailure(for claim: EvidenceClaim) -> String? {
        let hasEmptyPattern = claim.prohibitedWordingDE.contains { normalizedTokens($0).isEmpty }
        return hasEmptyPattern ? "empty-prohibited-pattern:\(claim.id)" : nil
    }

    private static func positiveWordingFailures(for claim: EvidenceClaim) -> [String] {
        positiveClaimViolations(in: claim.allowedWordingDE, claims: [claim]).map {
            "forbidden-wording:\(claim.id):\($0.prohibitedPattern)"
        }
    }

    static func containsProhibitedWording(_ text: String, claims: [EvidenceClaim] = EvidenceClaimRegistry.claims) -> Bool {
        !positiveClaimViolations(in: text, claims: claims).isEmpty
    }

    /// Finds unsupported positive claims. Explicit limitation and negative
    /// contexts (for example, "nicht validiert") are intentionally permitted.
    /// Matching uses diacritic-insensitive token stems so ordinary German
    /// inflections cannot trivially bypass the policy.
    static func positiveClaimViolations(
        in text: String,
        claims: [EvidenceClaim] = EvidenceClaimRegistry.claims
    ) -> [EvidenceClaimViolation] {
        evidenceSegments(in: text).flatMap { violations(in: $0, claims: claims) }
    }

    private static func violations(
        in segment: String,
        claims: [EvidenceClaim]
    ) -> [EvidenceClaimViolation] {
        let tokens = normalizedTokens(segment)
        guard !tokens.isEmpty else { return [] }
        return claims.flatMap { violations(in: segment, tokens: tokens, claim: $0) }
    }

    private static func violations(
        in segment: String,
        tokens: [String],
        claim: EvidenceClaim
    ) -> [EvidenceClaimViolation] {
        claim.prohibitedWordingDE.flatMap {
            violations(in: segment, tokens: tokens, claimID: claim.id, pattern: $0)
        }
    }

    private static func violations(
        in segment: String,
        tokens: [String],
        claimID: String,
        pattern: String
    ) -> [EvidenceClaimViolation] {
        let patternTokens = normalizedTokens(pattern)
        guard !patternTokens.isEmpty, patternTokens.count <= tokens.count else { return [] }
        return (0...(tokens.count - patternTokens.count)).compactMap {
            violation((
                segment: segment,
                tokens: tokens,
                claimID: claimID,
                pattern: pattern,
                patternTokens: patternTokens,
                start: $0
            ))
        }
    }

    private typealias ViolationCandidate = (
        segment: String,
        tokens: [String],
        claimID: String,
        pattern: String,
        patternTokens: [String],
        start: Int
    )

    private static func violation(_ candidate: ViolationCandidate) -> EvidenceClaimViolation? {
        let end = candidate.start + candidate.patternTokens.count
        let actualTokens = candidate.tokens[candidate.start..<end]
        let matches = zip(candidate.patternTokens, actualTokens).allSatisfy {
            token($0.1, matchesStem: $0.0)
        }
        guard matches else { return nil }
        guard !hasNegativeContext(tokens: candidate.tokens, matchRange: candidate.start..<end) else { return nil }
        return EvidenceClaimViolation(
            claimID: candidate.claimID,
            prohibitedPattern: candidate.pattern,
            excerpt: String(candidate.segment.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        )
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        return normalized.unicodeScalars
            .split { !CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
    }

    private static func token(_ token: String, matchesStem stem: String) -> Bool {
        token == stem || (stem.count >= 4 && token.hasPrefix(stem))
    }

    private static func hasNegativeContext(tokens: [String], matchRange: Range<Int>) -> Bool {
        if hasLeadingNegativeContext(tokens) { return true }
        if hasNeitherNorContext(tokens, before: matchRange.lowerBound) { return true }
        let lowerBound = max(tokens.startIndex, matchRange.lowerBound - 8)
        let upperBound = min(tokens.endIndex, matchRange.upperBound + 8)
        return tokens[lowerBound..<upperBound].indices.contains { isNegativeToken(tokens, at: $0) }
    }

    private static func hasLeadingNegativeContext(_ tokens: [String]) -> Bool {
        tokens.starts(with: ["nicht", "enthalten"])
            || tokens.starts(with: ["nicht", "beansprucht"])
            || tokens.starts(with: ["keine", "aussage"])
    }

    private static func hasNeitherNorContext(_ tokens: [String], before index: Int) -> Bool {
        tokens[..<index].contains("noch") && tokens[..<index].contains("weder")
    }

    private static func isNegativeToken(_ tokens: [String], at index: Int) -> Bool {
        let value = tokens[index]
        return isUnvalidated(value) || isNegativeQuantifier(value) || isStandaloneNot(tokens, at: index)
    }

    private static func isUnvalidated(_ value: String) -> Bool {
        value.hasPrefix("unvalidiert") || value.hasPrefix("ungepruft")
    }

    private static func isNegativeQuantifier(_ value: String) -> Bool {
        value == "weder" || value.hasPrefix("kein")
    }

    private static func isStandaloneNot(_ tokens: [String], at index: Int) -> Bool {
        guard tokens[index] == "nicht" else { return false }
        let next = tokens.index(after: index)
        return next == tokens.endIndex || tokens[next] != "nur"
    }

    private static func evidenceSegments(in text: String) -> [String] {
        let characters = Array(text)
        var segments: [String] = []
        var current = ""

        for index in characters.indices {
            let character = characters[index]
            let nextIndex = characters.index(after: index)
            let nextIsNumber = nextIndex < characters.endIndex && characters[nextIndex].isNumber
            if isEvidenceBoundary(character, nextIsNumber: nextIsNumber) {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        segments.append(current)
        return segments
    }

    private static func isEvidenceBoundary(_ character: Character, nextIsNumber: Bool) -> Bool {
        if character == "." { return !nextIsNumber }
        return "!?;\n\r".contains(character)
    }
}
