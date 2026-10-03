import CryptoKit
import XCTest
@testable import SessionCore

final class StudyPackageContractTests: XCTestCase {
    func testStudyPackageRejectsTamperedOrOversizedContent() {
        let sessionID = UUID()
        var files = Dictionary(uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.map { ($0, Data("test-\($0)".utf8)) })
        let manifest = StudyExportManifest({
            var values = StudyExportManifest.Values()
            values.sessionID = sessionID
            values.operatingMode = .evidenceSafe
            values.provenance = BuildProvenance({
                var provenance = BuildProvenance.Values()
                provenance.semanticVersion = "1.2.3"
                provenance.buildNumber = "4"
                provenance.algorithmVersion = "study-package-test"
                provenance.evidenceRegistryVersion = "1"
                return provenance
            }())
            values.fileDigests = files.mapValues(digest)
            values.contentFiles = StudyPackageContract.expectedContentFiles
            values.includedScopes = [.collection, .secondaryUse, .externalSharing]
            return values
        }())
        XCTAssertTrue(StudyPackageContract.validate(manifest: manifest, expectedSessionID: sessionID, fileData: files).isEmpty)
        files["session.json"] = Data("tampered".utf8)
        XCTAssertTrue(StudyPackageContract.validate(manifest: manifest, expectedSessionID: sessionID, fileData: files).contains("digest-mismatch:session.json"))

        files["session.json"] = Data(
            repeating: 0,
            count: StudyPackageContract.maximumContentFileBytes + 1
        )
        XCTAssertTrue(StudyPackageContract.validate(manifest: manifest, expectedSessionID: sessionID, fileData: files).contains("oversized:session.json"))
    }

    func testStudyPackageContractRequiresExactMembersSchemaSessionAndDigestShape() {
        let fixture = studyFixture()
        XCTAssertEqual(StudyPackageContract.validate(
            manifest: fixture.manifest,
            expectedSessionID: fixture.sessionID,
            fileData: fixture.files
        ), [])

        var unsupportedSchema = fixture.manifest
        unsupportedSchema.schemaVersion -= 1
        XCTAssertEqual(validationFailures(for: unsupportedSchema, fixture: fixture), ["unsupported-schema"])

        XCTAssertEqual(
            StudyPackageContract.validate(
                manifest: fixture.manifest,
                expectedSessionID: UUID(),
                fileData: fixture.files
            ),
            ["session-mismatch"]
        )

        var reorderedMembers = fixture.manifest
        reorderedMembers.contentFiles.reverse()
        XCTAssertEqual(validationFailures(for: reorderedMembers, fixture: fixture), ["unexpected-content-files"])

        var extraDigest = fixture.manifest
        extraDigest.fileDigests["unexpected.json"] = "not-a-content-digest"
        XCTAssertEqual(validationFailures(for: extraDigest, fixture: fixture), ["unexpected-digest-files"])

        var extraData = fixture.files
        extraData["unexpected.json"] = Data("extra".utf8)
        XCTAssertEqual(
            StudyPackageContract.validate(
                manifest: fixture.manifest,
                expectedSessionID: fixture.sessionID,
                fileData: extraData
            ),
            ["missing-or-extra-data"]
        )
    }

    func testStudyPackageContractRejectsTamperingUnsafeScopesAndIncompleteProvenance() {
        let fixture = studyFixture()
        var tampered = fixture.files
        tampered["session.json"] = Data("tampered-session".utf8)
        XCTAssertEqual(
            StudyPackageContract.validate(
                manifest: fixture.manifest,
                expectedSessionID: fixture.sessionID,
                fileData: tampered
            ),
            ["digest-mismatch:session.json"]
        )

        var evidenceSafeWithResearch = fixture.manifest
        evidenceSafeWithResearch.includedScopes.insert(.researchProcessing)
        XCTAssertEqual(validationFailures(for: evidenceSafeWithResearch, fixture: fixture), ["safe-mode-research-scope"])

        var experimentalWithoutResearch = fixture.manifest
        experimentalWithoutResearch.operatingMode = .experimentalResearch
        XCTAssertEqual(validationFailures(for: experimentalWithoutResearch, fixture: fixture), ["experimental-scope-missing"])

        var incompleteProvenance = fixture.manifest
        incompleteProvenance.provenance.algorithmVersion = ""
        XCTAssertEqual(validationFailures(for: incompleteProvenance, fixture: fixture), ["incomplete-generator-provenance"])
    }

    private func studyFixture() -> (sessionID: UUID, manifest: StudyExportManifest, files: [String: Data]) {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let files = Dictionary(uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.map {
            ($0, Data("deterministic-fixture:\($0)".utf8))
        })
        let provenance = BuildProvenance({
            var values = BuildProvenance.Values()
            values.semanticVersion = "1.0.0"
            values.buildNumber = "1"
            values.algorithmVersion = "fixture-algorithm"
            values.evidenceRegistryVersion = "fixture-registry"
            return values
        }())
        let manifest = StudyExportManifest({
            var values = StudyExportManifest.Values()
            values.sessionID = sessionID
            values.provenance = provenance
            values.fileDigests = files.mapValues(digest)
            values.contentFiles = StudyPackageContract.expectedContentFiles
            values.includedScopes = [.collection, .secondaryUse, .externalSharing]
            return values
        }())
        return (sessionID, manifest, files)
    }

    private func validationFailures(
        for manifest: StudyExportManifest,
        fixture: (sessionID: UUID, manifest: StudyExportManifest, files: [String: Data])
    ) -> [String] {
        StudyPackageContract.validate(manifest: manifest, expectedSessionID: fixture.sessionID, fileData: fixture.files)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
