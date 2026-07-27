import Foundation
import XCTest
@testable import SessionCore

final class SessionIntegrityTests: XCTestCase {
    func testResearchProtocolRequiresAcknowledgementAtOrBeforeEvaluation() {
        let evaluationDate = Date(timeIntervalSince1970: 500)
        let expiryDate = evaluationDate.addingTimeInterval(600)
        let futureAcknowledgement = ResearchProtocolReference(
            protocolIdentifier: "study",
            oversightReference: "oversight",
            expiresAt: expiryDate,
            disclosureAcknowledgedAt: evaluationDate.addingTimeInterval(1)
        )
        let currentAcknowledgement = ResearchProtocolReference(
            protocolIdentifier: "study",
            oversightReference: "oversight",
            expiresAt: expiryDate,
            disclosureAcknowledgedAt: evaluationDate
        )

        XCTAssertFalse(futureAcknowledgement.isUsable(at: evaluationDate))
        XCTAssertTrue(currentAcknowledgement.isUsable(at: evaluationDate))
    }

    func testConsentGrantRejectsFutureDatedGrantsForEveryScope() {
        let evaluationDate = Date(timeIntervalSince1970: 1_000)

        for scope in ConsentScope.allCases {
            let grant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [scope]
    values.documentIdentifier = "consent"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = evaluationDate.addingTimeInterval(1)
    return values
}())

            XCTAssertFalse(grant.authorizes(scope, at: evaluationDate), "\(scope) must not authorize before it is granted.")
        }
    }

    func testConsentGrantRejectsBlankIdentityFieldsForEveryScope() {
        let evaluationDate = Date(timeIntervalSince1970: 2_000)
        let blankIdentityVariants: [(String, String, String)] = [
            (" \n\t ", "1", "group"),
            ("consent", " \n\t ", "group"),
            ("consent", "1", " \n\t ")
        ]

        for scope in ConsentScope.allCases {
            for (documentIdentifier, documentVersion, participantGroupPseudonym) in blankIdentityVariants {
                let grant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [scope]
    values.documentIdentifier = documentIdentifier
    values.documentVersion = documentVersion
    values.participantGroupPseudonym = participantGroupPseudonym
    values.grantedAt = evaluationDate
    return values
}())

                XCTAssertFalse(grant.authorizes(scope, at: evaluationDate), "\(scope) must require complete grant identity.")
            }
        }
    }

    func testConsentGrantAuthorizesValidCurrentGrantAndLegacySessionsRemainDecodable() throws {
        let evaluationDate = Date(timeIntervalSince1970: 3_000)
        let validGrant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = Set(ConsentScope.allCases)
    values.documentIdentifier = "consent"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = evaluationDate
    return values
}())
        for scope in ConsentScope.allCases {
            XCTAssertTrue(validGrant.authorizes(scope, at: evaluationDate))
        }

        let currentSession = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [validGrant]
    return values
}())
        var legacyPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(currentSession)) as? [String: Any]
        )
        legacyPayload.removeValue(forKey: "consentGrants")
        let legacySession = try JSONDecoder().decode(
            CaptureSession.self,
            from: JSONSerialization.data(withJSONObject: legacyPayload)
        )

        XCTAssertTrue(legacySession.consentGrants.isEmpty)
        XCTAssertFalse(legacySession.authorizes(.collection, at: evaluationDate))
    }

    func testCaptureAuthorizationFreezesGrantIdentityAndEarliestSelectedExpiry() throws{
        try captureAuthorizationFreezesGrantIdentityAndEarliestSelectedExpiryAssertions()
    }

    func testCaptureAuthorizationRejectsSwappedOrMissingScopeGrantBindings() throws{
        try captureAuthorizationRejectsSwappedOrMissingScopeGrantBindingsAssertions()
    }

    func testCaptureAuthorizationRejectsDuplicateGrantIDsAtPreparationAndRevalidation() throws{
        try captureAuthorizationRejectsDuplicateGrantIDsAtPreparationAndRevalidationAssertions()
    }

}


private let captureAuthorizationFreezesGrantIdentityAndEarliestSelectedExpiryAssertions: @Sendable () throws -> Void = {
        let now = Date(timeIntervalSince1970: 10_000)
        let later = now.addingTimeInterval(600)
        let earliest = now.addingTimeInterval(300)
        let collection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection]
    values.documentIdentifier = "collection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    values.expiresAt = later
    return values
}())
        let reflection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.localReflection]
    values.documentIdentifier = "reflection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    values.expiresAt = earliest
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [collection, reflection]
    return values
}())

        let snapshot = try XCTUnwrap(session.captureAuthorizationSnapshot(at: now))
        XCTAssertEqual(snapshot.requiredScopes, [.collection, .localReflection])
        XCTAssertEqual(Set(snapshot.grantIDs), [collection.id, reflection.id])
        XCTAssertEqual(snapshot.grantIDByScope, [
            .collection: collection.id,
            .localReflection: reflection.id
        ])
        XCTAssertEqual(snapshot.effectiveExpiresAt, earliest)
        XCTAssertTrue(session.authorizes(snapshot, at: now.addingTimeInterval(299)))
        XCTAssertFalse(session.authorizes(snapshot, at: earliest))

        session.consentGrants[0].withdrawnAt = now.addingTimeInterval(10)
        session.consentGrants.append(ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection]
    values.documentIdentifier = "replacement"
    values.documentVersion = "2"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now.addingTimeInterval(10)
    values.expiresAt = later
    return values
}()))
        XCTAssertFalse(
            session.authorizes(snapshot, at: now.addingTimeInterval(11)),
            "A replacement grant must not retroactively authorize a prepared take."
        )
    }

private let captureAuthorizationRejectsSwappedOrMissingScopeGrantBindingsAssertions: @Sendable () throws -> Void = {
        let now = Date(timeIntervalSince1970: 30_000)
        let collection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection]
    values.documentIdentifier = "collection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        let reflection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.localReflection]
    values.documentIdentifier = "reflection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [collection, reflection]
    return values
}())
        let snapshot = try XCTUnwrap(session.captureAuthorizationSnapshot(at: now))

        XCTAssertTrue(session.authorizes(snapshot, at: now))

        let swapped = CaptureAuthorizationSnapshot({
    var values = CaptureAuthorizationSnapshot.Values()
    values.requiredScopes = snapshot.requiredScopes
    values.grantIDs = snapshot.grantIDs
    values.grantIDByScope = [
                .collection: reflection.id,
                .localReflection: collection.id
            ]
    values.effectiveExpiresAt = snapshot.effectiveExpiresAt
    values.preparedAt = snapshot.preparedAt
    return values
}())
        XCTAssertFalse(
            session.authorizes(swapped, at: now),
            "The frozen collection and reflection grant identities must not be interchangeable."
        )

        var mutated = session
        mutated.consentGrants[0].scopes = [.localReflection]
        XCTAssertFalse(
            mutated.authorizes(snapshot, at: now),
            "A frozen grant ID cannot retain collection authority after its scope is mutated."
        )

        let legacy = CaptureAuthorizationSnapshot({
    var values = CaptureAuthorizationSnapshot.Values()
    values.requiredScopes = snapshot.requiredScopes
    values.grantIDs = snapshot.grantIDs
    values.effectiveExpiresAt = snapshot.effectiveExpiresAt
    values.preparedAt = snapshot.preparedAt
    return values
}())
        XCTAssertFalse(session.authorizes(legacy, at: now), "Snapshots without exact bindings must fail closed.")

        var legacyPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        legacyPayload.removeValue(forKey: "grantIDByScope")
        let decodedLegacy = try JSONDecoder().decode(
            CaptureAuthorizationSnapshot.self,
            from: JSONSerialization.data(withJSONObject: legacyPayload)
        )
        XCTAssertTrue(decodedLegacy.grantIDByScope.isEmpty)
        XCTAssertFalse(session.authorizes(decodedLegacy, at: now), "Decoded pre-binding snapshots must fail closed.")
    }

private let captureAuthorizationRejectsDuplicateGrantIDsAtPreparationAndRevalidationAssertions: @Sendable () throws -> Void = {
        let now = Date(timeIntervalSince1970: 40_000)
        let duplicateID = UUID()
        let collection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.id = duplicateID
    values.scopes = [.collection]
    values.documentIdentifier = "collection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        let duplicateReflection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.id = duplicateID
    values.scopes = [.localReflection]
    values.documentIdentifier = "reflection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [collection, duplicateReflection]
    return values
}())

        XCTAssertNil(
            session.captureAuthorizationSnapshot(at: now),
            "Preparation must reject duplicate IDs even when their split scopes appear complete."
        )

        let validReflection = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.localReflection]
    values.documentIdentifier = "valid-reflection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        session.consentGrants = [collection, validReflection]
        let snapshot = try XCTUnwrap(session.captureAuthorizationSnapshot(at: now))
        session.consentGrants.append(ConsentGrant({
    var values = ConsentGrant.Values()
    values.id = collection.id
    values.scopes = [.collection]
    values.documentIdentifier = "duplicate-collection"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}()))
        XCTAssertFalse(
            session.authorizes(snapshot, at: now),
            "Revalidation must reject a bound ID that becomes ambiguous after preparation."
        )
    }
