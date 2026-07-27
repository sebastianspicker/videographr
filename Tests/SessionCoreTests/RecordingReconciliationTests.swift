import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif

extension SessionCoreTests {
    func testSessionStoreReconciliationRelinksPromotedCanonicalRecording() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-promoted")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "promoted before metadata link"
    return values
}())
        try store.save(session)
        let canonicalURL = try store.prepareRecordingURL(for: session)
        let movieData = Data("promoted movie".utf8)
        try movieData.write(to: canonicalURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.relinkedSessionIDs, [session.id])
        XCTAssertTrue(report.removedStagingFileNames.isEmpty)
        XCTAssertTrue(report.alreadyLinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertEqual(try store.load(id: session.id)?.recordingRelativePath, canonicalURL.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: canonicalURL), movieData)
#if os(macOS)
        XCTAssertTrue(store.hasBackupExclusionMarker(on: canonicalURL))
#else
        let values = try canonicalURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
#endif
    }

    func testSessionStoreReconciliationPreservesPromotedOpenTakeForRecovery() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-open-take")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }

        for lifecycleState in [
            CaptureTakeLifecycleState.prepared,
            .recording,
            .completionUnknown
        ] {
            let session = testTakeSession(lifecycleState: lifecycleState)
            try fixture.store.save(session)
            let canonicalURL = try fixture.store.prepareRecordingURL(for: session)
            try Data("promoted open movie".utf8).write(to: canonicalURL)

            let report = try fixture.store.reconcileRecordingArtifacts()

            XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
            XCTAssertTrue(report.alreadyLinkedSessionIDs.isEmpty)
            XCTAssertTrue(report.diagnostics.contains(RecordingArtifactDiagnostic(
                fileName: canonicalURL.lastPathComponent,
                reason: .captureFinalizationPending
            )))
            let recovered = try XCTUnwrap(fixture.store.load(id: session.id))
            XCTAssertNil(recovered.recordingRelativePath)
            XCTAssertEqual(recovered.mediaAssets.map(\.id), session.mediaAssets.map(\.id))
            XCTAssertEqual(recovered.mediaAssets.map(\.relativePath), session.mediaAssets.map(\.relativePath))
            XCTAssertEqual(recovered.takeManifests.first?.effectiveLifecycleState, .completionUnknown)
            XCTAssertTrue(FileManager.default.fileExists(atPath: canonicalURL.path))
        }
    }

    func testSessionStoreReconciliationRollsBackCanonicalFileAfterPersistedTakeFailure() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-failed-take")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }

        var session = testTakeSession(lifecycleState: .failed, includesAsset: false)
        session.recordingRelativePath = "\(session.id.uuidString).mp4"
        try fixture.store.save(session)
        let canonicalURL = try fixture.store.prepareRecordingURL(for: session)
        try Data("rollback artifact".utf8).write(to: canonicalURL)

        let report = try fixture.store.reconcileRecordingArtifacts()

        XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.alreadyLinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
        let recovered = try XCTUnwrap(fixture.store.load(id: session.id))
        XCTAssertNil(recovered.recordingRelativePath)
        XCTAssertTrue(recovered.mediaAssets.isEmpty)
        XCTAssertEqual(recovered.takeManifests.first?.effectiveLifecycleState, .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: canonicalURL.path))
    }

    func testSessionStoreReconciliationRelinksPromotedFinalizedTake() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-finalized-take")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }

        let session = testTakeSession(lifecycleState: .finalized)
        try fixture.store.save(session)
        let canonicalURL = try fixture.store.prepareRecordingURL(for: session)
        try Data("finalized movie".utf8).write(to: canonicalURL)

        let report = try fixture.store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.relinkedSessionIDs, [session.id])
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertEqual(try fixture.store.load(id: session.id)?.recordingRelativePath, canonicalURL.lastPathComponent)
    }

    func testSessionStoreReconciliationPreservesAmbiguousCanonicalRecovery() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-ambiguous-take")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }

        let session = testTakeSession(lifecycleState: .prepared, includesAsset: false)
        try fixture.store.save(session)
        let canonicalURL = try fixture.store.prepareRecordingURL(for: session)
        try Data("ambiguous artifact".utf8).write(to: canonicalURL)

        let report = try fixture.store.reconcileRecordingArtifacts()

        XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
        XCTAssertEqual(report.diagnostics, [RecordingArtifactDiagnostic(
            fileName: canonicalURL.lastPathComponent,
            reason: .canonicalRecoveryAmbiguous
        )])
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonicalURL.path))
        XCTAssertNil(try fixture.store.load(id: session.id)?.recordingRelativePath)
    }

    func testSessionStoreReconciliationRollsBackMetadataWhenPolicyVerificationFails() throws{
        try sessionStoreReconciliationRollsBackMetadataWhenPolicyVerificationFailsAssertions()
    }

    func testSessionStoreReconciliationLeavesAlreadyLinkedRecordingAndMetadataUnchanged() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-linked")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = testRecordingSession(id: sessionID, title: "already linked")
        try store.save(session)
        let metadataURL = dir.appendingPathComponent("\(sessionID.uuidString).json")
        let metadataData = try Data(contentsOf: metadataURL)
        let recordingURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        let movieData = Data("existing movie".utf8)
        try movieData.write(to: recordingURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.alreadyLinkedSessionIDs, [sessionID])
        XCTAssertTrue(report.removedStagingFileNames.isEmpty)
        XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataData)
        XCTAssertEqual(try Data(contentsOf: recordingURL), movieData)
#if os(macOS)
        XCTAssertTrue(store.hasBackupExclusionMarker(on: recordingURL))
#else
        let values = try recordingURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
#endif
    }

    func testSessionStoreReconciliationDiagnosesCanonicalMediaWithoutValidMetadata() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-orphans")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let missingSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "missing metadata"
    return values
}())
        let invalidSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "invalid metadata"
    return values
}())
        let missingURL = try store.prepareRecordingURL(for: missingSession)
        let invalidURL = try store.prepareRecordingURL(for: invalidSession)
        let missingData = Data("orphan movie".utf8)
        let invalidData = Data("invalid-metadata movie".utf8)
        try missingData.write(to: missingURL)
        try invalidData.write(to: invalidURL)
        let invalidMetadataURL = dir.appendingPathComponent("\(invalidSession.id.uuidString).json")
        let invalidMetadataData = Data("not json".utf8)
        try invalidMetadataData.write(to: invalidMetadataURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(Set(report.diagnostics), Set([
            RecordingArtifactDiagnostic(
                fileName: missingURL.lastPathComponent,
                reason: .sessionMetadataMissing
            ),
            RecordingArtifactDiagnostic(
                fileName: invalidURL.lastPathComponent,
                reason: .sessionMetadataInvalid
            )
        ]))
        XCTAssertTrue(report.removedStagingFileNames.isEmpty)
        XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.alreadyLinkedSessionIDs.isEmpty)
        XCTAssertEqual(try Data(contentsOf: missingURL), missingData)
        XCTAssertEqual(try Data(contentsOf: invalidURL), invalidData)
        XCTAssertEqual(try Data(contentsOf: invalidMetadataURL), invalidMetadataData)
    }

    func testSessionStoreReconciliationAndCleanupRejectLinksAndOutsidePaths() throws{
        try sessionStoreReconciliationAndCleanupRejectLinksAndOutsidePathsAssertions()
    }

}


private let sessionStoreReconciliationRollsBackMetadataWhenPolicyVerificationFailsAssertions: @Sendable () throws -> Void = {
        let dir = testTemporaryDirectory(named: "uv-store-reconcile-policy-rollback")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let baselineStore = testSessionStore(rootDirectory: dir)
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "relink policy rollback"
    return values
}())
        try baselineStore.save(session)
        let metadataURL = dir.appendingPathComponent("\(session.id.uuidString).json")
        let metadataData = try Data(contentsOf: metadataURL)
        let canonicalURL = try baselineStore.prepareRecordingURL(for: session)
        let movieData = Data("promoted movie".utf8)
        try movieData.write(to: canonicalURL)

        let lock = NSLock()
        var failuresRemaining = 1
        let failingStore = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = dir
    values.policyVerificationHook = { url in
            guard url.pathExtension == "json" else { return }
            lock.lock()
            defer { lock.unlock() }
            if failuresRemaining > 0 {
                failuresRemaining -= 1
                throw CocoaError(.fileWriteUnknown)
            }
        }
    return values
}())
        let failedReport = try failingStore.reconcileRecordingArtifacts()

        XCTAssertTrue(failedReport.relinkedSessionIDs.isEmpty)
        XCTAssertEqual(failedReport.diagnostics, [
            RecordingArtifactDiagnostic(
                fileName: canonicalURL.lastPathComponent,
                reason: .sessionMetadataUpdateFailed
            )
        ])
        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataData)
        XCTAssertNil(try baselineStore.load(id: session.id)?.recordingRelativePath)
        XCTAssertEqual(try Data(contentsOf: canonicalURL), movieData)

        let recoveredReport = try baselineStore.reconcileRecordingArtifacts()
        XCTAssertEqual(recoveredReport.relinkedSessionIDs, [session.id])
        XCTAssertEqual(try baselineStore.load(id: session.id)?.recordingRelativePath, canonicalURL.lastPathComponent)
    }

private let sessionStoreReconciliationAndCleanupRejectLinksAndOutsidePathsAssertions: @Sendable () throws -> Void = {
        let outsideData = Data("outside target".utf8)
        let fixture = try testNestedStoreFixture(named: "uv-store-reconcile-links", outsideData: outsideData)
        let container = fixture.container
        let rootDirectory = fixture.rootDirectory
        let outsideTarget = fixture.outsideTarget
        defer { try? FileManager.default.removeItem(at: container) }

        let store = fixture.store
        let canonicalSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "canonical link"
    return values
}())
        try store.save(canonicalSession)
        let canonicalLink = try store.prepareRecordingURL(for: canonicalSession)
        try FileManager.default.createSymbolicLink(at: canonicalLink, withDestinationURL: outsideTarget)
        let stagedLink = try store.prepareStagedRecordingURL(
            for: canonicalSession.id,
            transactionID: UUID()
        )
        try FileManager.default.createSymbolicLink(at: stagedLink, withDestinationURL: outsideTarget)
        let unrelatedURL = try store.recordingsDirectory().appendingPathComponent("family-video.mp4")
        try Data("unrelated".utf8).write(to: unrelatedURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(Set(report.diagnostics), Set([
            RecordingArtifactDiagnostic(
                fileName: canonicalLink.lastPathComponent,
                reason: .artifactIsSymbolicLink
            ),
            RecordingArtifactDiagnostic(
                fileName: stagedLink.lastPathComponent,
                reason: .artifactIsSymbolicLink
            )
        ]))
        XCTAssertNil(try store.load(id: canonicalSession.id)?.recordingRelativePath)
        XCTAssertEqual(try Data(contentsOf: outsideTarget), outsideData)
        XCTAssertEqual(try Data(contentsOf: unrelatedURL), Data("unrelated".utf8))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: canonicalLink.path))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: stagedLink.path))

        XCTAssertThrowsError(try store.discardStagedRecording(at: stagedLink)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        let outsideReservedURL = container.appendingPathComponent(stagedLink.lastPathComponent)
        try Data("outside reserved".utf8).write(to: outsideReservedURL)
        XCTAssertThrowsError(try store.discardStagedRecording(at: outsideReservedURL)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingOutsideStore)
        }
        XCTAssertEqual(try Data(contentsOf: outsideReservedURL), Data("outside reserved".utf8))
    }
