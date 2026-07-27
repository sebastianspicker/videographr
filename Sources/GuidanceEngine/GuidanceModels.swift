import Foundation

/// Device attitude sample from CoreMotion (or synthetic test input).
/// Angles are in degrees. Pitch: device tilt toward/away from scene.
/// Roll: left/right bank. Positive pitch ≈ camera tilted up (more ceiling).
public struct OrientationSample: Equatable, Sendable {
    public var pitchDegrees: Double
    public var rollDegrees: Double
    public var yawDegrees: Double

    public init(pitchDegrees: Double, rollDegrees: Double, yawDegrees: Double = 0) {
        self.pitchDegrees = pitchDegrees
        self.rollDegrees = rollDegrees
        self.yawDegrees = yawDegrees
    }
}

/// Aggregated metrics extracted from a live (or synthetic) video frame.
/// All normalized scores are in 0...1 unless noted.
public struct FrameMetrics: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var averageLuminance = 0.5
        public var topBandLuminance = 0.5
        public var bottomBandLuminance = 0.5
        public var leftBandLuminance = 0.5
        public var rightBandLuminance = 0.5
        public var boardRegionScore = 0.0
        public var boardCenterY = 0.45
        public var boardCenterX = 0.5
        public var ceilingFraction = 0.15
        public var floorFraction = 0.12
        public var backlightScore = 0.0
        public var horizontalBrightnessImbalance = 0.0
        public var emptyEdgeFraction = 0.1
        public var globalContrast = 0.35
        public var midBandVariance = 0.02
        public var edgeEnergy = 0.08
        public var clippedHighlightFraction = 0.02
        public var clippedShadowFraction = 0.02
        public var brightnessCenterY = 0.5

        public init() {}
    }

    public var averageLuminance: Double
    public var topBandLuminance: Double
    public var bottomBandLuminance: Double
    public var leftBandLuminance: Double
    public var rightBandLuminance: Double
    public var boardRegionScore: Double
    public var boardCenterY: Double
    public var boardCenterX: Double
    public var ceilingFraction: Double
    public var floorFraction: Double
    public var backlightScore: Double
    public var horizontalBrightnessImbalance: Double
    public var emptyEdgeFraction: Double
    /// Global contrast (max − min luminance proxy via percentile-like range).
    public var globalContrast: Double
    /// Variance of mid-band luminance (structure / texture in interaction zone).
    public var midBandVariance: Double
    /// Horizontal edge energy (simple gradient magnitude mean) - board edges / desks.
    public var edgeEnergy: Double
    /// Fraction of pixels near white (highlight clipping risk).
    public var clippedHighlightFraction: Double
    /// Fraction of pixels near black (shadow crushing).
    public var clippedShadowFraction: Double
    /// Vertical center of mass of brightness (0 top … 1 bottom).
    public var brightnessCenterY: Double

    public init(_ values: Values = Values()) {
        (averageLuminance, topBandLuminance) = (values.averageLuminance, values.topBandLuminance)
        (bottomBandLuminance, leftBandLuminance) = (values.bottomBandLuminance, values.leftBandLuminance)
        (rightBandLuminance, boardRegionScore) = (values.rightBandLuminance, values.boardRegionScore)
        (boardCenterY, boardCenterX) = (values.boardCenterY, values.boardCenterX)
        (ceilingFraction, floorFraction) = (values.ceilingFraction, values.floorFraction)
        (backlightScore, horizontalBrightnessImbalance) = (
            values.backlightScore,
            values.horizontalBrightnessImbalance
        )
        (emptyEdgeFraction, globalContrast) = (values.emptyEdgeFraction, values.globalContrast)
        (midBandVariance, edgeEnergy) = (values.midBandVariance, values.edgeEnergy)
        (clippedHighlightFraction, clippedShadowFraction) = (
            values.clippedHighlightFraction,
            values.clippedShadowFraction
        )
        brightnessCenterY = values.brightnessCenterY
    }
}

public enum GuidanceSeverity: Int, Comparable, Sendable {
    case ok = 0
    case info = 1
    case warning = 2
    case critical = 3

    public static func < (lhs: GuidanceSeverity, rhs: GuidanceSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum GuidanceCategory: String, Sendable, CaseIterable {
    case orientation
    case composition
    case blackboard
    case ceiling
    case backlight
    case general
    case interaction
    case motion
    case people
    case teachingScene
}

public struct GuidanceTip: Equatable, Identifiable, Sendable {
    public typealias Values = (
        id: String,
        category: GuidanceCategory,
        severity: GuidanceSeverity,
        message: String,
        actionHint: String
    )

    public var id: String
    public var category: GuidanceCategory
    public var severity: GuidanceSeverity
    public var message: String
    public var actionHint: String

    public init(_ values: Values) {
        id = values.id
        category = values.category
        severity = values.severity
        message = values.message
        actionHint = values.actionHint
    }
}

/// Full live understanding input: orientation + frame metrics + optional CV + motion + teaching situation.
public struct GuidanceInput: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var orientation: OrientationSample
        public var frame: FrameMetrics
        public var cv = CVFeatures.empty
        public var motion = MotionMetrics.stable
        public var teachingSituation = TeachingSituationID.frontalBoardInstruction
        public var analysisFocus: CodingAnalysisFocus?
        public var operatingMode = GuidanceOperatingMode.evidenceSafe

        public init(orientation: OrientationSample, frame: FrameMetrics) {
            self.orientation = orientation
            self.frame = frame
        }
    }

    public var orientation: OrientationSample
    public var frame: FrameMetrics
    public var cv: CVFeatures
    public var motion: MotionMetrics
    /// Selected teaching-situation preset (drives scene expectations and coding priors).
    public var teachingSituation: TeachingSituationID
    /// Optional analysis focus (professional vision, CM, LAF, …) soft-reweights IPN/GTI priors.
    public var analysisFocus: CodingAnalysisFocus?
    /// Evidence-safe is the default. Experimental mode is required before legacy
    /// IPN/GTI rule output is exposed as hypotheses.
    public var operatingMode: GuidanceOperatingMode

    public init(_ values: Values) {
        (orientation, frame) = (values.orientation, values.frame)
        (cv, motion) = (values.cv, values.motion)
        (teachingSituation, analysisFocus) = (values.teachingSituation, values.analysisFocus)
        operatingMode = values.operatingMode
    }
}

public struct GuidanceResult: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var tips: [GuidanceTip]
        public var placement: PlacementAssessment
        public var scene = TeachingSceneAssessment.unavailable
        public var pedagogicalCoding = PedagogicalCodingResult.empty()
        public var teachingSituation = TeachingSituationID.frontalBoardInstruction
        public var researchQuality: ResearchCaptureQuality?
        public var structureSufficiency: ResearchStructureSufficiency?
        public var observability = CaptureObservabilityAssessment(dimensions: [])
        public var operatingMode = GuidanceOperatingMode.evidenceSafe
        public var experimentalHypotheses = ExperimentalHypothesisSet.empty

        public init(tips: [GuidanceTip], placement: PlacementAssessment) {
            self.tips = tips
            self.placement = placement
        }
    }

    public var tips: [GuidanceTip]
    public var overallSeverity: GuidanceSeverity
    public var isReadyToRecord: Bool
    public var placement: PlacementAssessment
    public var scene: TeachingSceneAssessment
    public var pedagogicalCoding: PedagogicalCodingResult
    public var teachingSituation: TeachingSituationID
    /// Unvalidated rule-set composite (placement + scene match + coding + layout), not scientific validity.
    public var researchQuality: ResearchCaptureQuality
    /// Preset-conditional structure sufficiency (CV/scene vs teaching situation).
    public var structureSufficiency: ResearchStructureSufficiency
    /// Purpose- and mode-invariant direct capture measurements.
    public var observability: CaptureObservabilityAssessment
    public var operatingMode: GuidanceOperatingMode
    /// Present only when callers explicitly select experimental research mode.
    public var experimentalHypotheses: ExperimentalHypothesisSet

    public init(_ values: Values) {
        tips = values.tips.sorted {
            $0.severity == $1.severity ? $0.id < $1.id : $0.severity > $1.severity
        }
        overallSeverity = tips.map(\.severity).max() ?? .ok
        placement = values.placement
        scene = values.scene
        pedagogicalCoding = values.pedagogicalCoding
        teachingSituation = values.teachingSituation
        researchQuality = values.researchQuality ?? Self.assessResearchQuality(values)
        isReadyToRecord = Self.isReady(values, researchQuality: researchQuality)
        structureSufficiency = values.structureSufficiency ?? Self.defaultStructureSufficiency(values)
        observability = values.observability
        operatingMode = values.operatingMode
        experimentalHypotheses = values.experimentalHypotheses
    }

    private static func assessResearchQuality(_ values: Values) -> ResearchCaptureQuality {
        var input = ResearchCaptureQuality.AssessmentInput(
            placement: values.placement,
            scene: values.scene,
            coding: values.pedagogicalCoding
        )
        input.teachingSituation = values.teachingSituation
        return ResearchCaptureQuality.assess(input)
    }

    private static func defaultStructureSufficiency(_ values: Values) -> ResearchStructureSufficiency {
        var structure = ResearchStructureSufficiency.Values()
        structure.teachingSituation = values.teachingSituation
        structure.sceneType = values.scene.sceneType
        structure.layoutPattern = values.scene.layoutPattern
        structure.summaryDE = "Struktur-Suffizienz nicht ausgewertet."
        return ResearchStructureSufficiency(structure)
    }

    private static func isReady(_ values: Values, researchQuality: ResearchCaptureQuality) -> Bool {
        guard tipsPermitRecording(values.tips) else { return false }
        guard values.placement.quality == .directSignalsPass else { return false }
        return !hasStructureEvidence(values) || researchQuality.level != .unsuitable
    }

    private static func tipsPermitRecording(_ tips: [GuidanceTip]) -> Bool {
        let hasCritical = tips.contains { $0.severity == .critical }
        let warningCount = tips.filter { $0.severity == .warning }.count
        return !hasCritical && warningCount <= 1
    }

    private static func hasStructureEvidence(_ values: Values) -> Bool {
        if values.scene.confidence >= 0.25 { return true }
        if values.pedagogicalCoding.overallConfidence > 0.15 { return true }
        return codingHasStructure(values.pedagogicalCoding) && values.scene.sceneType != .emptyOrUnusable
    }

    private static func codingHasStructure(_ coding: PedagogicalCodingResult) -> Bool {
        !coding.ipnDimensions.isEmpty
            || !coding.timssActivities.isEmpty
            || !coding.gtiDimensions.isEmpty
    }

    /// Convenience for tests that only care about tips.
    public init(tips: [GuidanceTip]) {
        let placeholder = PlacementAssessment(
            quality: tips.contains(where: { $0.severity == .critical }) ? .defective
                : (tips.contains(where: { $0.severity == .warning }) ? .needsAdjustment : .directSignalsPass),
            score: tips.contains(where: { $0.severity == .critical }) ? 0.3
                : (tips.contains(where: { $0.severity == .warning }) ? 0.7 : 0.95),
            summaryDE: "Abgeleitet aus Tipps.",
            dimensions: []
        )
        self.init(Values(tips: tips, placement: placeholder))
    }
}
