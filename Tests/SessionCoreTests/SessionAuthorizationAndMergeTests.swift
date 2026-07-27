import Foundation
import XCTest
@testable import SessionCore

extension SessionIntegrityTests {
    func testExperimentalCaptureSnapshotRequiresResearchAuthority() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = ResearchProtocolReference(
                protocolIdentifier: "study",
                oversightReference: "oversight",
                expiresAt: now.addingTimeInterval(600),
                disclosureAcknowledgedAt: now
            )
    values.consentGrants = [ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection]
    values.documentIdentifier = "capture"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())]
    return values
}())
        XCTAssertNil(session.captureAuthorizationSnapshot(at: now))
        session.consentGrants.append(testResearchConsentGrant(at: now))
        let snapshot = session.captureAuthorizationSnapshot(at: now)
        XCTAssertEqual(
            snapshot?.requiredScopes,
            [.collection, .localReflection, .researchProcessing]
        )
        let frozen = try XCTUnwrap(snapshot)
        session.experimentalProtocol?.protocolIdentifier = "replacement"
        XCTAssertFalse(session.authorizes(frozen, at: now.addingTimeInterval(1)))
    }

    func testCaptureAuthorizationRejectsModeEscalationAndMalformedSnapshots() throws{
        try captureAuthorizationRejectsModeEscalationAndMalformedSnapshotsAssertions()
    }

    func testSecondaryUseIndependentlyGatesStudyPackageExport() {
        let grant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .externalSharing]
    values.documentIdentifier = "sharing"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [grant]
    return values
}())
        XCTAssertFalse(session.canExportExternally)
        XCTAssertTrue(StudyExportProjection.make(from: session).requiredScopes.contains(.secondaryUse))

        session.consentGrants.append(ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.secondaryUse]
    values.documentIdentifier = "secondary"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    return values
}()))
        XCTAssertTrue(session.canExportExternally)
    }

    func testExportOutboxTransitionsWithoutReauthorization() {
        let attemptedAt = Date(timeIntervalSince1970: 30_000)
        var event = ExportEvent({
    var values = ExportEvent.Values()
    values.exportedAt = attemptedAt
    values.operatorPseudonym = "operator"
    values.includedScopes = [.collection, .secondaryUse, .externalSharing]
    values.fileDigests = ["session.json": "digest"]
    values.status = .attempted
    return values
}())
        XCTAssertEqual(event.status, .attempted)
        XCTAssertNil(event.completedAt)

        let completedAt = attemptedAt.addingTimeInterval(10)
        event.finish(
            status: .completed,
            shareActivityIdentifier: "com.apple.UIKit.activity.Mail",
            failureDescription: nil,
            at: completedAt
        )
        XCTAssertEqual(event.status, .completed)
        XCTAssertEqual(event.completedAt, completedAt)
        XCTAssertEqual(event.shareActivityIdentifier, "com.apple.UIKit.activity.Mail")
    }

    func testDraftMergePreservesRuntimeOwnedFields() {
        let media = SessionMediaAsset({
    var values = SessionMediaAsset.Values()
    values.role = .ownRecorded
    values.relativePath = "fixture.mp4"
    return values
}())
        let event = ExportEvent({
    var values = ExportEvent.Values()
    values.operatorPseudonym = "operator"
    values.includedScopes = [.collection, .secondaryUse, .externalSharing]
    values.fileDigests = [:]
    return values
}())
        var persisted = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "persisted"
    values.mediaAssets = [media]
    values.exportEvents = [event]
    return values
}())
        var draft = persisted
        draft.title = "edited draft"
        draft.mediaAssets = []
        draft.exportEvents = []

        persisted.mergeDraftFields(from: draft)

        XCTAssertEqual(persisted.title, "edited draft")
        XCTAssertEqual(persisted.mediaAssets, [media])
        XCTAssertEqual(persisted.exportEvents, [event])
    }

    func testAbandonedCompletionUnknownTakeFailureRetainsDecisionAndAllowsRetry(){
        abandonedCompletionUnknownTakeFailureRetainsDecisionAndAllowsRetryAssertions()
    }

    func testActorDraftMergeCannotOverwriteConcurrentRuntimeMutation() async throws {
        let root = testTemporaryDirectory(named: "VideographrIntegrity")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = testSessionStore(rootDirectory: root)
        let actor = SessionStoreAsync(store: store)
        let original = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "original"
    return values
}())
        try store.save(original)
        var staleDraft = original
        staleDraft.title = "draft survives"
        let event = ExportEvent({
    var values = ExportEvent.Values()
    values.operatorPseudonym = "operator"
    values.includedScopes = [.collection, .secondaryUse, .externalSharing]
    values.fileDigests = [:]
    return values
}())

        _ = try await actor.mutateSession(id: original.id) { current in
            current.exportEvents.append(event)
        }
        let merged = try await actor.mergeDraftSession(staleDraft)

        XCTAssertEqual(merged.title, "draft survives")
        XCTAssertEqual(merged.exportEvents.map(\.id), [event.id])
        XCTAssertEqual(merged.exportEvents.first?.status, .completed)
    }
}


private let captureAuthorizationRejectsModeEscalationAndMalformedSnapshotsAssertions: @Sendable () throws -> Void = {
        let now = Date(timeIntervalSince1970: 25_000)
        let captureGrant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection]
    values.documentIdentifier = "capture"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    values.grantedAt = now
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.consentGrants = [captureGrant]
    return values
}())
        let evidenceSafeSnapshot = try XCTUnwrap(session.captureAuthorizationSnapshot(at: now))
        XCTAssertTrue(session.authorizes(evidenceSafeSnapshot, at: now))

        session.operatingMode = .experimentalResearch
        session.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "escalated-study",
            oversightReference: "oversight",
            expiresAt: now.addingTimeInterval(600),
            disclosureAcknowledgedAt: now
        )
        session.consentGrants.append(testResearchConsentGrant(at: now))
        XCTAssertFalse(
            session.authorizes(evidenceSafeSnapshot, at: now),
            "Changing to experimental mode must invalidate a take prepared without research authority."
        )

        session.operatingMode = .evidenceSafe
        session.experimentalProtocol = nil
        let emptySnapshot = CaptureAuthorizationSnapshot({
    var values = CaptureAuthorizationSnapshot.Values()
    values.requiredScopes = []
    values.grantIDs = []
    values.effectiveExpiresAt = nil
    values.preparedAt = now
    return values
}())
        XCTAssertFalse(session.authorizes(emptySnapshot, at: now))
        let futureSnapshot = CaptureAuthorizationSnapshot({
    var values = CaptureAuthorizationSnapshot.Values()
    values.requiredScopes = [.collection, .localReflection]
    values.grantIDs = [captureGrant.id]
    values.effectiveExpiresAt = nil
    values.preparedAt = now.addingTimeInterval(1)
    return values
}())
        XCTAssertFalse(session.authorizes(futureSnapshot, at: now))
    }

private let abandonedCompletionUnknownTakeFailureRetainsDecisionAndAllowsRetryAssertions: @Sendable () -> Void = {
        let sessionID = UUID()
        let asset = SessionMediaAsset({
    var values = SessionMediaAsset.Values()
    values.role = .ownRecorded
    values.relativePath = "\(sessionID.uuidString).mp4"
    return values
}())
        let decision = CaptureDecision({
    var values = CaptureDecision.Values()
    values.blockers = ["audio"]
    values.overrideReason = "documented"
    values.operatorPseudonym = "operator"
    values.operatingMode = .evidenceSafe
    values.operatorAuthenticationMethod = "deviceOwnerAuthentication"
    return values
}())
        let manifest = CaptureTakeManifest({
    var values = CaptureTakeManifest.Values()
    values.sessionID = sessionID
    values.mediaAssetID = asset.id
    values.decision = decision
    values.provenance = BuildProvenance({
    var values = BuildProvenance.Values()
    values.semanticVersion = "1"
    values.buildNumber = "1"
    return values
}())
    values.deviceDescription = "device"
    values.operatingSystemVersion = "system"
    values.lifecycleState = .completionUnknown
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.recordingRelativePath = asset.relativePath
    values.mediaAssets = [asset]
    values.captureDecisions = [decision]
    values.takeManifests = [manifest]
    values.consentGrants = [ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection]
    values.documentIdentifier = "capture"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    return values
}())]
    return values
}())

        XCTAssertEqual(session.failAbandonedTakes(canonicalMediaAssetIDs: []), 1)
        XCTAssertEqual(session.takeManifests.first?.effectiveLifecycleState, .failed)
        XCTAssertTrue(session.mediaAssets.isEmpty)
        XCTAssertNil(session.recordingRelativePath)
        XCTAssertEqual(session.captureDecisions, [decision])
        XCTAssertTrue(session.canStartNewCapture)
    }
