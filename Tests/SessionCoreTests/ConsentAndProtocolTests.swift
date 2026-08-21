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
