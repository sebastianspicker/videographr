import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testPedagogicalCodingWindowUsesMostRecentObservationForEqualScoresAndVotes() throws{
        try pedagogicalCodingWindowUsesMostRecentObservationForEqualScoresAndVotesAssertions()
    }

    func testEqualScoreCodingTopListsReflectionAndCalibrationIgnoreInputOrder(){
        equalScoreCodingTopListsReflectionAndCalibrationIgnoreInputOrderAssertions()
    }

    func testGuidanceResultEqualSeverityTipsIgnoreInputOrder() {
        let alpha = GuidanceTip((id: "alpha", category: .general, severity: .warning, message: "a", actionHint: "a"))
        let zeta = GuidanceTip((id: "zeta", category: .general, severity: .warning, message: "z", actionHint: "z"))
        let forward = GuidanceResult(tips: [zeta, alpha])
        let backward = GuidanceResult(tips: [alpha, zeta])
        XCTAssertEqual(forward.tips.map(\.id), ["alpha", "zeta"])
        XCTAssertEqual(forward.tips.map(\.id), backward.tips.map(\.id))
    }

    func testGTICodeSetDocumented() {
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)
        let domains = Set(GTIQualityCode.allCases.map(\.domain))
        XCTAssertEqual(domains, Set(["classroomManagement", "socialEmotionalSupport", "instruction"]))
        for code in GTIQualityCode.allCases {
            XCTAssertFalse(code.titleDE.isEmpty)
            XCTAssertFalse(code.researchNoteDE.isEmpty)
            XCTAssertFalse(code.domain.isEmpty)
        }
        // Full GTI set includes TALIS discourse + instruction sub-facets.
        XCTAssertTrue(GTIQualityCode.allCases.contains(.discourseQuality))
        XCTAssertTrue(GTIQualityCode.allCases.contains(.subjectClarity))
        XCTAssertTrue(GTIQualityCode.allCases.contains(.cognitiveEngagement))
        XCTAssertTrue(GTIQualityCode.allCases.contains(.assessmentFeedback))
    }

    func testAnalysisFocusReweightsGTIAndIPN() {
        let scene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let base = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: nil
        )
        let cm = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: .classroomManagement
        )
        let think = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: .studentThinking
        )
        XCTAssertEqual(base.gtiDimensions.count, 8)
        XCTAssertEqual(cm.gtiDimensions.count, 8)
        XCTAssertEqual(cm.analysisFocus, .classroomManagement)
        XCTAssertEqual(cm.primaryGTI, cm.gtiDimensions.max(by: { $0.level < $1.level }).flatMap { GTIQualityCode(rawValue: $0.code) })
        guard let cmManagement = cm.gtiDimensions.first(where: { $0.code == GTIQualityCode.classroomManagement.rawValue }),
              let baseManagement = base.gtiDimensions.first(where: { $0.code == GTIQualityCode.classroomManagement.rawValue }),
              let thinkDiscourseDimension = think.gtiDimensions.first(where: { $0.code == GTIQualityCode.discourseQuality.rawValue }),
              let baseDiscourseDimension = base.gtiDimensions.first(where: { $0.code == GTIQualityCode.discourseQuality.rawValue }) else {
            return XCTFail("Expected focused GTI dimensions")
        }
        let cmMgmt = cmManagement.level
        let baseMgmt = baseManagement.level
        XCTAssertGreaterThanOrEqual(cmMgmt, baseMgmt - 0.001)
        let thinkDiscourse = thinkDiscourseDimension.level
        let baseDiscourse = baseDiscourseDimension.level
        XCTAssertGreaterThanOrEqual(thinkDiscourse, baseDiscourse - 0.001)
        XCTAssertFalse(cm.summaryDE.isEmpty)
        XCTAssertTrue(cm.summaryDE.contains("Fokus") || cm.analysisFocus != nil)
    }

}

private let pedagogicalCodingWindowUsesMostRecentObservationForEqualScoresAndVotesAssertions: @Sendable () throws -> Void = {
        func assignment(
            family: PedagogicalCodeFamily,
            code: String,
            level: Double = 0.7
        ) -> PedagogicalCodeAssignment {
            let identity = PedagogicalCodeAssignment.Identity(
                id: "\(family.rawValue)-\(code)",
                family: family
            )
            let descriptor = PedagogicalCodeAssignment.Descriptor(code: code, labelDE: code)
            let measurement = PedagogicalCodeAssignment.Measurement(level: level, confidence: 0.8)
            let values = PedagogicalCodeAssignment.Values(
                identity: identity,
                descriptor: descriptor,
                measurement: measurement,
                rationaleDE: "fixture"
            )
            return PedagogicalCodeAssignment(values)
        }

        func result(
            timss: TIMSSActivityCode,
            gti: GTIQualityCode,
            scene: TeachingSceneType,
            layout: ClassroomLayoutPattern
        ) -> PedagogicalCodingResult {
            let assignments = PedagogicalCodingResult.Assignments(
                ipnDimensions: [],
                timssActivities: [assignment(family: .timssActivityScript, code: timss.rawValue)],
                gtiDimensions: [assignment(family: .gtiQuality, code: gti.rawValue)]
            )
            let primaryCodes = PedagogicalCodingResult.PrimaryCodes(timss: timss, gti: gti)
            let content = PedagogicalCodingResult.Content(
                assignments: assignments,
                primaryCodes: primaryCodes,
                overallConfidence: 0.8,
                summaryDE: "fixture"
            )
            let context = PedagogicalCodingResult.Context(
                sceneType: scene,
                teachingSituation: .frontalBoardInstruction,
                layoutPattern: layout
            )
            return PedagogicalCodingResult(.init(content: content, context: context))
        }

        let earlier = result(
            timss: .wholeClassInstruction,
            gti: .classroomManagement,
            scene: .boardCentricFrontal,
            layout: .frontalRows
        )
        let later = result(
            timss: .groupWork,
            gti: .instructionalQuality,
            scene: .multiPersonGroup,
            layout: .multiCluster
        )

        for (first, second, expected) in [(earlier, later, later), (later, earlier, earlier)] {
            for _ in 0..<20 {
                var window = PedagogicalCodingWindow(capacity: 2)
                window.push(first)
                window.push(second)
                let aggregate = try XCTUnwrap(window.aggregate())
                XCTAssertEqual(aggregate.timssActivities.map(\.code), [expected.primaryTIMSS.rawValue, first.primaryTIMSS.rawValue])
                XCTAssertEqual(aggregate.primaryTIMSS, expected.primaryTIMSS)
                XCTAssertEqual(aggregate.primaryGTI, expected.primaryGTI)
                XCTAssertEqual(aggregate.sceneType, expected.sceneType)
                XCTAssertEqual(aggregate.layoutPattern, expected.layoutPattern)
            }
        }
    }

private let equalScoreCodingTopListsReflectionAndCalibrationIgnoreInputOrderAssertions: @Sendable () -> Void = {
        func assignment(
            family: PedagogicalCodeFamily,
            code: String,
            label: String
        ) -> PedagogicalCodeAssignment {
            let identity = PedagogicalCodeAssignment.Identity(
                id: "\(family.rawValue)-\(code)",
                family: family
            )
            let descriptor = PedagogicalCodeAssignment.Descriptor(code: code, labelDE: label)
            let measurement = PedagogicalCodeAssignment.Measurement(level: 0.5, confidence: 0.8)
            let values = PedagogicalCodeAssignment.Values(
                identity: identity,
                descriptor: descriptor,
                measurement: measurement,
                rationaleDE: "fixture"
            )
            return PedagogicalCodeAssignment(values)
        }

        let ipn = [
            assignment(family: .ipnProcessQuality, code: IPNDimensionCode.cognitiveActivation.rawValue, label: "Cognitive"),
            assignment(family: .ipnProcessQuality, code: IPNDimensionCode.goalOrientation.rawValue, label: "Goal"),
            assignment(family: .ipnProcessQuality, code: IPNDimensionCode.classroomOrganization.rawValue, label: "Organization"),
            assignment(family: .ipnProcessQuality, code: IPNDimensionCode.learningSupport.rawValue, label: "Support")
        ]
        let timss = [
            assignment(family: .timssActivityScript, code: TIMSSActivityCode.groupWork.rawValue, label: "Group"),
            assignment(family: .timssActivityScript, code: TIMSSActivityCode.wholeClassInstruction.rawValue, label: "Whole class")
        ]
        let gti = [
            assignment(family: .gtiQuality, code: GTIQualityCode.subjectClarity.rawValue, label: "Clarity"),
            assignment(family: .gtiQuality, code: GTIQualityCode.classroomManagement.rawValue, label: "Management"),
            assignment(family: .gtiQuality, code: GTIQualityCode.instructionalQuality.rawValue, label: "Instruction"),
            assignment(family: .gtiQuality, code: GTIQualityCode.socialEmotionalSupport.rawValue, label: "Support")
        ]

        func result(reversed: Bool) -> PedagogicalCodingResult {
            let assignments = PedagogicalCodingResult.Assignments(
                ipnDimensions: reversed ? Array(ipn.reversed()) : ipn,
                timssActivities: reversed ? Array(timss.reversed()) : timss,
                gtiDimensions: reversed ? Array(gti.reversed()) : gti
            )
            let primaryCodes = PedagogicalCodingResult.PrimaryCodes(
                timss: .wholeClassInstruction,
                gti: .classroomManagement
            )
            let content = PedagogicalCodingResult.Content(
                assignments: assignments,
                primaryCodes: primaryCodes,
                overallConfidence: 0.8,
                summaryDE: "fixture"
            )
            let context = PedagogicalCodingResult.Context(
                sceneType: .boardCentricFrontal,
                teachingSituation: .frontalBoardInstruction,
                layoutPattern: .frontalRows
            )
            return PedagogicalCodingResult(.init(content: content, context: context))
        }

        let forward = result(reversed: false)
        let backward = result(reversed: true)
        XCTAssertEqual(forward.topTIMSS().map(\.code), backward.topTIMSS().map(\.code))
        XCTAssertEqual(forward.topGTI().map(\.code), backward.topGTI().map(\.code))

        let scene = testTeachingSceneAssessment(
            sceneType: .boardCentricFrontal,
            layoutPattern: .frontalRows
        )
        XCTAssertEqual(
            CodingInformedReflection.scaffoldNotes(coding: forward, scene: scene, situation: .frontalBoardInstruction),
            CodingInformedReflection.scaffoldNotes(coding: backward, scene: scene, situation: .frontalBoardInstruction)
        )
        XCTAssertEqual(
            PedagogicalCalibrationTable.ipnElevationHolds(coding: forward, scene: .boardCentricFrontal),
            PedagogicalCalibrationTable.ipnElevationHolds(coding: backward, scene: .boardCentricFrontal)
        )
        XCTAssertEqual(
            PedagogicalCalibrationTable.gtiElevationHolds(coding: forward, scene: .boardCentricFrontal),
            PedagogicalCalibrationTable.gtiElevationHolds(coding: backward, scene: .boardCentricFrontal)
        )
    }
