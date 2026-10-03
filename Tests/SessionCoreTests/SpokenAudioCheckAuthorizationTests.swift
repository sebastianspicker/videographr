import XCTest
@testable import SessionCore

final class SpokenAudioCheckAuthorizationTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 10_000)

    func testAuthorizationPinsBothScopesWithoutRequiringResearchConsent() throws {
        let grant = documentedGrant(
            scopes: [.collection, .localReflection],
            expiresAt: now.addingTimeInterval(30)
        )
        var session = captureSession(grants: [grant])
        session.operatingMode = .experimentalResearch

        let authorization = try XCTUnwrap(
            SpokenAudioCheckAuthorization.make(for: session, at: now, covering: 4.5)
        )

        XCTAssertEqual(authorization.grantIDByScope[.collection], grant.id)
        XCTAssertEqual(authorization.grantIDByScope[.localReflection], grant.id)
        XCTAssertTrue(authorization.authorizes(session, at: now, covering: 4.5))
    }

    func testPreparationRejectsMissingOrInsufficientlyLongConsent() {
        let collectionOnly = documentedGrant(scopes: [.collection])
        XCTAssertNil(SpokenAudioCheckAuthorization.make(
            for: captureSession(grants: [collectionOnly]),
            at: now,
            covering: 4.5
        ))

        let expiring = documentedGrant(
            scopes: [.collection, .localReflection],
            expiresAt: now.addingTimeInterval(4.5)
        )
        XCTAssertNil(SpokenAudioCheckAuthorization.make(
            for: captureSession(grants: [expiring]),
            at: now,
            covering: 4.5
        ))
    }

    func testFrozenAuthorizationRejectsReplacementWithdrawalExpiryAndSessionSwitch() throws {
        let grant = documentedGrant(
            scopes: [.collection, .localReflection],
            expiresAt: now.addingTimeInterval(20)
        )
        let session = captureSession(grants: [grant])
        let authorization = try XCTUnwrap(
            SpokenAudioCheckAuthorization.make(for: session, at: now, covering: 4.5)
        )

        let replacement = documentedGrant(scopes: [.collection, .localReflection])
        XCTAssertFalse(authorization.authorizes(
            captureSession(id: session.id, grants: [replacement]),
            at: now.addingTimeInterval(1)
        ))

        var withdrawn = grant
        withdrawn.withdrawnAt = now.addingTimeInterval(1)
        XCTAssertFalse(authorization.authorizes(
            captureSession(id: session.id, grants: [withdrawn]),
            at: now.addingTimeInterval(1)
        ))
        XCTAssertFalse(authorization.authorizes(session, at: now.addingTimeInterval(20)))
        XCTAssertFalse(authorization.authorizes(
            captureSession(grants: [grant]),
            at: now.addingTimeInterval(1)
        ))
    }

    func testAuthorizationRejectsInvalidCoverageIntervals() throws {
        let session = captureSession(grants: [documentedGrant(scopes: [.collection, .localReflection])])
        let authorization = try XCTUnwrap(SpokenAudioCheckAuthorization.make(for: session, at: now))

        XCTAssertFalse(authorization.authorizes(session, at: now, covering: -.leastNonzeroMagnitude))
        XCTAssertFalse(authorization.authorizes(session, at: now, covering: .infinity))
    }

    private func documentedGrant(
        scopes: Set<ConsentScope>,
        expiresAt: Date? = nil
    ) -> ConsentGrant {
        ConsentGrant({
            var values = ConsentGrant.Values()
            values.scopes = scopes
            values.documentIdentifier = "consent-form"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group-a"
            values.grantedAt = now.addingTimeInterval(-1)
            values.expiresAt = expiresAt
            return values
        }())
    }

    private func captureSession(
        id: UUID = UUID(),
        grants: [ConsentGrant]
    ) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.id = id
            values.consentGrants = grants
            return values
        }())
    }
}
