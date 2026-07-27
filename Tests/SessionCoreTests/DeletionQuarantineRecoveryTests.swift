import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif

extension SessionCoreTests {
    func testSessionStoreReconciliationRestoresDeletionQuarantineAfterMoveCrash() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-delete-restore")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = testRecordingSession(id: sessionID, title: "delete interrupted after move")
        try store.save(session)
        let canonicalURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        let movieData = Data("quarantined movie".utf8)
        try movieData.write(to: canonicalURL)
        try store.secureFinalizedRecording(at: canonicalURL)
        let transactionID = UUID()
        let quarantineURL = canonicalURL.deletingLastPathComponent()
            .appendingPathComponent(".deleting-\(transactionID.uuidString)-\(sessionID.uuidString).mp4")
        try FileManager.default.moveItem(at: canonicalURL, to: quarantineURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.restoredQuarantineFileNames, [quarantineURL.lastPathComponent])
        XCTAssertTrue(report.removedQuarantineFileNames.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineURL.path))
        XCTAssertEqual(try Data(contentsOf: canonicalURL), movieData)
        XCTAssertEqual(try store.load(id: sessionID)?.recordingRelativePath, recordingName)
    }

    func testSessionStoreReconciliationRestoresAndLinksUnlinkedCanonicalDeletionQuarantine() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-unlinked-delete-restore")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "unlinked delete interrupted after move"
    return values
}())
        try store.save(session)
        let canonicalURL = try store.prepareRecordingURL(for: session)
        let movieData = Data("unlinked quarantined movie".utf8)
        try movieData.write(to: canonicalURL)
        try store.secureFinalizedRecording(at: canonicalURL)
        let quarantineURL = canonicalURL.deletingLastPathComponent()
            .appendingPathComponent(".deleting-\(UUID().uuidString)-\(session.id.uuidString).mp4")
        try FileManager.default.moveItem(at: canonicalURL, to: quarantineURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.restoredQuarantineFileNames, [quarantineURL.lastPathComponent])
        XCTAssertEqual(report.relinkedSessionIDs, [session.id])
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineURL.path))
        XCTAssertEqual(try Data(contentsOf: canonicalURL), movieData)
        XCTAssertEqual(try store.load(id: session.id)?.recordingRelativePath, canonicalURL.lastPathComponent)
    }

    func testSessionStoreReconciliationRemovesDeletionQuarantineAfterMetadataDeleteCrash() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-delete-remove")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = testRecordingSession(id: sessionID, title: "delete interrupted after metadata removal")
        try store.save(session)
        let canonicalURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        try Data("quarantined movie".utf8).write(to: canonicalURL)
        let quarantineURL = canonicalURL.deletingLastPathComponent()
            .appendingPathComponent(".deleting-\(UUID().uuidString)-\(sessionID.uuidString).mp4")
        try FileManager.default.moveItem(at: canonicalURL, to: quarantineURL)
        let metadataURL = dir.appendingPathComponent("\(sessionID.uuidString).json")
        try FileManager.default.removeItem(at: metadataURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.removedQuarantineFileNames, [quarantineURL.lastPathComponent])
        XCTAssertTrue(report.restoredQuarantineFileNames.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: canonicalURL.path))
        XCTAssertNil(try store.load(id: sessionID))
    }

    func testSessionStoreReconciliationLeavesAmbiguousInvalidAndLinkedQuarantinesUntouched() throws {
        try sessionStoreReconciliationLeavesAmbiguousInvalidAndLinkedQuarantinesAssertions()
    }
}

private let sessionStoreReconciliationLeavesAmbiguousInvalidAndLinkedQuarantinesAssertions: @Sendable () throws -> Void = {
        let outsideData = Data("outside quarantine target".utf8)
        let fixture = try testNestedStoreFixture(named: "uv-store-reconcile-delete-invalid", outsideData: outsideData)
        let container = fixture.container
        let rootDirectory = fixture.rootDirectory
        let outsideTarget = fixture.outsideTarget
        defer { try? FileManager.default.removeItem(at: container) }

        let store = fixture.store
        let occupiedID = UUID()
        let occupiedName = "\(occupiedID.uuidString).mp4"
        let occupiedSession = CaptureSession({
    var values = CaptureSession.Values()
    values.id = occupiedID
    values.title = "occupied restore"
    values.recordingRelativePath = occupiedName
    return values
}())
        try store.save(occupiedSession)
        let recordingsDirectory = try store.recordingsDirectory()
        let occupiedCanonicalURL = recordingsDirectory.appendingPathComponent(occupiedName)
        let occupiedCanonicalData = Data("canonical wins".utf8)
        try occupiedCanonicalData.write(to: occupiedCanonicalURL)
        let occupiedQuarantineURL = recordingsDirectory
            .appendingPathComponent(".deleting-\(UUID().uuidString)-\(occupiedID.uuidString).mp4")
        let occupiedQuarantineData = Data("quarantine retained".utf8)
        try occupiedQuarantineData.write(to: occupiedQuarantineURL)

        let invalidID = UUID()
        let invalidMetadataURL = rootDirectory.appendingPathComponent("\(invalidID.uuidString).json")
        let invalidMetadataData = Data("not json".utf8)
        try invalidMetadataData.write(to: invalidMetadataURL)
        let invalidQuarantineURL = recordingsDirectory
            .appendingPathComponent(".deleting-\(UUID().uuidString)-\(invalidID.uuidString).mp4")
        let invalidQuarantineData = Data("invalid metadata quarantine".utf8)
        try invalidQuarantineData.write(to: invalidQuarantineURL)

        let linkedID = UUID()
        let linkedQuarantineURL = recordingsDirectory
            .appendingPathComponent(".deleting-\(UUID().uuidString)-\(linkedID.uuidString).mp4")
        try FileManager.default.createSymbolicLink(at: linkedQuarantineURL, withDestinationURL: outsideTarget)
        let malformedQuarantineURL = recordingsDirectory
            .appendingPathComponent(".deleting-\(UUID().uuidString).mp4")
        let malformedData = Data("malformed quarantine".utf8)
        try malformedData.write(to: malformedQuarantineURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(Set(report.diagnostics), Set([
            RecordingArtifactDiagnostic(
                fileName: occupiedQuarantineURL.lastPathComponent,
                reason: .canonicalRestoreDestinationOccupied
            ),
            RecordingArtifactDiagnostic(
                fileName: invalidQuarantineURL.lastPathComponent,
                reason: .sessionMetadataInvalid
            ),
            RecordingArtifactDiagnostic(
                fileName: linkedQuarantineURL.lastPathComponent,
                reason: .artifactIsSymbolicLink
            ),
            RecordingArtifactDiagnostic(
                fileName: malformedQuarantineURL.lastPathComponent,
                reason: .invalidDeletionQuarantineName
            )
        ]))
        XCTAssertEqual(try Data(contentsOf: occupiedCanonicalURL), occupiedCanonicalData)
        XCTAssertEqual(try Data(contentsOf: occupiedQuarantineURL), occupiedQuarantineData)
        XCTAssertEqual(try Data(contentsOf: invalidQuarantineURL), invalidQuarantineData)
        XCTAssertEqual(try Data(contentsOf: invalidMetadataURL), invalidMetadataData)
        XCTAssertEqual(try Data(contentsOf: malformedQuarantineURL), malformedData)
        XCTAssertEqual(try Data(contentsOf: outsideTarget), outsideData)
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: linkedQuarantineURL.path))
    }
