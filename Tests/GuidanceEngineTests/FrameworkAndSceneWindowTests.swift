import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testResearchCodingSnapshotJSONExport() throws {
        let snap = testLessonAnalysisSnapshot()
        XCTAssertEqual(snap.primaryTIMSS, TIMSSActivityCode.wholeClassInstruction.rawValue)
        XCTAssertEqual(snap.primaryGTI, GTIQualityCode.instructionalQuality.rawValue)
        XCTAssertEqual(snap.ipn.count, IPNDimensionCode.allCases.count)
        XCTAssertEqual(snap.gti.count, GTIQualityCode.allCases.count)
        XCTAssertEqual(snap.analysisFocus, CodingAnalysisFocus.lessonAnalysis.rawValue)
        let json = try snap.jsonString()
        XCTAssertTrue(json.contains("ipn"))
        XCTAssertTrue(json.contains("timss"))
        XCTAssertTrue(json.contains("gti"))
        XCTAssertTrue(json.contains("\"semanticVersion\" : \"test\""))
        XCTAssertTrue(json.contains("\"buildNumber\" : \"1\""))
        XCTAssertTrue(json.contains("experimental-coding-rules-test"))
        let data = try snap.jsonData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchCodingSnapshot.self, from: data)
        XCTAssertEqual(decoded.teachingSituation, TeachingSituationID.frontalBoardInstruction.rawValue)
        XCTAssertEqual(decoded.gti.count, 8)
    }

    func testFrontalClassroomFixturePrefersWholeClassTIMSSOverPublicBoard() {
        let coding = testClassroomCoding(frame: Self.goodFrame())
        let wholeClass = coding.timssActivities.first {
            $0.code == TIMSSActivityCode.wholeClassInstruction.rawValue
        }?.level ?? 0
        let publicBoard = coding.timssActivities.first {
            $0.code == TIMSSActivityCode.publicBoardWork.rawValue
        }?.level ?? 0

        XCTAssertEqual(coding.primaryTIMSS, .wholeClassInstruction)
        XCTAssertGreaterThan(wholeClass, publicBoard)
    }

    func testBoardDependentLayoutsWithoutBoardFallThroughAcrossPresets() {
        for layout in [ClassroomLayoutPattern.frontalRows, .presentationFocus] {
            let cv = CVFeatures.make { values in
                values.source = .fixture
                values.personCount = 1
                values.personCoverage = 0.12
                values.faceCount = 1
                values.personMidBandOccupancy = 0.72
                values.personCentroidY = 0.52
                values.personCentroidX = 0.5
                values.faceScaleScore = 0.85
                values.layoutPattern = layout
                values.analysisSucceeded = true
            }

            for preset in TeachingSituationID.allCases {
                let scene = TeachingSceneAssessor.assess(cv: cv, preset: preset)
                XCTAssertEqual(scene.boardSignal, 0, accuracy: 0.000_001)
                XCTAssertEqual(scene.sceneType, .actorsWithoutBoard, "layout=\(layout), preset=\(preset)")
            }
        }
    }

    func testFrameworkCrosswalkDocumented() {
        XCTAssertGreaterThanOrEqual(PedagogicalFrameworkCrosswalk.links.count, 6)
        for link in PedagogicalFrameworkCrosswalk.links {
            XCTAssertFalse(link.noteDE.isEmpty)
            XCTAssertTrue(link.ipn != nil || link.timss != nil || link.gti != nil)
        }
    }

    func testAllPresetsHaveGTIEmphasis() {
        for preset in TeachingSituationCatalogue.all {
            XCTAssertFalse(preset.gtiEmphasis.isEmpty, "missing gtiEmphasis for \(preset.id)")
            for raw in preset.gtiEmphasis {
                XCTAssertNotNil(GTIQualityCode(rawValue: raw), "unknown GTI code \(raw) in \(preset.id)")
            }
        }
    }

    func testGTIDomainRollupsPresent() {
        let scene = TeachingSceneAssessor.assess(cv: .fixtureDialoguePair(), preset: .teacherLedDialogue)
        let coding = PedagogicalCoder.code(
            cv: .fixtureDialoguePair(),
            scene: scene,
            teachingSituation: .teacherLedDialogue,
            analysisFocus: .studentThinking
        )
        let domains = coding.gtiDomainLevels
        XCTAssertNotNil(domains["classroomManagement"])
        XCTAssertNotNil(domains["socialEmotionalSupport"])
        XCTAssertNotNil(domains["instruction"])
        XCTAssertEqual(coding.primaryGTI, coding.gtiDimensions.max(by: { $0.level < $1.level }).flatMap { GTIQualityCode(rawValue: $0.code) })
    }

    func testFormativeAndDemoElevateAssessmentAndClarity() {
        let formScene = TeachingSceneAssessor.assess(cv: .fixtureFormativeAssessment(), preset: .formativeAssessmentDialogue)
        let form = PedagogicalCoder.code(
            cv: .fixtureFormativeAssessment(),
            scene: formScene,
            teachingSituation: .formativeAssessmentDialogue
        )
        let assess = form.gtiDimensions.first { $0.code == GTIQualityCode.assessmentFeedback.rawValue }
        guard let assess else { return XCTFail("Expected assessment GTI dimension") }
        XCTAssertGreaterThan(assess.level, 0.35)

        let demoScene = TeachingSceneAssessor.assess(cv: .fixtureTeacherDemonstration(), preset: .teacherDemonstration)
        let demo = PedagogicalCoder.code(
            cv: .fixtureTeacherDemonstration(),
            scene: demoScene,
            teachingSituation: .teacherDemonstration
        )
        let clarity = demo.gtiDimensions.first { $0.code == GTIQualityCode.subjectClarity.rawValue }
        guard let clarity else { return XCTFail("Expected clarity GTI dimension") }
        XCTAssertGreaterThan(clarity.level, 0.4)
    }

    func testPresetLayoutMismatchSurfacesGuidanceTip() {
        let engine = GuidanceEngine()
        // Group fixture under frontal board preset → layout/scene mismatch tips.
        let result = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: Self.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureGroupWork(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        let tipIDs = Set(result.tips.map(\.id))
        XCTAssertTrue(
            tipIDs.contains("scene-preset-mismatch")
                || tipIDs.contains("preset-layout-mismatch")
                || tipIDs.contains("preset-people-shortfall")
                || tipIDs.contains("preset-board-required"),
            "expected preset/structure mismatch tip, got \(tipIDs)"
        )
        XCTAssertFalse(result.scene.matchesPreset)
    }

    func testTeachingSceneWindowAggregatesDominantScene() throws {
        var window = TeachingSceneWindow(capacity: 4)
        let a = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let b = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let c = TeachingSceneAssessor.assess(cv: .fixtureGroupWork(), preset: .collaborativeGroupWork)
        window.push(a)
        window.push(b)
        window.push(c)
        let agg = try XCTUnwrap(window.aggregate())
        XCTAssertEqual(agg.sceneType, .boardCentricFrontal) // majority frontal
        XCTAssertTrue(agg.summaryDE.contains("Zeitfenster"))
    }

    func testTeachingSceneWindowUsesMostRecentObservationForEqualSceneAndLayoutVotes() throws {
        let earlier = testTeachingSceneAssessment(
            sceneType: .boardCentricFrontal,
            layoutPattern: .frontalRows
        )
        let later = testTeachingSceneAssessment(
            sceneType: .multiPersonGroup,
            layoutPattern: .multiCluster
        )

        for (first, second, expected) in [(earlier, later, later), (later, earlier, earlier)] {
            for _ in 0..<20 {
                var window = TeachingSceneWindow(capacity: 2)
                window.push(first)
                window.push(second)
                let aggregate = try XCTUnwrap(window.aggregate())
                XCTAssertEqual(aggregate.sceneType, expected.sceneType)
                XCTAssertEqual(aggregate.layoutPattern, expected.layoutPattern)
            }
        }
    }

    func testTeachingSceneWindowUsesMostRecentObservationForEqualPresetMatchVotes() {
        func assessment(matchesPreset: Bool) -> TeachingSceneAssessment {
            testTeachingSceneAssessment(
                sceneType: .boardCentricFrontal,
                layoutPattern: .frontalRows,
                matchesPreset: matchesPreset
            )
        }

        for values in [[assessment(matchesPreset: false), assessment(matchesPreset: true)],
                       [assessment(matchesPreset: true), assessment(matchesPreset: false)]]
        {
            var window = TeachingSceneWindow(capacity: 2)
            values.forEach { window.push($0) }
            XCTAssertEqual(window.aggregate()?.matchesPreset, values.last?.matchesPreset)
        }
    }

}
