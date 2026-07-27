import Foundation

extension GuidanceEngine {
    func presetExpectationTips(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID
    ) -> [GuidanceTip] {
        guard cv.analysisSucceeded else { return [] }
        let preset = TeachingSituationCatalogue.preset(for: situation)
        let peopleN = max(cv.personCount, cv.faceCount)
        let board = max(cv.multiCueBoardQuality, cv.boardConfidence)
        var tips = presetBoardRequirementTips(preset, board: board)
        tips += presetPeopleShortfallTips(preset, peopleN: peopleN)
        tips += presetMultiPersonTips(preset, scene: scene, peopleN: peopleN)
        tips += presetBoardDominanceTips(preset, scene: scene, peopleN: peopleN)
        tips += presetCoPresenceTips(preset, cv: cv, peopleN: peopleN)
        tips += evaluateGTICaptureExpectations(cv: cv, scene: scene, situation: situation, preset: preset)
        tips += presetLayoutTips(preset, cv: cv, scene: scene, priorTips: tips)
        tips += presetCaptureGuidanceTips(preset, scene: scene, priorTips: tips)
        return tips
    }

    private func presetBoardRequirementTips(
        _ preset: TeachingSituationPreset,
        board: Double
    ) -> [GuidanceTip] {
        guard preset.requiresBoard else { return [] }
        guard board < config.boardMinScore else { return [] }
        return [GuidanceTip((
            id: "preset-board-required",
            category: .teachingScene,
            severity: .warning,
            message: "Situation „\(preset.titleDE)“ erfordert eine erkennbare Schreibfläche (Score \(percent(board))).",
            actionHint: preset.mismatchHintDE
        ))]
    }

    private func presetPeopleShortfallTips(
        _ preset: TeachingSituationPreset,
        peopleN: Int
    ) -> [GuidanceTip] {
        guard peopleN < preset.minPeople else { return [] }
        return [GuidanceTip((
            id: "preset-people-shortfall",
            category: .teachingScene,
            severity: preset.minPeople >= 3 ? .warning : .info,
            message: "Situation „\(preset.titleDE)“ erwartet ≥ \(preset.minPeople) Akteure - erkannt: \(peopleN).",
            actionHint: "Ausschnitt so wählen, dass die vorgesehenen Akteure der Unterrichtssituation sichtbar sind."
        ))]
    }

    private func presetMultiPersonTips(
        _ preset: TeachingSituationPreset,
        scene: TeachingSceneAssessment,
        peopleN: Int
    ) -> [GuidanceTip] {
        guard preset.prefersMultiPerson else { return [] }
        guard scene.sceneType == .boardCentricFrontal else { return [] }
        guard peopleN < 3 else { return [] }
        return [GuidanceTip((
            id: "preset-wants-group",
            category: .teachingScene,
            severity: .info,
            message: "Tafel-frontale Szene erkannt - für „\(preset.titleDE)“ eher Mehrpersonen-Cluster anstreben.",
            actionHint: preset.mismatchHintDE
        ))]
    }

    private func presetBoardDominanceTips(
        _ preset: TeachingSituationPreset,
        scene: TeachingSceneAssessment,
        peopleN: Int
    ) -> [GuidanceTip] {
        presetBoardOnlyTips(preset, scene: scene) + presetBoardFrontalTips(preset, scene: scene, peopleN: peopleN)
    }

    private func presetBoardOnlyTips(
        _ preset: TeachingSituationPreset,
        scene: TeachingSceneAssessment
    ) -> [GuidanceTip] {
        guard !preset.requiresBoard else { return [] }
        guard preset.boardEmphasis < 0.35 else { return [] }
        guard scene.sceneType == .boardOnly else { return [] }
        return [presetBoardDominanceTip(preset)]
    }

    private func presetBoardFrontalTips(
        _ preset: TeachingSituationPreset,
        scene: TeachingSceneAssessment,
        peopleN: Int
    ) -> [GuidanceTip] {
        guard !preset.requiresBoard else { return [] }
        guard preset.boardEmphasis < 0.3 else { return [] }
        guard scene.sceneType == .boardCentricFrontal else { return [] }
        guard peopleN < preset.minPeople else { return [] }
        return [presetBoardDominanceTip(preset)]
    }

    private func presetBoardDominanceTip(_ preset: TeachingSituationPreset) -> GuidanceTip {
        GuidanceTip((
            id: "preset-board-overdominant",
            category: .teachingScene,
            severity: .info,
            message: "Schreibfläche dominiert - für „\(preset.titleDE)“ eher Akteure und Interaktionsraum priorisieren.",
            actionHint: preset.captureGuidanceDE.isEmpty ? preset.mismatchHintDE : preset.captureGuidanceDE
        ))
    }

    private func presetCoPresenceTips(
        _ preset: TeachingSituationPreset,
        cv: CVFeatures,
        peopleN: Int
    ) -> [GuidanceTip] {
        guard preset.requiresBoard else { return [] }
        guard preset.coPresenceEmphasis >= 0.8 else { return [] }
        guard peopleN >= 1 else { return [] }
        let co = CVFeatureFusion.coPresenceScore(from: cv)
        guard co < config.minPersonBoardCoPresence else { return [] }
        return [presetCoPresenceTip(preset, co: co)]
    }

    private func presetCoPresenceTip(_ preset: TeachingSituationPreset, co: Double) -> GuidanceTip {
        GuidanceTip((
            id: "preset-copresence-shortfall",
            category: .teachingScene,
            severity: .warning,
            message: "Situation „\(preset.titleDE)“ braucht hohe Person–Tafel-Co-Präsenz (aktuell \(percent(co))).",
            actionHint: preset.captureGuidanceDE.isEmpty ? preset.mismatchHintDE : preset.captureGuidanceDE
        ))
    }

    private func presetLayoutTips(
        _ preset: TeachingSituationPreset,
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        priorTips: [GuidanceTip]
    ) -> [GuidanceTip] {
        if let mismatchTip = presetLayoutMismatchTip(preset, cv: cv, scene: scene) {
            return [mismatchTip]
        }
        return presetLayoutMatchTips(preset, cv: cv, scene: scene, priorTips: priorTips)
    }

    private func presetLayoutMismatchTip(
        _ preset: TeachingSituationPreset,
        cv: CVFeatures,
        scene: TeachingSceneAssessment
    ) -> GuidanceTip? {
        guard hasComparableLayout(preset, cv: cv) else { return nil }
        guard !preset.preferredLayouts.contains(cv.layoutPattern) else { return nil }
        guard scene.layoutSignal < 0.45 else { return nil }
        return GuidanceTip((
            id: "preset-layout-mismatch",
            category: .teachingScene,
            severity: .info,
            message: "Layout „\(cv.layoutPattern.titleDE)“ weicht von „\(preset.titleDE)“ ab (Fit \(percent(scene.layoutSignal))).",
            actionHint: preset.captureGuidanceDE.isEmpty
                ? "Raumstruktur an die gewählte Unterrichtssituation anpassen (Cluster/Reihen/Kreis/Verteilung)."
                : preset.captureGuidanceDE
        ))
    }

    private func hasComparableLayout(_ preset: TeachingSituationPreset, cv: CVFeatures) -> Bool {
        guard cv.layoutPattern != .unknown else { return false }
        guard cv.layoutPattern != .empty else { return false }
        return !preset.preferredLayouts.isEmpty
    }

    private func presetLayoutMatchTips(
        _ preset: TeachingSituationPreset,
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        priorTips: [GuidanceTip]
    ) -> [GuidanceTip] {
        guard scene.matchesPreset else { return [] }
        guard scene.layoutSignal >= 0.7 else { return [] }
        guard cv.layoutPattern != .unknown else { return [] }
        guard priorTips.filter({ $0.severity >= .warning }).isEmpty else { return [] }
        return [GuidanceTip((
            id: "preset-layout-match",
            category: .teachingScene,
            severity: .ok,
            message: "Layout „\(cv.layoutPattern.titleDE)“ passt zur Situation „\(preset.titleDE)“.",
            actionHint: "Ausschnitt und Stativ beibehalten."
        ))]
    }

    private func presetCaptureGuidanceTips(
        _ preset: TeachingSituationPreset,
        scene: TeachingSceneAssessment,
        priorTips: [GuidanceTip]
    ) -> [GuidanceTip] {
        guard scene.matchesPreset else { return [] }
        guard scene.presetMatchScore >= 0.55 else { return [] }
        guard !preset.captureGuidanceDE.isEmpty else { return [] }
        guard priorTips.filter({ $0.severity >= .warning }).isEmpty else { return [] }
        return [GuidanceTip((
            id: "preset-capture-guidance",
            category: .teachingScene,
            severity: .ok,
            message: "Aufnahmehinweis „\(preset.titleDE)“: \(preset.captureGuidanceDE)",
            actionHint: "Stativ fixieren und kontinuierliche Aufnahme starten."
        ))]
    }
}
