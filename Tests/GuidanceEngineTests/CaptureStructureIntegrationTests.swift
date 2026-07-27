import XCTest
@testable import GuidanceEngine

/// Integration coverage for presets, structure observations, Vision wiring, and research coding.
final class CaptureStructureIntegrationTests: XCTestCase {

    // MARK: Presets

    func testTwelvePresetsEncodeDistinctResearchCaptureBars() {
        XCTAssertEqual(TeachingSituationID.allCases.count, 12)
        XCTAssertEqual(TeachingSituationCatalogue.count, 12)
        var configs: [TeachingSituationID: GuidanceConfig] = [:]
        for id in TeachingSituationID.allCases {
            let p = TeachingSituationCatalogue.preset(for: id)
            XCTAssertFalse(p.expectedScenes.isEmpty, "\(id)")
            XCTAssertFalse(p.ipnEmphasis.isEmpty, "\(id)")
            XCTAssertFalse(p.expectedTIMSSActivities.isEmpty, "\(id)")
            XCTAssertFalse(p.gtiEmphasis.isEmpty, "\(id)")
            XCTAssertFalse(p.preferredLayouts.isEmpty, "\(id)")
            configs[id] = .forTeachingSituation(id)
        }
        guard let frontal = configs[.frontalBoardInstruction],
              let group = configs[.collaborativeGroupWork],
              let demo = configs[.teacherDemonstration] else {
            return XCTFail("Expected required preset configurations")
        }
        XCTAssertGreaterThan(frontal.boardMinScore, group.boardMinScore)
        XCTAssertGreaterThan(demo.minPersonBoardCoPresence, group.minPersonBoardCoPresence)
        XCTAssertGreaterThan(group.minPersonCoverage, frontal.minPersonCoverage - 0.001)
    }

    // MARK: Structure sufficiency (scene vs preset, not placement alone)

    func testStructureSufficiencyDiffersByPresetOnSameCV() {
        let cv = CVFeatures.fixtureClassroomPresent()
        let frontalScene = TeachingSceneAssessor.assess(cv: cv, preset: .frontalBoardInstruction)
        let groupScene = TeachingSceneAssessor.assess(cv: cv, preset: .collaborativeGroupWork)
        let frontal = ResearchStructureAssessor.assess(
            cv: cv, scene: frontalScene, teachingSituation: .frontalBoardInstruction
        )
        let group = ResearchStructureAssessor.assess(
            cv: cv, scene: groupScene, teachingSituation: .collaborativeGroupWork
        )
        XCTAssertTrue(frontal.sufficient, frontal.summaryDE)
        XCTAssertFalse(group.sufficient, group.summaryDE)
        XCTAssertGreaterThan(frontal.score, group.score)
        XCTAssertTrue(frontal.checks.contains { $0.id == "sceneMatch" && $0.ok })
        XCTAssertTrue(group.checks.contains { $0.id == "sceneMatch" && !$0.ok } || !group.sufficient)

        let failed = ResearchStructureAssessor.assess(
            cv: .fixtureAnalysisFailed(),
            scene: TeachingSceneAssessor.assess(cv: .fixtureAnalysisFailed(), preset: .frontalBoardInstruction),
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertFalse(failed.sufficient)
        XCTAssertEqual(failed.score, 0)
    }

    func testResearchFixturesSufficeForIntendedPresets() {
        let pairs: [(CVFeatures, TeachingSituationID)] = [
            (.fixtureClassroomPresent(), .frontalBoardInstruction),
            (.fixtureGroupWork(), .collaborativeGroupWork),
            (.fixtureDialoguePair(), .teacherLedDialogue),
            (.fixturePartnerWork(), .partnerWork),
            (.fixtureStudentAtBoard(), .studentBoardPresentation),
            (.fixtureExperimentSpread(), .handsOnExperiment),
            (.fixtureCircleDiscussion(), .circleOrPlenumDiscussion),
            (.fixtureManagementOverview(), .classroomManagementOverview),
            (.fixtureSeatworkScattered(), .individualSeatwork),
            (.fixtureTeacherDemonstration(), .teacherDemonstration),
            (.fixtureTransitionOrganization(), .transitionOrganization),
            (.fixtureFormativeAssessment(), .formativeAssessmentDialogue)
        ]
        for (cv, situation) in pairs {
            let scene = TeachingSceneAssessor.assess(cv: cv, preset: situation)
            let s = ResearchStructureAssessor.assess(cv: cv, scene: scene, teachingSituation: situation)
            XCTAssertTrue(
                s.sufficient || s.score >= 0.45,
                "\(situation) fixture insufficient: \(s.summaryDE) score=\(s.score) scene=\(scene.sceneType)"
            )
            XCTAssertTrue(scene.matchesPreset || scene.presetMatchScore >= 0.45,
                          "\(situation) scene match weak: \(scene.summaryDE)")
        }
    }

    // MARK: Production Vision source (structure → pure features)

    func testProductionVisionEmitsResearchStructureSignals() throws {
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let src = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift",
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        for token in [
            "VNDetectRectanglesRequest",
            "VNDetectHumanRectanglesRequest",
            "VNDetectFaceRectanglesRequest",
            "VNDetectDocumentSegmentationRequest",
            "VNRecognizeTextRequest",
            "VNDetectHumanBodyPoseRequest",
            "VNGenerateAttentionBasedSaliencyImageRequest",
            "ClassroomLayoutAnalyzer",
            "secondaryWritingSurfaceSupport",
            "secondaryBoardSupport",
            "elevatedGesture",
            "presentationFocus",
            "interactionDensity",
            "analysisSucceeded: false",
            "configure(for:"
        ] {
            XCTAssertTrue(src.contains(token), "Vision adapter missing \(token)")
        }
        let sampler = try String(
            contentsOf: root.appendingPathComponent(
                "App/Unterrichtsvideographie/Live/FrameSampler.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(sampler.contains("vision.analyze(pixelBuffer:"))
        XCTAssertTrue(sampler.contains("configureVision"))
    }

    // MARK: IPN / TIMSS / GTI completeness

    func testCodingFamiliesAreCompleteAndStructureModulatesConfidence() {
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)

        let goodScene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction
        )
        let good = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: goodScene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: .lessonAnalysis
        )
        XCTAssertEqual(good.ipnDimensions.count, 7)
        XCTAssertEqual(good.gtiDimensions.count, 8)
        XCTAssertFalse(good.timssActivities.isEmpty)
        XCTAssertGreaterThan(good.overallConfidence, 0.25)

        let empty = testCodingResult(
            cv: .fixtureEmptyRoom(),
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(empty.ipnDimensions.isEmpty)
        XCTAssertEqual(empty.primaryTIMSS, .unclearOrNonInstructional)

        let failed = PedagogicalCoder.code(
            cv: .fixtureAnalysisFailed(),
            scene: TeachingSceneAssessor.assess(cv: .fixtureAnalysisFailed(), preset: .frontalBoardInstruction),
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(failed.ipnDimensions.isEmpty)
        XCTAssertTrue(failed.gtiDimensions.isEmpty)
        XCTAssertEqual(failed.overallConfidence, 0)

        // GTI domains
        let domains = Set(good.gtiDimensions.compactMap { GTIQualityCode(rawValue: $0.code)?.domain })
        XCTAssertTrue(domains.contains("classroomManagement"))
        XCTAssertTrue(domains.contains("socialEmotionalSupport"))
        XCTAssertTrue(domains.contains("instruction"))
    }

    // MARK: End-to-end guidance engine integration

    func testGuidanceSurfacesStructureSufficiencyAndCoding() {
        let good = testGuidanceResult(
            frame: Self.goodFrame(),
            analysisFocus: .lessonAnalysis
        )
        XCTAssertTrue([
            good.structureSufficiency.sufficient,
            good.structureSufficiency.score >= 0.5
        ].contains(true))
        XCTAssertFalse(good.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertFalse(good.pedagogicalCoding.gtiDimensions.isEmpty)
        XCTAssertEqual(good.pedagogicalCoding.analysisFocus, .lessonAnalysis)
        let goodTipIDs = Set(good.tips.map(\.id))
        let hasPositiveStructureTip = !goodTipIDs.isDisjoint(
            with: ["structure-sufficiency-ok", "unvalidated-rule-set-pass"]
        )
        XCTAssertTrue([hasPositiveStructureTip, good.structureSufficiency.sufficient].contains(true))

        let mismatch = testGuidanceResult(
            frame: Self.goodFrame(),
            teachingSituation: .collaborativeGroupWork
        )
        XCTAssertFalse(mismatch.structureSufficiency.sufficient)
        let mismatchTipIDs = Set(mismatch.tips.map(\.id))
        let hasMismatchTip = !mismatchTipIDs.isDisjoint(
            with: ["structure-sufficiency-fail", "scene-preset-mismatch"]
        )
        XCTAssertTrue([hasMismatchTip, !mismatch.scene.matchesPreset].contains(true))
        // Same placement frame, different research outcome by preset.
        XCTAssertNotEqual(good.scene.matchesPreset, mismatch.scene.matchesPreset)
    }

    func testClassroomAndGroupPresetMatrix() {
        let fixtures: [(String, CVFeatures)] = [
            ("classroom", .fixtureClassroomPresent()),
            ("group", .fixtureGroupWork()),
            ("empty", .fixtureEmptyRoom())
        ]
        let rows = ResearchStructureAssessor.matrix(fixtures: fixtures)
        XCTAssertEqual(rows.count, TeachingSituationID.allCases.count * fixtures.count)
        let classroomFrontal = rows.first {
            $0.preset == .frontalBoardInstruction && $0.fixture == "classroom"
        }
        let classroomGroup = rows.first {
            $0.preset == .collaborativeGroupWork && $0.fixture == "classroom"
        }
        guard let classroomFrontal, let classroomGroup else {
            return XCTFail("Expected classroom rows for frontal and group presets")
        }
        XCTAssertTrue(classroomFrontal.sufficient || classroomFrontal.score > classroomGroup.score)
        let emptyAny = rows.filter { $0.fixture == "empty" }
        XCTAssertTrue(emptyAny.allSatisfy { !$0.sufficient })
    }

    private static func goodFrame() -> FrameMetrics {
        testStandardGoodFrame()
    }
}
