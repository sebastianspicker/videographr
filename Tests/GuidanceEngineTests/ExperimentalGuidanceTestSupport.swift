@testable import GuidanceEngine

let testResearchProvenance = ResearchArtifactProvenance((
    semanticVersion: "test",
    buildNumber: "1",
    schemaVersion: 2,
    algorithmVersion: "experimental-coding-rules-test",
    evidenceRegistryVersion: "1"
))

let testReportGeneratorProvenance = ResearchArtifactProvenance((
    semanticVersion: "test",
    buildNumber: "1",
    schemaVersion: 2,
    algorithmVersion: "research-report-test",
    evidenceRegistryVersion: "1"
))

/// Legacy scene/coding expectations must opt into the explicitly unvalidated mode.
struct ExperimentalGuidanceOptions {
    var cv: CVFeatures
    var motion: MotionMetrics
    var teachingSituation: TeachingSituationID
    var analysisFocus: CodingAnalysisFocus?

    init(
        cv: CVFeatures,
        motion: MotionMetrics = .stable,
        teachingSituation: TeachingSituationID = .frontalBoardInstruction,
        analysisFocus: CodingAnalysisFocus? = nil
    ) {
        self.cv = cv
        self.motion = motion
        self.teachingSituation = teachingSituation
        self.analysisFocus = analysisFocus
    }
}

func experimentalGuidanceInput(
    orientation: OrientationSample,
    frame: FrameMetrics,
    cv: CVFeatures = .empty,
    motion: MotionMetrics = .stable
) -> GuidanceInput {
    experimentalGuidanceInput(
        orientation: orientation,
        frame: frame,
        options: ExperimentalGuidanceOptions(cv: cv, motion: motion)
    )
}

func experimentalGuidanceInput(
    orientation: OrientationSample,
    frame: FrameMetrics,
    options: ExperimentalGuidanceOptions
) -> GuidanceInput {
    GuidanceInput({
    var values = GuidanceInput.Values(orientation: orientation, frame: frame)
    values.cv = options.cv
    values.motion = options.motion
    values.teachingSituation = options.teachingSituation
    values.analysisFocus = options.analysisFocus
    values.operatingMode = .experimentalResearch(protocolReference: "test-only-unvalidated-rules")
    return values
}())
}

func testTeachingSceneAssessment(
    sceneType: TeachingSceneType,
    layoutPattern: ClassroomLayoutPattern,
    matchesPreset: Bool = true
) -> TeachingSceneAssessment {
    let classification = TeachingSceneAssessment.Classification(
        sceneType: sceneType,
        confidence: 0.8,
        presetMatchScore: 0.8,
        matchesPreset: matchesPreset
    )
    let structure = TeachingSceneAssessment.StructureSignals(layoutPattern: layoutPattern)
    let values = TeachingSceneAssessment.Values(
        classification: classification,
        summaryDE: "fixture",
        structureSignals: structure
    )
    return TeachingSceneAssessment(values)
}

func testStandardGoodFrame() -> FrameMetrics {
    FrameMetrics({
        var values = FrameMetrics.Values()
        values.averageLuminance = 0.45
        values.topBandLuminance = 0.5
        values.bottomBandLuminance = 0.4
        values.leftBandLuminance = 0.42
        values.rightBandLuminance = 0.43
        values.boardRegionScore = 0.55
        values.boardCenterY = 0.38
        values.boardCenterX = 0.5
        values.ceilingFraction = 0.12
        values.floorFraction = 0.12
        values.backlightScore = 0.1
        values.horizontalBrightnessImbalance = 0.05
        values.emptyEdgeFraction = 0.15
        values.globalContrast = 0.4
        values.midBandVariance = 0.03
        values.edgeEnergy = 0.1
        values.clippedHighlightFraction = 0.02
        values.clippedShadowFraction = 0.02
        values.brightnessCenterY = 0.48
        return values
    }())
}

func testFusionGoodFrame() -> FrameMetrics {
    FrameMetrics({
        var values = FrameMetrics.Values()
        values.averageLuminance = 0.48
        values.topBandLuminance = 0.55
        values.bottomBandLuminance = 0.4
        values.leftBandLuminance = 0.45
        values.rightBandLuminance = 0.45
        values.boardRegionScore = 0.75
        values.boardCenterY = 0.42
        values.boardCenterX = 0.5
        values.ceilingFraction = 0.12
        values.floorFraction = 0.12
        values.backlightScore = 0.15
        values.horizontalBrightnessImbalance = 0.05
        values.emptyEdgeFraction = 0.12
        values.globalContrast = 0.45
        values.midBandVariance = 0.03
        values.edgeEnergy = 0.1
        values.clippedHighlightFraction = 0.02
        values.clippedShadowFraction = 0.02
        values.brightnessCenterY = 0.48
        return values
    }())
}

func testGuidanceResult(
    frame: FrameMetrics = testStandardGoodFrame(),
    cv: CVFeatures = .fixtureClassroomPresent(),
    teachingSituation: TeachingSituationID = .frontalBoardInstruction,
    analysisFocus: CodingAnalysisFocus? = nil
) -> GuidanceResult {
    GuidanceEngine().evaluate(experimentalGuidanceInput(
        orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
        frame: frame,
        options: ExperimentalGuidanceOptions(
            cv: cv,
            teachingSituation: teachingSituation,
            analysisFocus: analysisFocus
        )
    ))
}

func testResearchCodingSnapshot(
    configure: (inout ResearchCodingSnapshot.Values) -> Void = { _ in }
) -> ResearchCodingSnapshot {
    ResearchCodingSnapshot({
        var values = ResearchCodingSnapshot.Values(provenance: testResearchProvenance)
        values.teachingSituation = TeachingSituationID.frontalBoardInstruction.rawValue
        values.sceneType = "boardCentricFrontal"
        values.layoutPattern = "frontalRows"
        values.presetMatchScore = 0.8
        values.matchesPreset = true
        values.sceneConfidence = 0.8
        values.primaryTIMSS = "wholeClassInstruction"
        values.primaryGTI = "instructionalQuality"
        values.overallConfidence = 0.8
        values.summaryDE = "fixture"
        values.ipn = []
        values.timss = []
        values.gti = []
        values.boardSignal = 0.8
        values.peopleSignal = 0.8
        values.coPresenceSignal = 0.8
        values.layoutSignal = 0.8
        configure(&values)
        return values
    }())
}

func testClassroomPlacement(
    scene: TeachingSceneAssessment,
    frame: FrameMetrics = testStandardGoodFrame()
) -> PlacementAssessment {
    var input = PlacementAssessment.AssessmentInput(
        orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
        frame: frame
    )
    input.cv = .fixtureClassroomPresent()
    input.scene = scene
    input.teachingSituation = .frontalBoardInstruction
    return PlacementAssessment.assess(input)
}

func testClassroomCoding(frame: FrameMetrics = testStandardGoodFrame()) -> PedagogicalCodingResult {
    let scene = TeachingSceneAssessor.assess(
        cv: .fixtureClassroomPresent(),
        preset: .frontalBoardInstruction
    )
    return PedagogicalCoder.code(
        cv: .fixtureClassroomPresent(),
        scene: scene,
        teachingSituation: .frontalBoardInstruction,
        frame: frame
    )
}

func testCodingResult(
    cv: CVFeatures,
    teachingSituation: TeachingSituationID
) -> PedagogicalCodingResult {
    let scene = TeachingSceneAssessor.assess(cv: cv, preset: teachingSituation)
    return PedagogicalCoder.code(cv: cv, scene: scene, teachingSituation: teachingSituation)
}

func testLessonAnalysisSnapshot() -> ResearchCodingSnapshot {
    let scene = TeachingSceneAssessor.assess(
        cv: .fixtureClassroomPresent(),
        preset: .frontalBoardInstruction
    )
    let coding = PedagogicalCoder.code(
        cv: .fixtureClassroomPresent(),
        scene: scene,
        teachingSituation: .frontalBoardInstruction,
        analysisFocus: .lessonAnalysis
    )
    return ResearchCodingSnapshot.from(
        coding: coding,
        scene: scene,
        analysisFocus: .lessonAnalysis,
        provenance: testResearchProvenance
    )
}

func testFrameWithWeakBoardPosition() -> FrameMetrics {
    var frame = testFusionGoodFrame()
    frame.boardRegionScore = 0.2
    frame.boardCenterX = 0.1
    frame.boardCenterY = 0.1
    return frame
}
