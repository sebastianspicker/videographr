import Foundation

private let observabilityCategories: [String: GuidanceCategory] = [
    "level": .orientation,
    "stability": .motion,
    "signalStability": .motion,
    "exposure": .backlight,
    "writingSurface": .blackboard,
    "actors": .people,
    "coPresence": .people
]

extension GuidanceEngine {
    func appendPlacementSummary(
        to tips: inout [GuidanceTip],
        placement: PlacementAssessment,
        situation: TeachingSituationID
    ) {
        if !tips.contains(where: { $0.severity >= .warning }) {
            tips.append(GuidanceTip((
                id: "placement-direct-signals-pass",
                category: .general,
                severity: .ok,
                message: "Die unvalidierten Platzierungs- und Szenenregeln für „\(TeachingSituationCatalogue.preset(for: situation).titleDE)“ melden keine Warnung.",
                actionHint: "Kurz Pegelprobe, dann kontinuierliche Aufnahme starten (Stativ nicht mehr bewegen)."
            )))
            return
        }
        guard placement.quality == .needsAdjustment else { return }
        let missing = placement.dimensions.filter { !$0.ok }.map(\.labelDE).prefix(3).joined(separator: ", ")
        tips.append(GuidanceTip((
            id: "placement-checklist",
            category: .general,
            severity: .info,
            message: "Checkliste Platzierung/Szene noch offen: \(missing).",
            actionHint: "Punkte der Reihe nach korrigieren: erst Stativ/Horizont, dann Höhe/Neigung, dann Standort und Unterrichtssituation."
        )))
    }

    func appendStructureTips(to tips: inout [GuidanceTip], context: ResearchTipContext) {
        guard context.hasEvidence else { return }
        if context.structure.sufficient {
            tips.append(GuidanceTip((
                id: "structure-sufficiency-ok",
                category: .teachingScene,
                severity: .ok,
                message: context.structure.summaryDE,
                actionHint: context.structure.actionHintDE
            )))
            return
        }
        tips.append(GuidanceTip((
            id: "structure-sufficiency-fail",
            category: .teachingScene,
            severity: .warning,
            message: context.structure.summaryDE,
            actionHint: context.structure.actionHintDE
        )))
        for check in context.structure.failedChecks.prefix(3) {
            tips.append(structureCheckTip(check, actionHint: context.structure.actionHintDE))
        }
    }

    private func structureCheckTip(_ check: ResearchStructureCheck, actionHint: String) -> GuidanceTip {
        let isSceneOrBoard = check.id == "sceneMatch" || check.id == "board"
        return GuidanceTip((
            id: "structure-check-\(check.id)",
            category: .teachingScene,
            severity: isSceneOrBoard ? .warning : .info,
            message: "\(check.labelDE): \(check.detailDE)",
            actionHint: actionHint
        ))
    }

    func appendResearchQualityTip(to tips: inout [GuidanceTip], context: ResearchTipContext) {
        guard context.hasEvidence else { return }
        switch context.quality.level {
        case .unsuitable:
            tips.append(GuidanceTip((
                id: "unvalidated-rule-set-unsuitable",
                category: .teachingScene,
                severity: .warning,
                message: context.quality.summaryDE,
                actionHint: TeachingSituationCatalogue.preset(for: context.situation).mismatchHintDE
            )))
        case .unvalidatedRuleSetPass:
            tips.append(GuidanceTip((
                id: "unvalidated-rule-set-pass",
                category: .teachingScene,
                severity: .ok,
                message: context.quality.summaryDE,
                actionHint: "Stativ fixieren und kontinuierliche Aufnahme starten."
            )))
        default:
            break
        }
    }

    func appendSignalCompletenessTip(to tips: inout [GuidanceTip], cv: CVFeatures) {
        guard cv.analysisSucceeded else { return }
        let completeness = cv.researchSignalCompleteness
        guard completeness.score < 0.45 else { return }
        tips.append(GuidanceTip((
            id: "cv-signal-completeness-low",
            category: .teachingScene,
            severity: .info,
            message: completeness.summaryDE + " Fehlend: \(completeness.missingSignals.prefix(4).joined(separator: ", ")).",
            actionHint: "Ausschnitt und Beleuchtung so wählen, dass Tafel, Akteure und Layout stabil erkannt werden."
        )))
    }

    func appendCodingAlignmentTips(
        to tips: inout [GuidanceTip],
        hasStructureEvidence: Bool,
        coding: PedagogicalCodingResult,
        situation: TeachingSituationID
    ) {
        guard hasStructureEvidence, coding.overallConfidence > 0.2 else { return }
        let preset = TeachingSituationCatalogue.preset(for: situation)
        appendTIMSSAlignmentTip(to: &tips, coding: coding, preset: preset)
        appendGTIBalanceTip(to: &tips, coding: coding, preset: preset)
    }

    private func appendTIMSSAlignmentTip(
        to tips: inout [GuidanceTip],
        coding: PedagogicalCodingResult,
        preset: TeachingSituationPreset
    ) {
        guard !coding.primaryTIMSSMatchesPresetExpectation else { return }
        let expected = preset.expectedTIMSSActivities
            .compactMap { TIMSSActivityCode(rawValue: $0)?.titleDE }
            .joined(separator: ", ")
        tips.append(GuidanceTip((
            id: "timss-preset-alignment",
            category: .teachingScene,
            severity: .info,
            message: "TIMSS-Primär „\(coding.primaryTIMSS.titleDE)“ weicht von Preset-Erwartung (\(expected)) ab.",
            actionHint: preset.captureGuidanceDE.isEmpty ? preset.mismatchHintDE : preset.captureGuidanceDE
        )))
    }

    private func appendGTIBalanceTip(
        to tips: inout [GuidanceTip],
        coding: PedagogicalCodingResult,
        preset: TeachingSituationPreset
    ) {
        guard coding.gtiDomainBalance < 0.35, coding.gtiDimensions.count >= 4 else { return }
        tips.append(GuidanceTip((
            id: "gti-domain-imbalance",
            category: .teachingScene,
            severity: .info,
            message: "GTI-Domänen unausgeglichen (Balance \(Int(coding.gtiDomainBalance * 100)) %) - Capture betont eine Qualitätsfacette stark.",
            actionHint: "Ausschnitt so wählen, dass Organisation, Klima und Instruction gemeinsam sichtbar bleiben (Preset: \(preset.titleDE))."
        )))
    }

    /// Builds normal-mode output from direct measurements only. Legacy scene,
    /// coding, and composite research heuristics are neither executed nor exposed.
    func evidenceSafeResult(
        observability: CaptureObservabilityAssessment,
        teachingSituation: TeachingSituationID
    ) -> GuidanceResult {
        let tips = observability.dimensions.compactMap(observabilityTip)
        let placement = evidenceSafePlacement(observability)
        var result = GuidanceResult.Values(tips: tips, placement: placement)
        result.scene = .unavailable
        result.pedagogicalCoding = .empty()
        result.teachingSituation = teachingSituation
        result.researchQuality = unavailableResearchQuality()
        result.structureSufficiency = unavailableStructure(teachingSituation)
        result.observability = observability
        result.operatingMode = .evidenceSafe
        result.experimentalHypotheses = .empty
        return GuidanceResult(result)
    }

    private func observabilityTip(_ dimension: CaptureObservabilityDimension) -> GuidanceTip? {
        guard dimension.status != .pass else { return nil }
        let unavailable = dimension.status == .unavailable
        return GuidanceTip((
            id: "observability-\(dimension.id)",
            category: observabilityCategories[dimension.id] ?? .general,
            severity: observabilitySeverity(dimension),
            message: "\(dimension.labelDE): \(dimension.detailDE)",
            actionHint: unavailable
                ? "Signalverfügbarkeit und Berechtigungen prüfen."
                : "Kameraposition oder Beleuchtung prüfen und den Messwert erneut beobachten."
        ))
    }

    private func observabilitySeverity(_ dimension: CaptureObservabilityDimension) -> GuidanceSeverity {
        switch dimension.status {
        case .pass: return .ok
        case .warn: return .warning
        case .fail: return failedObservabilitySeverity(dimension.id)
        case .unavailable: return .info
        }
    }

    private func isCriticalObservabilityDimension(_ id: String) -> Bool {
        id == "level" || id == "exposure"
    }

    private func failedObservabilitySeverity(_ id: String) -> GuidanceSeverity {
        isCriticalObservabilityDimension(id) ? .critical : .warning
    }

    private func evidenceSafePlacement(_ observability: CaptureObservabilityAssessment) -> PlacementAssessment {
        let values = observability.dimensions.compactMap(\.value)
        return PlacementAssessment(
            quality: evidenceSafePlacementQuality(observability.dimensions),
            score: values.reduce(0, +) / Double(max(1, values.count)),
            summaryDE: "Direkte technische Aufnahmesignale; keine Aussage zur Unterrichts- oder Forschungsqualität.",
            dimensions: observability.dimensions.map(placementDimension)
        )
    }

    private func evidenceSafePlacementQuality(
        _ dimensions: [CaptureObservabilityDimension]
    ) -> PlacementQualityLevel {
        if dimensions.contains(where: { $0.status == .fail }) { return .defective }
        let hasWarning = dimensions.contains { $0.status == .warn || $0.status == .unavailable }
        return hasWarning ? .needsAdjustment : .directSignalsPass
    }

    private func placementDimension(_ dimension: CaptureObservabilityDimension) -> PlacementDimension {
        PlacementDimension(
            id: dimension.id,
            labelDE: dimension.labelDE,
            ok: dimension.status == .pass,
            detailDE: dimension.detailDE
        )
    }

    private func unavailableResearchQuality() -> ResearchCaptureQuality {
        var values = ResearchCaptureQuality.Values()
        values.summaryDE = "Im evidenzsicheren Modus nicht ausgewertet."
        return ResearchCaptureQuality(values)
    }

    private func unavailableStructure(_ teachingSituation: TeachingSituationID) -> ResearchStructureSufficiency {
        var values = ResearchStructureSufficiency.Values()
        values.teachingSituation = teachingSituation
        values.summaryDE = "Im evidenzsicheren Modus nicht ausgewertet."
        return ResearchStructureSufficiency(values)
    }
}
