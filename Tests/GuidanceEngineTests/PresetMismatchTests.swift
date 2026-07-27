import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testWrongPresetMultiPersonDoesNotInventBoardCentricOrMatch(){
        wrongPresetMultiPersonDoesNotInventBoardCentricOrMatchAssertions()
    }

    /// expectedScenes membership alone never forces matchesPreset when score is penalty-low.
    func testMatchesPresetRequiresScoreThresholdNotJustExpectedScene() {
        // Empty / failed never match even if somehow labeled.
        let empty = TeachingSceneAssessor.assess(cv: .fixtureEmptyRoom(), preset: .frontalBoardInstruction)
        XCTAssertFalse(empty.matchesPreset)
        XCTAssertLessThan(empty.presetMatchScore, 0.3)

        let failed = TeachingSceneAssessor.assess(cv: .fixtureAnalysisFailed(), preset: .frontalBoardInstruction)
        XCTAssertFalse(failed.matchesPreset)
        XCTAssertEqual(failed.sceneType, .emptyOrUnusable)

        // Board-only under multi-person group preset: not enough people → no match.
        let boardOnlyUnderGroup = TeachingSceneAssessor.assess(
            cv: .fixtureBoardNoPeople(),
            preset: .collaborativeGroupWork
        )
        XCTAssertFalse(boardOnlyUnderGroup.matchesPreset)
        XCTAssertEqual(boardOnlyUnderGroup.sceneType, .boardOnly)
    }

    /// Production Vision adapter source is present and documents the structure→pure features contract.


    // MARK: - Layout structure + expanded coding (research enrichment)




































    // MARK: - Scene window, GTI tips, research report, reflection scaffolds
























    // MARK: - Unvalidated rule-set composite, presets, timeline











    // MARK: - Helpers

    static func goodFrame() -> FrameMetrics {
        testStandardGoodFrame()
    }
}


private let wrongPresetMultiPersonDoesNotInventBoardCentricOrMatchAssertions: @Sendable () -> Void = {
        // Group work under frontal: stay multi-person, fail preset match, low coding conf vs matched group.
        let groupUnderFrontal = TeachingSceneAssessor.assess(
            cv: .fixtureGroupWork(),
            frame: TeachingSceneAndCodingTests.goodFrame(),
            preset: .frontalBoardInstruction
        )
        XCTAssertNotEqual(
            groupUnderFrontal.sceneType, .boardCentricFrontal,
            "must not invent boardCentricFrontal for weak-board group structure: \(groupUnderFrontal)"
        )
        XCTAssertEqual(groupUnderFrontal.sceneType, .multiPersonGroup)
        XCTAssertFalse(groupUnderFrontal.matchesPreset, groupUnderFrontal.summaryDE)
        XCTAssertLessThan(groupUnderFrontal.presetMatchScore, 0.48)

        let groupMatched = TeachingSceneAssessor.assess(
            cv: .fixtureGroupWork(),
            frame: TeachingSceneAndCodingTests.goodFrame(),
            preset: .collaborativeGroupWork
        )
        XCTAssertTrue(groupMatched.matchesPreset)
        XCTAssertGreaterThan(groupMatched.presetMatchScore, groupUnderFrontal.presetMatchScore)

        let codingWrong = PedagogicalCoder.code(
            cv: .fixtureGroupWork(),
            scene: groupUnderFrontal,
            teachingSituation: .frontalBoardInstruction,
            frame: TeachingSceneAndCodingTests.goodFrame()
        )
        let codingRight = PedagogicalCoder.code(
            cv: .fixtureGroupWork(),
            scene: groupMatched,
            teachingSituation: .collaborativeGroupWork,
            frame: TeachingSceneAndCodingTests.goodFrame()
        )
        XCTAssertGreaterThan(codingRight.overallConfidence, codingWrong.overallConfidence)
        // Wrong-preset multiperson must not get frontal whole-class as if matched board scene.
        let wrongPrimaryLevel = codingWrong.timssActivities.first {
            $0.code == codingWrong.primaryTIMSS.rawValue
        }?.level ?? 0
        let groupWorkLevel = codingWrong.timssActivities.first {
            $0.code == TIMSSActivityCode.groupWork.rawValue
        }?.level ?? 0
        XCTAssertGreaterThan(groupWorkLevel, 0.35)
        // Primary should track observed multi-person structure, not invented frontal instruction.
        XCTAssertTrue(
            codingWrong.primaryTIMSS == .groupWork
                || codingWrong.primaryTIMSS == .seatworkCollaborative
                || codingWrong.primaryTIMSS == .discussionPlenum,
            "primary=\(codingWrong.primaryTIMSS) conf=\(codingWrong.overallConfidence)"
        )
        XCTAssertLessThan(codingWrong.overallConfidence, 0.55,
                          "wrong-preset coding conf must stay moderate (matchFactor from low score)")
        XCTAssertGreaterThan(wrongPrimaryLevel, 0.2)
        XCTAssertNotEqual(codingWrong.primaryTIMSS, .wholeClassInstruction)
        XCTAssertNotEqual(codingWrong.primaryTIMSS, .publicBoardWork)

        // Circle under frontal: stay circle/plenum structure, no boardCentricFrontal, no match.
        let circleUnderFrontal = TeachingSceneAssessor.assess(
            cv: .fixtureCircleDiscussion(),
            frame: TeachingSceneAndCodingTests.goodFrame(),
            preset: .frontalBoardInstruction
        )
        XCTAssertNotEqual(
            circleUnderFrontal.sceneType, .boardCentricFrontal,
            "must not invent boardCentricFrontal for circle structure: \(circleUnderFrontal)"
        )
        XCTAssertTrue(
            circleUnderFrontal.sceneType == .circleDiscussion
                || circleUnderFrontal.sceneType == .multiPersonGroup,
            "got \(circleUnderFrontal.sceneType)"
        )
        XCTAssertFalse(circleUnderFrontal.matchesPreset, circleUnderFrontal.summaryDE)
        XCTAssertLessThan(circleUnderFrontal.presetMatchScore, 0.48)

        let circleCoding = PedagogicalCoder.code(
            cv: .fixtureCircleDiscussion(),
            scene: circleUnderFrontal,
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertFalse(circleUnderFrontal.matchesPreset)
        XCTAssertLessThan(circleCoding.overallConfidence, 0.55)
        XCTAssertNotEqual(circleCoding.primaryTIMSS, .wholeClassInstruction)
    }
