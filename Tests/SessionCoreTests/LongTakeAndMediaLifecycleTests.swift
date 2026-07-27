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
    func testImportedMediaRollbackAndSessionDeletionDoNotLeaveOrphans() throws {
        let fixture = try testImportSourceFixture(named: "SessionCoreImportRollback")
        let directory = fixture.directory
        let source = fixture.source
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        let store = testSessionStore(rootDirectory: directory)
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Import rollback"
    return values
}())
        try store.save(session)

        let uncommitted = try store.importMedia(from: source, into: session.id)
        let uncommittedURL = try store.validatedMediaURL(for: uncommitted, sessionID: session.id)
        try store.discardUncommittedImportedMedia(uncommitted, from: session.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: uncommittedURL.path))

        let committed = try store.importMedia(from: source, into: session.id)
        let committedURL = try store.validatedMediaURL(for: committed, sessionID: session.id)
        session.mediaAssets.append(committed)
        try store.save(session)
        XCTAssertThrowsError(try store.discardUncommittedImportedMedia(committed, from: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .importedMediaAlreadyCommitted)
        }

        try store.deleteSessionAndMedia(id: session.id)
        XCTAssertNil(try store.load(id: session.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: committedURL.path))
    }

    func testPlannedDurationClampsAndRoundTrips() throws {
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.plannedDurationMinutes = 999
    return values
}())
        XCTAssertEqual(session.plannedDurationMinutes, 240)
        let data = try JSONEncoder().encode(CaptureSession({
    var values = CaptureSession.Values()
    values.plannedDurationMinutes = 0
    return values
}()))
        XCTAssertEqual(try JSONDecoder().decode(CaptureSession.self, from: data).plannedDurationMinutes, 1)
    }

    func testObservationJournalLongTakeRetainsAllRowsAndDeduplicatesRetries() throws {
        let fixture = testJournalStoreFixture(named: "SessionCoreJournalLong")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = fixture.store
        let session = fixture.session
        try store.save(session)
        let start = Date(timeIntervalSince1970: 1_000)
        // Five-second samples across a full 120-minute planned take.
        for offset in 0..<1_440 {
            try store.appendCaptureObservation(
                CaptureObservation({
    var values = CaptureObservation.Values()
    values.observedAt = start.addingTimeInterval(Double(offset * 5))
    values.kind = .periodic
    values.measurements = ["signal": Double(offset)]
    return values
}()),
                toSession: session.id
            )
        }
        let retry = CaptureObservation({
    var values = CaptureObservation.Values()
    values.id = UUID()
    values.observedAt = start
    values.kind = .transition
    return values
}())
        try store.appendCaptureObservation(retry, toSession: session.id)
        try store.appendCaptureObservation(retry, toSession: session.id)

        let observations = try store.loadCaptureObservations(forSession: session.id)
        XCTAssertEqual(observations.count, 1_441)
        XCTAssertEqual(observations.map(\.id).filter { $0 == retry.id }.count, 1)
        XCTAssertEqual(observations.first?.observedAt, start)
        XCTAssertEqual(observations.last?.observedAt, start.addingTimeInterval(7_195))
    }

    func testSavingMergedSessionDoesNotDuplicateJournalHistoryIntoMetadata() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreJournalMetadataBound")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Metadata bound"
    return values
}())
        try store.save(session)
        for index in 0..<96 {
            try store.appendCaptureObservation(
                CaptureObservation({
    var values = CaptureObservation.Values()
    values.kind = .periodic
    values.measurements = ["sample": Double(index)]
    return values
}()),
                toSession: session.id
            )
        }

        var loaded = try XCTUnwrap(store.load(id: session.id))
        XCTAssertEqual(loaded.captureObservations.count, 96)
        loaded.title = "Unrelated metadata edit"
        try store.save(loaded)

        let raw = try Data(contentsOf: directory.appendingPathComponent("\(session.id.uuidString).json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let persisted = try decoder.decode(CaptureSession.self, from: raw)
        XCTAssertTrue(persisted.captureObservations.isEmpty)
        XCTAssertEqual(try store.loadCaptureObservations(forSession: session.id).count, 96)
        XCTAssertLessThan(raw.count, 20_000)
    }

    func testCodingSnapshotJournalLongTakeDeduplicatesAndKeepsMetadataBounded() throws{
        try codingSnapshotJournalLongTakeDeduplicatesAndKeepsMetadataBoundedAssertions()
    }

    func testCodingSnapshotJournalIsRemovedOnDeletionAndOrphanReconciliation() throws{
        try codingSnapshotJournalIsRemovedOnDeletionAndOrphanReconciliationAssertions()
    }

}


private let codingSnapshotJournalLongTakeDeduplicatesAndKeepsMetadataBoundedAssertions: @Sendable () throws -> Void = {
        let directory = testTemporaryDirectory(named: "SessionCoreCodingJournalLong")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let session = testResearchAuthorizedSession(
            title: "Coding journal",
            protocolIdentifier: "coding-journal"
        )
        try store.save(session)
        let start = Date(timeIntervalSince1970: 10_000)
        var first: ResearchCodingSnapshot?
        for index in 0..<1_440 {
            let snapshot = testResearchCodingSnapshot { values in
                values.createdAt = start.addingTimeInterval(Double(index * 5))
            }
            if first == nil { first = snapshot }
            try store.appendCodingSnapshot(snapshot, toSession: session.id)
        }
        try store.appendCodingSnapshot(try XCTUnwrap(first), toSession: session.id)

        let snapshots = try store.loadCodingSnapshots(forSession: session.id)
        XCTAssertEqual(snapshots.count, 1_440)
        XCTAssertEqual(snapshots.first?.createdAt, start)
        XCTAssertEqual(snapshots.last?.createdAt, start.addingTimeInterval(7_195))
        let raw = try Data(contentsOf: directory.appendingPathComponent("\(session.id.uuidString).json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertTrue(try decoder.decode(CaptureSession.self, from: raw).codingSnapshots.isEmpty)
        XCTAssertLessThan(raw.count, 20_000)

        let journal = directory.appendingPathComponent("CodingSnapshots/\(session.id.uuidString).jsonl")
        let handle = try FileHandle(forWritingTo: journal)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"interrupted\":".utf8))
        try handle.synchronize()
        XCTAssertEqual(try store.loadCodingSnapshots(forSession: session.id).count, 1_440)
        let hydrated = try XCTUnwrap(store.load(id: session.id))
        XCTAssertEqual(hydrated.latestCodingSnapshot?.id, snapshots.last?.id)
        XCTAssertEqual(hydrated.codingTimeline.segments.last?.snapshot?.id, snapshots.last?.id)
        XCTAssertEqual(hydrated.codingTimeline.segments.count, 1)
    }

private let codingSnapshotJournalIsRemovedOnDeletionAndOrphanReconciliationAssertions: @Sendable () throws -> Void = {
        let directory = testTemporaryDirectory(named: "SessionCoreCodingJournalCleanup")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let session = testResearchAuthorizedSession(
            title: "Coding cleanup",
            protocolIdentifier: "coding-cleanup"
        )
        try store.save(session)
        let snapshot = testResearchCodingSnapshot()
        try store.appendCodingSnapshot(snapshot, toSession: session.id)
        let journal = directory.appendingPathComponent("CodingSnapshots/\(session.id.uuidString).jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: journal.path))
        try store.deleteSessionAndMedia(id: session.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: journal.path))

        let orphanID = UUID()
        let orphan = directory.appendingPathComponent("CodingSnapshots/\(orphanID.uuidString).jsonl")
        try Data("{}\n".utf8).write(to: orphan)
        let report = try store.reconcilePersistenceArtifacts()
        XCTAssertEqual(report.removedOrphanCodingJournalFileNames, [orphan.lastPathComponent])
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }
