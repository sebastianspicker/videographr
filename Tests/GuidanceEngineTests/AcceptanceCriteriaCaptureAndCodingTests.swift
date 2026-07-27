import XCTest
@testable import GuidanceEngine

extension AcceptanceCriteriaTests {
    func testCaptureGuardrailsConfigureAVFoundationAndSanitizeRouteMetadata() throws {
        let cameraSource = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/CameraSessionModel.swift"
        )
        let controllerSource = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/CaptureSessionController.swift"
        )
        let liveSource = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/LiveGuidanceView.swift"
        )

        for token in [
            "movieOutput.maxRecordedDuration = request.maximumDuration",
            "movieOutput.maxRecordedFileSize = request.maximumFileSize",
            "startCapacityMonitor(for: recording)",
            "volumeAvailableCapacityForImportantUsageKey"
        ] {
            XCTAssertTrue(controllerSource.contains(token), "missing capture guardrail: \(token)")
        }
        for token in [
            "func enforceCaptureAuthorization(",
            "normalizedAudioRoute(portTypeRawValues:"
        ] {
            XCTAssertTrue(cameraSource.contains(token), "missing capture guardrail: \(token)")
        }
        XCTAssertFalse(cameraSource.contains("portName"), "device-provided route names must not be retained")
        for token in [
            "syncCaptureAuthorization()",
            "reserveProtectedArtifact()",
            "cleanupAbandonedFiles()"
        ] {
            XCTAssertTrue(liveSource.contains(token), "missing live capture boundary: \(token)")
        }
    }

    // MARK: AC4 - Full IPN / TIMSS / GTI software coding layers

    func testAC4_fullIPNTIMSSGTICodingWithHonestEmptyPaths(){
        aC4_fullIPNTIMSSGTICodingWithHonestEmptyPathsAssertions()
    }

    // MARK: AC5 exercised by suite run; experimental composite rule

    func testAC5_researchQualityCompositeUsesSceneNotOnlyPlacement(){
        aC5_researchQualityCompositeUsesSceneNotOnlyPlacementAssertions()
    }

    // MARK: - Helpers

    static func goodFrame() -> FrameMetrics {
        testStandardGoodFrame()
    }
}

extension GuidanceResult {
    /// Board multi-cue or scene board signal for assertions without private access.
    func cvFeaturesBoardOrScene() -> Double {
        max(scene.boardSignal, researchQuality.placementScore > 0 ? scene.boardSignal : 0)
    }
}


private let aC4_fullIPNTIMSSGTICodingWithHonestEmptyPathsAssertions: @Sendable () -> Void = {
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)
        XCTAssertEqual(
            Set(GTIQualityCode.allCases.map(\.domain)),
            Set(["classroomManagement", "socialEmotionalSupport", "instruction"])
        )

        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            frame: AcceptanceCriteriaTests.goodFrame(),
            preset: .frontalBoardInstruction
        )
        let codingSettings = PedagogicalCodeInput.Settings(
            teachingSituation: .frontalBoardInstruction,
            frame: AcceptanceCriteriaTests.goodFrame(),
            analysisFocus: .lessonAnalysis
        )
        let coding = PedagogicalCoder.code(PedagogicalCodeInput(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            settings: codingSettings
        ))
        XCTAssertEqual(coding.ipnDimensions.count, IPNDimensionCode.allCases.count)
        XCTAssertEqual(coding.gtiDimensions.count, GTIQualityCode.allCases.count)
        XCTAssertFalse(coding.timssActivities.isEmpty)
        XCTAssertGreaterThan(coding.overallConfidence, 0.2)
        XCTAssertNotEqual(coding.primaryTIMSS, .unclearOrNonInstructional)
        XCTAssertEqual(coding.analysisFocus, .lessonAnalysis)

        // Failed CV → no invented IPN/GTI
        let failedScene = TeachingSceneAssessor.assess(
            cv: .fixtureAnalysisFailed(),
            preset: .frontalBoardInstruction
        )
        let failed = PedagogicalCoder.code(
            cv: .fixtureAnalysisFailed(),
            scene: failedScene,
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(failed.ipnDimensions.isEmpty)
        XCTAssertTrue(failed.gtiDimensions.isEmpty)
        XCTAssertEqual(failed.overallConfidence, 0)

        // Empty room → TIMSS unclear, no full IPN set
        let emptyScene = TeachingSceneAssessor.assess(
            cv: .fixtureEmptyRoom(),
            preset: .frontalBoardInstruction
        )
        let empty = PedagogicalCoder.code(
            cv: .fixtureEmptyRoom(),
            scene: emptyScene,
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(empty.ipnDimensions.isEmpty)
        XCTAssertEqual(empty.primaryTIMSS, .unclearOrNonInstructional)

        // Cross-family research fixtures
        let groupScene = TeachingSceneAssessor.assess(
            cv: .fixtureGroupWork(),
            preset: .collaborativeGroupWork
        )
        let groupCode = PedagogicalCoder.code(
            cv: .fixtureGroupWork(),
            scene: groupScene,
            teachingSituation: .collaborativeGroupWork
        )
        XCTAssertEqual(groupCode.primaryTIMSS, .groupWork)

        let expScene = TeachingSceneAssessor.assess(
            cv: .fixtureExperimentSpread(),
            preset: .handsOnExperiment
        )
        let expCode = PedagogicalCoder.code(
            cv: .fixtureExperimentSpread(),
            scene: expScene,
            teachingSituation: .handsOnExperiment
        )
        XCTAssertEqual(expCode.primaryTIMSS, .experimentLab)
        let expIPN = expCode.ipnDimensions.first { $0.code == IPNDimensionCode.experimentation.rawValue }
        guard let expIPN else { return XCTFail("Expected experimentation IPN dimension") }
        XCTAssertGreaterThan(expIPN.level, 0.4)
    }

private let aC5_researchQualityCompositeUsesSceneNotOnlyPlacementAssertions: @Sendable () -> Void = {
        let sceneEmpty = TeachingSceneAssessor.assess(
            cv: .fixtureEmptyRoom(),
            preset: .frontalBoardInstruction
        )
        var placementEmptyInput = PlacementAssessment.AssessmentInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: AcceptanceCriteriaTests.goodFrame()
        )
        placementEmptyInput.cv = .fixtureEmptyRoom()
        placementEmptyInput.scene = sceneEmpty
        placementEmptyInput.teachingSituation = .frontalBoardInstruction
        let placementGoodEmpty = PlacementAssessment.assess(placementEmptyInput)
        let codingEmpty = PedagogicalCoder.code(
            cv: .fixtureEmptyRoom(),
            scene: sceneEmpty,
            teachingSituation: .frontalBoardInstruction
        )
        var emptyInput = ResearchCaptureQuality.AssessmentInput(
            placement: placementGoodEmpty,
            scene: sceneEmpty,
            coding: codingEmpty
        )
        emptyInput.teachingSituation = .frontalBoardInstruction
        let rqEmpty = ResearchCaptureQuality.assess(emptyInput)

        let sceneGood = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let codingGood = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: sceneGood,
            teachingSituation: .frontalBoardInstruction
        )
        var placementGoodInput = PlacementAssessment.AssessmentInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: AcceptanceCriteriaTests.goodFrame()
        )
        placementGoodInput.cv = .fixtureClassroomPresent()
        placementGoodInput.scene = sceneGood
        placementGoodInput.teachingSituation = .frontalBoardInstruction
        let placementGood = PlacementAssessment.assess(placementGoodInput)
        var goodInput = ResearchCaptureQuality.AssessmentInput(
            placement: placementGood,
            scene: sceneGood,
            coding: codingGood
        )
        goodInput.teachingSituation = .frontalBoardInstruction
        let rqGood = ResearchCaptureQuality.assess(goodInput)

        XCTAssertGreaterThan(rqGood.score, rqEmpty.score)
        XCTAssertGreaterThan(rqGood.sceneMatchScore, rqEmpty.sceneMatchScore)
    }
