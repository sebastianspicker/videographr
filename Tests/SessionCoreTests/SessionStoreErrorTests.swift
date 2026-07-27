import XCTest
@testable import SessionCore

extension SessionCoreTests {
    func testSessionStoreErrorsHaveActionableLocalizedDescriptions() {
        let errors: [SessionStoreError] = [
            .rootDirectoryIsSymbolicLink,
            .sessionIdentifierMismatch,
            .recordingDirectoryIsSymbolicLink,
            .recordingFileIsSymbolicLink,
            .recordingOutsideStore,
            .localArtifactPolicyMismatch,
            .sessionMetadataRollbackFailed
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.localizedDescription.contains("SessionStoreError"))
            XCTAssertFalse(error.localizedDescription.contains("/"))
        }
    }
}
