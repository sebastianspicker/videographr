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
    func testSessionStoreRejectsFilenameAndDecodedIdentifierMismatch() throws {
        let dir = testTemporaryDirectory(named: "uv-store-id-mismatch")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let requestedID = UUID()
        let decodedID = UUID()
        let decoded = CaptureSession({
    var values = CaptureSession.Values()
    values.id = decodedID
    values.title = "tampered id"
    values.recordingRelativePath = "\(decodedID.uuidString).mp4"
    return values
}())
        let metadataURL = try writeSessionFixture(decoded, to: dir, fileID: requestedID)
        let recordingsURL = try testSessionStore(rootDirectory: dir).recordingsDirectory()
        let decodedRecordingURL = recordingsURL.appendingPathComponent("\(decodedID.uuidString).mp4")
        try Data("movie".utf8).write(to: decodedRecordingURL)
        let store = testSessionStore(rootDirectory: dir)

        XCTAssertThrowsError(try store.load(id: requestedID)) { error in
            XCTAssertEqual(error as? SessionStoreError, .sessionIdentifierMismatch)
        }
        let listing = try store.listSessionsWithDiagnostics()
        XCTAssertTrue(listing.sessions.isEmpty)
        XCTAssertEqual(listing.failures.map(\.fileName), [metadataURL.lastPathComponent])
        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: requestedID)) { error in
            XCTAssertEqual(error as? SessionStoreError, .sessionIdentifierMismatch)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: decodedRecordingURL.path))
    }

    func testSessionStoreDiagnosticsRejectNoncanonicalUUIDMetadataFilename() throws {
        let dir = testTemporaryDirectory(named: "uv-store-noncanonical-id")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        guard let sessionID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE") else {
            return XCTFail("Invalid fixed UUID")
        }
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.title = "noncanonical filename"
    return values
}())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let noncanonicalURL = dir.appendingPathComponent("\(sessionID.uuidString.lowercased()).json")
        try encoder.encode(session).write(to: noncanonicalURL, options: .atomic)

        let listing = try testSessionStore(rootDirectory: dir).listSessionsWithDiagnostics()

        XCTAssertTrue(listing.sessions.isEmpty)
        XCTAssertEqual(listing.failures.map(\.fileName), [noncanonicalURL.lastPathComponent])
        XCTAssertTrue(FileManager.default.fileExists(atPath: noncanonicalURL.path))
    }

    func testSessionStoreRejectsCrossSessionRecordingReference() throws {
        let dir = testTemporaryDirectory(named: "uv-store-cross-recording")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let ownerID = UUID()
        let otherID = UUID()
        let tampered = CaptureSession({
    var values = CaptureSession.Values()
    values.id = ownerID
    values.title = "cross reference"
    values.recordingRelativePath = "\(otherID.uuidString).mp4"
    return values
}())
        let metadataURL = try writeSessionFixture(tampered, to: dir)
        let store = testSessionStore(rootDirectory: dir)
        let otherRecordingURL = try store.recordingsDirectory()
            .appendingPathComponent("\(otherID.uuidString).mp4")
        try Data("other movie".utf8).write(to: otherRecordingURL)

        XCTAssertThrowsError(try store.load(id: ownerID)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileNameMismatch)
        }
        let listing = try store.listSessionsWithDiagnostics()
        XCTAssertTrue(listing.sessions.isEmpty)
        XCTAssertEqual(listing.failures.map(\.fileName), [metadataURL.lastPathComponent])
        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: ownerID)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileNameMismatch)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertEqual(try Data(contentsOf: otherRecordingURL), Data("other movie".utf8))
    }

    func testSessionStoreRejectsMetadataSymlinkWithoutTouchingTargetOrMedia() throws {
        let dir = testTemporaryDirectory(named: "uv-store-metadata-link")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sessionID = UUID()
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.title = "linked metadata"
    values.recordingRelativePath = "\(sessionID.uuidString).mp4"
    return values
}())
        let outsideTarget = try writeSessionFixture(
            session,
            to: dir.deletingLastPathComponent(),
            fileID: UUID()
        )
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideTarget)
        }

        let metadataLink = dir.appendingPathComponent("\(sessionID.uuidString).json")
        try FileManager.default.createSymbolicLink(at: metadataLink, withDestinationURL: outsideTarget)
        let store = testSessionStore(rootDirectory: dir)
        let recordingURL = try store.recordingsDirectory()
            .appendingPathComponent("\(sessionID.uuidString).mp4")
        try Data("movie".utf8).write(to: recordingURL)
        let targetData = try Data(contentsOf: outsideTarget)

        try assertMetadataSymlinkIsRejected(by: store, sessionID: sessionID, metadataLink: metadataLink)
        XCTAssertEqual(try Data(contentsOf: outsideTarget), targetData)
        XCTAssertEqual(try Data(contentsOf: recordingURL), Data("movie".utf8))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: metadataLink.path))
    }

    func testSessionStoreRejectsDanglingMetadataSymlink() throws {
        let dir = testTemporaryDirectory(named: "uv-store-dangling-metadata")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sessionID = UUID()
        let missingTarget = dir.deletingLastPathComponent()
            .appendingPathComponent("uv-missing-metadata-\(UUID().uuidString).json")
        let metadataLink = dir.appendingPathComponent("\(sessionID.uuidString).json")
        try FileManager.default.createSymbolicLink(at: metadataLink, withDestinationURL: missingTarget)
        let store = testSessionStore(rootDirectory: dir)

        try assertMetadataSymlinkIsRejected(by: store, sessionID: sessionID, metadataLink: metadataLink)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: metadataLink.path))
    }

    func testSessionStoreDeleteRejectsRecordingSymlinkEscape() throws {
        let fixture = try testStoreFixtureWithExternalSentinel(
            named: "uv-store-symlink",
            externalName: "uv-symlink-outside"
        )
        let dir = fixture.directory
        let outsideURL = fixture.outsideURL
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideURL)
        }

        let store = fixture.store
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.title = "symlink"
    values.recordingRelativePath = recordingName
    return values
}())
        try store.save(session)
        let symlinkURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        XCTAssertNotNil(try store.load(id: session.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func testSessionStoreDeleteRejectsDanglingRecordingSymlink() throws {
        let dir = testTemporaryDirectory(named: "uv-store-dangling-recording")
        let missingTarget = dir.deletingLastPathComponent()
            .appendingPathComponent("uv-missing-recording-\(UUID().uuidString).mp4")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = testSessionStore(rootDirectory: dir)
        let sessionID = UUID()
        let recordingName = "\(sessionID.uuidString).mp4"
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.title = "dangling recording"
    values.recordingRelativePath = recordingName
    return values
}())
        try store.save(session)
        let linkURL = try store.recordingsDirectory().appendingPathComponent(recordingName)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: missingTarget)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        XCTAssertNotNil(try store.load(id: session.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path))
    }

}
