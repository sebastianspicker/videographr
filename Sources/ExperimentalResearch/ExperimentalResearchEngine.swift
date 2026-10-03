import Foundation
import GuidanceEngine
import SessionCore

/// Explicitly opt-in, unvalidated research evaluation. This is separate from
/// `GuidanceEngine.evaluate`, whose output remains direct observability only.
public struct ExperimentalResearchResult: Equatable, Sendable {
    public var observability: GuidanceResult
    public var teachingSituation: TeachingSituationID
    public var scene: TeachingSceneAssessment
    public var coding: PedagogicalCodingResult
    public var structureSufficiency: ResearchStructureSufficiency
    public var researchQuality: ResearchCaptureQuality
    public var hypotheses: ExperimentalHypothesisSet

    public var isUnvalidatedRuleSetPass: Bool {
        observability.placement.directSignalsPass
            && scene.matchesPreset
            && structureSufficiency.sufficient
            && researchQuality.level != .unsuitable
    }
}

public struct ExperimentalResearchEngine: Sendable {
    public var guidance: GuidanceEngine

    public init(guidance: GuidanceEngine = GuidanceEngine()) {
        self.guidance = guidance
    }

    var config: GuidanceConfig { guidance.config }

    func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }

    public func evaluate(
        orientation: OrientationSample,
        frame: FrameMetrics,
        cv: CVFeatures = .empty,
        motion: MotionMetrics = .stable,
        teachingSituation: TeachingSituationID,
        analysisFocus: CodingAnalysisFocus? = nil,
        experimentalSignals: ExperimentalCaptureSignals? = nil
    ) -> ExperimentalResearchResult {
        var safeInput = GuidanceInput.Values(orientation: orientation, frame: frame)
        safeInput.cv = cv
        safeInput.motion = motion
        let safe = guidance.evaluate(GuidanceInput(safeInput))
        return evaluate(
            observability: safe,
            frame: frame,
            cv: cv,
            teachingSituation: teachingSituation,
            analysisFocus: analysisFocus,
            experimentalSignals: experimentalSignals
        )
    }

    /// Runs only the opt-in research rules when direct observability was already evaluated by
    /// the caller for the same frame. This avoids repeating the direct engine on each frame.
    public func evaluate(
        observability: GuidanceResult,
        frame: FrameMetrics,
        cv: CVFeatures = .empty,
        teachingSituation: TeachingSituationID,
        analysisFocus: CodingAnalysisFocus? = nil,
        experimentalSignals: ExperimentalCaptureSignals? = nil
    ) -> ExperimentalResearchResult {
        let signals = experimentalSignals ?? ExperimentalCaptureSignals(cv: cv)
        let scene = TeachingSceneAssessor.assess(signals: signals, frame: frame, preset: teachingSituation)
        let coding = PedagogicalCoder.code(PedagogicalCodeInput(
            cv: cv,
            scene: scene,
            settings: .init(teachingSituation: teachingSituation, frame: frame, analysisFocus: analysisFocus)
        ))
        let structure = ResearchStructureAssessor.assess(cv: cv, scene: scene, teachingSituation: teachingSituation)
        var qualityInput = ResearchCaptureQuality.AssessmentInput(
            placement: observability.placement,
            scene: scene,
            coding: coding
        )
        qualityInput.teachingSituation = teachingSituation
        qualityInput.structureSufficiency = structure
        let quality = ResearchCaptureQuality.assess(qualityInput)
        return ExperimentalResearchResult(
            observability: observability,
            teachingSituation: teachingSituation,
            scene: scene,
            coding: coding,
            structureSufficiency: structure,
            researchQuality: quality,
            hypotheses: ExperimentalHypothesisSet(
                hypotheses: (coding.ipnDimensions + coding.timssActivities + coding.gtiDimensions).map(ExperimentalHypothesis.init)
            )
        )
    }
}
