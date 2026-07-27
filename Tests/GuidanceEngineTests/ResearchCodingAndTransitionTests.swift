import XCTest
@testable import GuidanceEngine

/// Contract coverage for checklists, transitions, codebooks, matrices, and readiness reports.
final class ResearchCodingAndTransitionTests: XCTestCase {

    func testPresetResearchChecklistIsNotEmpty() {
        for id in TeachingSituationID.allCases {
            let p = TeachingSituationCatalogue.preset(for: id)
            XCTAssertGreaterThanOrEqual(p.researchCaptureChecklistDE.count, 3, "\(id)")
            XCTAssertFalse(p.timssScriptFamilyDE.isEmpty)
            XCTAssertTrue(p.researchCaptureChecklistDE.contains { $0.contains("Preset") || $0.contains("Szene") })
        }
    }

    func testSceneTransitionDetectorFiresOnChange() {
        var det = SceneTransitionDetector()
        let a = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let b = TeachingSceneAssessor.assess(cv: .fixtureGroupWork(), preset: .collaborativeGroupWork)
        XCTAssertNil(det.observe(scene: a)) // first sample seeds only
        let event = det.observe(scene: b)
        guard let event else { return XCTFail("Expected a scene transition event") }
        XCTAssertEqual(event.fromScene, TeachingSceneType.boardCentricFrontal.rawValue)
        XCTAssertFalse(event.noteDE.isEmpty)
        XCTAssertEqual(det.events.count, 1)
    }

    func testActorScaleVarianceFusion() {
        let uniform = [
            ImageNormalizedRect(x: 0.2, y: 0.4, width: 0.1, height: 0.25),
            ImageNormalizedRect(x: 0.4, y: 0.4, width: 0.1, height: 0.24),
            ImageNormalizedRect(x: 0.6, y: 0.4, width: 0.1, height: 0.26)
        ]
        let mixed = [
            ImageNormalizedRect(x: 0.1, y: 0.3, width: 0.08, height: 0.12),
            ImageNormalizedRect(x: 0.4, y: 0.35, width: 0.2, height: 0.45)
        ]
        let vUniform = CVFeatureFusion.actorScaleVariance(personRects: uniform)
        let vMixed = CVFeatureFusion.actorScaleVariance(personRects: mixed)
        XCTAssertLessThan(vUniform, vMixed)
        XCTAssertGreaterThan(vMixed, 0.15)
    }

    func testVisionActorScaleAndPoseAreWired() throws {
        let src = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift",
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        XCTAssertTrue(src.contains("actorScaleVariance"))
        XCTAssertTrue(src.contains("poseConfidenceMean"))
        XCTAssertTrue(src.contains("saliencyPeopleOverlap"))
    }

    func testTopKTIMSSAndGTIBalance() {
        let scene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        let topT = coding.topTIMSS(k: 3)
        XCTAssertEqual(topT.count, min(3, coding.timssActivities.count))
        XCTAssertEqual(topT.first?.code, coding.primaryTIMSS.rawValue)
        let topG = coding.topGTI(k: 3)
        XCTAssertEqual(topG.count, 3)
        XCTAssertGreaterThanOrEqual(coding.gtiDomainBalance, 0)
        XCTAssertLessThanOrEqual(coding.gtiDomainBalance, 1)
        XCTAssertTrue(coding.primaryTIMSSMatchesPresetExpectation)
    }

    func testResearchCodebookCatalogueIsComplete() {
        XCTAssertEqual(ResearchCodebookCatalogue.ipnEntries.count, 7)
        XCTAssertEqual(ResearchCodebookCatalogue.timssEntries.count, 12)
        XCTAssertEqual(ResearchCodebookCatalogue.gtiEntries.count, 8)
        XCTAssertEqual(ResearchCodebookCatalogue.allEntries.count, 7 + 12 + 8)
        XCTAssertEqual(ResearchCodebookCatalogue.familyCounts["ipn"], 7)
        XCTAssertTrue(ResearchCodebookCatalogue.softwareBoundaryDE.contains("Proxy")
                      || ResearchCodebookCatalogue.softwareBoundaryDE.contains("proxy")
                      || ResearchCodebookCatalogue.softwareBoundaryDE.contains("multi-rater"))
    }

    func testTIMSSAlignmentTipWhenPresetMismatches() {
        // Classroom geometry coded as whole-class under group preset → alignment tip possible
        let r = testGuidanceResult(
            frame: Self.goodFrame(),
            teachingSituation: .collaborativeGroupWork
        )
        // May surface timss-preset-alignment and/or structure fail
        let ids = Set(r.tips.map(\.id))
        XCTAssertTrue(
            ids.contains("timss-preset-alignment")
                || ids.contains("structure-sufficiency-fail")
                || ids.contains("scene-preset-mismatch")
                || !r.pedagogicalCoding.primaryTIMSSMatchesPresetExpectation
        )
    }

    func testStructureMatrixExportsIntendedPairs() {
        let cells = ResearchStructureMatrixExport.build()
        XCTAssertEqual(
            cells.count,
            TeachingSituationID.allCases.count * ResearchStructureMatrixExport.defaultFixtures.count
        )
        for pair in ResearchStructureMatrixExport.intendedPairs {
            let expectedIdentity = (pair.fixture, pair.preset.rawValue)
            let cell = cells.first { ($0.fixture, $0.preset) == expectedIdentity }
            guard let cell else { return XCTFail("missing \(pair)") }
            XCTAssertTrue(
                [cell.sufficient, cell.score >= 0.45, cell.matchesPreset].contains(true),
                "intended pair weak: \(pair) score=\(cell.score) scene=\(cell.scene)"
            )
        }
        let emptyCells = cells.filter { $0.fixture == "empty" }
        XCTAssertTrue(emptyCells.allSatisfy { !$0.sufficient })
    }

    func testUnvalidatedRuleSetReportFromGuidance() {
        let good = testGuidanceResult(
            frame: Self.goodFrame(),
            analysisFocus: .lessonAnalysis
        )
        let report = ResearchReadinessReport.build(from: good)
        XCTAssertEqual(report.ipnCount, 7)
        XCTAssertEqual(report.gtiCount, 8)
        XCTAssertTrue(report.sceneMatchesPreset)
        XCTAssertFalse(report.summaryDE.isEmpty)
        XCTAssertTrue(report.unvalidatedRulesPass || report.structureScore >= 0.45)

        let bad = testGuidanceResult(
            frame: Self.goodFrame(),
            cv: .fixtureEmptyRoom()
        )
        let badReport = ResearchReadinessReport.build(from: bad)
        XCTAssertFalse(badReport.unvalidatedRulesPass)
    }

    func testFullStackResearchCodingIntegration() {
        XCTAssertEqual(TeachingSituationCatalogue.count, 12)
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)
        let r = testGuidanceResult(
            frame: Self.goodFrame(),
            analysisFocus: .professionalVision
        )
        XCTAssertFalse(r.structureSufficiency.checks.isEmpty)
        XCTAssertFalse(r.pedagogicalCoding.topTIMSS().isEmpty)
        XCTAssertFalse(r.pedagogicalCoding.topGTI().isEmpty)
        let report = ResearchReadinessReport.build(from: r)
        XCTAssertEqual(report.primaryTIMSS, r.pedagogicalCoding.primaryTIMSS)
        let checklist = TeachingSituationCatalogue.preset(for: .frontalBoardInstruction).researchCaptureChecklistDE
        XCTAssertGreaterThanOrEqual(checklist.count, 4)
    }

    private static func goodFrame() -> FrameMetrics {
        testStandardGoodFrame()
    }
}
