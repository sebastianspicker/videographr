@testable import ExperimentalResearch
import GuidanceEngine
import SessionCore
import XCTest

final class CaptureSessionResearchReportTests: XCTestCase {
    private let provenance = ResearchArtifactProvenance(("1.0", "1", 2, "algo", "registry"))

    func testEvidenceSafeSessionYieldsNoReportOrScaffold() {
        var session = CaptureSession()
        session.latestCodingSnapshot = snapshot()
        session.buildProvenance = buildProvenance()
        XCTAssertEqual(session.operatingMode, .evidenceSafe)
        XCTAssertNil(session.researchCaptureReport(generatorProvenance: buildProvenance()))
        XCTAssertEqual(session.reflectionScaffoldNotes(), [:])
    }

    func testExperimentalSessionWithoutSnapshotYieldsNothing() {
        var session = CaptureSession()
        session.operatingMode = .experimentalResearch
        session.buildProvenance = buildProvenance()
        XCTAssertNil(session.researchCaptureReport(generatorProvenance: buildProvenance()))
        XCTAssertEqual(session.reflectionScaffoldNotes(), [:])
    }

    func testExperimentalSessionBuildsReportFromSnapshot() throws {
        var session = CaptureSession()
        session.operatingMode = .experimentalResearch
        session.buildProvenance = buildProvenance()
        session.latestCodingSnapshot = snapshot()
        let report = try XCTUnwrap(session.researchCaptureReport(generatorProvenance: buildProvenance()))
        XCTAssertEqual(report.snapshotCount, 1)
        XCTAssertEqual(report.id, session.id)
        XCTAssertFalse(session.reflectionScaffoldNotes().isEmpty)
    }

    func testReportRequiresCaptureProvenance() {
        var session = CaptureSession()
        session.operatingMode = .experimentalResearch
        session.latestCodingSnapshot = snapshot()
        XCTAssertNil(session.researchCaptureReport(generatorProvenance: buildProvenance()))
    }

    func testReconstructionRestoresKnownRawValues() {
        var session = CaptureSession()
        session.teachingSituation = .collaborativeGroupWork
        var values = snapshotValues()
        values.primaryTIMSS = TIMSSActivityCode.groupWork.rawValue
        values.primaryGTI = GTIQualityCode.subjectClarity.rawValue
        values.sceneType = TeachingSceneType.circleDiscussion.rawValue
        values.layoutPattern = ClassroomLayoutPattern.empty.rawValue
        let snap = ResearchCodingSnapshot(values)
        let coding = session.reflectionCodingResult(from: snap)
        XCTAssertEqual(coding.primaryTIMSS, .groupWork)
        XCTAssertEqual(coding.primaryGTI, .subjectClarity)
        XCTAssertEqual(coding.sceneType, .circleDiscussion)
        XCTAssertEqual(coding.layoutPattern, .empty)
        XCTAssertEqual(coding.teachingSituation, .collaborativeGroupWork)
        XCTAssertEqual(session.reflectionSceneAssessment(from: snap).sceneType, .circleDiscussion)
    }

    func testReconstructionFallsBackForUnknownRawValues() {
        let session = CaptureSession()
        var values = snapshotValues()
        values.primaryTIMSS = "nope"
        values.primaryGTI = "nope"
        values.sceneType = "nope"
        values.layoutPattern = "nope"
        let snap = ResearchCodingSnapshot(values)
        let coding = session.reflectionCodingResult(from: snap)
        XCTAssertEqual(coding.primaryTIMSS, .unclearOrNonInstructional)
        XCTAssertEqual(coding.primaryGTI, .instructionalQuality)
        XCTAssertEqual(coding.sceneType, .emptyOrUnusable)
        XCTAssertEqual(coding.layoutPattern, .unknown)
        let scene = session.reflectionSceneAssessment(from: snap)
        XCTAssertEqual(scene.sceneType, .emptyOrUnusable)
        XCTAssertEqual(scene.layoutPattern, .unknown)
    }

    func testReconstructionCarriesSnapshotRowsAndUnknownFamilyFallsBackToIPN() {
        let session = CaptureSession()
        var values = snapshotValues()
        values.ipn = [ResearchCodeRow(
            id: "ipn-1", family: "unknownFamily", code: "goalOrientation", labelDE: "Ziel",
            level: 0.5, confidence: 0.4, rationaleDE: "weil"
        )]
        let coding = session.reflectionCodingResult(from: ResearchCodingSnapshot(values))
        XCTAssertEqual(coding.ipnDimensions.first?.family, .ipnProcessQuality)
        XCTAssertEqual(coding.ipnDimensions.first?.code, "goalOrientation")
        XCTAssertEqual(coding.ipnDimensions.first?.level, 0.5)
    }

    private func buildProvenance() -> BuildProvenance {
        var values = BuildProvenance.Values()
        values.semanticVersion = provenance.semanticVersion
        values.buildNumber = provenance.buildNumber
        values.schemaVersion = provenance.schemaVersion
        values.algorithmVersion = provenance.algorithmVersion
        values.evidenceRegistryVersion = provenance.evidenceRegistryVersion
        return BuildProvenance(values)
    }

    private func snapshotValues() -> ResearchCodingSnapshot.Values {
        ResearchCodingSnapshot.Values(provenance: provenance)
    }

    private func snapshot() -> ResearchCodingSnapshot {
        var values = snapshotValues()
        values.primaryTIMSS = TIMSSActivityCode.wholeClassInstruction.rawValue
        values.primaryGTI = GTIQualityCode.instructionalQuality.rawValue
        values.sceneType = TeachingSceneType.boardCentricFrontal.rawValue
        values.layoutPattern = ClassroomLayoutPattern.empty.rawValue
        return ResearchCodingSnapshot(values)
    }
}
