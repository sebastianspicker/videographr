extension PlacementAssessment {
    static func motionIsStable(_ context: AssessmentContext) -> Bool {
        context.motion.isStable
            && context.motion.smoothedAngularSpeed <= context.config.maxSmoothedAngularSpeed
    }

    static func observationIsStable(_ context: AssessmentContext) -> Bool {
        !context.cv.analysisSucceeded
            || context.cv.source == .heuristic
            || context.cv.observationStability >= context.config.minObservationStability
    }

    static func stabilityDetail(
        motionOK: Bool,
        observationOK: Bool,
        context: AssessmentContext
    ) -> String {
        if !motionOK {
            return "Zu viel Gerätebewegung (\(String(format: "%.1f", context.motion.smoothedAngularSpeed)) °/s) - Stativ festziehen."
        }
        if !observationOK {
            return "CV-Beobachtung flackert (Stabilität \(percentage(context.cv.observationStability))) - Stativ ruhig halten, Ausschnitt nicht springen lassen."
        }
        return "Lage und CV-Beobachtung stabil (\(String(format: "%.1f", context.motion.smoothedAngularSpeed)) °/s, CV \(percentage(context.cv.observationStability)))."
    }

    static func compositionPasses(_ context: AssessmentContext) -> Bool {
        context.frame.emptyEdgeFraction <= context.config.emptyEdgeCritical
            && context.frame.averageLuminance >= context.config.tooDarkLuminance
            && context.frame.averageLuminance <= context.config.tooBrightLuminance
            && context.frame.globalContrast >= context.config.minGlobalContrast
    }

    static func isDefective(tips: [GuidanceTip], score: Double) -> Bool {
        tips.contains(where: { $0.severity == .critical }) || score < 0.45
    }

    static func needsAdjustment(
        dimensions: [PlacementDimension],
        tips: [GuidanceTip]
    ) -> Bool {
        !dimensions.allSatisfy(\.ok) || tips.contains(where: { $0.severity == .warning })
    }

    static func summary(
        for quality: PlacementQualityLevel,
        dimensions: [PlacementDimension],
        preset: TeachingSituationPreset
    ) -> String {
        let bad = dimensions.filter { !$0.ok }.map(\.labelDE).joined(separator: ", ")
        switch quality {
        case .directSignalsPass:
            return "Die unvalidierten Platzierungs- und Szenenregeln für „\(preset.titleDE)“ sind erfüllt; keine Aussage zur wissenschaftlichen Nutzbarkeit."
        case .needsAdjustment:
            return "Vor der Aufnahme anpassen: \(bad)."
        case .defective:
            return "Direkte Platzierungs- oder Szenensignale liegen außerhalb der konfigurierten Grenzwerte: \(bad)."
        }
    }

    private static func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}
