import Foundation

extension GuidanceEngine {
    func teachingSceneTips(
        _ scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        cv: CVFeatures
    ) -> [GuidanceTip] {
        if let earlyTips = earlyTeachingSceneTips(scene, situation: situation, cv: cv) {
            return earlyTips
        }
        return teachingSceneMatchTips(scene, situation: situation)
    }

    private func earlyTeachingSceneTips(
        _ scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        cv: CVFeatures
    ) -> [GuidanceTip]? {
        guard cv.analysisSucceeded else {
            return cvAnalysisFailureTips(cv, situation: situation)
        }
        guard scene.confidence >= 0.25 else { return [] }
        guard let emptySceneTip = emptyTeachingSceneTip(scene, situation: situation) else { return nil }
        return [emptySceneTip]
    }

    private func cvAnalysisFailureTips(
        _ cv: CVFeatures,
        situation: TeachingSituationID
    ) -> [GuidanceTip] {
        guard cv.source == .vision || cv.source == .fixture else { return [] }
        let preset = TeachingSituationCatalogue.preset(for: situation)
        return [
            GuidanceTip((
                id: "cv-analysis-failed",
                category: .teachingScene,
                severity: .warning,
                message: "Struktur-CV fehlgeschlagen - Unterrichtsszene und Akteure nicht auswertbar.",
                actionHint: "Kamera freigeben, Beleuchtung prüfen, Ausschnitt ruhig halten und erneut versuchen (Situation: \(preset.titleDE)). Ohne Strukturanalyse ist die experimentelle Regelprüfung nicht verfügbar."
            ))
        ]
    }

    private func emptyTeachingSceneTip(
        _ scene: TeachingSceneAssessment,
        situation: TeachingSituationID
    ) -> GuidanceTip? {
        guard scene.sceneType == .emptyOrUnusable else { return nil }
        guard scene.confidence >= 0.5 else { return nil }
        let preset = TeachingSituationCatalogue.preset(for: situation)
        return GuidanceTip((
            id: "scene-empty",
            category: .teachingScene,
            severity: .critical,
            message: "Die unvalidierte Regelprüfung meldet einen leeren oder nicht passenden Ausschnitt.",
            actionHint: "Kamera auf das Lehr-Lern-Geschehen richten (Situation: \(preset.titleDE))."
        ))
    }

    private func teachingSceneMatchTips(
        _ scene: TeachingSceneAssessment,
        situation: TeachingSituationID
    ) -> [GuidanceTip] {
        let preset = TeachingSituationCatalogue.preset(for: situation)
        if !scene.matchesPreset {
            return [GuidanceTip((
                id: "scene-preset-mismatch",
                category: .teachingScene,
                severity: scene.presetMatchScore < 0.30 ? .warning : .info,
                message: scene.summaryDE,
                actionHint: preset.mismatchHintDE
            ))]
        }
        guard scene.presetMatchScore >= 0.7 else { return [] }
        return [GuidanceTip((
            id: "scene-preset-match",
            category: .teachingScene,
            severity: .ok,
            message: scene.summaryDE,
            actionHint: "Ausschnitt beibehalten; Stativ nicht mehr bewegen."
        ))]
    }
}
