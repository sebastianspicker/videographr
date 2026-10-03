import Foundation

/// Transient authority for the local spoken-audio check. The exact grants are frozen so a
/// replacement grant cannot retroactively authorize an already prepared microphone action.
public struct SpokenAudioCheckAuthorization: Equatable, Sendable {
    public static let requiredScopes: Set<ConsentScope> = [.collection, .localReflection]

    public let sessionID: UUID
    public let preparedAt: Date
    public let grantIDByScope: [ConsentScope: UUID]
    public let effectiveExpiresAt: Date?

    public static func make(
        for session: CaptureSession,
        at date: Date = Date(),
        covering duration: TimeInterval = 0
    ) -> Self? {
        guard let end = authorizationEnd(startingAt: date, covering: duration) else { return nil }
        let bindings = requiredScopes.reduce(into: [ConsentScope: UUID]()) { result, scope in
            result[scope] = session.consentGrants
                .filter { $0.authorizes(scope, at: date) && $0.authorizes(scope, at: end) }
                .sorted(by: preferredGrant)
                .first?
                .id
        }
        guard bindings.count == requiredScopes.count,
              bindings.values.allSatisfy({ id in
                  session.consentGrants.filter({ $0.id == id }).count == 1
              })
        else { return nil }

        let selectedIDs = Set(bindings.values)
        let expiry = session.consentGrants
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.expiresAt)
            .min()
        return Self(
            sessionID: session.id,
            preparedAt: date,
            grantIDByScope: bindings,
            effectiveExpiresAt: expiry
        )
    }

    public func authorizes(
        _ session: CaptureSession,
        at date: Date = Date(),
        covering duration: TimeInterval = 0
    ) -> Bool {
        guard session.id == sessionID,
              preparedAt <= date,
              Set(grantIDByScope.keys) == Self.requiredScopes,
              let end = Self.authorizationEnd(startingAt: date, covering: duration),
              effectiveExpiresAt.map({ $0 > end }) ?? true
        else { return false }

        return Self.requiredScopes.allSatisfy { scope in
            guard let id = grantIDByScope[scope],
                  session.consentGrants.filter({ $0.id == id }).count == 1,
                  let grant = session.consentGrants.first(where: { $0.id == id })
            else { return false }
            return grant.authorizes(scope, at: date) && grant.authorizes(scope, at: end)
        }
    }

    private static func authorizationEnd(startingAt date: Date, covering duration: TimeInterval) -> Date? {
        guard duration.isFinite, duration >= 0 else { return nil }
        let end = date.addingTimeInterval(duration)
        guard end.timeIntervalSinceReferenceDate.isFinite, end >= date else { return nil }
        return end
    }

    private static func preferredGrant(_ lhs: ConsentGrant, _ rhs: ConsentGrant) -> Bool {
        let leftExpiry = lhs.expiresAt ?? .distantFuture
        let rightExpiry = rhs.expiresAt ?? .distantFuture
        if leftExpiry != rightExpiry { return leftExpiry > rightExpiry }
        if lhs.grantedAt != rhs.grantedAt { return lhs.grantedAt > rhs.grantedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
