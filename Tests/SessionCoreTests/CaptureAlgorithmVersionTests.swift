import SessionCore
import XCTest

final class CaptureAlgorithmVersionTests: XCTestCase {
    func testVersionLiteralsAreFrozen() {
        XCTAssertEqual(CaptureAlgorithmVersion.directObservability, "capture-observability-v1")
        XCTAssertEqual(CaptureAlgorithmVersion.studyPackage, "study-package-v1")
    }
}
