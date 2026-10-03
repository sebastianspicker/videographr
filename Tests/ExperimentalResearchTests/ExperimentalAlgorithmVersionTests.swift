import ExperimentalResearch
import XCTest

final class ExperimentalAlgorithmVersionTests: XCTestCase {
    func testVersionSuffixLiteralIsFrozen() {
        XCTAssertEqual(ExperimentalAlgorithmVersion.suffix, "experimental-coding-rules-v1+frame-windows-v2")
    }
}
