import Foundation

private let observabilityCategories: [String: GuidanceCategory] = [
    "level": .orientation, "stability": .motion, "signalStability": .motion,
    "exposure": .backlight, "writingSurface": .blackboard, "actors": .people,
    "coPresence": .people
]

extension GuidanceEngine {
    func evidenceSafeResult(
        tips: [GuidanceTip],
        placement: PlacementAssessment,
        observability: CaptureObservabilityAssessment
    ) -> GuidanceResult {
        let directTips = observability.dimensions.compactMap(observabilityTip)
        var values = GuidanceResult.Values(tips: tips + directTips, placement: placement)
        values.observability = observability
        return GuidanceResult(values)
    }

    private func observabilityTip(_ dimension: CaptureObservabilityDimension) -> GuidanceTip? {
        guard dimension.status != .pass else { return nil }
        let severity: GuidanceSeverity
        switch dimension.status {
        case .pass: severity = .ok
        case .warn: severity = .warning
        case .fail: severity = (dimension.id == "level" || dimension.id == "exposure") ? .critical : .warning
        case .unavailable: severity = .info
        }
        return GuidanceTip((
            id: "observability-\(dimension.id)",
            category: observabilityCategories[dimension.id] ?? .general,
            severity: severity,
            message: "\(dimension.labelDE): \(dimension.detailDE)",
            actionHint: dimension.status == .unavailable
                ? "Signalverfügbarkeit und Berechtigungen prüfen."
                : "Kameraposition oder Beleuchtung prüfen und den Messwert erneut beobachten."
        ))
    }
}
