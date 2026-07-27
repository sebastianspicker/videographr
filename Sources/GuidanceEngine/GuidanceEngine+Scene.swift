import Foundation

extension GuidanceEngine {
    /// Prefer situation-tuned thresholds for scene-sensitive knobs; keep any stricter caller overrides on geometry.
    func mergeConfig(base: GuidanceConfig, situation: GuidanceConfig) -> GuidanceConfig {
        var c = base
        c.boardMinScore = situation.boardMinScore
        c.minMultiCueBoardQuality = situation.minMultiCueBoardQuality
        c.minPersonBoardCoPresence = situation.minPersonBoardCoPresence
        c.minPersonCoverage = situation.minPersonCoverage
        c.minPeopleSpatialUsefulness = situation.minPeopleSpatialUsefulness
        c.minPersonMidBandOccupancy = situation.minPersonMidBandOccupancy
        c.interactionZoneMinScore = situation.interactionZoneMinScore
        c.interactionZoneCriticalScore = situation.interactionZoneCriticalScore
        c.emptyEdgeCritical = situation.emptyEdgeCritical
        c.minGlobalContrast = situation.minGlobalContrast
        c.floorWarningFraction = situation.floorWarningFraction
        return c
    }

    public func evaluateTeachingScene(
        _ scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        cv: CVFeatures = .empty
    ) -> [GuidanceTip] {
        teachingSceneTips(scene, situation: situation, cv: cv)
    }

    public func evaluatePresetExpectations(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID
    ) -> [GuidanceTip] {
        presetExpectationTips(cv: cv, scene: scene, situation: situation)
    }

    public func evaluateGTICaptureExpectations(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        preset: TeachingSituationPreset? = nil
    ) -> [GuidanceTip] {
        gtiCaptureExpectationTips(cv: cv, scene: scene, situation: situation, preset: preset)
    }
}
