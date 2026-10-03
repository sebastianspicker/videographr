import SessionCore
import XCTest

@testable import Unterrichtsvideographie

final class BuildProvenanceFactoryTests: XCTestCase {
    /// Persisted algorithm identifiers must stay byte-identical across refactors.
    func testComposedAlgorithmVersionsArePinned() {
        XCTAssertEqual(
            BuildProvenanceFactory.capture(for: .evidenceSafe).algorithmVersion,
            "capture-observability-v1"
        )
        XCTAssertEqual(
            BuildProvenanceFactory.capture(for: .experimentalResearch).algorithmVersion,
            "capture-observability-v1+experimental-coding-rules-v1+frame-windows-v2"
        )
        XCTAssertEqual(BuildProvenanceFactory.export.algorithmVersion, "study-package-v1")
        XCTAssertEqual(
            BuildProvenanceFactory.researchArtifact.algorithmVersion,
            "capture-observability-v1+experimental-coding-rules-v1+frame-windows-v2"
        )
    }
}
