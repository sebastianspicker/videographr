import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

final class ConsentAndProtocolTests: XCTestCase {
    func testResearchCaptureRequiresCurrentProtocolAndResearchConsent() {
        let now = Date()
        let protocolReference = ResearchProtocolReference(
            protocolIdentifier: "study", oversightReference: "oversight", expiresAt: now.addingTimeInterval(60), disclosureAcknowledgedAt: now
        )
        let collectionOnly = grant(scopes: [.collection, .localReflection], at: now)
        let research = grant(scopes: [.collection, .localReflection, .researchProcessing], at: now)
        XCTAssertFalse(session(protocolReference, [collectionOnly]).hasUsableExperimentalProtocol)
        XCTAssertTrue(session(protocolReference, [research]).hasUsableExperimentalProtocol)
    }

    func testFrozenCaptureAuthorizationRejectsReplacementGrant() throws {
        let now = Date()
        var capture = session(
            ResearchProtocolReference(
                protocolIdentifier: "study", oversightReference: "oversight",
                expiresAt: now.addingTimeInterval(60), disclosureAcknowledgedAt: now
            ),
            [grant(scopes: [.collection, .localReflection, .researchProcessing], at: now)]
        )
        let snapshot = try XCTUnwrap(capture.captureAuthorizationSnapshot(at: now))
        XCTAssertTrue(capture.authorizes(snapshot, at: now))

        capture.consentGrants = [grant(scopes: [.collection, .localReflection, .researchProcessing], at: now)]
        XCTAssertFalse(capture.authorizes(snapshot, at: now))
    }

    func testVersionOneDecodeCarriesLegacyMediaButNeverInventsScopedConsentAuthority() throws {
        let recordingPath = "Recordings/legacy-take.mp4"
        let source = CaptureSession({
            var values = CaptureSession.Values()
            values.recordingRelativePath = recordingPath
            values.consent = ConsentRecord(
                informedParticipantsAcknowledged: true,
                secondaryUseAcknowledged: true,
                storageResponsibilityAcknowledged: true,
                acknowledgedAt: Date(timeIntervalSinceReferenceDate: 1)
            )
            return values
        }())
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        payload["schemaVersion"] = 1
        [
            "teachingSituation", "codingSnapshots", "codingTimeline", "operatingMode",
            "experimentalProtocol", "mediaAssets", "evidenceAnnotations", "captureDecisions",
            "takeManifests", "captureObservations", "consentGrants", "retentionPolicy",
            "exportEvents", "buildProvenance"
        ].forEach { payload.removeValue(forKey: $0) }

        var decoded = try JSONDecoder().decode(
            CaptureSession.self,
            from: JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        )

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.operatingMode, .evidenceSafe)
        XCTAssertEqual(decoded.mediaAssets.map(\.relativePath), [recordingPath])
        XCTAssertEqual(decoded.mediaAssets.map(\.role), [.ownRecorded])
        XCTAssertTrue(decoded.consentGrants.isEmpty)
        XCTAssertFalse(decoded.authorizes(.collection))
        XCTAssertFalse(decoded.authorizes(.localReflection))
        XCTAssertNil(decoded.captureAuthorizationSnapshot())

        decoded.migrateLegacyDataIfNeeded()
        XCTAssertEqual(decoded.schemaVersion, SessionSchema.currentVersion)
        XCTAssertEqual(decoded.mediaAssets.map(\.relativePath), [recordingPath])
        XCTAssertTrue(decoded.consentGrants.isEmpty)
        XCTAssertFalse(decoded.authorizes(.collection))
    }

    func testFrozenCaptureAuthorizationPinsGrantBindingsAndFailsClosedForReplacementExpiryAndWithdrawal() throws {
        let preparedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        let collection = grant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            scopes: [.collection],
            grantedAt: preparedAt.addingTimeInterval(-1),
            expiresAt: preparedAt.addingTimeInterval(120)
        )
        let localReflection = grant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            scopes: [.localReflection],
            grantedAt: preparedAt.addingTimeInterval(-1),
            expiresAt: preparedAt.addingTimeInterval(60)
        )
        let session = readySession(grants: [collection, localReflection])
        let snapshot = try XCTUnwrap(session.captureAuthorizationSnapshot(at: preparedAt))

        XCTAssertEqual(snapshot.requiredScopes, [.collection, .localReflection])
        XCTAssertEqual(snapshot.grantIDByScope, [
            .collection: collection.id,
            .localReflection: localReflection.id
        ])
        XCTAssertEqual(snapshot.effectiveExpiresAt, localReflection.expiresAt)
        XCTAssertTrue(session.authorizes(snapshot, at: preparedAt.addingTimeInterval(1)))

        let replacement = grant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            scopes: [.collection],
            grantedAt: preparedAt.addingTimeInterval(-1),
            expiresAt: preparedAt.addingTimeInterval(120)
        )
        var replacedGrant = session
        replacedGrant.consentGrants = [replacement, localReflection]
        XCTAssertFalse(replacedGrant.authorizes(snapshot, at: preparedAt.addingTimeInterval(1)))

        XCTAssertFalse(session.authorizes(snapshot, at: preparedAt.addingTimeInterval(60)))

        var withdrawnLocalReflection = localReflection
        withdrawnLocalReflection.withdrawnAt = preparedAt.addingTimeInterval(2)
        var withdrawnGrant = session
        withdrawnGrant.consentGrants = [collection, withdrawnLocalReflection]
        XCTAssertFalse(withdrawnGrant.authorizes(snapshot, at: preparedAt.addingTimeInterval(3)))
    }

    private func grant(
        id: UUID = UUID(),
        scopes: Set<ConsentScope>,
        grantedAt: Date = Date(timeIntervalSinceReferenceDate: 1),
        expiresAt: Date? = nil
    ) -> ConsentGrant {
        ConsentGrant({
            var values = ConsentGrant.Values()
            values.id = id
            values.scopes = scopes
            values.documentIdentifier = "consent-form"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group-a"
            values.grantedAt = grantedAt
            values.expiresAt = expiresAt
            return values
        }())
    }

    private func readySession(grants: [ConsentGrant]) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.title = "Ready session"
            values.context = SessionContext({
                var context = SessionContext.Values()
                context.subject = "Physics"
                context.lessonGoal = "Observe a demonstration"
                return context
            }())
            values.consentGrants = grants
            return values
        }())
    }

    private func grant(scopes: Set<ConsentScope>, at date: Date) -> ConsentGrant {
        ConsentGrant({
            var values = ConsentGrant.Values()
            values.scopes = scopes
            values.documentIdentifier = "consent"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group"
            values.grantedAt = date
            return values
        }())
    }

    private func session(_ reference: ResearchProtocolReference, _ grants: [ConsentGrant]) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.operatingMode = .experimentalResearch
            values.experimentalProtocol = reference
            values.consentGrants = grants
            return values
        }())
    }
}
