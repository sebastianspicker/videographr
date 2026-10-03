import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

final class CaptureSessionTransitionTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    func testActivateExperimentalModeStoresProtocolAndSwitchesMode() {
        var session = CaptureSession()
        let reference = ResearchProtocolReference(
            protocolIdentifier: "study", oversightReference: "oversight",
            expiresAt: now.addingTimeInterval(60), disclosureAcknowledgedAt: now
        )
        session.activateExperimentalMode(protocol: reference)
        XCTAssertEqual(session.operatingMode, .experimentalResearch)
        XCTAssertEqual(session.experimentalProtocol, reference)
    }

    func testReturnToEvidenceSafeClearsProtocol() {
        var session = CaptureSession()
        session.activateExperimentalMode(protocol: ResearchProtocolReference(
            protocolIdentifier: "study", oversightReference: "oversight", expiresAt: now.addingTimeInterval(60)
        ))
        session.returnToEvidenceSafe()
        XCTAssertEqual(session.operatingMode, .evidenceSafe)
        XCTAssertNil(session.experimentalProtocol)
    }

    func testHasUsableExperimentalProtocolAtDate() {
        var session = CaptureSession()
        session.activateExperimentalMode(protocol: ResearchProtocolReference(
            protocolIdentifier: "study", oversightReference: "oversight",
            expiresAt: now.addingTimeInterval(60), disclosureAcknowledgedAt: now
        ))
        session.replaceConsentGrants(with: draft(scopes: [.collection, .researchProcessing]), at: now)
        XCTAssertTrue(session.hasUsableExperimentalProtocol(at: now))
        XCTAssertFalse(session.hasUsableExperimentalProtocol(at: now.addingTimeInterval(61)))
        XCTAssertFalse(session.hasUsableExperimentalProtocol(at: now.addingTimeInterval(-1)))
    }

    func testReplaceConsentGrantsWithdrawsActiveGrantsAndAppendsTrimmedGrant() {
        var session = CaptureSession()
        session.replaceConsentGrants(with: draft(scopes: [.collection]), at: now)
        let later = now.addingTimeInterval(10)
        let expiry = later.addingTimeInterval(3_600)
        session.replaceConsentGrants(
            with: ConsentGrantDraft(
                scopes: [.collection, .localReflection],
                documentIdentifier: "  doc  ", documentVersion: " 2 ",
                participantGroupPseudonym: "\ngroup\n", expiresAt: expiry
            ),
            at: later
        )
        XCTAssertEqual(session.consentGrants.count, 2)
        XCTAssertEqual(session.consentGrants[0].withdrawnAt, later)
        let current = session.consentGrants[1]
        XCTAssertNil(current.withdrawnAt)
        XCTAssertEqual(current.scopes, [.collection, .localReflection])
        XCTAssertEqual(current.documentIdentifier, "doc")
        XCTAssertEqual(current.documentVersion, "2")
        XCTAssertEqual(current.participantGroupPseudonym, "group")
        XCTAssertEqual(current.grantedAt, later)
        XCTAssertEqual(current.expiresAt, expiry)
    }

    func testReplaceConsentGrantsKeepsAlreadyWithdrawnTimestamp() {
        var session = CaptureSession()
        session.replaceConsentGrants(with: draft(scopes: [.collection]), at: now)
        session.replaceConsentGrants(with: draft(scopes: []), at: now.addingTimeInterval(5))
        session.replaceConsentGrants(with: draft(scopes: []), at: now.addingTimeInterval(9))
        XCTAssertEqual(session.consentGrants.count, 1)
        XCTAssertEqual(session.consentGrants[0].withdrawnAt, now.addingTimeInterval(5))
    }

    func testIncompleteDraftsStillWithdrawButNeverAppend() {
        let incomplete = [
            draft(scopes: []),
            ConsentGrantDraft(scopes: [.collection], documentIdentifier: " ", documentVersion: "1", participantGroupPseudonym: "g", expiresAt: nil),
            ConsentGrantDraft(scopes: [.collection], documentIdentifier: "d", documentVersion: "", participantGroupPseudonym: "g", expiresAt: nil),
            ConsentGrantDraft(scopes: [.collection], documentIdentifier: "d", documentVersion: "1", participantGroupPseudonym: "\n", expiresAt: nil)
        ]
        for bad in incomplete {
            var session = CaptureSession()
            session.replaceConsentGrants(with: draft(scopes: [.collection]), at: now)
            let later = now.addingTimeInterval(10)
            session.replaceConsentGrants(with: bad, at: later)
            XCTAssertEqual(session.consentGrants.count, 1)
            XCTAssertEqual(session.consentGrants[0].withdrawnAt, later)
            XCTAssertFalse(session.authorizes(.collection, at: later))
        }
    }

    func testRemoveAnnotationRemovesOnlyMatchingID() {
        var session = CaptureSession()
        let keep = EvidenceAnnotation(EvidenceAnnotation.Values())
        let drop = EvidenceAnnotation(EvidenceAnnotation.Values())
        session.evidenceAnnotations = [keep, drop]
        session.removeAnnotation(id: drop.id)
        XCTAssertEqual(session.evidenceAnnotations, [keep])
        session.removeAnnotation(id: UUID())
        XCTAssertEqual(session.evidenceAnnotations, [keep])
    }

    private func draft(scopes: Set<ConsentScope>) -> ConsentGrantDraft {
        ConsentGrantDraft(
            scopes: scopes, documentIdentifier: "doc", documentVersion: "1",
            participantGroupPseudonym: "group", expiresAt: nil
        )
    }
}
