import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testStudentPresentationAndDialogueAndExperimentFullPath() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 1, rollDegrees: 0)
        let frame = Self.goodFrame()

        let presentation = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: .fixtureStudentAtBoard(),
                motion: .stable,
                teachingSituation: .studentBoardPresentation,
                analysisFocus: nil
            )
        ))
        XCTAssertTrue(presentation.scene.matchesPreset, presentation.scene.summaryDE)
        XCTAssertFalse(presentation.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertTrue(
            presentation.pedagogicalCoding.primaryTIMSS == .studentPresentation
                || presentation.pedagogicalCoding.primaryTIMSS == .publicBoardWork
        )

        let dialogue = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: .fixtureDialoguePair(),
                motion: .stable,
                teachingSituation: .teacherLedDialogue,
                analysisFocus: nil
            )
        ))
        XCTAssertTrue(dialogue.scene.matchesPreset, dialogue.scene.summaryDE)
        XCTAssertFalse(dialogue.pedagogicalCoding.timssActivities.isEmpty)

        let experiment = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: .fixtureExperimentSpread(),
                motion: .stable,
                teachingSituation: .handsOnExperiment,
                analysisFocus: nil
            )
        ))
        XCTAssertTrue(experiment.scene.matchesPreset || experiment.scene.presetMatchScore > 0.35,
                      experiment.scene.summaryDE)
        XCTAssertFalse(experiment.pedagogicalCoding.ipnDimensions.isEmpty)
    }

    func testFailedCVEmptyCodingAndUnusableScene() {
        let engine = GuidanceEngine()
        let result = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 0, rollDegrees: 0),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureAnalysisFailed(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertEqual(result.scene.sceneType, .emptyOrUnusable)
        XCTAssertFalse(result.scene.matchesPreset)
        XCTAssertTrue(result.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertEqual(result.pedagogicalCoding.primaryTIMSS, .unclearOrNonInstructional)
    }

    /// Honest degrade: hard Vision/structure failure must not claim direct-signal recording readiness.
    func testFailedCVBlocksRecordingReadinessAndSurfacesTip() {
        let engine = GuidanceEngine()
        let result = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 1, rollDegrees: 1),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureAnalysisFailed(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))

        // Structure path unusable + empty coding (fixtureAnalysisFailed is vision source + !succeeded).
        XCTAssertFalse(CVFeatures.fixtureAnalysisFailed().analysisSucceeded)
        XCTAssertEqual(CVFeatures.fixtureAnalysisFailed().source, .vision)
        XCTAssertEqual(result.scene.sceneType, .emptyOrUnusable)
        XCTAssertTrue(result.pedagogicalCoding.ipnDimensions.isEmpty)

        // Must surface actionable CV-fail or unusable-scene tip (not silent pass).
        let failTip = result.tips.first {
            $0.id == "cv-analysis-failed" || $0.id == "scene-empty"
        }
        guard let failTip else { return XCTFail("tips=\(result.tips.map(\.id))") }
        XCTAssertGreaterThanOrEqual(failTip.severity, .warning)
        XCTAssertFalse(failTip.actionHint.isEmpty)

        // Placement dimensions must not auto-pass people/scene on hard CV fail.
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "people" }?.ok, false)
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "teachingScene" }?.ok, false)

        // No unvalidated rule-set pass claim.
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        XCTAssertFalse(result.isReadyToRecord)
        XCTAssertFalse(result.placement.directSignalsPass)
    }

    func testGuidanceSurfacesSceneAssessmentAndBothCodingFamilies() {
        let result = testGuidanceResult(frame: Self.goodFrame())
        XCTAssertNotEqual(result.scene.sceneType, .emptyOrUnusable)
        XCTAssertEqual(result.pedagogicalCoding.ipnDimensions.count, IPNDimensionCode.allCases.count)
        XCTAssertFalse(result.pedagogicalCoding.timssActivities.isEmpty)
        XCTAssertNotEqual(result.pedagogicalCoding.primaryTIMSS, .unclearOrNonInstructional)
        XCTAssertTrue(result.tips.contains { $0.category == .teachingScene || $0.id.contains("scene") || $0.id.contains("preset") || $0.id == "placement-direct-signals-pass" })
    }

    // MARK: - Enrichment acceptance: fixture×preset matrix + coding differentiation

    /// Every research fixture should match its intended teaching-situation preset on the shipped path.
    func testAllResearchFixturesMatchIntendedPresets() {
        let pairs: [(CVFeatures, TeachingSituationID, TeachingSceneType)] = [
            (.fixtureClassroomPresent(), .frontalBoardInstruction, .boardCentricFrontal),
            (.fixtureGroupWork(), .collaborativeGroupWork, .multiPersonGroup),
            (.fixtureDialoguePair(), .teacherLedDialogue, .dialoguePair),
            (.fixturePartnerWork(), .partnerWork, .dialoguePair),
            (.fixtureStudentAtBoard(), .studentBoardPresentation, .studentAtBoard),
            (.fixtureExperimentSpread(), .handsOnExperiment, .experimentSpread),
            (.fixtureCircleDiscussion(), .circleOrPlenumDiscussion, .circleDiscussion),
            (.fixtureManagementOverview(), .classroomManagementOverview, .wholeRoomOverview)
        ]
        for (cv, situation, expectedScene) in pairs {
            let scene = TeachingSceneAssessor.assess(cv: cv, frame: Self.goodFrame(), preset: situation)
            XCTAssertEqual(scene.sceneType, expectedScene, "\(situation): got \(scene.sceneType)")
            XCTAssertTrue(scene.matchesPreset, "\(situation): \(scene.summaryDE)")
            XCTAssertGreaterThan(scene.presetMatchScore, 0.45, "\(situation)")

            let coding = PedagogicalCoder.code(
                cv: cv, scene: scene, teachingSituation: situation, frame: Self.goodFrame()
            )
            XCTAssertEqual(coding.ipnDimensions.count, IPNDimensionCode.allCases.count, "\(situation)")
            XCTAssertFalse(coding.timssActivities.isEmpty, "\(situation)")
            XCTAssertNotEqual(coding.primaryTIMSS, .unclearOrNonInstructional, "\(situation)")
        }
    }

    /// Same structural fixture under board-centric vs multi-person presets changes match AND coding confidence.
    func testCrossPresetCodingConfidenceAndLevelsDiffer() {
        let cv = CVFeatures.fixtureClassroomPresent()
        let frontalScene = TeachingSceneAssessor.assess(cv: cv, frame: Self.goodFrame(), preset: .frontalBoardInstruction)
        let groupScene = TeachingSceneAssessor.assess(cv: cv, frame: Self.goodFrame(), preset: .collaborativeGroupWork)
        XCTAssertTrue(frontalScene.matchesPreset)
        XCTAssertFalse(groupScene.matchesPreset)

        let frontalCoding = PedagogicalCoder.code(
            cv: cv, scene: frontalScene, teachingSituation: .frontalBoardInstruction, frame: Self.goodFrame()
        )
        let groupCoding = PedagogicalCoder.code(
            cv: cv, scene: groupScene, teachingSituation: .collaborativeGroupWork, frame: Self.goodFrame()
        )
        // Mismatch must not invent equal-or-higher overall confidence than matching preset.
        XCTAssertGreaterThan(frontalCoding.overallConfidence, groupCoding.overallConfidence)

        let frontalGoal = frontalCoding.ipnDimensions.first { $0.code == IPNDimensionCode.goalOrientation.rawValue }?.level ?? 0
        let groupSocial = groupCoding.ipnDimensions.first { $0.code == IPNDimensionCode.socialClimate.rawValue }?.level ?? 0
        XCTAssertGreaterThan(frontalGoal, 0.35)
        // Social climate still computed for group coding (full set), but overall conf lower.
        XCTAssertGreaterThan(groupSocial, 0.1)
        XCTAssertEqual(frontalCoding.ipnDimensions.count, 7)
        XCTAssertEqual(groupCoding.ipnDimensions.count, 7)
    }

    /// Experiment fixture elevates IPN experimentation dimension vs frontal classroom.
    func testExperimentationDimensionElevatedForLabScene() {
        let expScene = TeachingSceneAssessor.assess(
            cv: .fixtureExperimentSpread(), frame: Self.goodFrame(), preset: .handsOnExperiment
        )
        let classScene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(), frame: Self.goodFrame(), preset: .frontalBoardInstruction
        )
        let expCoding = PedagogicalCoder.code(
            cv: .fixtureExperimentSpread(), scene: expScene, teachingSituation: .handsOnExperiment
        )
        let classCoding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(), scene: classScene, teachingSituation: .frontalBoardInstruction,
            frame: Self.goodFrame()
        )
        let expLevel = expCoding.ipnDimensions.first { $0.code == IPNDimensionCode.experimentation.rawValue }?.level ?? 0
        let classExp = classCoding.ipnDimensions.first { $0.code == IPNDimensionCode.experimentation.rawValue }?.level ?? 0
        XCTAssertGreaterThan(expLevel, classExp)
        XCTAssertGreaterThan(expLevel, 0.45)
    }

    /// Unstable observation lowers scene confidence vs stable identical structure.
    func testUnstableObservationLowersSceneConfidence() {
        let stable = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(), frame: Self.goodFrame(), preset: .frontalBoardInstruction
        )
        let unstable = TeachingSceneAssessor.assess(
            cv: .fixtureUnstableObservation(), frame: Self.goodFrame(), preset: .frontalBoardInstruction
        )
        XCTAssertEqual(stable.sceneType, unstable.sceneType)
        XCTAssertGreaterThan(stable.confidence, unstable.confidence)
    }

    /// Wrong-preset multi-person weak-board fixtures must NOT invent board-centric frontal
    /// or claim matchesPreset under board-required frontal (soft prior honesty).
}
