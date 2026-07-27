import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testProductionVisionAdapterSourceIsPresentAndWired() throws {
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // TeachingSceneAndCodingTests.swift dir
            .deletingLastPathComponent() // GuidanceEngineTests
            .deletingLastPathComponent() // Tests
        let adapter = root
            .appendingPathComponent("App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift")
        let sampler = root
            .appendingPathComponent("App/Unterrichtsvideographie/Live/FrameSampler.swift")
        let camera = root
            .appendingPathComponent("App/Unterrichtsvideographie/Live/CameraSessionModel.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: adapter.path), "missing \(adapter.path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampler.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: camera.path))

        let adapterSrc = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift",
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        let samplerSrc = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/FrameSampler.swift"
        )
        let cameraSrc = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/CameraSessionModel.swift"
        )

        // Multi-cue board + people + co-presence + stability + honest fail.
        XCTAssertTrue(adapterSrc.contains("VNDetectRectanglesRequest"))
        XCTAssertTrue(adapterSrc.contains("VNDetectHumanRectanglesRequest"))
        XCTAssertTrue(adapterSrc.contains("VNDetectFaceRectanglesRequest"))
        XCTAssertTrue(adapterSrc.contains("VNDetectDocumentSegmentationRequest"))
        XCTAssertTrue(sourceContainsAny(adapterSrc, ["VNRecognizeTextRequest", "makeTextRequest"]))
        XCTAssertTrue(adapterSrc.contains("VNDetectHumanBodyPoseRequest"))
        XCTAssertTrue(adapterSrc.contains("analysisSucceeded: false"))
        XCTAssertTrue(sourceContainsAny(adapterSrc, ["CVObservationSmoother", "smoother"]))
        XCTAssertTrue(sourceContainsAny(adapterSrc, ["boardEdgeSupport", "fuseBoardEdgeSupport"]))
        XCTAssertTrue(sourceContainsAny(adapterSrc, ["personBoardCoPresence", "coPresence"]))
        XCTAssertTrue(adapterSrc.contains("ClassroomLayoutAnalyzer"), "production ML must emit layout structure")
        XCTAssertTrue(sourceContainsAny(adapterSrc, ["boardTextDensity", "textSupport"]))
        XCTAssertTrue(adapterSrc.contains("configure(for:"), "preset-aware Vision cadence")
        XCTAssertTrue(adapterSrc.contains("layoutPattern"))

        // Wired into live capture path with teaching-situation preset.
        XCTAssertTrue(samplerSrc.contains("VisionClassroomAnalyzer"))
        XCTAssertTrue(sourceContainsAny(samplerSrc, ["configureVision", "configure(for:"]))
        XCTAssertTrue(cameraSrc.contains("teachingSituation"))
        XCTAssertTrue(sourceContainsAny(cameraSrc, ["GuidanceInput", "engine.evaluate"]))
        XCTAssertTrue(cameraSrc.contains("recomputeGuidance"))
        XCTAssertTrue(sourceContainsAny(cameraSrc, ["prepareVision", "configureVision", "sampler.configureVision"]))
    }

    func testLayoutPatternsOnResearchFixtures() {
        XCTAssertEqual(CVFeatures.fixtureClassroomPresent().layoutPattern, .frontalRows)
        XCTAssertEqual(CVFeatures.fixtureGroupWork().layoutPattern, .multiCluster)
        XCTAssertEqual(CVFeatures.fixtureDialoguePair().layoutPattern, .dyadClose)
        XCTAssertEqual(CVFeatures.fixtureCircleDiscussion().layoutPattern, .circleLike)
        XCTAssertEqual(CVFeatures.fixtureExperimentSpread().layoutPattern, .sparseSpread)
        XCTAssertEqual(CVFeatures.fixtureSeatworkScattered().layoutPattern, .seatworkScattered)
        XCTAssertEqual(CVFeatures.fixtureTeacherDemonstration().layoutPattern, .presentationFocus)
        XCTAssertEqual(CVFeatures.fixtureEmptyRoom().layoutPattern, .empty)
    }

    func testLayoutAnalyzerFromPersonRects() {
        let board = ImageNormalizedRect(x: 0.2, y: 0.1, width: 0.6, height: 0.3)
        let people = [
            ImageNormalizedRect(x: 0.25, y: 0.45, width: 0.12, height: 0.28),
            ImageNormalizedRect(x: 0.45, y: 0.48, width: 0.12, height: 0.26),
            ImageNormalizedRect(x: 0.62, y: 0.5, width: 0.11, height: 0.25)
        ]
        var input = ClassroomLayoutAnalysisInput(personRects: people)
        input.board = board
        input.boardConfidence = 0.8
        let metrics = ClassroomLayoutAnalyzer.analyze(input)
        XCTAssertGreaterThan(metrics.horizontalSpread, 0.1)
        XCTAssertNotEqual(metrics.pattern, .empty)
        XCTAssertGreaterThanOrEqual(metrics.estimatedClusterCount, 1)
    }

    func testNewPresetsClassifyAndMatchIntendedFixtures() {
        let seat = TeachingSceneAssessor.assess(
            cv: .fixtureSeatworkScattered(),
            preset: .individualSeatwork
        )
        XCTAssertEqual(seat.sceneType, .individualSeatwork)
        XCTAssertTrue(seat.matchesPreset)
        XCTAssertGreaterThan(seat.layoutSignal, 0.5)

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

        let transition = TeachingSceneAssessor.assess(
            cv: .fixtureTransitionOrganization(),
            preset: .transitionOrganization
        )
        XCTAssertTrue(
            transition.sceneType == .transitionMoment
                || transition.sceneType == .wholeRoomOverview
        )
        XCTAssertTrue(transition.matchesPreset)

        let formative = TeachingSceneAssessor.assess(
            cv: .fixtureFormativeAssessment(),
            preset: .formativeAssessmentDialogue
        )
        XCTAssertEqual(formative.sceneType, .dialoguePair)
        XCTAssertTrue(formative.matchesPreset)
    }

    func testCodingIncludesGTIFamilyAndFullIPN() {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertEqual(coding.ipnDimensions.count, IPNDimensionCode.allCases.count)
        XCTAssertEqual(coding.gtiDimensions.count, GTIQualityCode.allCases.count)
        XCTAssertFalse(coding.timssActivities.isEmpty)
        XCTAssertEqual(coding.layoutPattern, .frontalRows)
        XCTAssertTrue(
            coding.summaryDE.contains("GTI")
                || coding.gtiDimensions.contains(where: { $0.level > 0.2 })
        )
    }

    func testSeatworkAndDemoAndTransitionCodingPaths() {
        let seatScene = TeachingSceneAssessor.assess(cv: .fixtureSeatworkScattered(), preset: .individualSeatwork)
        let seatCode = PedagogicalCoder.code(
            cv: .fixtureSeatworkScattered(),
            scene: seatScene,
            teachingSituation: .individualSeatwork
        )
        XCTAssertEqual(seatCode.primaryTIMSS, .seatworkIndividual)

        let demoScene = TeachingSceneAssessor.assess(cv: .fixtureTeacherDemonstration(), preset: .teacherDemonstration)
        let demoCode = PedagogicalCoder.code(
            cv: .fixtureTeacherDemonstration(),
            scene: demoScene,
            teachingSituation: .teacherDemonstration
        )
        XCTAssertTrue(
            demoCode.primaryTIMSS == .publicBoardWork
                || demoCode.primaryTIMSS == .wholeClassInstruction
        )
        let goal = demoCode.ipnDimensions.first { $0.code == IPNDimensionCode.goalOrientation.rawValue }
        guard let goal else { return XCTFail("Expected goal-orientation IPN dimension") }
        XCTAssertGreaterThan(goal.level, 0.4)

        let trScene = TeachingSceneAssessor.assess(cv: .fixtureTransitionOrganization(), preset: .transitionOrganization)
        let trCode = PedagogicalCoder.code(
            cv: .fixtureTransitionOrganization(),
            scene: trScene,
            teachingSituation: .transitionOrganization
        )
        XCTAssertEqual(trCode.primaryTIMSS, .transitionOrganization)
    }

    func testPedagogicalCodingWindowAggregates() throws {
        var window = PedagogicalCodingWindow(capacity: 4)
        let scene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let a = PedagogicalCoder.code(cv: .fixtureClassroomPresent(), scene: scene, teachingSituation: .frontalBoardInstruction)
        let b = PedagogicalCoder.code(cv: .fixtureClassroomPresent(), scene: scene, teachingSituation: .frontalBoardInstruction)
        window.push(a)
        window.push(b)
        let agg = try XCTUnwrap(window.aggregate())
        XCTAssertEqual(agg.ipnDimensions.count, IPNDimensionCode.allCases.count)
        XCTAssertEqual(agg.gtiDimensions.count, GTIQualityCode.allCases.count)
        XCTAssertTrue(agg.summaryDE.contains("Zeitfenster") || agg.overallConfidence > 0)
    }

}

private func sourceContainsAny(_ source: String, _ tokens: [String]) -> Bool {
    tokens.contains(where: source.contains)
}
