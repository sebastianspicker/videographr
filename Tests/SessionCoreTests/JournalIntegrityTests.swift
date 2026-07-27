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
    func testDeleteRollsBackMetadataJournalsAndMediaWhenCodingJournalDeletionFails() throws{
        try deleteRollsBackMetadataJournalsAndMediaWhenCodingJournalDeletionFailsAssertions()
    }

    func testCodingSnapshotAppendRejectsExpiredOrRevokedResearchAuthority() throws{
        try codingSnapshotAppendRejectsExpiredOrRevokedResearchAuthorityAssertions()
    }

    func testObservationJournalConcurrentAppendsHaveDeterministicOrder() throws {
        let fixture = testJournalStoreFixture(named: "SessionCoreJournalConcurrent")
        let directory = fixture.directory
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = fixture.store
        let session = fixture.session
        try store.save(session)
        let fixedTime = Date(timeIntervalSince1970: 2_000)
        let observations = (0..<24).map { index in
            CaptureObservation({
    var values = CaptureObservation.Values()
    values.id = UUID()
    values.observedAt = fixedTime
    values.kind = .periodic
    values.measurements = ["index": Double(index)]
    return values
}())
        }
        let group = DispatchGroup()
        let errors = LockedErrorDescriptions()
        for observation in observations {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do { try store.appendCaptureObservation(observation, toSession: session.id) }
                catch { errors.record(error) }
            }
        }
        group.wait()
        XCTAssertTrue(errors.snapshot.isEmpty, "errors=\(errors.snapshot)")
        let loaded = try store.loadCaptureObservations(forSession: session.id)
        XCTAssertEqual(loaded.map(\.id), observations.map(\.id).sorted { $0.uuidString < $1.uuidString })
    }

    func testObservationJournalIgnoresOnlyInterruptedFinalFragmentAndMigratesInlineRows() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreJournalRecovery")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let legacy = CaptureObservation({
    var values = CaptureObservation.Values()
    values.kind = .periodic
    values.measurements = ["legacy": 1]
    return values
}())
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Legacy journal"
    return values
}())
        session.captureObservations = [legacy]
        try store.save(session)
        _ = try store.migrateLegacySession(id: session.id)
        let journal = directory.appendingPathComponent("Observations/\(session.id.uuidString).jsonl")
        let handle = try FileHandle(forWritingTo: journal)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"truncated\":".utf8))
        try handle.synchronize()

        XCTAssertEqual(try store.loadCaptureObservations(forSession: session.id).map(\.id), [legacy.id])
        let metadataDecoder = JSONDecoder()
        metadataDecoder.dateDecodingStrategy = .iso8601
        let metadata = try metadataDecoder.decode(
            CaptureSession.self,
            from: Data(contentsOf: directory.appendingPathComponent("\(session.id.uuidString).json"))
        )
        XCTAssertTrue(metadata.captureObservations.isEmpty)
    }

    func testObservationJournalRejectsOversizedCompleteLine() throws {
        let (directory, store, session, journal) = try testObservationJournalFixture(
            named: "SessionCoreJournalLargeLine"
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        var oversized = Data(repeating: 0x20, count: SessionStore.maximumObservationLineBytes + 1)
        oversized.append(0x0A)
        try oversized.write(to: journal)

        XCTAssertThrowsError(try store.loadCaptureObservations(forSession: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .observationJournalInvalid)
        }
    }

    func testObservationJournalRejectsOversizedTotalBeforeLoadingIt() throws {
        let (directory, store, session, journal) = try testObservationJournalFixture(
            named: "SessionCoreJournalLargeTotal"
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(repeating: 0x20, count: SessionStore.maximumObservationJournalBytes + 1).write(to: journal)

        XCTAssertThrowsError(try store.loadCaptureObservations(forSession: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .observationJournalInvalid)
        }
    }

}


private let deleteRollsBackMetadataJournalsAndMediaWhenCodingJournalDeletionFailsAssertions: @Sendable () throws -> Void = {
        let directory = testTemporaryDirectory(named: "SessionCoreDeleteRollback")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = directory
    values.persistenceFaultHook = { point in
            if case .beforeCodingJournalDeletion = point {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    return values
}())
        let session = testResearchAuthorizedSession(
            title: "Delete rollback",
            protocolIdentifier: "delete-rollback"
        )
        try store.save(session)
        try store.appendCaptureObservation(CaptureObservation({
    var values = CaptureObservation.Values()
    values.kind = .periodic
    return values
}()), toSession: session.id)
        let snapshot = testResearchCodingSnapshot()
        try store.appendCodingSnapshot(snapshot, toSession: session.id)
        let mediaURL = try store.prepareRecordingURL(for: session)
        let mediaData = Data("delete rollback media".utf8)
        try mediaData.write(to: mediaURL)
        try store.secureFinalizedRecording(at: mediaURL)
        let metadataURL = directory.appendingPathComponent("\(session.id.uuidString).json")
        let observationURL = directory.appendingPathComponent("Observations/\(session.id.uuidString).jsonl")
        let codingURL = directory.appendingPathComponent("CodingSnapshots/\(session.id.uuidString).jsonl")
        let metadataData = try Data(contentsOf: metadataURL)
        let observationData = try Data(contentsOf: observationURL)
        let codingData = try Data(contentsOf: codingURL)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id))

        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataData)
        XCTAssertEqual(try Data(contentsOf: observationURL), observationData)
        XCTAssertEqual(try Data(contentsOf: codingURL), codingData)
        XCTAssertEqual(try Data(contentsOf: mediaURL), mediaData)
        XCTAssertEqual(try store.loadCaptureObservations(forSession: session.id).count, 1)
        XCTAssertEqual(try store.loadCodingSnapshots(forSession: session.id).map(\.id), [snapshot.id])
        let recordingNames = try FileManager.default.contentsOfDirectory(atPath: mediaURL.deletingLastPathComponent().path)
        XCTAssertFalse(recordingNames.contains { $0.hasPrefix(".deleting-") })
    }

private let codingSnapshotAppendRejectsExpiredOrRevokedResearchAuthorityAssertions: @Sendable () throws -> Void = {
        let directory = testTemporaryDirectory(named: "SessionCoreCodingJournalAuthorization")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let grant = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection, .researchProcessing]
    values.documentIdentifier = "test"
    values.documentVersion = "1"
    values.participantGroupPseudonym = "group"
    return values
}())
        let expired = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = ResearchProtocolReference(
                protocolIdentifier: "expired", oversightReference: "test",
                expiresAt: Date().addingTimeInterval(-1)
            )
    values.consentGrants = [grant]
    return values
}())
        try store.save(expired)
        let snapshot = testResearchCodingSnapshot()
        XCTAssertThrowsError(try store.appendCodingSnapshot(snapshot, toSession: expired.id)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteNoPermission)
        }

        var revokedGrant = grant
        revokedGrant.withdrawnAt = Date()
        let revoked = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = ResearchProtocolReference(
                protocolIdentifier: "revoked", oversightReference: "test",
                expiresAt: Date().addingTimeInterval(3_600)
            )
    values.consentGrants = [revokedGrant]
    return values
}())
        try store.save(revoked)
        XCTAssertThrowsError(try store.appendCodingSnapshot(snapshot, toSession: revoked.id)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteNoPermission)
        }
    }
