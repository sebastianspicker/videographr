import Foundation

typealias ResearchTipContext = (
    hasEvidence: Bool,
    structure: ResearchStructureSufficiency,
    quality: ResearchCaptureQuality,
    situation: TeachingSituationID
)

struct ExperimentalCaptureAssessment {
    var tips: [GuidanceTip]
    var scene: TeachingSceneAssessment
    var placement: PlacementAssessment
    var coding: PedagogicalCodingResult
}

/// Pure, testable camera-setup guidance for Videographr (domain: Unterrichtsvideographie).
/// Focus: how to place iPhone/iPad so continuous takes support later analysis
/// (level frame, interaction zone, board, no contre-jour, usable composition).
public struct GuidanceEngine: Sendable {
    public var config: GuidanceConfig

    public init(config: GuidanceConfig = .default) {
        self.config = config
    }

    public func evaluate(_ input: GuidanceInput) -> GuidanceResult {
        let observability = CaptureObservabilityAssessment.assess(
            orientation: input.orientation,
            frame: input.frame,
            cv: input.cv,
            motion: input.motion
        )
        guard input.operatingMode.isExperimental else {
            return evidenceSafeResult(observability: observability, teachingSituation: input.teachingSituation)
        }
        return experimentalResult(input, observability: observability)
    }

    private func experimentalResult(
        _ input: GuidanceInput,
        observability: CaptureObservabilityAssessment
    ) -> GuidanceResult {
        var assessment = experimentalCaptureAssessment(input)
        appendPlacementSummary(
            to: &assessment.tips,
            placement: assessment.placement,
            situation: input.teachingSituation
        )
        let structure = ResearchStructureAssessor.assess(
            cv: input.cv,
            scene: assessment.scene,
            teachingSituation: input.teachingSituation
        )
        var qualityInput = ResearchCaptureQuality.AssessmentInput(
            placement: assessment.placement,
            scene: assessment.scene,
            coding: assessment.coding
        )
        qualityInput.teachingSituation = input.teachingSituation
        qualityInput.structureSufficiency = structure
        let quality = ResearchCaptureQuality.assess(qualityInput)
        let researchContext: ResearchTipContext = (
            hasEvidence: hasStructureEvidence(input, assessment: assessment),
            structure: structure,
            quality: quality,
            situation: input.teachingSituation
        )
        appendResearchTips(to: &assessment.tips, input: input, assessment: assessment, context: researchContext)
        return makeExperimentalResult(
            assessment,
            input: input,
            context: researchContext,
            observability: observability
        )
    }

    private func experimentalCaptureAssessment(_ input: GuidanceInput) -> ExperimentalCaptureAssessment {
        let activeConfig = mergeConfig(
            base: config,
            situation: GuidanceConfig.forTeachingSituation(input.teachingSituation)
        )
        let engine = GuidanceEngine(config: activeConfig)
        var tips = engine.captureTips(input)
        let scene = TeachingSceneAssessor.assess(
            cv: input.cv,
            frame: input.frame,
            preset: input.teachingSituation
        )
        tips.append(contentsOf: engine.evaluateTeachingScene(
            scene,
            situation: input.teachingSituation,
            cv: input.cv
        ))
        tips.append(contentsOf: engine.evaluatePresetExpectations(
            cv: input.cv,
            scene: scene,
            situation: input.teachingSituation
        ))
        var placementInput = PlacementAssessment.AssessmentInput(
            orientation: input.orientation,
            frame: input.frame
        )
        placementInput.tips = tips
        placementInput.config = activeConfig
        placementInput.cv = input.cv
        placementInput.motion = input.motion
        placementInput.scene = scene
        placementInput.teachingSituation = input.teachingSituation
        let placement = PlacementAssessment.assess(placementInput)
        let coding = PedagogicalCoder.code(PedagogicalCodeInput(
            cv: input.cv,
            scene: scene,
            settings: .init(
                teachingSituation: input.teachingSituation,
                frame: input.frame,
                analysisFocus: input.analysisFocus
            )
        ))
        return ExperimentalCaptureAssessment(
            tips: tips,
            scene: scene,
            placement: placement,
            coding: coding
        )
    }

    private func captureTips(_ input: GuidanceInput) -> [GuidanceTip] {
        var tips = evaluateOrientation(input.orientation)
        tips += evaluateCeilingAndFloor(input.orientation, frame: input.frame)
        tips += evaluateBlackboard(frame: input.frame, cv: input.cv)
        tips += evaluateInteractionZone(input.orientation, frame: input.frame, cv: input.cv)
        tips += evaluateBacklight(input.frame)
        tips += evaluateComposition(input.frame)
        tips += evaluateExposureStructure(input.frame)
        tips += evaluatePeopleCV(input.cv)
        tips += evaluateMotion(input.motion)
        return tips
    }

    private func hasStructureEvidence(
        _ input: GuidanceInput,
        assessment: ExperimentalCaptureAssessment
    ) -> Bool {
        input.cv.analysisSucceeded
            && (assessment.scene.confidence >= 0.25 || assessment.coding.overallConfidence > 0.15)
    }

    private func appendResearchTips(
        to tips: inout [GuidanceTip],
        input: GuidanceInput,
        assessment: ExperimentalCaptureAssessment,
        context: ResearchTipContext
    ) {
        appendStructureTips(to: &tips, context: context)
        appendResearchQualityTip(to: &tips, context: context)
        appendSignalCompletenessTip(to: &tips, cv: input.cv)
        appendCodingAlignmentTips(
            to: &tips,
            hasStructureEvidence: context.hasEvidence,
            coding: assessment.coding,
            situation: input.teachingSituation
        )
    }

    private func makeExperimentalResult(
        _ assessment: ExperimentalCaptureAssessment,
        input: GuidanceInput,
        context: ResearchTipContext,
        observability: CaptureObservabilityAssessment
    ) -> GuidanceResult {
        var result = GuidanceResult.Values(tips: assessment.tips, placement: assessment.placement)
        result.scene = assessment.scene
        result.pedagogicalCoding = assessment.coding
        result.teachingSituation = input.teachingSituation
        result.researchQuality = context.quality
        result.structureSufficiency = context.structure
        result.observability = observability
        result.operatingMode = input.operatingMode
        result.experimentalHypotheses = .fromLegacyCoding(assessment.coding)
        return GuidanceResult(result)
    }

}
