import Foundation

private struct ResearchQualitySignals {
    var placement = 0.0
    var sceneMatch = 0.0
    var codingConfidence = 0.0
    var layout = 0.0
    var structure = 0.0
    var placementPasses = false
    var scenePasses = false
    var codingPasses = false
    var structurePasses = false
    var gtiInstruction = 0.0
    var gtiManagement = 0.0
}

// MARK: - Unvalidated rule-set composite

/// Unvalidated rule-set composite fusing placement, teaching-scene match, and coding confidence.
/// It reports rule activation only; it does not establish scientific validity.
///
/// Research use (Derry usable video; Kramer production; IPN/TIMSS/GTI structure): placement alone is
/// insufficient - the observed scene must match the selected teaching-situation preset and yield
/// non-empty software codes with honest confidence.
public struct ResearchCaptureQuality: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var score = 0.0
        public var level = Level.unsuitable
        public var placementScore = 0.0
        public var sceneMatchScore = 0.0
        public var codingConfidence = 0.0
        public var layoutFit = 0.0
        public var summaryDE = ""
        public var dimensions: [ResearchQualityDimension] = []

        public init() {}
    }

    public struct AssessmentInput: Equatable, Sendable {
        public var placement: PlacementAssessment
        public var scene: TeachingSceneAssessment
        public var coding: PedagogicalCodingResult
        public var teachingSituation = TeachingSituationID.frontalBoardInstruction
        public var structureSufficiency: ResearchStructureSufficiency?

        public init(
            placement: PlacementAssessment,
            scene: TeachingSceneAssessment,
            coding: PedagogicalCodingResult
        ) {
            self.placement = placement
            self.scene = scene
            self.coding = coding
        }
    }

    public var score: Double
    public var level: Level
    public var placementScore: Double
    public var sceneMatchScore: Double
    public var codingConfidence: Double
    public var layoutFit: Double
    public var summaryDE: String
    public var dimensions: [ResearchQualityDimension]

    public enum Level: String, Codable, Sendable, CaseIterable {
        case unvalidatedRuleSetPass
        case ruleSetPassWithCaveats
        case needsAdjustment
        case unsuitable

        public var titleDE: String {
            switch self {
            case .unvalidatedRuleSetPass: return "Unvalidierte Regelprüfung erfüllt"
            case .ruleSetPassWithCaveats: return "Regelprüfung mit Einschränkungen"
            case .needsAdjustment: return "Anpassung nötig"
            case .unsuitable: return "Regelprüfung nicht erfüllt"
            }
        }
    }

    public init(_ values: Values = Values()) {
        score = min(1, max(0, values.score))
        level = values.level
        placementScore = min(1, max(0, values.placementScore))
        sceneMatchScore = min(1, max(0, values.sceneMatchScore))
        codingConfidence = min(1, max(0, values.codingConfidence))
        layoutFit = min(1, max(0, values.layoutFit))
        summaryDE = values.summaryDE
        dimensions = values.dimensions
    }

    public static func assess(_ input: AssessmentInput) -> ResearchCaptureQuality {
        let preset = TeachingSituationCatalogue.preset(for: input.teachingSituation)
        let signals = researchSignals(input)
        let dimensions = qualityDimensions(input, preset: preset, signals: signals)
        let score = weightedScore(signals)
        let level = qualityLevel(signals, score: score)
        let summary = qualitySummary(level, preset: preset, dimensions: dimensions)
        var values = Values()
        values.score = score
        values.level = level
        values.placementScore = signals.placement
        values.sceneMatchScore = signals.sceneMatch
        values.codingConfidence = signals.codingConfidence
        values.layoutFit = signals.layout
        values.summaryDE = summary
        values.dimensions = dimensions
        return ResearchCaptureQuality(values)
    }

    private static func researchSignals(_ input: AssessmentInput) -> ResearchQualitySignals {
        var signals = ResearchQualitySignals()
        signals.placement = input.placement.score
        signals.sceneMatch = input.scene.presetMatchScore
        signals.codingConfidence = input.coding.overallConfidence
        signals.layout = input.scene.layoutSignal
        signals.structure = input.structureSufficiency?.score ?? input.scene.presetMatchScore
        signals.structurePasses = structurePasses(input)
        signals.scenePasses = scenePasses(input.scene)
        signals.codingPasses = codingPasses(input.coding)
        signals.placementPasses = placementPasses(input.placement)
        let domains = input.coding.gtiDomainLevels
        signals.gtiInstruction = domains["instruction"] ?? signals.codingConfidence
        signals.gtiManagement = domains["classroomManagement"] ?? signals.codingConfidence
        return signals
    }

    private static func structurePasses(_ input: AssessmentInput) -> Bool {
        input.structureSufficiency?.sufficient
            ?? (input.scene.matchesPreset && input.scene.confidence >= 0.35)
    }

    private static func scenePasses(_ scene: TeachingSceneAssessment) -> Bool {
        scene.matchesPreset && scene.confidence >= 0.35
    }

    private static func codingPasses(_ coding: PedagogicalCodingResult) -> Bool {
        let hasAssignments = !coding.ipnDimensions.isEmpty || !coding.timssActivities.isEmpty
        return coding.overallConfidence >= 0.28 && hasAssignments
    }

    private static func placementPasses(_ placement: PlacementAssessment) -> Bool {
        if placement.quality == .directSignalsPass { return true }
        return placement.quality == .needsAdjustment && placement.score >= 0.7
    }

    private static func qualityDimensions(
        _ input: AssessmentInput,
        preset: TeachingSituationPreset,
        signals: ResearchQualitySignals
    ) -> [ResearchQualityDimension] {
        [
            ResearchQualityDimension((
                id: "placement",
                labelDE: "Platzierung",
                ok: signals.placementPasses,
                score: signals.placement,
                detailDE: input.placement.summaryDE
            )),
            ResearchQualityDimension((
                id: "sceneMatch",
                labelDE: "Unterrichtsszene / Preset",
                ok: signals.scenePasses,
                score: signals.sceneMatch,
                detailDE: input.scene.summaryDE
            )),
            ResearchQualityDimension((
                id: "structure",
                labelDE: "Struktur-Suffizienz",
                ok: signals.structurePasses,
                score: signals.structure,
                detailDE: input.structureSufficiency?.summaryDE
                    ?? "Abgeleitet aus Szenen-Match (\(pct(signals.sceneMatch)))."
            )),
            ResearchQualityDimension((
                id: "layout",
                labelDE: "Layout-Struktur",
                ok: signals.layout >= 0.4 || preset.preferredLayouts.isEmpty,
                score: signals.layout,
                detailDE: "Layout \(input.scene.layoutPattern.titleDE) · Fit \(pct(signals.layout))"
            )),
            ResearchQualityDimension((
                id: "coding",
                labelDE: "IPN/TIMSS/GTI-Kodierung",
                ok: signals.codingPasses,
                score: signals.codingConfidence,
                detailDE: input.coding.summaryDE
            )),
            gtiDimension(signals)
        ]
    }

    private static func gtiDimension(_ signals: ResearchQualitySignals) -> ResearchQualityDimension {
        ResearchQualityDimension((
            id: "gtiDomains",
            labelDE: "GTI Domänen (Instr./Mgmt)",
            ok: gtiDomainsPass(signals),
            score: (signals.gtiInstruction + signals.gtiManagement) / 2,
            detailDE: gtiDetail(signals)
        ))
    }

    private static func gtiDomainsPass(_ signals: ResearchQualitySignals) -> Bool {
        signals.gtiInstruction >= 0.25
            || signals.gtiManagement >= 0.25
            || signals.codingConfidence < 0.15
    }

    private static func gtiDetail(_ signals: ResearchQualitySignals) -> String {
        String(
            format: "Instruction %.0f %% · Management %.0f %%",
            signals.gtiInstruction * 100,
            signals.gtiManagement * 100
        )
    }

    private static func weightedScore(_ signals: ResearchQualitySignals) -> Double {
        let gtiMean = (signals.gtiInstruction + signals.gtiManagement) / 2
        let raw = 0.22 * signals.placement + 0.26 * signals.sceneMatch
            + 0.18 * signals.structure + 0.16 * signals.codingConfidence
            + 0.10 * signals.layout + 0.08 * gtiMean
        return min(1, max(0, raw))
    }

    private static func qualityLevel(_ signals: ResearchQualitySignals, score: Double) -> Level {
        if fullRuleSetPasses(signals, score: score) { return .unvalidatedRuleSetPass }
        if caveatedRuleSetPasses(signals, score: score) { return .ruleSetPassWithCaveats }
        return score >= 0.32 ? .needsAdjustment : .unsuitable
    }

    private static func fullRuleSetPasses(_ signals: ResearchQualitySignals, score: Double) -> Bool {
        signals.placementPasses && signals.scenePasses && signals.structurePasses
            && signals.codingPasses && score >= 0.62
    }

    private static func caveatedRuleSetPasses(_ signals: ResearchQualitySignals, score: Double) -> Bool {
        let hasPassingDimension = signals.scenePasses || signals.structurePasses || signals.placementPasses
        return score >= 0.48 && hasPassingDimension
    }

    private static func qualitySummary(
        _ level: Level,
        preset: TeachingSituationPreset,
        dimensions: [ResearchQualityDimension]
    ) -> String {
        switch level {
        case .unvalidatedRuleSetPass:
            return "Unvalidierte Regeln für Platzierung, Szene „\(preset.titleDE)“ und Kodieraktivierung sind erfüllt; keine Aussage zur wissenschaftlichen Nutzbarkeit."
        case .ruleSetPassWithCaveats:
            return caveatSummary(dimensions)
        case .needsAdjustment:
            return "Unvalidierte Regelprüfung meldet Anpassungsbedarf: \(weakDimensions(dimensions))."
        case .unsuitable:
            return "Unvalidierte Regelprüfung für „\(preset.titleDE)“ nicht erfüllt - keine Aussage zur wissenschaftlichen Nutzbarkeit."
        }
    }

    private static func caveatSummary(_ dimensions: [ResearchQualityDimension]) -> String {
        let weak = weakDimensions(dimensions)
        let detail = weak.isEmpty ? "grenzwertig" : weak
        return "Unvalidierte Regelprüfung mit Einschränkungen (\(detail))."
    }

    private static func weakDimensions(_ dimensions: [ResearchQualityDimension]) -> String {
        dimensions.filter { !$0.ok }.map(\.labelDE).joined(separator: ", ")
    }

    private static func pct(_ v: Double) -> String {
        "\(Int((v * 100).rounded())) %"
    }
}

public struct ResearchQualityDimension: Equatable, Identifiable, Sendable {
    public typealias Values = (id: String, labelDE: String, ok: Bool, score: Double, detailDE: String)

    public var id: String
    public var labelDE: String
    public var ok: Bool
    public var score: Double
    public var detailDE: String

    public init(_ values: Values) {
        id = values.id
        labelDE = values.labelDE
        ok = values.ok
        score = min(1, max(0, values.score))
        detailDE = values.detailDE
    }
}
