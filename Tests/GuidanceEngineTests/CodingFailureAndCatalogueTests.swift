import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testCodingFailedCVReturnsEmpty() {
        let coding = PedagogicalCoder.code(
            cv: .empty,
            scene: .unavailable,
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(coding.ipnDimensions.isEmpty)
        XCTAssertTrue(coding.timssActivities.isEmpty)
        XCTAssertEqual(coding.primaryTIMSS, .unclearOrNonInstructional)
    }

    func testExperimentFixtureCodesLabActivity() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureExperimentSpread(),
            preset: .handsOnExperiment
        )
        let expectedScenes: Set<TeachingSceneType> = [
            .experimentSpread,
            .multiPersonGroup,
            .actorsWithoutBoard
        ]
        XCTAssertTrue(expectedScenes.contains(scene.sceneType), "got \(scene.sceneType)")
        let coding = PedagogicalCoder.code(
            cv: .fixtureExperimentSpread(),
            scene: scene,
            teachingSituation: .handsOnExperiment
        )
        let lab = coding.timssActivities.first {
            $0.code == TIMSSActivityCode.experimentLab.rawValue
        }?.level ?? 0
        let group = coding.timssActivities.first {
            $0.code == TIMSSActivityCode.groupWork.rawValue
        }?.level ?? 0
        let hasExperimentCoding = [
            lab > 0.3,
            group > 0.3,
            coding.primaryTIMSS == .experimentLab,
            coding.primaryTIMSS == .groupWork
        ].contains(true)
        let validCoding = scene.sceneType == .experimentSpread
            ? coding.primaryTIMSS == .experimentLab
            : hasExperimentCoding
        XCTAssertTrue(validCoding)
    }

    // MARK: - Full catalogue differentiation (acceptance)

    func testAllTwelveResearchSituationsPresentAndDistinct() {
        let ids = TeachingSituationID.allCases
        XCTAssertEqual(ids.count, 12)
        XCTAssertGreaterThanOrEqual(TeachingSituationCatalogue.count, TeachingSituationCatalogue.richMinimumCount)
        let required: Set<TeachingSituationID> = [
            .frontalBoardInstruction, .teacherLedDialogue, .collaborativeGroupWork,
            .partnerWork, .studentBoardPresentation, .handsOnExperiment,
            .classroomManagementOverview, .circleOrPlenumDiscussion,
            .individualSeatwork, .teacherDemonstration, .transitionOrganization,
            .formativeAssessmentDialogue
        ]
        XCTAssertEqual(Set(ids), required)

        var configs: [TeachingSituationID: GuidanceConfig] = [:]
        for id in ids {
            let p = TeachingSituationCatalogue.preset(for: id)
            XCTAssertFalse(p.captureGuidanceDE.isEmpty, "missing capture guidance for \(id)")
            XCTAssertFalse(p.researchAnchorDE.isEmpty, "missing research anchor for \(id)")
            XCTAssertFalse(p.preferredLayouts.isEmpty, "missing preferred layouts for \(id)")
            configs[id] = GuidanceConfig.forTeachingSituation(id)
        }
        // Board-required vs multi-person presets differ on same knobs.
        guard let frontal = configs[.frontalBoardInstruction],
              let group = configs[.collaborativeGroupWork],
              let presentation = configs[.studentBoardPresentation],
              let demo = configs[.teacherDemonstration],
              let seatwork = configs[.individualSeatwork] else {
            return XCTFail("Expected required preset configurations")
        }
        XCTAssertGreaterThan(frontal.boardMinScore, group.boardMinScore)
        XCTAssertGreaterThan(presentation.minPersonBoardCoPresence, group.minPersonBoardCoPresence)
        XCTAssertGreaterThan(group.minPersonCoverage, frontal.minPersonCoverage - 0.001)
        XCTAssertNotEqual(frontal.minMultiCueBoardQuality, group.minMultiCueBoardQuality)
        XCTAssertGreaterThan(demo.boardMinScore, seatwork.boardMinScore)
        XCTAssertGreaterThan(demo.minPersonBoardCoPresence, seatwork.minPersonBoardCoPresence)
    }

    func testSameFixtureReadinessDiffersAcrossPresets() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        let frame = Self.goodFrame()
        let cv = CVFeatures.fixtureClassroomPresent()

        func evaluate(_ situation: TeachingSituationID) -> GuidanceResult {
            let options = ExperimentalGuidanceOptions(
                cv: cv,
                motion: .stable,
                teachingSituation: situation,
                analysisFocus: nil
            )
            let input = experimentalGuidanceInput(
                orientation: orientation,
                frame: frame,
                options: options
            )
            return engine.evaluate(input)
        }

        let frontal = evaluate(.frontalBoardInstruction)
        let group = evaluate(.collaborativeGroupWork)
        let circle = evaluate(.circleOrPlenumDiscussion)

        XCTAssertTrue(frontal.scene.matchesPreset)
        XCTAssertGreaterThan(frontal.scene.presetMatchScore, group.scene.presetMatchScore)
        XCTAssertGreaterThan(frontal.scene.presetMatchScore, circle.scene.presetMatchScore)

        let frontalSceneOK = frontal.placement.dimensions.first { $0.id == "teachingScene" }?.ok ?? false
        let groupSceneOK = group.placement.dimensions.first { $0.id == "teachingScene" }?.ok ?? false
        XCTAssertTrue(frontalSceneOK)
        XCTAssertFalse(groupSceneOK, "board-centric classroom must not pass group preset scene dimension")
        // The same structure can pass the unvalidated rule set for one preset and not another.
        let frontalAcceptable = [
            frontal.placement.quality == .directSignalsPass,
            frontal.isReadyToRecord,
            frontal.scene.matchesPreset
        ].contains(true)
        XCTAssertTrue(frontalAcceptable, "frontal should be acceptable path")
        let mismatchTerms = ["preset", "scene"]
        let groupHasMismatchTip = group.tips.contains { tip in
            mismatchTerms.contains(where: tip.id.contains)
        }
        let groupRejected = [
            group.placement.quality != .directSignalsPass,
            !group.scene.matchesPreset,
            groupHasMismatchTip
        ].contains(true)
        XCTAssertTrue(groupRejected, "group preset on frontal geometry should fail or tip")
    }

    func testCircleAndManagementAndPartnerFixturesClassifyAndMatch() {
        let circle = TeachingSceneAssessor.assess(
            cv: .fixtureCircleDiscussion(),
            preset: .circleOrPlenumDiscussion
        )
        XCTAssertTrue(
            circle.sceneType == .circleDiscussion || circle.sceneType == .multiPersonGroup,
            "got \(circle.sceneType)"
        )
        XCTAssertTrue(circle.matchesPreset, circle.summaryDE)

        let management = TeachingSceneAssessor.assess(
            cv: .fixtureManagementOverview(),
            preset: .classroomManagementOverview
        )
        XCTAssertTrue(
            management.sceneType == .wholeRoomOverview
                || management.sceneType == .multiPersonGroup
                || management.sceneType == .circleDiscussion,
            "got \(management.sceneType)"
        )
        XCTAssertTrue(management.matchesPreset, management.summaryDE)

        let partner = TeachingSceneAssessor.assess(
            cv: .fixturePartnerWork(),
            preset: .partnerWork
        )
        XCTAssertEqual(partner.sceneType, .dialoguePair)
        XCTAssertTrue(partner.matchesPreset, partner.summaryDE)

        let partnerCoding = PedagogicalCoder.code(
            cv: .fixturePartnerWork(),
            scene: partner,
            teachingSituation: .partnerWork
        )
        XCTAssertEqual(partnerCoding.primaryTIMSS, .partnerWork)
        XCTAssertFalse(partnerCoding.ipnDimensions.isEmpty)
    }

    func testFullIPNDimensionSetOnSuccessfulClassroom() {
        let coding = testClassroomCoding(frame: Self.goodFrame())
        let codes = Set(coding.ipnCodes)
        for dim in IPNDimensionCode.allCases {
            XCTAssertTrue(codes.contains(dim.rawValue), "missing IPN dimension \(dim)")
            let assignment = coding.ipnDimensions.first { $0.code == dim.rawValue }
            guard let assignment else { return XCTFail("missing IPN assignment \(dim)") }
            XCTAssertFalse(assignment.rationaleDE.isEmpty)
            XCTAssertGreaterThan(assignment.confidence, 0)
        }
        XCTAssertEqual(coding.ipnDimensions.count, IPNDimensionCode.allCases.count)
    }

    func testTIMSSActivitySetCompleteAndDocumented() {
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        let coding = testClassroomCoding(frame: Self.goodFrame())
        XCTAssertFalse(coding.timssActivities.isEmpty)
        // Expected TIMSS activities for frontal must appear with non-trivial level.
        for raw in TeachingSituationCatalogue.preset(for: .frontalBoardInstruction).expectedTIMSSActivities {
            let level = coding.timssActivities.first { $0.code == raw }?.level ?? 0
            XCTAssertGreaterThan(level, 0.1, "expected TIMSS activity \(raw) missing/low")
        }
        XCTAssertTrue(
            coding.primaryTIMSS == .wholeClassInstruction
                || coding.primaryTIMSS == .publicBoardWork
        )
    }

}
