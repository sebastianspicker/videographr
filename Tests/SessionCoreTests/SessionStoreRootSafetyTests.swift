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
    func testSessionStoreRejectsRealRootDirectorySymlinkAcrossOperations() throws{
        try sessionStoreRejectsRealRootDirectorySymlinkAcrossOperationsAssertions()
    }

    func testSessionStoreRejectsRealRecordingsDirectorySymlinkAcrossOperations() throws{
        try sessionStoreRejectsRealRecordingsDirectorySymlinkAcrossOperationsAssertions()
    }

    func testSessionStorePrepareRecordingRejectsLiveAndDanglingCanonicalSymlinks() throws {
        let outsideData = Data("outside movie".utf8)
        let fixture = try testNestedStoreFixture(named: "uv-store-canonical-links", outsideData: outsideData)
        let container = fixture.container
        let outsideTarget = fixture.outsideTarget
        let missingTarget = container.appendingPathComponent("missing.mp4")
        defer { try? FileManager.default.removeItem(at: container) }

        let store = fixture.store
        let recordingsDirectory = try store.recordingsDirectory()
        let liveSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "live link"
    return values
}())
        let liveLink = recordingsDirectory.appendingPathComponent("\(liveSession.id.uuidString).mp4")
        try FileManager.default.createSymbolicLink(at: liveLink, withDestinationURL: outsideTarget)

        XCTAssertThrowsError(try store.prepareRecordingURL(for: liveSession)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        XCTAssertEqual(try Data(contentsOf: outsideTarget), outsideData)
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: liveLink.path))

        let danglingSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "dangling link"
    return values
}())
        let danglingLink = recordingsDirectory.appendingPathComponent("\(danglingSession.id.uuidString).mp4")
        try FileManager.default.createSymbolicLink(at: danglingLink, withDestinationURL: missingTarget)

        XCTAssertThrowsError(try store.prepareRecordingURL(for: danglingSession)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: danglingLink.path))
    }

    func testSessionStoreDeleteRejectsTraversalWithoutTouchingOutsideFile() throws {
        let fixture = try testStoreFixtureWithExternalSentinel(
            named: "uv-store-traversal",
            externalName: "uv-outside"
        )
        let dir = fixture.directory
        let outsideURL = fixture.outsideURL
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideURL)
        }

        let store = fixture.store
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "unsafe"
    values.recordingRelativePath = "../\(outsideURL.lastPathComponent)"
    return values
}())
        let metadataURL = try writeSessionFixture(session, to: dir)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .unsafeRecordingRelativePath)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

}


private let sessionStoreRejectsRealRootDirectorySymlinkAcrossOperationsAssertions: @Sendable () throws -> Void = {
        let container = testTemporaryDirectory(named: "uv-store-root-link")
        let outsideDirectory = container.appendingPathComponent("outside", isDirectory: true)
        let rootLink = container.appendingPathComponent("Sessions", isDirectory: true)
        let sentinelURL = outsideDirectory.appendingPathComponent("sentinel")
        let sentinelData = Data("outside sentinel".utf8)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        try sentinelData.write(to: sentinelURL)
        try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: outsideDirectory)
        defer { try? FileManager.default.removeItem(at: container) }

        let store = testSessionStore(rootDirectory: rootLink)
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "must stay outside"
    return values
}())

        XCTAssertThrowsError(try store.save(session)) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.load(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.listSessionsWithDiagnostics()) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.recordingsDirectory()) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.prepareRecordingURL(for: session)) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.reconcileRecordingArtifacts()) { error in
            XCTAssertEqual(error as? SessionStoreError, .rootDirectoryIsSymbolicLink)
        }

        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinelData)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: outsideDirectory.path),
            [sentinelURL.lastPathComponent]
        )
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: outsideDirectory.appendingPathComponent("\(session.id.uuidString).json").path
        ))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: rootLink.path))
    }

private let sessionStoreRejectsRealRecordingsDirectorySymlinkAcrossOperationsAssertions: @Sendable () throws -> Void = {
        let container = testTemporaryDirectory(named: "uv-store-recordings-link")
        let rootDirectory = container.appendingPathComponent("Sessions", isDirectory: true)
        let outsideDirectory = container.appendingPathComponent("outside", isDirectory: true)
        let sentinelURL = outsideDirectory.appendingPathComponent("sentinel")
        let sentinelData = Data("outside sentinel".utf8)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        try sentinelData.write(to: sentinelURL)
        defer { try? FileManager.default.removeItem(at: container) }

        let store = testSessionStore(rootDirectory: rootDirectory)
        let persistedSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "existing metadata"
    return values
}())
        try store.save(persistedSession)
        let metadataURL = rootDirectory.appendingPathComponent("\(persistedSession.id.uuidString).json")
        let metadataData = try Data(contentsOf: metadataURL)
        let recordingsLink = rootDirectory.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: recordingsLink, withDestinationURL: outsideDirectory)

        let newSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "must not save"
    return values
}())
        XCTAssertThrowsError(try store.save(newSession)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.load(id: persistedSession.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.listSessionsWithDiagnostics()) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: persistedSession.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.recordingsDirectory()) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.prepareRecordingURL(for: newSession)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.reconcileRecordingArtifacts()) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }

        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataData)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinelData)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: outsideDirectory.path),
            [sentinelURL.lastPathComponent]
        )
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: rootDirectory.appendingPathComponent("\(newSession.id.uuidString).json").path
        ))
        XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: recordingsLink.path))
    }
