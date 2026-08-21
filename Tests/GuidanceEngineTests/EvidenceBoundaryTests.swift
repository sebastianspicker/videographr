import XCTest
@testable import GuidanceEngine

final class EvidenceBoundaryTests: XCTestCase {
    func testEvidenceRegistryRejectsUnsupportedEffectivenessClaims() {
        XCTAssertTrue(EvidenceClaimRegistry.validate().isEmpty)
        for claim in ["Diese Aufnahme ist forschungstauglich.", "Psychometrisch validierte Kodierungen."] {
            XCTAssertTrue(EvidenceClaimRegistry.containsProhibitedWording(claim))
        }
        XCTAssertFalse(EvidenceClaimRegistry.containsProhibitedWording("Kein validiertes Kodierinstrument."))
    }
}
