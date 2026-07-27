import XCTest
@testable import GuidanceEngine

/// Integration coverage from presets and direct structure signals through research coding.
final class GuidanceStructureIntegrationTests: XCTestCase {

    // Preset research bars
    func testPresetResearchBarsAreDistinct() {
        let frontal = TeachingSituationCatalogue.preset(for: .frontalBoardInstruction)
        let group = TeachingSituationCatalogue.preset(for: .collaborativeGroupWork)
        let dialogue = TeachingSituationCatalogue.preset(for: .teacherLedDialogue)
        XCTAssertGreaterThan(frontal.minResearchBoardScore, group.minResearchBoardScore)
        XCTAssertGreaterThan(frontal.minResearchCoPresence, group.minResearchCoPresence)
        XCTAssertGreaterThan(group.minResearchInteractionDensity, frontal.minResearchInteractionDensity - 0.001)
        XCTAssertGreaterThan(dialogue.minResearchInteractionDensity, 0.15)
        XCTAssertGreaterThan(frontal.minResearchBoardTextDensity, 0.1)
        XCTAssertEqual(group.minResearchBoardTextDensity, 0)
        XCTAssertEqual(TeachingSituationID.allCases.count, 12)
    }

    // Scene uses density/text/secondary (student at board path)
    func testTextAndCoPresenceDriveStudentAtBoardOrDemo() {
        let demo = TeachingSceneAssessor.assess(
            cv: .fixtureTeacherDemonstration(),
            preset: .teacherDemonstration
        )
        XCTAssertTrue(
            demo.sceneType == .teacherDemonstration
                || demo.sceneType == .studentAtBoard
                || demo.sceneType == .boardCentricFrontal
        )
        XCTAssertTrue(demo.matchesPreset)
        let student = TeachingSceneAssessor.assess(
            cv: .fixtureStudentAtBoard(),
            preset: .studentBoardPresentation
        )
        XCTAssertEqual(student.sceneType, .studentAtBoard)
        XCTAssertTrue(student.matchesPreset)
    }

    // Structure sufficiency uses research bars and extra checks
    func testStructureSufficiencyHasExtendedChecks() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let s = ResearchStructureAssessor.assess(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        let ids = Set(s.checks.map(\.id))
        for id in ["board", "boardText", "peopleCount", "peopleSpatial", "coPresence",
                   "layout", "sceneMatch", "stability", "interactionDensity"] {
            XCTAssertTrue(ids.contains(id), "missing check \(id)")
        }
        XCTAssertTrue(s.sufficient || s.score >= 0.5)
    }

    // Vision production signals (static)
    func testVisionSaliencyPeopleAndElevatedGestureAreWired() throws {
        let src = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift",
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        for t in ["saliencyPeopleOverlap", "elevatedGesture", "secondaryBoardSupport",
                  "presentationFocus", "interactionDensity", "analysisSucceeded: false"] {
            XCTAssertTrue(src.contains(t), t)
        }
    }

    // IPN/TIMSS/GTI completeness and structure-modulated confidence
    func testCodingFamiliesAndTIMSSAlignmentNote() {
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: .lessonAnalysis
        )
        XCTAssertEqual(coding.ipnDimensions.count, 7)
        XCTAssertEqual(coding.gtiDimensions.count, 8)
        XCTAssertFalse(coding.timssActivities.isEmpty)
        XCTAssertGreaterThan(coding.overallConfidence, 0.2)
        // Primary TIMSS for classroom should be whole-class or public board
        XCTAssertTrue(
            coding.primaryTIMSS == .wholeClassInstruction
                || coding.primaryTIMSS == .publicBoardWork
        )
        let domains = coding.gtiDomainLevels
        XCTAssertNotNil(domains["instruction"])
        XCTAssertNotNil(domains["classroomManagement"])
    }

    // Failed structure checks surface as tips
    func testStructureCheckTipsOnPresetMismatch() {
        let r = testGuidanceResult(
            frame: Self.goodFrame(),
            teachingSituation: .collaborativeGroupWork
        )
        XCTAssertFalse(r.structureSufficiency.sufficient)
        let tipIDs = Set(r.tips.map(\.id))
        XCTAssertTrue(
            tipIDs.contains("structure-sufficiency-fail")
                || tipIDs.contains(where: { $0.hasPrefix("structure-check-") })
                || tipIDs.contains("scene-preset-mismatch")
        )
    }

    // Placement includes structureSufficiency dimension
    func testPlacementDimensionStructureSufficiency() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let placement = testClassroomPlacement(scene: scene, frame: Self.goodFrame())
        let dim = placement.dimensions.first { $0.id == "structureSufficiency" }
        guard let dim else { return XCTFail("Expected structureSufficiency dimension") }
        XCTAssertTrue(dim.ok, dim.detailDE)
    }

    // The unvalidated rule-set composite includes a structure dimension.
    func testUnvalidatedRuleSetCompositeIncludesStructureDimension() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        let placement = testClassroomPlacement(scene: scene, frame: Self.goodFrame())
        let suff = ResearchStructureAssessor.assess(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        var qualityInput = ResearchCaptureQuality.AssessmentInput(
            placement: placement,
            scene: scene,
            coding: coding
        )
        qualityInput.teachingSituation = .frontalBoardInstruction
        qualityInput.structureSufficiency = suff
        let rq = ResearchCaptureQuality.assess(qualityInput)
        XCTAssertTrue(rq.dimensions.contains { $0.id == "structure" })
        XCTAssertTrue(rq.dimensions.contains { $0.id == "gtiDomains" })
        XCTAssertGreaterThanOrEqual(rq.dimensions.count, 5)
        XCTAssertNotEqual(rq.level, .unsuitable)
    }

    // End-to-end: same geometry, different presets, full stack
    func testSameGeometryWithDifferentPresetsAcrossFullStack() {
        let frame = Self.goodFrame()
        let cv = CVFeatures.fixtureClassroomPresent()
        let frontal = testGuidanceResult(
            frame: frame,
            cv: cv,
            analysisFocus: .lessonAnalysis
        )
        let group = testGuidanceResult(
            frame: frame,
            cv: cv,
            teachingSituation: .collaborativeGroupWork,
            analysisFocus: .studentThinking
        )
        XCTAssertTrue(frontal.scene.matchesPreset)
        XCTAssertFalse(group.scene.matchesPreset)
        XCTAssertTrue(frontal.structureSufficiency.sufficient || frontal.structureSufficiency.score > group.structureSufficiency.score)
        XCTAssertFalse(frontal.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertFalse(frontal.pedagogicalCoding.gtiDimensions.isEmpty)
        XCTAssertEqual(frontal.pedagogicalCoding.ipnDimensions.count, 7)
        XCTAssertEqual(frontal.pedagogicalCoding.gtiDimensions.count, 8)
        XCTAssertNotEqual(frontal.researchQuality.score, group.researchQuality.score)
        XCTAssertTrue(frontal.placement.dimensions.contains { $0.id == "structureSufficiency" })
        XCTAssertTrue(frontal.placement.dimensions.contains { $0.id == "teachingScene" })
    }

    private static func goodFrame() -> FrameMetrics {
        testStandardGoodFrame()
    }
}
