import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testCodingSegmentTimelineBoundsNoisyLongTakes() {
        func snapshot(index: Int) -> ResearchCodingSnapshot {
            ResearchCodingSnapshot({
    var values = ResearchCodingSnapshot.Values(provenance: testResearchProvenance)
    values.teachingSituation = TeachingSituationID.frontalBoardInstruction.rawValue
    values.sceneType = index.isMultiple(of: 2) ? "boardCentricFrontal" : "multiPersonGroup"
    values.layoutPattern = index.isMultiple(of: 2) ? "frontalRows" : "multiCluster"
    values.presetMatchScore = 0.8
    values.matchesPreset = true
    values.sceneConfidence = 0.8
    values.primaryTIMSS = index.isMultiple(of: 2) ? "wholeClassInstruction" : "groupWork"
    values.primaryGTI = "instructionalQuality"
    values.overallConfidence = 0.8
    values.summaryDE = "fixture-\(index)"
    values.ipn = []
    values.timss = []
    values.gti = []
    values.boardSignal = 0.8
    values.peopleSignal = 0.8
    values.coPresenceSignal = 0.8
    values.layoutSignal = 0.8
    return values
}())
        }

        var timeline = CodingSegmentTimeline(minSegmentSeconds: 1)
        let start = Date(timeIntervalSince1970: 100)
        for index in 0..<(CodingSegmentTimeline.maxSegments + 3) {
            timeline.observe(
                snapshot: snapshot(index: index),
                at: start.addingTimeInterval(Double(index * 2))
            )
        }

        XCTAssertEqual(timeline.segments.count, CodingSegmentTimeline.maxSegments)
        XCTAssertEqual(timeline.segments.first?.snapshot?.summaryDE, "fixture-3")
        XCTAssertEqual(timeline.segments.last?.snapshot?.summaryDE, "fixture-2050")
    }

    func testCodingInformedReflectionScaffolds() {
        let scene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        let notes = CodingInformedReflection.scaffoldNotes(
            coding: coding,
            scene: scene,
            situation: .frontalBoardInstruction
        )
        XCTAssertEqual(notes.count, 4)
        guard let lessonGoals = notes[CodingInformedReflection.lessonGoalsKey],
              let instructionalStrategies = notes[CodingInformedReflection.instructionalStrategiesKey] else {
            return XCTFail("Expected reflection notes")
        }
        XCTAssertTrue(lessonGoals.contains("TIMSS") || lessonGoals.contains("Situation"))
        XCTAssertTrue(instructionalStrategies.contains("IPN") || instructionalStrategies.contains("GTI"))
    }

    func testUnvalidatedRuleSetPassOnClassroomFixture() {
        let engine = GuidanceEngine()
        let result = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureClassroomPresent(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertEqual(result.scene.sceneType, .boardCentricFrontal)
        XCTAssertTrue(result.scene.matchesPreset)
        XCTAssertFalse(result.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertGreaterThan(result.researchQuality.score, 0.4)
        XCTAssertNotEqual(result.researchQuality.level, .unsuitable)
        XCTAssertGreaterThanOrEqual(result.researchQuality.dimensions.count, 4)
    }

    func testUnvalidatedRuleSetIsUnsuitableOnEmptyFixture() {
        let engine = GuidanceEngine()
        let result = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureEmptyRoom(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertEqual(result.scene.sceneType, .emptyOrUnusable)
        XCTAssertTrue(
            result.researchQuality.level == .unsuitable
                || result.researchQuality.level == .needsAdjustment
        )
        XCTAssertFalse(result.isReadyToRecord)
    }

    func testPresetRecommendationsByFocus() {
        let cm = TeachingSituationCatalogue.recommended(for: .classroomManagement)
        XCTAssertTrue(cm.contains(.classroomManagementOverview))
        XCTAssertTrue(cm.contains(.transitionOrganization))
        let think = TeachingSituationCatalogue.recommended(for: .studentThinking)
        XCTAssertTrue(think.contains(.formativeAssessmentDialogue))
        XCTAssertEqual(TeachingSituationCatalogue.families.count, 6)
        XCTAssertEqual(TeachingSituationCatalogue.family(for: .frontalBoardInstruction), "Ganzklasse / Tafel")
    }

    func testCodingSegmentTimelineTracksSceneChange() {
        var timeline = CodingSegmentTimeline(minSegmentSeconds: 0.01)
        let sceneA = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let codeA = PedagogicalCoder.code(cv: .fixtureClassroomPresent(), scene: sceneA, teachingSituation: .frontalBoardInstruction)
        let snapA = ResearchCodingSnapshot.from(
            coding: codeA, scene: sceneA, provenance: testResearchProvenance
        )
        timeline.observe(snapshot: snapA, at: Date(timeIntervalSince1970: 1000))
        let sceneB = TeachingSceneAssessor.assess(cv: .fixtureGroupWork(), preset: .collaborativeGroupWork)
        let codeB = PedagogicalCoder.code(cv: .fixtureGroupWork(), scene: sceneB, teachingSituation: .collaborativeGroupWork)
        let snapB = ResearchCodingSnapshot.from(
            coding: codeB, scene: sceneB, provenance: testResearchProvenance
        )
        timeline.observe(snapshot: snapB, at: Date(timeIntervalSince1970: 1010))
        timeline.close(at: Date(timeIntervalSince1970: 1020))
        XCTAssertGreaterThanOrEqual(timeline.segments.count, 1)
        XCTAssertNotNil(timeline.dominantTIMSS)
        XCTAssertGreaterThan(timeline.totalDurationSeconds, 0)
    }

    func testInteractionDensityFromClassroomFixture() {
        let cv = CVFeatures.fixtureClassroomPresent()
        let d = CVFeatureFusion.interactionDensity(from: cv)
        XCTAssertGreaterThan(d, 0.2)
        let empty = CVFeatureFusion.interactionDensity(from: .fixtureEmptyRoom())
        XCTAssertEqual(empty, 0, accuracy: 0.05)
    }
}
