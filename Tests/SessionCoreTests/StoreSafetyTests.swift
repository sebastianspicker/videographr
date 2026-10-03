import XCTest
@testable import SessionCore
import GuidanceEngine
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class StoreSafetyTests: XCTestCase {
    func testRecordingReconciliationPreservesLinkedImportsAndReportsRealOrphans() throws {
        let root = try makeRoot()
        let store = SessionStore(rootDirectory: root)
        var target = session(title: "Synthetic imported video")
        try store.save(target)
        let source = root.appendingPathComponent("synthetic-source.mp4")
        let bytes = Data("synthetic media bytes".utf8)
        try bytes.write(to: source)
        let asset = try store.importMedia(from: source, into: target.id)
        target.mediaAssets = [asset]
        try store.save(target)
        try store.commitImportedMedia(asset, toSession: target.id)
        let recordings = root.appendingPathComponent("Recordings")
        let orphanName = "\(UUID().uuidString).mp4"
        try bytes.write(to: recordings.appendingPathComponent(orphanName))

        let reopened = SessionStore(rootDirectory: root)
        let report = try reopened.reconcileRecordingArtifacts()
        XCTAssertEqual(report.diagnostics, [RecordingArtifactDiagnostic(
            fileName: orphanName, reason: .sessionMetadataMissing
        )])
        let restored = try XCTUnwrap(reopened.load(id: target.id))
        XCTAssertEqual(restored.mediaAssets.map(\.id), [asset.id])
        XCTAssertNil(restored.recordingRelativePath)
        XCTAssertEqual(try Data(contentsOf: recordings.appendingPathComponent(asset.relativePath)), bytes)
        XCTAssertEqual(try Data(contentsOf: recordings.appendingPathComponent(orphanName)), bytes)
    }

    private enum ExpectedFailure: Error {
        case injected
    }

    func testMetadataWithADifferentDecodedIdentifierIsNeverLoadedOrDeleted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let requestedID = UUID()
        let decodedID = UUID()
        let session = CaptureSession({
            var values = CaptureSession.Values()
            values.id = decodedID
            values.title = "tampered"
            return values
        }())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(session).write(to: root.appendingPathComponent("\(requestedID.uuidString).json"))
        let store = SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            return values
        }())
        XCTAssertThrowsError(try store.load(id: requestedID)) { error in
            XCTAssertEqual(error as? SessionStoreError, .sessionIdentifierMismatch)
        }
        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: requestedID))
    }

    func testSymlinkAndNonRegularInputsOrStagingDestinationsAreRefused() throws {
        let root = try makeRoot()
        let store = makeStore(root: root)
        let source = root.appendingPathComponent(".source.mp4")
        let linkedSource = root.appendingPathComponent(".linked.mp4")
        try Data("source".utf8).write(to: source)
        try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: source)

        XCTAssertThrowsError(try store.importMedia(from: linkedSource, into: UUID())) { error in
            XCTAssertEqual(error as? SessionStoreError, .importedMediaSourceIsSymbolicLink)
        }

        let directorySource = root.appendingPathComponent(".directory.mp4")
        try FileManager.default.createDirectory(at: directorySource, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.importMedia(from: directorySource, into: UUID())) { error in
            XCTAssertEqual(error as? SessionStoreError, .importedMediaSourceIsNotRegularFile)
        }

        let fifoSource = root.appendingPathComponent(".fifo.mp4")
        let fifoResult = fifoSource.path.withCString { mkfifo($0, mode_t(0o600)) }
        XCTAssertEqual(fifoResult, 0)
        XCTAssertThrowsError(try store.importMedia(from: fifoSource, into: UUID())) { error in
            XCTAssertEqual(error as? SessionStoreError, .importedMediaSourceIsNotRegularFile)
        }

        let linkedStaging = try store.prepareStagedRecordingURL(for: UUID(), transactionID: UUID())
        try FileManager.default.createSymbolicLink(at: linkedStaging, withDestinationURL: source)
        XCTAssertThrowsError(try store.discardStagedRecording(at: linkedStaging)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingFileIsSymbolicLink)
        }

        let directoryStaging = try store.prepareStagedRecordingURL(for: UUID(), transactionID: UUID())
        try FileManager.default.createDirectory(at: directoryStaging, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.discardStagedRecording(at: directoryStaging)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingArtifactIsNotRegularFile)
        }
    }

    func testDeletionFailureRestoresExactMetadataJournalsAndMedia() throws {
        let root = try makeRoot()
        let session = sessionWithJournals()
        let healthyStore = makeStore(root: root)
        try healthyStore.save(session)
        let mediaURL = try healthyStore.prepareRecordingURL(for: session)
        try Data("media".utf8).write(to: mediaURL)

        let metadataURL = root.appendingPathComponent("\(session.id.uuidString).json")
        let observationURL = root.appendingPathComponent("Observations/\(session.id.uuidString).jsonl")
        let codingURL = root.appendingPathComponent("CodingSnapshots/\(session.id.uuidString).jsonl")
        let expectedMetadata = try Data(contentsOf: metadataURL)
        let expectedObservations = try Data(contentsOf: observationURL)
        let expectedCoding = try Data(contentsOf: codingURL)
        let expectedMedia = try Data(contentsOf: mediaURL)

        let failingStore = makeStore(root: root, persistenceFaultHook: { point in
            guard point == .beforeCodingJournalDeletion else { return }
            throw ExpectedFailure.injected
        })
        XCTAssertThrowsError(try failingStore.deleteSessionAndMedia(id: session.id))

        XCTAssertEqual(try Data(contentsOf: metadataURL), expectedMetadata)
        XCTAssertEqual(try Data(contentsOf: observationURL), expectedObservations)
        XCTAssertEqual(try Data(contentsOf: codingURL), expectedCoding)
        XCTAssertEqual(try Data(contentsOf: mediaURL), expectedMedia)
        let recordingNames = try FileManager.default.contentsOfDirectory(atPath: mediaURL.deletingLastPathComponent().path)
        XCTAssertFalse(recordingNames.contains(where: { $0.hasPrefix(".deleting-") }))
    }

    func testMetadataVerificationFailureRestoresPreviousBytes() throws {
        let root = try makeRoot()
        let original = session(title: "original")
        try makeStore(root: root).save(original)
        let metadataURL = root.appendingPathComponent("\(original.id.uuidString).json")
        let expectedMetadata = try Data(contentsOf: metadataURL)

        let failingStore = makeStore(root: root, policyVerificationHook: { url in
            if url == metadataURL { throw ExpectedFailure.injected }
        })
        XCTAssertThrowsError(try failingStore.save(session(id: original.id, title: "changed")))

        XCTAssertEqual(try Data(contentsOf: metadataURL), expectedMetadata)
        XCTAssertEqual(try makeStore(root: root).load(id: original.id)?.title, "original")
    }

    func testFailedImportAfterPromotionLeavesNoTransactionArtifacts() throws {
        let root = try makeRoot()
        let source = root.appendingPathComponent(".import.mp4")
        try Data("import".utf8).write(to: source)
        let store = makeStore(root: root, persistenceFaultHook: { point in
            guard point == .afterImportPromotion else { return }
            throw ExpectedFailure.injected
        })

        XCTAssertThrowsError(try store.importMedia(from: source, into: UUID()))

        let recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recordings.path), [])
    }

    func testOccupiedImportDestinationIsPreservedWithoutTransactionArtifacts() throws {
        let root = try makeRoot()
        let assetID = UUID()
        let recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        let occupiedDestination = recordings.appendingPathComponent("\(assetID.uuidString).mp4")
        let expectedDestination = Data("occupied".utf8)
        try expectedDestination.write(to: occupiedDestination)
        let source = root.appendingPathComponent(".collision.mp4")
        try Data("import".utf8).write(to: source)
        let store = makeStore(root: root, importedMediaIDFactory: { assetID })

        XCTAssertThrowsError(try store.importMedia(from: source, into: UUID()))

        XCTAssertEqual(try Data(contentsOf: occupiedDestination), expectedDestination)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recordings.path), [occupiedDestination.lastPathComponent])
    }

    func testPausedImportCopyDoesNotBlockMetadataMutationOnAsyncStore() async throws {
        let root = try makeRoot()
        let copyOpened = expectation(description: "import source opened")
        let mutationCompleted = expectation(description: "metadata mutation completed")
        let allowCopy = DispatchSemaphore(value: 0)
        let store = SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            values.importSourceOpenedHook = {
                copyOpened.fulfill()
                allowCopy.wait()
            }
            return values
        }())
        let session = session(title: "before")
        try store.save(session)
        let source = root.appendingPathComponent(".concurrent-import.mp4")
        try Data(repeating: 0x2A, count: 2 * 1_024 * 1_024).write(to: source)
        let asyncStore = SessionStoreAsync(store: store)
        let importTask = Task {
            try await asyncStore.importMedia(from: source, into: session.id)
        }
        defer {
            allowCopy.signal()
            importTask.cancel()
        }

        await fulfillment(of: [copyOpened], timeout: 2)
        let reconciliation = try await asyncStore.reconcilePersistenceArtifacts()
        XCTAssertEqual(reconciliation.removedOrphanImportedFileNames, [])
        let mutationTask = Task {
            let updated = try await asyncStore.mutateSession(id: session.id) {
                $0.title = "during import"
            }
            mutationCompleted.fulfill()
            return updated
        }
        await fulfillment(of: [mutationCompleted], timeout: 2)
        let updated = try await mutationTask.value
        XCTAssertEqual(updated.title, "during import")

        allowCopy.signal()
        let asset = try await importTask.value
        try await asyncStore.discardUncommittedImportedMedia(asset, from: session.id)
    }

    func testCancelledPausedImportRollsBackItsReservedArtifacts() async throws {
        let root = try makeRoot()
        let copyOpened = expectation(description: "cancelled import source opened")
        let allowCopy = DispatchSemaphore(value: 0)
        let store = SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            values.importSourceOpenedHook = {
                copyOpened.fulfill()
                allowCopy.wait()
            }
            return values
        }())
        let source = root.appendingPathComponent(".cancelled-import.mp4")
        try Data(repeating: 0x17, count: 2 * 1_024 * 1_024).write(to: source)
        let asyncStore = SessionStoreAsync(store: store)
        let importTask = Task {
            try await asyncStore.importMedia(from: source, into: UUID())
        }
        defer { allowCopy.signal() }

        await fulfillment(of: [copyOpened], timeout: 2)
        importTask.cancel()
        allowCopy.signal()
        do {
            _ = try await importTask.value
            XCTFail("Cancelled import unexpectedly completed")
        } catch is CancellationError {
            // Expected: the transaction-owned marker and staging file are rolled back below.
        }

        let recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recordings.path), [])
    }

    func testRecordingTransactionOwnershipRejectsStaleCallbacks() {
        var ownership = RecordingArtifactOwnership<String>()
        let destination = URL(fileURLWithPath: "/private/tmp/recording.mp4")
        XCTAssertTrue(ownership.register("current", at: destination))
        XCTAssertFalse(ownership.register("stale", at: destination))
        XCTAssertNil(ownership.validatedDestination(for: "current", matching: URL(fileURLWithPath: "/private/tmp/other.mp4")))
        XCTAssertEqual(ownership.confirm("stale"), nil)
        XCTAssertEqual(ownership.confirm("current"), destination)
    }

    func testPersistenceReconciliationRemovesOnlyOrphanJournals() throws {
        let root = try makeRoot()
        let session = session(title: "known")
        let store = makeStore(root: root)
        try store.save(session)
        let orphanID = UUID()
        let observationDirectory = root.appendingPathComponent("Observations", isDirectory: true)
        let codingDirectory = root.appendingPathComponent("CodingSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: observationDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codingDirectory, withIntermediateDirectories: true)
        let knownObservation = observationDirectory.appendingPathComponent("\(session.id.uuidString).jsonl")
        let knownCoding = codingDirectory.appendingPathComponent("\(session.id.uuidString).jsonl")
        let orphanObservation = observationDirectory.appendingPathComponent("\(orphanID.uuidString).jsonl")
        let orphanCoding = codingDirectory.appendingPathComponent("\(orphanID.uuidString).jsonl")
        try Data().write(to: knownObservation)
        try Data().write(to: knownCoding)
        try Data().write(to: orphanObservation)
        try Data().write(to: orphanCoding)

        let report = try store.reconcilePersistenceArtifacts()

        XCTAssertEqual(report.removedOrphanJournalFileNames, [orphanObservation.lastPathComponent])
        XCTAssertEqual(report.removedOrphanCodingJournalFileNames, [orphanCoding.lastPathComponent])
        XCTAssertTrue(FileManager.default.fileExists(atPath: knownObservation.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: knownCoding.path))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func makeStore(
        root: URL,
        policyVerificationHook: ((URL) throws -> Void)? = nil,
        persistenceFaultHook: ((SessionStore.PersistenceFaultPoint) throws -> Void)? = nil,
        importedMediaIDFactory: (() -> UUID)? = nil
    ) -> SessionStore {
        SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            values.policyVerificationHook = policyVerificationHook
            values.persistenceFaultHook = persistenceFaultHook
            values.importedMediaIDFactory = importedMediaIDFactory
            return values
        }())
    }

    private func session(id: UUID = UUID(), title: String) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.id = id
            values.title = title
            return values
        }())
    }

    private func sessionWithJournals() -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.captureObservations = [CaptureObservation(CaptureObservation.Values())]
            values.codingSnapshots = [ResearchCodingSnapshot(ResearchCodingSnapshot.Values(
                provenance: ResearchArtifactProvenance((
                    semanticVersion: "1.0.0",
                    buildNumber: "1",
                    schemaVersion: 1,
                    algorithmVersion: "test",
                    evidenceRegistryVersion: "test"
                ))
            ))]
            return values
        }())
    }
}
