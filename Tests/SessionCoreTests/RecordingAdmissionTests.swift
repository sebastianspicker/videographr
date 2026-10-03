import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

final class RecordingAdmissionTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 10_000)

    func testSuccessBuildsDecisionAndAuthorization() throws {
        let session = authorizedSession()
        let admission = try XCTUnwrap(try evaluate(session: session).get())
        XCTAssertEqual(admission.authorization, session.captureAuthorizationSnapshot(at: now))
        XCTAssertEqual(admission.decision.blockers, [])
        XCTAssertNil(admission.decision.overrideReason)
        XCTAssertEqual(admission.decision.operatorPseudonym, "op")
        XCTAssertEqual(admission.decision.operatingMode, .evidenceSafe)
        XCTAssertEqual(admission.decision.operatorAuthenticationMethod, "device-owner")
    }

    func testRefusesWithoutAuthorization() {
        assertRefusal(evaluate(session: CaptureSession()), .authorizationMissing)
        XCTAssertEqual(
            RecordingAdmission.Refusal.authorizationMissing.messageDE,
            "Aufnahme blockiert: aktiver lokaler Freigabedatensatz für Erhebung und Reflexion fehlt."
        )
    }

    func testRefusesWhenAuthorizationExpiresWithin45Seconds() {
        var soon = CaptureSession()
        soon.replaceConsentGrants(with: draft(expiresAt: now.addingTimeInterval(45)), at: now.addingTimeInterval(-1))
        assertRefusal(evaluate(session: soon), .authorizationExpiresSoon)
        var later = CaptureSession()
        later.replaceConsentGrants(with: draft(expiresAt: now.addingTimeInterval(46)), at: now.addingTimeInterval(-1))
        XCTAssertNoThrow(try evaluate(session: later).get())
        XCTAssertEqual(
            RecordingAdmission.Refusal.authorizationExpiresSoon.messageDE,
            "Aufnahme blockiert: die früheste erforderliche Freigabe läuft in weniger als 45 Sekunden ab."
        )
    }

    func testRefusesExperimentalModeWithoutUsableProtocol() {
        // Experimental mode without a protocol already fails the authorization snapshot, so a
        // protocol/consent combination that snapshots but is not usable cannot be built here.
        var session = authorizedSession()
        session.operatingMode = .experimentalResearch
        assertRefusal(evaluate(session: session), .authorizationMissing)
        XCTAssertEqual(
            RecordingAdmission.Refusal.experimentalProtocolUnusable.messageDE,
            "Experimenteller Modus blockiert: Protokoll- oder Aufsichtsreferenz fehlt bzw. ist abgelaufen."
        )
    }

    func testExperimentalModeWithUsableProtocolIsAdmitted() throws {
        var session = CaptureSession()
        session.replaceConsentGrants(
            with: ConsentGrantDraft(
                scopes: [.collection, .localReflection, .researchProcessing],
                documentIdentifier: "d", documentVersion: "1", participantGroupPseudonym: "g", expiresAt: nil
            ),
            at: now.addingTimeInterval(-100)
        )
        session.activateExperimentalMode(protocol: ResearchProtocolReference(
            protocolIdentifier: "p", oversightReference: "o",
            expiresAt: now.addingTimeInterval(3_600), disclosureAcknowledgedAt: now.addingTimeInterval(-50)
        ))
        let admission = try evaluate(session: session).get()
        XCTAssertEqual(admission.decision.operatingMode, .experimentalResearch)
        XCTAssertEqual(admission.authorization.researchProtocolIdentifier, "p")
    }

    func testRefusesWhenRecordingSlotIsOccupied() {
        var withAsset = authorizedSession()
        withAsset.mediaAssets = [SessionMediaAsset(SessionMediaAsset.Values())]
        assertRefusal(evaluate(session: withAsset), .recordingSlotOccupied)
        var withPath = authorizedSession()
        withPath.recordingRelativePath = "Recordings/take.mp4"
        assertRefusal(evaluate(session: withPath), .recordingSlotOccupied)
        XCTAssertEqual(
            RecordingAdmission.Refusal.recordingSlotOccupied.messageDE,
            "Diese Sitzung besitzt bereits eine eigene Aufnahme. Bitte eine neue Sitzung für einen weiteren Take anlegen."
        )
    }

    func testImportedAssetDoesNotOccupyRecordingSlot() throws {
        var session = authorizedSession()
        var values = SessionMediaAsset.Values()
        values.role = .otherImported
        session.mediaAssets = [SessionMediaAsset(values)]
        XCTAssertNoThrow(try evaluate(session: session).get())
    }

    func testRefusesBlockersWithoutOverrideReason() {
        let status = CaptureRuntimeStatus(spokenAudioCheckCompleted: false)
        assertRefusal(evaluate(session: authorizedSession(), runtimeStatus: status, overrideReason: "  \n"), .overrideReasonMissing)
        XCTAssertEqual(
            RecordingAdmission.Refusal.overrideReasonMissing.messageDE,
            "Für den Start trotz technischer Warnungen ist eine Begründung erforderlich."
        )
    }

    func testRefusesWhenReadinessForbidsRecording() {
        var values = SessionReadiness.Values()
        values.canRecord = false
        values.blockers = [.consentMissing]
        values.summaryDE = "Nicht bereit."
        let result = evaluate(session: authorizedSession(), readiness: SessionReadiness(values), overrideReason: "Grund")
        assertRefusal(result, .notReady(summaryDE: "Nicht bereit."))
        if case .failure(let refusal) = result { XCTAssertEqual(refusal.messageDE, "Nicht bereit.") }
    }

    func testOverrideAdmitsQualityWarningsAndRecordsBlockerGoldens() throws {
        var values = SessionReadiness.Values()
        values.canRecord = false
        values.blockers = [.audioNotReady, .contextIncomplete]
        let status = CaptureRuntimeStatus(batteryPercent: 15, thermalState: "kritisch", spokenAudioCheckCompleted: false)
        let admission = try evaluate(
            session: authorizedSession(), readiness: SessionReadiness(values),
            runtimeStatus: status, overrideReason: "  Notfall  "
        ).get()
        XCTAssertEqual(admission.decision.overrideReason, "Notfall")
        XCTAssertEqual(
            admission.decision.blockers,
            [
                "audioNotReady", "batteryLow", "contextIncomplete",
                "spokenAudioPlaybackCheckMissing", "thermalState:kritisch"
            ]
        )
        XCTAssertEqual(
            RecordingAdmission.recordingBlockers(readiness: SessionReadiness(values), runtimeStatus: status),
            [
                "audioNotReady", "contextIncomplete", "batteryLow",
                "thermalState:kritisch", "spokenAudioPlaybackCheckMissing"
            ]
        )
    }

    func testThermalSeriousAndBatteryBoundaryBlockers() {
        let readiness = SessionReadiness(readyValues())
        XCTAssertEqual(
            RecordingAdmission.recordingBlockers(
                readiness: readiness,
                runtimeStatus: CaptureRuntimeStatus(batteryPercent: 16, thermalState: "ernst", spokenAudioCheckCompleted: true)
            ),
            ["thermalState:ernst"]
        )
        XCTAssertEqual(
            RecordingAdmission.recordingBlockers(
                readiness: readiness,
                runtimeStatus: CaptureRuntimeStatus(batteryPercent: 16, thermalState: "erhöht", spokenAudioCheckCompleted: true)
            ),
            []
        )
    }

    func testEffectiveOperatorFallbacks() throws {
        let fromGrant = try evaluate(session: authorizedSession(), operatorPseudonym: "  ").get()
        XCTAssertEqual(fromGrant.decision.operatorPseudonym, "group")
        let trimmed = try evaluate(session: authorizedSession(), operatorPseudonym: " op2 ").get()
        XCTAssertEqual(trimmed.decision.operatorPseudonym, "op2")
    }

    func testCheckOrderPrefersAuthorizationOverLaterRefusals() {
        var session = CaptureSession()
        session.recordingRelativePath = "Recordings/take.mp4"
        assertRefusal(
            evaluate(session: session, runtimeStatus: CaptureRuntimeStatus(), overrideReason: ""),
            .authorizationMissing
        )
    }

    // MARK: - Helpers

    private func readyValues() -> SessionReadiness.Values {
        var values = SessionReadiness.Values()
        values.canRecord = true
        return values
    }

    private func draft(expiresAt: Date?) -> ConsentGrantDraft {
        ConsentGrantDraft(
            scopes: [.collection, .localReflection], documentIdentifier: "d",
            documentVersion: "1", participantGroupPseudonym: "group", expiresAt: expiresAt
        )
    }

    private func authorizedSession() -> CaptureSession {
        var session = CaptureSession()
        session.replaceConsentGrants(with: draft(expiresAt: nil), at: now.addingTimeInterval(-100))
        return session
    }

    private func evaluate(
        session: CaptureSession,
        readiness: SessionReadiness? = nil,
        runtimeStatus: CaptureRuntimeStatus = CaptureRuntimeStatus(spokenAudioCheckCompleted: true),
        overrideReason: String = "",
        operatorPseudonym: String = "op"
    ) -> Result<RecordingAdmission.Admission, RecordingAdmission.Refusal> {
        RecordingAdmission.evaluate(
            session: session,
            readiness: readiness ?? SessionReadiness(readyValues()),
            runtimeStatus: runtimeStatus,
            overrideReason: overrideReason,
            operatorPseudonym: operatorPseudonym,
            operatorAuthenticationMethod: "device-owner",
            at: now
        )
    }

    private func assertRefusal(
        _ result: Result<RecordingAdmission.Admission, RecordingAdmission.Refusal>,
        _ expected: RecordingAdmission.Refusal,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard case .failure(let refusal) = result else {
            return XCTFail("Expected refusal \(expected)", file: file, line: line)
        }
        XCTAssertEqual(refusal, expected, file: file, line: line)
    }
}
