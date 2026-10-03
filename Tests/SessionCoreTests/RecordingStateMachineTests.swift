import XCTest
@testable import SessionCore

final class RecordingStateMachineTests: XCTestCase {
    func testPrepareInstallsCaptureOwnedValuesAtomically() {
        var session = CaptureSession()
        let initialUpdatedAt = session.updatedAt
        let preparedAt = Date(timeIntervalSinceReferenceDate: 10)
        let mutation = makePreparedMutation(sessionID: session.id, preparedAt: preparedAt)

        XCTAssertTrue(RecordingStateMachine.prepare(mutation, in: &session))
        XCTAssertEqual(session.captureDecisions, [mutation.decision])
        XCTAssertEqual(session.mediaAssets, [mutation.asset])
        XCTAssertEqual(session.takeManifests, [mutation.manifest])
        XCTAssertEqual(session.buildProvenance, mutation.provenance)
        XCTAssertEqual(session.updatedAt, max(initialUpdatedAt, preparedAt))
        XCTAssertFalse(RecordingStateMachine.prepare(mutation, in: &session))
        XCTAssertEqual(session.takeManifests.count, 1)
    }

    func testBeganAndCompletionUnknownIgnoreStaleAndTerminalTransactions() {
        var session = sessionWithPreparedTake()
        let transactionID = session.takeManifests[0].id
        let beganAt = Date(timeIntervalSinceReferenceDate: 20)

        XCTAssertFalse(RecordingStateMachine.began(transactionID: UUID(), in: &session, at: beganAt))
        XCTAssertTrue(RecordingStateMachine.began(transactionID: transactionID, in: &session, at: beganAt))
        XCTAssertEqual(session.takeManifests[0].effectiveLifecycleState, .recording)
        XCTAssertEqual(session.updatedAt, beganAt)
        XCTAssertFalse(RecordingStateMachine.began(transactionID: transactionID, in: &session, at: beganAt))

        let unknownAt = Date(timeIntervalSinceReferenceDate: 30)
        XCTAssertTrue(RecordingStateMachine.completionUnknown(transactionID: transactionID, in: &session, at: unknownAt))
        XCTAssertEqual(session.takeManifests[0].effectiveLifecycleState, .completionUnknown)
        XCTAssertFalse(RecordingStateMachine.completionUnknown(transactionID: transactionID, in: &session, at: unknownAt))

        XCTAssertTrue(RecordingStateMachine.failed(transactionID: transactionID, reason: "cancelled", in: &session, at: unknownAt))
        XCTAssertFalse(RecordingStateMachine.began(transactionID: transactionID, in: &session, at: unknownAt))
        XCTAssertFalse(RecordingStateMachine.completionUnknown(transactionID: transactionID, in: &session, at: unknownAt))
    }

    func testFinalizedWritesMetadataAndClosesTimeline() {
        var session = sessionWithPreparedTake()
        let initialUpdatedAt = session.updatedAt
        let transactionID = session.takeManifests[0].id
        let endedAt = Date(timeIntervalSinceReferenceDate: 40)
        let metadata = FinalizedMediaMetadata(
            durationMilliseconds: 1_234,
            sha256: "digest",
            codec: "avc1",
            resolution: "1920×1080",
            frameRate: 29.97
        )

        XCTAssertTrue(RecordingStateMachine.finalized(
            transactionID: transactionID,
            metadata: metadata,
            finalRoute: "builtInMic",
            canonicalFileName: "take.mp4",
            in: &session,
            at: endedAt
        ))
        XCTAssertEqual(session.recordingRelativePath, "take.mp4")
        XCTAssertEqual(session.mediaAssets[0].durationMilliseconds, 1_234)
        XCTAssertEqual(session.mediaAssets[0].sha256, "digest")
        XCTAssertEqual(session.mediaAssets[0].codec, "avc1")
        XCTAssertEqual(session.mediaAssets[0].resolution, "1920×1080")
        XCTAssertEqual(session.mediaAssets[0].frameRate, 29.97)
        XCTAssertEqual(session.takeManifests[0].effectiveLifecycleState, .finalized)
        XCTAssertEqual(session.takeManifests[0].endedAt, endedAt)
        XCTAssertEqual(session.takeManifests[0].finalizedAt, endedAt)
        XCTAssertEqual(session.takeManifests[0].durationMilliseconds, 1_234)
        XCTAssertEqual(session.takeManifests[0].cameraConfiguration["actualCodec"], "avc1")
        XCTAssertEqual(session.takeManifests[0].cameraConfiguration["actualResolution"], "1920×1080")
        XCTAssertEqual(session.takeManifests[0].cameraConfiguration["actualFrameRate"], "29.97")
        XCTAssertEqual(session.takeManifests[0].audioConfiguration["finalRoute"], "builtInMic")
        XCTAssertEqual(session.updatedAt, max(initialUpdatedAt, endedAt))
        XCTAssertFalse(RecordingStateMachine.finalized(
            transactionID: UUID(),
            metadata: metadata,
            finalRoute: "stale",
            canonicalFileName: "stale.mp4",
            in: &session,
            at: endedAt
        ))
        XCTAssertFalse(RecordingStateMachine.finalized(
            transactionID: transactionID,
            metadata: metadata,
            finalRoute: "different",
            canonicalFileName: "other.mp4",
            in: &session,
            at: Date(timeIntervalSinceReferenceDate: 50)
        ))
        XCTAssertFalse(RecordingStateMachine.failed(
            transactionID: transactionID,
            reason: "late failure",
            in: &session,
            at: endedAt
        ))
    }

    func testFailedRemovesOnlyItsAssetAndIsTerminallyIdempotent() {
        var session = sessionWithPreparedTake()
        let initialUpdatedAt = session.updatedAt
        let transactionID = session.takeManifests[0].id
        let assetID = session.mediaAssets[0].id
        session.recordingRelativePath = session.mediaAssets[0].relativePath
        let failedAt = Date(timeIntervalSinceReferenceDate: 60)

        XCTAssertTrue(RecordingStateMachine.failed(
            transactionID: transactionID,
            reason: "capture failure",
            in: &session,
            at: failedAt
        ))
        XCTAssertEqual(session.takeManifests[0].effectiveLifecycleState, .failed)
        XCTAssertEqual(session.takeManifests[0].failureReason, "capture failure")
        XCTAssertEqual(session.takeManifests[0].endedAt, failedAt)
        XCTAssertFalse(session.mediaAssets.contains(where: { $0.id == assetID }))
        XCTAssertNil(session.recordingRelativePath)
        XCTAssertEqual(session.updatedAt, max(initialUpdatedAt, failedAt))
        XCTAssertFalse(RecordingStateMachine.failed(
            transactionID: transactionID,
            reason: "later failure",
            in: &session,
            at: Date(timeIntervalSinceReferenceDate: 70)
        ))
        XCTAssertFalse(RecordingStateMachine.failed(
            transactionID: UUID(),
            reason: "stale",
            in: &session,
            at: failedAt
        ))
    }

    private func sessionWithPreparedTake() -> CaptureSession {
        var session = CaptureSession()
        XCTAssertTrue(RecordingStateMachine.prepare(
            makePreparedMutation(sessionID: session.id, preparedAt: Date(timeIntervalSinceReferenceDate: 1)),
            in: &session
        ))
        return session
    }

    private func makePreparedMutation(sessionID: UUID, preparedAt: Date) -> PreparedRecordingMutation {
        var assetValues = SessionMediaAsset.Values()
        assetValues.id = UUID()
        assetValues.relativePath = "take.mp4"
        let asset = SessionMediaAsset(assetValues)
        var manifestValues = CaptureTakeManifest.Values()
        manifestValues.id = UUID()
        manifestValues.sessionID = sessionID
        manifestValues.mediaAssetID = asset.id
        manifestValues.startedAt = preparedAt
        manifestValues.lifecycleState = .prepared
        let manifest = CaptureTakeManifest(manifestValues)
        var provenanceValues = BuildProvenance.Values()
        provenanceValues.semanticVersion = "1.0"
        let provenance = BuildProvenance(provenanceValues)
        return PreparedRecordingMutation(
            transactionID: manifest.id,
            asset: asset,
            decision: CaptureDecision(),
            manifest: manifest,
            provenance: provenance,
            preparedAt: preparedAt
        )
    }
}
