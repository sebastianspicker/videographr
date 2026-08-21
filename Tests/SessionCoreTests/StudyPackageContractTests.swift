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

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
