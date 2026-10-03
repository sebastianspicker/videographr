import Foundation

/// A scoped grant; legacy acknowledgements intentionally do not decode into this type.
public struct ConsentGrant: Codable, Equatable, Identifiable, Sendable {
    public struct Values: Sendable {
        public var id = UUID()
        public var scopes: Set<ConsentScope> = []
        public var documentIdentifier = ""
        public var documentVersion = ""
        public var participantGroupPseudonym = ""
        public var grantedAt = Date()
        public var expiresAt: Date?
        public var withdrawnAt: Date?

        public init() {}
    }

    public var id: UUID
    public var scopes: Set<ConsentScope>
    public var documentIdentifier: String
    public var documentVersion: String
    public var participantGroupPseudonym: String
    public var grantedAt: Date
    public var expiresAt: Date?
    public var withdrawnAt: Date?

    public init(_ values: Values = Values()) {
        id = values.id
        scopes = values.scopes
        documentIdentifier = values.documentIdentifier
        documentVersion = values.documentVersion
        participantGroupPseudonym = values.participantGroupPseudonym
        grantedAt = values.grantedAt
        expiresAt = values.expiresAt
        withdrawnAt = values.withdrawnAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, scopes, documentIdentifier, documentVersion, participantGroupPseudonym, grantedAt, expiresAt, withdrawnAt
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(SessionCoding.canonicalOrder(scopes), forKey: .scopes)
        try c.encode(documentIdentifier, forKey: .documentIdentifier)
        try c.encode(documentVersion, forKey: .documentVersion)
        try c.encode(participantGroupPseudonym, forKey: .participantGroupPseudonym)
        try c.encode(grantedAt, forKey: .grantedAt)
        try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try c.encodeIfPresent(withdrawnAt, forKey: .withdrawnAt)
    }

    public func authorizes(_ scope: ConsentScope, at date: Date = Date()) -> Bool {
        let requirements = [
            scopes.contains(scope),
            isDocumented,
            isCurrent(at: date)
        ]
        return requirements.allSatisfy({ $0 })
    }

    private var isDocumented: Bool {
        [documentIdentifier, documentVersion, participantGroupPseudonym]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func isCurrent(at date: Date) -> Bool {
        let requirements = [
            grantedAt <= date,
            withdrawnAt == nil,
            expiresAt.map { $0 > date } ?? true
        ]
        return requirements.allSatisfy({ $0 })
    }
}
