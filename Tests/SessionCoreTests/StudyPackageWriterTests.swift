import Foundation
import XCTest
import SessionCore

final class StudyPackageWriterTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_767_323_045) // 2026-01-02T03:04:05Z
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!

    func testBuiltPackageSatisfiesTheContractWithMatchingDigestsAndNoMedia() async throws {
        let writer = StudyPackageWriter()
        let session = populatedSession()
        let packageURL = try await build(session, with: writer)

        let members = try StudyPackageDirectory.validatedMemberURLs(in: packageURL)
        XCTAssertEqual(Set(members.keys), Set(StudyPackageContract.expectedPackageFiles))
        XCTAssertFalse(members.keys.contains { $0.lowercased().hasSuffix(".mp4") })

        let manifest = try readManifest(members)
        let fileData = try readContent(members)
        XCTAssertEqual(
            StudyPackageContract.validate(manifest: manifest, expectedSessionID: session.id, fileData: fileData),
            []
        )
        XCTAssertEqual(manifest.contentFiles, StudyPackageContract.expectedContentFiles)
        for (name, data) in fileData {
            XCTAssertFalse(data.isEmpty, "\(name) should carry the populated session's records")
            XCTAssertEqual(manifest.fileDigests[name], SessionCoding.sha256Hex(data), name)
        }
        let validated = try await writer.validatedManifest(at: packageURL, expectedSessionID: session.id)
        XCTAssertEqual(validated, manifest)
    }

    func testBuiltPackageExcludesLocalDisclosureAuditHistory() async throws {
        let writer = StudyPackageWriter()
        var session = populatedSession()
        var eventValues = ExportEvent.Values()
        eventValues.operatorPseudonym = "audit-only-operator"
        eventValues.operatorAuthenticationMethod = "deviceOwnerAuthentication"
        eventValues.shareActivityIdentifier = "audit-only-provider"
        eventValues.status = .failed
        eventValues.failureDescription = "audit-only-failure"
        session.exportEvents = [ExportEvent(eventValues)]

        let packageURL = try await build(session, with: writer)
        let members = try StudyPackageDirectory.validatedMemberURLs(in: packageURL)
        let sessionData = try Data(contentsOf: try XCTUnwrap(members[StudyPackageContract.sessionFile]))
        let sharedSession = try SessionCoding.decoder().decode(CaptureSession.self, from: sessionData)

        XCTAssertEqual(session.exportEvents.count, 1, "Projection must not mutate the local outbox.")
        XCTAssertEqual(sharedSession.exportEvents, [])
        XCTAssertFalse(String(decoding: sessionData, as: UTF8.self).contains("audit-only-"))
    }

    func testIdenticalSessionsProduceIdenticalPackageBytes() async throws {
        let writer = StudyPackageWriter()
        let first = try StudyPackageDirectory.validatedMemberURLs(in: try await build(populatedSession(), with: writer))
        let second = try StudyPackageDirectory.validatedMemberURLs(in: try await build(populatedSession(), with: writer))

        XCTAssertEqual(try readContent(first), try readContent(second))
        // The manifest's only wall-clock field is `generatedAt`; everything else is derived from the session.
        var firstManifest = try readManifest(first)
        var secondManifest = try readManifest(second)
        firstManifest.generatedAt = fixedDate
        secondManifest.generatedAt = fixedDate
        XCTAssertEqual(try firstManifest.canonicalJSONData(), try secondManifest.canonicalJSONData())
    }

    // MARK: - Helpers

    private func build(_ session: CaptureSession, with writer: StudyPackageWriter) async throws -> URL {
        let packageURL = try await writer.build(session: session, exportID: UUID(), provenance: provenance())
        addTeardownBlock { await writer.removePackage(at: packageURL) }
        return packageURL
    }

    private func readManifest(_ members: [String: URL]) throws -> StudyExportManifest {
        let url = try XCTUnwrap(members[StudyPackageContract.manifestFile])
        return try SessionCoding.decoder().decode(StudyExportManifest.self, from: Data(contentsOf: url))
    }

    private func readContent(_ members: [String: URL]) throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.map { name in
            (name, try Data(contentsOf: try XCTUnwrap(members[name])))
        })
    }

    private func provenance() -> BuildProvenance {
        var values = BuildProvenance.Values()
        values.semanticVersion = "1.0.0"
        values.buildNumber = "1"
        values.algorithmVersion = "fixture-algorithm"
        values.evidenceRegistryVersion = "fixture-registry"
        return BuildProvenance(values)
    }

    private func populatedSession() -> CaptureSession {
        let grantID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        var values = CaptureSession.Values()
        values.id = sessionID
        values.createdAt = fixedDate
        values.updatedAt = fixedDate
        values.title = "Synthetische Sitzung"
        values.operatingMode = .experimentalResearch
        values.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "protocol-1",
            oversightReference: "oversight-1",
            expiresAt: Date(timeIntervalSince1970: 4_102_444_800), // 2100-01-01
            disclosureAcknowledgedAt: fixedDate
        )
        values.consentGrants = [ConsentGrant({
            var grant = ConsentGrant.Values()
            grant.id = grantID
            grant.scopes = Set(ConsentScope.allCases)
            grant.documentIdentifier = "doc"
            grant.documentVersion = "1"
            grant.participantGroupPseudonym = "group-a"
            grant.grantedAt = fixedDate
            return grant
        }())]
        values.mediaAssets = [SessionMediaAsset({
            var asset = SessionMediaAsset.Values()
            asset.id = assetID
            asset.relativePath = "\(assetID.uuidString).mp4"
            asset.createdAt = fixedDate
            return asset
        }())]
        values.evidenceAnnotations = [EvidenceAnnotation({
            var annotation = EvidenceAnnotation.Values()
            annotation.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!
            annotation.promptIdentifier = "lessonGoals"
            annotation.mediaAssetID = assetID
            annotation.note = "Synthetische Notiz"
            annotation.createdAt = fixedDate
            annotation.revisedAt = fixedDate
            return annotation
        }())]
        values.captureObservations = [CaptureObservation({
            var observation = CaptureObservation.Values()
            observation.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
            observation.observedAt = fixedDate
            observation.measurements = ["level": 0.5]
            return observation
        }())]
        var snapshot = ResearchCodingSnapshot.Values(provenance: ResearchArtifactProvenance((
            semanticVersion: "1.0.0", buildNumber: "1", schemaVersion: 1,
            algorithmVersion: "fixture-algorithm", evidenceRegistryVersion: "fixture-registry"
        )))
        snapshot.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        snapshot.createdAt = fixedDate
        values.codingSnapshots = [ResearchCodingSnapshot(snapshot)]
        values.buildProvenance = provenance()
        return CaptureSession(values)
    }
}
