/// Multi-factor assessment of device/camera placement for research-grade classroom video.
public struct PlacementAssessment: Equatable, Sendable {
    public var quality: PlacementQualityLevel
    public var score: Double
    public var summaryDE: String
    public var dimensions: [PlacementDimension]

    public init(
        quality: PlacementQualityLevel,
        score: Double,
        summaryDE: String,
        dimensions: [PlacementDimension]
    ) {
        self.quality = quality
        self.score = min(1, max(0, score))
        self.summaryDE = summaryDE
        self.dimensions = dimensions
    }

    public var directSignalsPass: Bool {
        quality == .directSignalsPass
    }

    public struct AssessmentInput: Sendable {
        public var orientation: OrientationSample
        public var frame: FrameMetrics
        public var tips: [GuidanceTip] = []
        public var config: GuidanceConfig = .default
        public var cv: CVFeatures = .empty
        public var motion: MotionMetrics = .stable
        public var scene: TeachingSceneAssessment?
        public var teachingSituation: TeachingSituationID = .frontalBoardInstruction

        public init(orientation: OrientationSample, frame: FrameMetrics) {
            self.orientation = orientation
            self.frame = frame
        }
    }

    public static func assess(_ input: AssessmentInput) -> PlacementAssessment {
        let context = AssessmentContext(input)
        let dimensions = dimensionResults(context)
        let score = Double(dimensions.filter(\.ok).count) / Double(max(1, dimensions.count))
        let quality = quality(for: dimensions, tips: input.tips, score: score)
        return PlacementAssessment(
            quality: quality,
            score: score,
            summaryDE: summary(for: quality, dimensions: dimensions, preset: context.preset),
            dimensions: dimensions
        )
    }

    public static func interactionZoneScore(
        frame: FrameMetrics,
        orientation: OrientationSample,
        cv: CVFeatures = .empty
    ) -> Double {
        let board = min(1, CVFeatureFusion.effectiveBoardScore(frame: frame, cv: cv))
        let verticalWaste = min(1, frame.ceilingFraction + frame.floorFraction)
        let edgeWaste = min(1, frame.emptyEdgeFraction)
        let pitchPenalty = min(0.35, abs(orientation.pitchDegrees) / 60.0)
        let peopleBoost: Double
        let coPresenceBoost: Double
        if cv.analysisSucceeded && cv.source != .heuristic {
            peopleBoost = min(0.22, cv.peopleSpatialUsefulness * 0.22)
            coPresenceBoost = min(0.12, CVFeatureFusion.coPresenceScore(from: cv) * 0.12)
        } else {
            peopleBoost = min(0.1, frame.midBandVariance * 2)
            coPresenceBoost = 0
        }
        let structureBoost = min(0.08, frame.edgeEnergy)
        let raw = 0.34 * board
            + 0.20 * (1.0 - verticalWaste)
            + 0.10 * (1.0 - edgeWaste)
            + 0.07 * (1.0 - pitchPenalty)
            + 0.18 * (peopleBoost / 0.22)
            + 0.08 * (coPresenceBoost / 0.12)
            + 0.03 * (structureBoost / 0.08)
        return min(1, max(0, raw))
    }

    struct AssessmentContext {
        let orientation: OrientationSample
        let frame: FrameMetrics
        let tips: [GuidanceTip]
        let config: GuidanceConfig
        let cv: CVFeatures
        let motion: MotionMetrics
        let preset: TeachingSituationPreset
        let resolvedScene: TeachingSceneAssessment
        let teachingSituation: TeachingSituationID

        init(_ input: AssessmentInput) {
            self.orientation = input.orientation
            self.frame = input.frame
            self.tips = input.tips
            self.config = input.config
            self.cv = input.cv
            self.motion = input.motion
            self.preset = TeachingSituationCatalogue.preset(for: input.teachingSituation)
            self.resolvedScene = input.scene ?? TeachingSceneAssessor.assess(
                cv: input.cv, frame: input.frame, preset: input.teachingSituation
            )
            self.teachingSituation = input.teachingSituation
        }

        var structureCVFailed: Bool { !cv.analysisSucceeded && cv.source != .heuristic }
        var structureCVPending: Bool { !cv.analysisSucceeded && cv.source == .heuristic }
    }

    private struct DimensionStatus {
        let ok: Bool
        let detailDE: String
    }

    private struct GeometryDimensionText {
        let pass: String
        let failure: String
    }

    private static func dimensionResults(_ context: AssessmentContext) -> [PlacementDimension] {
        geometryDimensions(context) + framingDimensions(context) + researchDimensions(context)
    }

    private static func geometryDimensions(_ context: AssessmentContext) -> [PlacementDimension] {
        let orientation = context.orientation
        let frame = context.frame
        let config = context.config
        let levelOK = abs(orientation.rollDegrees) <= config.rollWarningDegrees
        let pitchOK = orientation.pitchDegrees <= config.pitchUpWarningDegrees
            && orientation.pitchDegrees >= config.pitchDownWarningDegrees
        let ceilingOK = frame.ceilingFraction <= config.ceilingWarningFraction
            && orientation.pitchDegrees <= config.pitchUpWarningDegrees
        let floorOK = frame.floorFraction <= config.floorWarningFraction
            && orientation.pitchDegrees >= config.pitchDownWarningDegrees
        return [
            geometryDimension("horizon", "Horizont / Roll", levelOK, GeometryDimensionText(pass: "Bildkante waagerecht (Roll \(Int(orientation.rollDegrees))°).", failure: "Schräglage \(Int(orientation.rollDegrees))° - Stativ nivellieren.")),
            geometryDimension("pitch", "Neigung / Höhe", pitchOK, GeometryDimensionText(pass: "Pitch im Arbeitsbereich (\(Int(orientation.pitchDegrees))°).", failure: "Pitch \(Int(orientation.pitchDegrees))° - Höhe/Neigung auf Interaktionszone richten.")),
            geometryDimension("ceiling", "Deckenanteil", ceilingOK, GeometryDimensionText(pass: "Decke im Rahmen (ca. \(pct(frame.ceilingFraction))).", failure: "Zu viel Decke (ca. \(pct(frame.ceilingFraction))) - nach unten neigen/absenken.")),
            geometryDimension("floor", "Bodenanteil", floorOK, GeometryDimensionText(pass: "Bodenanteil im Rahmen.", failure: "Zu viel Boden - Gerät anheben und leicht nach oben neigen."))
        ]
    }

    private static func geometryDimension(
        _ id: String,
        _ label: String,
        _ ok: Bool,
        _ text: GeometryDimensionText
    ) -> PlacementDimension {
        dimension(id, label, ok, ok ? text.pass : text.failure)
    }

    private static func framingDimensions(_ context: AssessmentContext) -> [PlacementDimension] {
        let board = boardStatus(context)
        let lightOK = context.frame.backlightScore < context.config.backlightWarningScore
            && context.frame.clippedHighlightFraction <= context.config.maxHighlightClipFraction
        let interactionScore = interactionZoneScore(frame: context.frame, orientation: context.orientation, cv: context.cv)
        let interactionOK = interactionScore >= context.config.interactionZoneMinScore
        let compositionOK = compositionPasses(context)
        return [
            dimension("board", "Tafel / Schreibfläche", board.ok, board.detailDE),
            dimension("light", "Gegenlicht / Belichtung", lightOK, lightOK ? "Licht brauchbar (Highlights \(pct(context.frame.clippedHighlightFraction)))." : "Gegenlicht oder Highlight-Clipping - Standort/Belichtung ändern."),
            dimension("interaction", "Lehr-Lern-Zone", interactionOK, interactionOK ? "Interaktionsraum im Bild (Score \(pct(interactionScore)))." : "Interaktionsraum schwach abgedeckt - näher / besser zentrieren."),
            dimension("composition", "Bildausschnitt / Kontrast", compositionOK, compositionOK ? "Ausschnitt und Kontrast brauchbar (Kontrast \(pct(context.frame.globalContrast)))." : "Ausschnitt/Kontrast anpassen - Abstand, Zoom, Belichtung.")
        ]
    }

    private static func researchDimensions(_ context: AssessmentContext) -> [PlacementDimension] {
        let people = peopleStatus(context)
        let scene = sceneStatus(context)
        let structure = structureStatus(context)
        let stability = stabilityStatus(context)
        return [
            dimension("people", "Personen (CV)", people.ok, people.detailDE),
            dimension("teachingScene", "Unterrichtsszene / Preset", scene.ok, scene.detailDE),
            dimension("structureSufficiency", "Struktur-Suffizienz (Forschung)", structure.ok, structure.detailDE),
            dimension("stability", "Stativ- / Beobachtungsstabilität", stability.ok, stability.detailDE)
        ]
    }

    private static func boardStatus(_ context: AssessmentContext) -> DimensionStatus {
        let score = CVFeatureFusion.effectiveBoardScore(frame: context.frame, cv: context.cv)
        let boardQualityOK = boardQualityIsAcceptable(score: score, context: context)
        let center = CVFeatureFusion.effectiveBoardCenter(frame: context.frame, cv: context.cv)
        let centerOK = boardCenterIsAcceptable(center.y, context: context)
        let ok = boardQualityOK && centerOK
        let detail = boardDetail(ok: ok, score: score, context: context)
        return DimensionStatus(ok: ok, detailDE: detail)
    }

    private static func boardQualityIsAcceptable(score: Double, context: AssessmentContext) -> Bool {
        guard context.preset.requiresBoard else { return true }
        guard usesPrimaryCV(context) else {
            return score >= context.config.boardMinScore
        }
        return score >= context.config.boardMinScore && hasReliableBoardEvidence(context)
    }

    private static func usesPrimaryCV(_ context: AssessmentContext) -> Bool {
        context.cv.analysisSucceeded && context.cv.source != .heuristic
    }

    private static func hasReliableBoardEvidence(_ context: AssessmentContext) -> Bool {
        context.cv.multiCueBoardQuality >= context.config.minMultiCueBoardQuality
            || context.cv.boardConfidence >= context.config.boardMinScore
    }

    private static func boardCenterIsAcceptable(_ centerY: Double, context: AssessmentContext) -> Bool {
        !context.preset.requiresBoard
            || (centerY >= context.config.boardTooHighY && centerY <= context.config.boardTooLowY)
    }

    private static func boardDetail(ok: Bool, score: Double, context: AssessmentContext) -> String {
        guard ok else { return "Tafel fehlt, schwach multi-cue oder ungünstig - seitlich-frontal positionieren." }
        guard context.preset.requiresBoard else { return "Schreibfläche für diese Situation optional - ok." }
        return "Schreibfläche brauchbar (Score \(pct(score)), Multi-Cue \(pct(context.cv.multiCueBoardQuality)), CV \(context.cv.source.rawValue))."
    }

    private static func peopleStatus(_ context: AssessmentContext) -> DimensionStatus {
        if let status = unavailablePeopleStatus(context) { return status }
        let count = max(context.cv.personCount, context.cv.faceCount)
        let eligibility = peopleEligibility(count: count, context: context)
        return DimensionStatus(ok: eligibility.ok, detailDE: peopleDetail(ok: eligibility.ok, count: count, hasActors: eligibility.hasActors, context: context))
    }

    private static func unavailablePeopleStatus(_ context: AssessmentContext) -> DimensionStatus? {
        if context.structureCVFailed {
            return DimensionStatus(ok: false, detailDE: "Struktur-CV fehlgeschlagen - Personen/Akteure nicht auswertbar; keine wissenschaftliche Nutzbarkeit ableitbar.")
        }
        if context.structureCVPending {
            return DimensionStatus(ok: true, detailDE: "Personen-CV noch nicht ausgewertet (Heuristik/Luminanz-Fallback).")
        }
        return nil
    }

    private static func peopleEligibility(count: Int, context: AssessmentContext) -> (ok: Bool, hasActors: Bool) {
        let hasActors = hasRequiredActors(count: count, context: context)
        let spatialOK = hasUsefulPeopleSpatialDistribution(context)
        let multiOK = hasRequiredMultiPersonCoverage(count: count, context: context)
        return (hasActors && spatialOK && multiOK && count >= context.preset.minPeople, hasActors)
    }

    private static func hasRequiredActors(count: Int, context: AssessmentContext) -> Bool {
        count >= max(1, context.preset.minPeople) || context.cv.personCoverage >= context.config.minPersonCoverage
    }

    private static func hasUsefulPeopleSpatialDistribution(_ context: AssessmentContext) -> Bool {
        context.cv.peopleSpatialUsefulness >= context.config.minPeopleSpatialUsefulness
            && context.cv.personMidBandOccupancy >= context.config.minPersonMidBandOccupancy
    }

    private static func hasRequiredMultiPersonCoverage(count: Int, context: AssessmentContext) -> Bool {
        !context.preset.prefersMultiPerson || count >= 3 || context.cv.peopleSpatialUsefulness >= 0.4
    }

    private static func peopleDetail(
        ok: Bool,
        count: Int,
        hasActors: Bool,
        context: AssessmentContext
    ) -> String {
        if count < context.preset.minPeople {
            return "Zu wenige Akteure für „\(context.preset.titleDE)“ (n=\(count), erwartet ≥ \(context.preset.minPeople))."
        }
        if !hasActors { return "Keine Personen erkannt - auf Lehr-Lern-Geschehen richten, nicht leere Wand." }
        if !ok {
            return "Personen räumlich ungünstig (Nutzbarkeit \(pct(context.cv.peopleSpatialUsefulness)), Mittelband \(pct(context.cv.personMidBandOccupancy))) - Interaktionszone zentrieren."
        }
        return "Akteure räumlich brauchbar (n=\(count), Nutzbarkeit \(pct(context.cv.peopleSpatialUsefulness)), Mittelband \(pct(context.cv.personMidBandOccupancy)), Co-Präsenz \(pct(CVFeatureFusion.coPresenceScore(from: context.cv))))."
    }

    private static func sceneStatus(_ context: AssessmentContext) -> DimensionStatus {
        if context.structureCVFailed {
            return DimensionStatus(ok: false, detailDE: "Struktur-CV fehlgeschlagen - Unterrichtsszene nicht ableitbar; experimentelle Regelprüfung nicht verfügbar.")
        }
        if context.structureCVPending {
            return DimensionStatus(ok: true, detailDE: "Szenen-CV noch nicht ausgewertet (Heuristik-Fallback).")
        }
        let ok = context.resolvedScene.matchesPreset && context.resolvedScene.presetMatchScore >= 0.45
        return DimensionStatus(ok: ok, detailDE: context.resolvedScene.summaryDE)
    }

    private static func structureStatus(_ context: AssessmentContext) -> DimensionStatus {
        if context.structureCVFailed {
            return DimensionStatus(ok: false, detailDE: "Struktur-CV fehlgeschlagen - Suffizienz nicht bewertbar.")
        }
        if context.structureCVPending {
            return DimensionStatus(ok: true, detailDE: "Struktur-Suffizienz ausstehend (Heuristik-Fallback).")
        }
        let structure = ResearchStructureAssessor.assess(
            cv: context.cv, scene: context.resolvedScene, teachingSituation: context.teachingSituation
        )
        return DimensionStatus(ok: structure.sufficient || structure.score >= 0.48, detailDE: structure.summaryDE)
    }

    private static func stabilityStatus(_ context: AssessmentContext) -> DimensionStatus {
        let motionOK = motionIsStable(context)
        let observationOK = observationIsStable(context)
        let ok = motionOK && observationOK
        return DimensionStatus(
            ok: ok,
            detailDE: stabilityDetail(
                motionOK: motionOK,
                observationOK: observationOK,
                context: context
            )
        )
    }

    private static func quality(
        for dimensions: [PlacementDimension],
        tips: [GuidanceTip],
        score: Double
    ) -> PlacementQualityLevel {
        if isDefective(tips: tips, score: score) { return .defective }
        if needsAdjustment(dimensions: dimensions, tips: tips) { return .needsAdjustment }
        return .directSignalsPass
    }

    private static func dimension(_ id: String, _ label: String, _ ok: Bool, _ detail: String) -> PlacementDimension {
        PlacementDimension(id: id, labelDE: label, ok: ok, detailDE: detail)
    }

    private static func pct(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}
