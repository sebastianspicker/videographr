import XCTest
@testable import GuidanceEngine

/// Drives shipped preset catalogue, scene assessment, IPN/TIMSS coding, and preset-conditional guidance.
final class TeachingSceneAndCodingTests: XCTestCase {

    // MARK: - Preset catalogue

    func testRichTeachingSituationCatalogue() {
        XCTAssertGreaterThanOrEqual(
            TeachingSituationCatalogue.count,
            TeachingSituationCatalogue.richMinimumCount
        )
        XCTAssertEqual(TeachingSituationID.allCases.count, TeachingSituationCatalogue.all.count)
        for preset in TeachingSituationCatalogue.all {
            XCTAssertFalse(preset.titleDE.isEmpty)
            XCTAssertFalse(preset.summaryDE.isEmpty)
            XCTAssertFalse(preset.expectedScenes.isEmpty)
            XCTAssertFalse(preset.mismatchHintDE.isEmpty)
            XCTAssertFalse(preset.ipnEmphasis.isEmpty)
            XCTAssertFalse(preset.expectedTIMSSActivities.isEmpty)
        }
    }

    func testPresetConfigsDifferForBoardVsGroup() {
        let frontal = GuidanceConfig.forTeachingSituation(.frontalBoardInstruction)
        let group = GuidanceConfig.forTeachingSituation(.collaborativeGroupWork)
        XCTAssertGreaterThan(frontal.boardMinScore, group.boardMinScore)
        XCTAssertGreaterThan(frontal.minPersonBoardCoPresence, group.minPersonBoardCoPresence)
        XCTAssertGreaterThan(group.minPersonCoverage, 0)
    }

    // MARK: - Scene assessment

    func testClassroomFixtureIsBoardCentricFrontal() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            frame: Self.goodFrame(),
            preset: .frontalBoardInstruction
        )
        XCTAssertEqual(scene.sceneType, .boardCentricFrontal)
        XCTAssertTrue(scene.matchesPreset)
        XCTAssertGreaterThan(scene.presetMatchScore, 0.55)
    }

    func testEmptyRoomIsUnusableAndMismatchesPresets() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureEmptyRoom(),
            preset: .frontalBoardInstruction
        )
        XCTAssertEqual(scene.sceneType, .emptyOrUnusable)
        XCTAssertFalse(scene.matchesPreset)
        XCTAssertLessThan(scene.presetMatchScore, 0.3)
    }

    func testGroupWorkFixtureClassifiesAsMultiPersonGroup() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureGroupWork(),
            preset: .collaborativeGroupWork
        )
        XCTAssertEqual(scene.sceneType, .multiPersonGroup)
        XCTAssertTrue(scene.matchesPreset, scene.summaryDE)
    }

    func testSameGeometryDifferentPresetsYieldDifferentMatch() {
        let cv = CVFeatures.fixtureClassroomPresent()
        let frontal = TeachingSceneAssessor.assess(cv: cv, preset: .frontalBoardInstruction)
        let group = TeachingSceneAssessor.assess(cv: cv, preset: .collaborativeGroupWork)
        // Board-centric classroom matches frontal; group preset prefers multi-person clusters.
        XCTAssertTrue(frontal.matchesPreset)
        XCTAssertGreaterThan(frontal.presetMatchScore, group.presetMatchScore)
    }

    func testFailedCVDoesNotInventScene() {
        let scene = TeachingSceneAssessor.assess(cv: .empty, preset: .frontalBoardInstruction)
        XCTAssertEqual(scene.sceneType, .emptyOrUnusable)
        XCTAssertEqual(scene.confidence, 0)
        XCTAssertFalse(scene.matchesPreset)
    }

    func testStudentAtBoardAndDialogueFixtures() {
        let presentation = TeachingSceneAssessor.assess(
            cv: .fixtureStudentAtBoard(),
            preset: .studentBoardPresentation
        )
        XCTAssertTrue(
            presentation.sceneType == .studentAtBoard || presentation.sceneType == .boardCentricFrontal,
            "got \(presentation.sceneType)"
        )
        XCTAssertTrue(presentation.matchesPreset, presentation.summaryDE)

        let dialogue = TeachingSceneAssessor.assess(
            cv: .fixtureDialoguePair(),
            preset: .teacherLedDialogue
        )
        XCTAssertTrue(
            dialogue.sceneType == .dialoguePair || dialogue.sceneType == .boardCentricFrontal,
            "got \(dialogue.sceneType)"
        )
        XCTAssertTrue(dialogue.matchesPreset, dialogue.summaryDE)
    }

    // MARK: - Preset-conditional guidance (shipped evaluate path)

    func testSamePlacementDifferentPresetsChangeTipsOrReadiness() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        let frame = Self.goodFrame()
        let cv = CVFeatures.fixtureClassroomPresent() // board-centric, 4 people

        let frontalInput = experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: cv,
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        )
        let groupInput = experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: cv,
                motion: .stable,
                teachingSituation: .collaborativeGroupWork,
                analysisFocus: nil
            )
        )

        let frontal = engine.evaluate(frontalInput)
        let group = engine.evaluate(groupInput)

        XCTAssertEqual(frontal.teachingSituation, .frontalBoardInstruction)
        XCTAssertEqual(group.teachingSituation, .collaborativeGroupWork)
        XCTAssertNotEqual(frontal.scene.presetMatchScore, group.scene.presetMatchScore, accuracy: 0.001)

        // Scene labels on results should differ in match status or tips.
        let commonMismatchIDs: Set<String> = ["scene-preset-mismatch", "preset-wants-group"]
        let frontalMismatch = !Set(frontal.tips.map(\.id)).isDisjoint(with: commonMismatchIDs)
        let groupMismatchIDs = commonMismatchIDs.union(["preset-people-shortfall"])
        let groupMismatch = !Set(group.tips.map(\.id)).isDisjoint(with: groupMismatchIDs)
        let frontalSceneOK = frontal.placement.dimensions.first { $0.id == "teachingScene" }?.ok
        let groupSceneOK = group.placement.dimensions.first { $0.id == "teachingScene" }?.ok
        // Group preset on board-centric may tip for wanting group; frontal should match better.
        XCTAssertTrue(frontal.scene.matchesPreset)
        XCTAssertTrue(
            [
                frontal.scene.presetMatchScore > group.scene.presetMatchScore,
                frontalMismatch != groupMismatch,
                frontalSceneOK != groupSceneOK
            ].contains(true),
            "Expected preset-conditional difference; frontal match=\(frontal.scene.presetMatchScore) group=\(group.scene.presetMatchScore) tipsF=\(frontal.tips.map(\.id)) tipsG=\(group.tips.map(\.id))"
        )
    }

    func testGroupFixtureFailsFrontalBoardRequirementPath() {
        let engine = GuidanceEngine()
        let input = experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureGroupWork(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        )
        let result = engine.evaluate(input)
        // Group work has weak board - frontal preset requires board → mismatch or board tips.
        let sceneDim = result.placement.dimensions.first { $0.id == "teachingScene" }
        XCTAssertNotNil(sceneDim)
        XCTAssertTrue(
            !result.scene.matchesPreset
                || result.tips.contains { $0.id.contains("board") || $0.id.contains("scene") || $0.id.contains("preset") },
            "tips=\(result.tips.map(\.id)) scene=\(result.scene)"
        )
    }

    func testGroupFixtureMatchesGroupPresetBetterThanFrontal() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        let frame = Self.goodFrame()
        let cv = CVFeatures.fixtureGroupWork()

        let asGroup = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: cv,
                motion: .stable,
                teachingSituation: .collaborativeGroupWork,
                analysisFocus: nil
            )
        ))
        let asFrontal = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: cv,
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))

        XCTAssertEqual(asGroup.scene.sceneType, .multiPersonGroup)
        XCTAssertTrue(asGroup.scene.matchesPreset, asGroup.scene.summaryDE)
        XCTAssertGreaterThan(asGroup.scene.presetMatchScore, asFrontal.scene.presetMatchScore)
    }

    func testGuidanceResultIncludesSceneAndCoding() {
        let result = GuidanceEngine().evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 0, rollDegrees: 0),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureClassroomPresent(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertNotEqual(result.scene.sceneType, .emptyOrUnusable)
        XCTAssertFalse(result.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertFalse(result.pedagogicalCoding.timssActivities.isEmpty)
        XCTAssertTrue(result.placement.dimensions.contains { $0.id == "teachingScene" })
    }

    // MARK: - IPN / TIMSS pedagogical coding

    func testIPNAndTIMSSCodeSetsDocumented() {
        // Full IPN set: Videostudie facets + process-quality extensions.
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertTrue(IPNDimensionCode.allCases.contains(.experimentation))
        XCTAssertTrue(IPNDimensionCode.allCases.contains(.errorCulture))
        XCTAssertTrue(IPNDimensionCode.allCases.contains(.classroomOrganization))
        XCTAssertGreaterThanOrEqual(TIMSSActivityCode.allCases.count, 8)
        for d in IPNDimensionCode.allCases {
            XCTAssertFalse(d.titleDE.isEmpty)
            XCTAssertFalse(d.researchNoteDE.isEmpty)
        }
        for a in TIMSSActivityCode.allCases {
            XCTAssertFalse(a.titleDE.isEmpty)
        }
    }

    func testCodingClassroomPresentHasBothFamilies() {
        let coding = testClassroomCoding(frame: Self.goodFrame())
        XCTAssertFalse(coding.ipnDimensions.isEmpty)
        XCTAssertFalse(coding.timssActivities.isEmpty)
        XCTAssertTrue(coding.ipnCodes.contains(IPNDimensionCode.classroomOrganization.rawValue))
        XCTAssertTrue(coding.ipnCodes.contains(IPNDimensionCode.goalOrientation.rawValue))
        XCTAssertTrue(coding.ipnCodes.contains(IPNDimensionCode.learningSupport.rawValue))
        XCTAssertNotEqual(coding.primaryTIMSS, .unclearOrNonInstructional)
        // Board-centric frontal → whole-class / public board work direction
        let primaryLevel = coding.timssActivities.first { $0.code == coding.primaryTIMSS.rawValue }?.level ?? 0
        XCTAssertGreaterThan(primaryLevel, 0.3)
        let boardWork = coding.timssActivities.first { $0.code == TIMSSActivityCode.publicBoardWork.rawValue }
        let groupWork = coding.timssActivities.first { $0.code == TIMSSActivityCode.groupWork.rawValue }
        XCTAssertNotNil(boardWork)
        if let boardWork, let groupWork {
            XCTAssertGreaterThan(boardWork.level, groupWork.level,
                                 "Board-heavy frontal should prefer public board over group work")
        }
    }

    func testCodingEmptyRoomDiffersFromClassroom() {
        let emptyScene = TeachingSceneAssessor.assess(cv: .fixtureEmptyRoom())
        let emptyCoding = PedagogicalCoder.code(
            cv: .fixtureEmptyRoom(),
            scene: emptyScene,
            teachingSituation: .frontalBoardInstruction
        )
        let classScene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent())
        let classCoding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: classScene,
            teachingSituation: .frontalBoardInstruction,
            frame: Self.goodFrame()
        )

        XCTAssertEqual(emptyCoding.primaryTIMSS, .unclearOrNonInstructional)
        // Insufficient signal → no invented IPN dimension levels.
        XCTAssertTrue(emptyCoding.ipnDimensions.isEmpty, "empty scene must not invent IPN codes")
        XCTAssertEqual(emptyCoding.timssActivities.count, 1)
        XCTAssertEqual(emptyCoding.timssActivities.first?.code, TIMSSActivityCode.unclearOrNonInstructional.rawValue)
        XCTAssertFalse(classCoding.ipnDimensions.isEmpty)
        let classGoal = classCoding.ipnDimensions.first { $0.code == IPNDimensionCode.goalOrientation.rawValue }?.level ?? 0
        XCTAssertGreaterThan(classGoal, 0.3)
        XCTAssertNotEqual(classCoding.primaryTIMSS, .unclearOrNonInstructional)
    }

    func testCodingGroupScenePrefersGroupWorkActivity() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureGroupWork(),
            preset: .collaborativeGroupWork
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureGroupWork(),
            scene: scene,
            teachingSituation: .collaborativeGroupWork
        )
        let groupLevel = coding.timssActivities.first { $0.code == TIMSSActivityCode.groupWork.rawValue }?.level ?? 0
        let boardLevel = coding.timssActivities.first { $0.code == TIMSSActivityCode.publicBoardWork.rawValue }?.level ?? 0
        XCTAssertGreaterThan(groupLevel, boardLevel,
                             "Group fixture should elevate groupWork over publicBoardWork")
        let social = coding.ipnDimensions.first { $0.code == IPNDimensionCode.socialClimate.rawValue }?.level ?? 0
        let goal = coding.ipnDimensions.first { $0.code == IPNDimensionCode.goalOrientation.rawValue }?.level ?? 0
        // Group scene: social climate elevated; goal weaker than board-centric classroom.
        XCTAssertGreaterThan(social, 0.2)
        XCTAssertLessThan(goal, 0.65)
    }

}
