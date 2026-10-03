import GuidanceEngine
import SessionCore

public extension ExperimentalResearchEngine {
    func evaluatePresetExpectations(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID
    ) -> [ExperimentalResearchTip] {
        presetExpectationTips(cv: cv, scene: scene, situation: situation)
    }

    func evaluateGTICaptureExpectations(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        preset: TeachingSituationPreset? = nil
    ) -> [ExperimentalResearchTip] {
        gtiCaptureExpectationTips(cv: cv, scene: scene, situation: situation, preset: preset)
    }
}
