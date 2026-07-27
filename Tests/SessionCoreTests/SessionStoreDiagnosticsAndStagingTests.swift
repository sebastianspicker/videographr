import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif
#if os(macOS)
#endif

extension SessionCoreTests {
    func testSessionStoreListSessionsPropagatesDirectoryEnumerationError() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("uv-store-file-root-\(UUID().uuidString)")
        try Data("not a directory".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = testSessionStore(rootDirectory: fileURL)
        XCTAssertThrowsError(try store.listSessions())
        XCTAssertThrowsError(try store.listSessionsWithDiagnostics())
        XCTAssertThrowsError(try store.prepareRecordingURL(for: CaptureSession()))
    }

    func testSessionStoreDiagnosticsPreserveValidSessionsAndCorruptFiles() throws {
        let fixture = try testStoreFixture(named: "uv-store-diagnostics")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "valid"
    return values
}())
        try store.save(session)
        let corruptURL = dir.appendingPathComponent("corrupt.json")
        try Data("not JSON".utf8).write(to: corruptURL)

        let listing = try store.listSessionsWithDiagnostics()
        XCTAssertEqual(listing.sessions.map(\.id), [session.id])
        XCTAssertEqual(listing.failures.map(\.fileName), ["corrupt.json"])
        XCTAssertFalse(listing.failures[0].errorDescription.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
        XCTAssertEqual(try store.listSessions().map(\.id), [session.id])
    }

    func testSessionStoreDeleteSessionAndMediaIsIdempotent() throws {
        let fixture = try testStoreFixture(named: "uv-store-delete")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = testRecordingSession(id: sessionID, title: "delete")
        try store.save(session)
        let recordingURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        try Data("movie".utf8).write(to: recordingURL)

        try store.deleteSessionAndMedia(id: session.id)
        XCTAssertNil(try store.load(id: session.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordingURL.path))
        XCTAssertNoThrow(try store.deleteSessionAndMedia(id: session.id))
    }

    func testSessionStoreDeleteRemovesPromotedCanonicalMovieBeforeMetadataLink() throws {
        let fixture = try testStoreFixture(named: "uv-store-delete-unlinked")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "promoted but not linked"
    return values
}())
        try store.save(session)
        let canonicalURL = try store.prepareRecordingURL(for: session)
        try Data("promoted movie".utf8).write(to: canonicalURL)

        try store.deleteSessionAndMedia(id: session.id)

        XCTAssertNil(try store.load(id: session.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: canonicalURL.path))
    }

    func testSessionStoreDeleteRejectsUnlinkedCanonicalLinkAndDirectory() throws {
        let outsideData = Data("outside movie".utf8)
        let fixture = try testNestedStoreFixture(named: "uv-store-delete-unlinked-invalid", outsideData: outsideData)
        let container = fixture.container
        let rootDirectory = fixture.rootDirectory
        let outsideTarget = fixture.outsideTarget
        defer { try? FileManager.default.removeItem(at: container) }

        let store = fixture.store
        let linkedSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "unlinked canonical symlink"
    return values
}())
        try store.save(linkedSession)
        let linkedMetadataURL = rootDirectory.appendingPathComponent("\(linkedSession.id.uuidString).json")
        let linkedCanonicalURL = try store.prepareRecordingURL(for: linkedSession)
        try FileManager.default.createSymbolicLink(at: linkedCanonicalURL, withDestinationURL: outsideTarget)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: linkedSession.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: linkedMetadataURL.path))
        XCTAssertEqual(try Data(contentsOf: outsideTarget), outsideData)

        let directorySession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "unlinked canonical directory"
    return values
}())
        try store.save(directorySession)
        let directoryMetadataURL = rootDirectory.appendingPathComponent("\(directorySession.id.uuidString).json")
        let canonicalDirectoryURL = try store.prepareRecordingURL(for: directorySession)
        try FileManager.default.createDirectory(at: canonicalDirectoryURL, withIntermediateDirectories: false)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: directorySession.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingArtifactIsNotRegularFile)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryMetadataURL.path))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonicalDirectoryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testSessionStoreSecuresHiddenStagedRecordingBeforePromotion() throws {
        let fixture = try testStoreFixture(named: "uv-store-staged-recording")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessionID = UUID()
        let transactionID = UUID()
        let stagedURL = try store.prepareStagedRecordingURL(
            for: sessionID,
            transactionID: transactionID
        )
        XCTAssertEqual(
            stagedURL.lastPathComponent,
            ".videographr-\(sessionID.uuidString)-\(transactionID.uuidString).mp4"
        )
        try Data("staged movie".utf8).write(to: stagedURL)

        XCTAssertNoThrow(try store.secureFinalizedRecording(at: stagedURL))
        XCTAssertEqual(try Data(contentsOf: stagedURL), Data("staged movie".utf8))
#if os(macOS)
        XCTAssertTrue(store.hasBackupExclusionMarker(on: stagedURL))
#else
        let values = try stagedURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
#endif

        let malformedURL = try store.recordingsDirectory()
            .appendingPathComponent(".videographr-\(sessionID.uuidString).mp4")
        let malformedData = Data("malformed stage".utf8)
        try malformedData.write(to: malformedURL)
        XCTAssertThrowsError(try store.secureFinalizedRecording(at: malformedURL)) { error in
            XCTAssertEqual(error as? SessionStoreError, .invalidReservedStagingFileName)
        }
        XCTAssertEqual(try Data(contentsOf: malformedURL), malformedData)
    }

    func testSessionStoreReconciliationRemovesOnlyExactAbandonedStagingFiles() throws {
        let fixture = try testStoreFixture(named: "uv-store-reconcile-staged")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let stagedURL = try store.prepareStagedRecordingURL(
            for: UUID(),
            transactionID: UUID()
        )
        let malformedStagingURL = try store.recordingsDirectory()
            .appendingPathComponent(".videographr-\(UUID().uuidString).mp4")
        let malformedUnicodeBody = String(repeating: "💥", count: 18) + "x"
        XCTAssertEqual(malformedUnicodeBody.utf8.count, 73)
        let malformedUnicodeURL = try store.recordingsDirectory()
            .appendingPathComponent(".videographr-\(malformedUnicodeBody).mp4")
        let unrelatedURL = try store.recordingsDirectory().appendingPathComponent("notes.txt")
        try Data("abandoned".utf8).write(to: stagedURL)
        try Data("malformed but retained".utf8).write(to: malformedStagingURL)
        try Data("unicode retained".utf8).write(to: malformedUnicodeURL)
        try Data("unrelated".utf8).write(to: unrelatedURL)

        let report = try store.reconcileRecordingArtifacts()

        XCTAssertEqual(report.removedStagingFileNames, [stagedURL.lastPathComponent])
        XCTAssertTrue(report.relinkedSessionIDs.isEmpty)
        XCTAssertTrue(report.alreadyLinkedSessionIDs.isEmpty)
        XCTAssertEqual(Set(report.diagnostics), Set([
            RecordingArtifactDiagnostic(
                fileName: malformedStagingURL.lastPathComponent,
                reason: .invalidReservedStagingName
            ),
            RecordingArtifactDiagnostic(
                fileName: malformedUnicodeURL.lastPathComponent,
                reason: .invalidReservedStagingName
            )
        ]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
        XCTAssertEqual(try Data(contentsOf: malformedStagingURL), Data("malformed but retained".utf8))
        XCTAssertEqual(try Data(contentsOf: malformedUnicodeURL), Data("unicode retained".utf8))
        XCTAssertEqual(try Data(contentsOf: unrelatedURL), Data("unrelated".utf8))

        let cleanupURL = try store.prepareStagedRecordingURL(for: UUID(), transactionID: UUID())
        try Data("explicit cleanup".utf8).write(to: cleanupURL)
        XCTAssertNoThrow(try store.discardStagedRecording(at: cleanupURL))
        XCTAssertNoThrow(try store.discardStagedRecording(at: cleanupURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cleanupURL.path))
    }

}
