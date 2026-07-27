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
    func testDeletingSessionAlsoDeletesObservationJournal() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreJournalDelete")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Delete"
    return values
}())
        try store.save(session)
        try store.appendCaptureObservation(CaptureObservation({
    var values = CaptureObservation.Values()
    values.kind = .periodic
    return values
}()), toSession: session.id)
        let journal = directory.appendingPathComponent("Observations/\(session.id.uuidString).jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: journal.path))
        try store.deleteSessionAndMedia(id: session.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: journal.path))
    }

    func testPersistenceReconciliationRemovesOnlyMarkedUncommittedImport() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreImportRecovery")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionCoreImportRecoverySource-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        try Data([1, 2, 3]).write(to: source)
        let store = testSessionStore(rootDirectory: directory)
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Import recovery"
    return values
}())
        try store.save(session)
        let pending = try store.importMedia(from: source, into: session.id)

        let report = try store.reconcilePersistenceArtifacts()
        XCTAssertEqual(report.removedOrphanImportedFileNames, [pending.relativePath])
        XCTAssertThrowsError(try store.validatedMediaURL(for: pending, sessionID: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .mediaFileMissing)
        }
    }

    func testPersistenceReconciliationRetainsImportMarkerForUnsafeDestination() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreImportRecoveryUnsafe")
        let outsideDestination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionCoreImportRecoveryOutside-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: outsideDestination)
        }
        try Data([1, 2, 3]).write(to: outsideDestination)

        let store = testSessionStore(rootDirectory: directory)
        let recordings = try store.recordingsDirectory()
        let sessionID = UUID()
        let assetID = UUID()
        let destination = recordings.appendingPathComponent("\(assetID.uuidString).mp4")
        let marker = recordings.appendingPathComponent(
            ".videographr-import-\(sessionID.uuidString)-\(assetID.uuidString).pending"
        )
        try Data(sessionID.uuidString.utf8).write(to: marker)
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: outsideDestination)

        let firstReport = try store.reconcilePersistenceArtifacts()
        try assertUnsafeImportArtifactIsPreserved(
            report: firstReport,
            marker: marker,
            destination: destination,
            outsideDestination: outsideDestination
        )

        let secondReport = try store.reconcilePersistenceArtifacts()
        try assertUnsafeImportArtifactIsPreserved(
            report: secondReport,
            marker: marker,
            destination: destination,
            outsideDestination: outsideDestination
        )
    }

    func testPersistenceReconciliationRetainsImportMarkerForNonRegularDestination() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreImportRecoveryNonRegular")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = testSessionStore(rootDirectory: directory)
        let recordings = try store.recordingsDirectory()
        let sessionID = UUID()
        let assetID = UUID()
        let destination = recordings.appendingPathComponent("\(assetID.uuidString).mp4", isDirectory: true)
        let marker = recordings.appendingPathComponent(
            ".videographr-import-\(sessionID.uuidString)-\(assetID.uuidString).pending"
        )
        try Data(sessionID.uuidString.utf8).write(to: marker)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)

        let expectedDiagnostic = RecordingArtifactDiagnostic(
            fileName: destination.lastPathComponent,
            reason: .unsupportedArtifactType
        )
        let firstReport = try store.reconcilePersistenceArtifacts()
        XCTAssertEqual(firstReport.removedOrphanImportedFileNames, [])
        XCTAssertEqual(firstReport.diagnostics, [expectedDiagnostic])
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        let secondReport = try store.reconcilePersistenceArtifacts()
        XCTAssertEqual(secondReport.removedOrphanImportedFileNames, [])
        XCTAssertEqual(secondReport.diagnostics, [expectedDiagnostic])
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testScopedConsentAndExperimentalProtocolAreExplicit() throws {
        let expires = Date().addingTimeInterval(60)
        let protocolReference = ResearchProtocolReference(
            protocolIdentifier: "study-1", oversightReference: "ethics-1", expiresAt: expires
        )
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = protocolReference
    values.consentGrants = [ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection, .researchProcessing]
    values.documentIdentifier = "consent"
    values.documentVersion = "2"
    values.participantGroupPseudonym = "group-a"
    return values
}())]
    return values
}())
        XCTAssertTrue(session.hasUsableExperimentalProtocol)
        XCTAssertTrue(session.canStartNewCapture)
        XCTAssertFalse(session.canExportExternally)
        session.consentGrants[0].withdrawnAt = Date()
        XCTAssertFalse(session.canStartNewCapture)
    }

    func testCanonicalStudyManifestIsStableAndSorted() throws {
        let id = UUID()
        let manifest = StudyExportManifest({
    var values = StudyExportManifest.Values()
    values.sessionID = id
    values.generatedAt = Date(timeIntervalSince1970: 1)
    values.operatingMode = .evidenceSafe
    values.provenance = BuildProvenance({
    var values = BuildProvenance.Values()
    values.semanticVersion = "1.2.3"
    values.buildNumber = "4"
    return values
}())
    values.fileDigests = ["z.json": "z", "a.json": "a"]
    values.includedScopes = [.collection, .secondaryUse, .externalSharing]
    return values
}())
        let text = try XCTUnwrap(String(data: manifest.canonicalJSONData(), encoding: .utf8))
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "a.json")?.lowerBound), try XCTUnwrap(text.range(of: "z.json")?.lowerBound))
        XCTAssertTrue(text.contains("\"schemaVersion\":3"))
        XCTAssertTrue(text.contains("\"contentFiles\":[\"a.json\",\"z.json\"]"))
        XCTAssertTrue(text.contains("\"externalSharing\""))
    }

    func testStudyPackageContractRejectsTamperSchemaDuplicatesAndOversize(){
        studyPackageContractRejectsTamperSchemaDuplicatesAndOversizeAssertions()
    }

}


private let studyPackageContractRejectsTamperSchemaDuplicatesAndOversizeAssertions: @Sendable () -> Void = {
        let sessionID = UUID()
        let files = Dictionary(uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.map {
            ($0, Data("fixture-\($0)".utf8))
        })
        func digest(_ data: Data) -> String {
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        let digests = files.mapValues(digest)
        let provenance = BuildProvenance({
    var values = BuildProvenance.Values()
    values.semanticVersion = "1.2.3"
    values.buildNumber = "4"
    values.algorithmVersion = "study-package-test"
    values.evidenceRegistryVersion = "1"
    return values
}())
        let manifest = StudyExportManifest({
    var values = StudyExportManifest.Values()
    values.sessionID = sessionID
    values.operatingMode = .evidenceSafe
    values.provenance = provenance
    values.fileDigests = digests
    values.contentFiles = StudyPackageContract.expectedContentFiles
    values.includedScopes = [.collection, .secondaryUse, .externalSharing]
    return values
}())
        XCTAssertTrue(StudyPackageContract.validate(
            manifest: manifest, expectedSessionID: sessionID, fileData: files
        ).isEmpty)

        var tampered = files
        tampered["session.json"] = Data("tampered".utf8)
        XCTAssertTrue(StudyPackageContract.validate(
            manifest: manifest, expectedSessionID: sessionID, fileData: tampered
        ).contains("digest-mismatch:session.json"))

        var unknownSchema = manifest
        unknownSchema.schemaVersion += 1
        XCTAssertTrue(StudyPackageContract.validate(
            manifest: unknownSchema, expectedSessionID: sessionID, fileData: files
        ).contains("unsupported-schema"))

        var duplicate = manifest
        duplicate.contentFiles.append("session.json")
        XCTAssertTrue(StudyPackageContract.validate(
            manifest: duplicate, expectedSessionID: sessionID, fileData: files
        ).contains("unexpected-content-files"))

        var oversizedFiles = files
        oversizedFiles["session.json"] = Data(
            count: StudyPackageContract.maximumContentFileBytes + 1
        )
        var oversizedManifest = manifest
        guard let oversizedSession = oversizedFiles["session.json"] else {
            return XCTFail("Expected oversized session fixture")
        }
        oversizedManifest.fileDigests["session.json"] = digest(oversizedSession)
        XCTAssertTrue(StudyPackageContract.validate(
            manifest: oversizedManifest,
            expectedSessionID: sessionID,
            fileData: oversizedFiles
        ).contains("oversized:session.json"))
    }
