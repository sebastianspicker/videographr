/// Threshold configuration for classroom capture placement heuristics.
public struct GuidanceConfig: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var rollWarningDegrees = 5.0
        public var rollCriticalDegrees = 12.0
        public var pitchUpWarningDegrees = 12.0
        public var pitchUpCriticalDegrees = 22.0
        public var pitchDownWarningDegrees = -10.0
        public var pitchDownCriticalDegrees = -18.0
        public var ceilingWarningFraction = 0.26
        public var ceilingCriticalFraction = 0.40
        public var floorWarningFraction = 0.28
        public var floorCriticalFraction = 0.42
        public var boardMinScore = 0.35
        public var boardTooHighY = 0.28
        public var boardTooLowY = 0.62
        public var backlightWarningScore = 0.45
        public var backlightCriticalScore = 0.70
        public var imbalanceWarning = 0.35
        public var emptyEdgeCritical = 0.38
        public var tooDarkLuminance = 0.18
        public var tooBrightLuminance = 0.88
        public var maxHighlightClipFraction = 0.12
        public var minGlobalContrast = 0.18
        public var minEdgeEnergy = 0.02
        public var minPersonCoverage = 0.02
        public var maxSmoothedAngularSpeed = 12.0
        public var minMultiCueBoardQuality = 0.32
        public var minPeopleSpatialUsefulness = 0.28
        public var minPersonMidBandOccupancy = 0.28
        public var minPersonBoardCoPresence = 0.30
        public var minObservationStability = 0.35

        public init() {}
    }

    public var rollWarningDegrees: Double
    public var rollCriticalDegrees: Double
    public var pitchUpWarningDegrees: Double
    public var pitchUpCriticalDegrees: Double
    public var pitchDownWarningDegrees: Double
    public var pitchDownCriticalDegrees: Double
    public var ceilingWarningFraction: Double
    public var ceilingCriticalFraction: Double
    public var floorWarningFraction: Double
    public var floorCriticalFraction: Double
    public var boardMinScore: Double
    public var boardTooHighY: Double
    public var boardTooLowY: Double
    public var backlightWarningScore: Double
    public var backlightCriticalScore: Double
    public var imbalanceWarning: Double
    public var emptyEdgeCritical: Double
    public var tooDarkLuminance: Double
    public var tooBrightLuminance: Double
    public var maxHighlightClipFraction: Double
    public var minGlobalContrast: Double
    public var minEdgeEnergy: Double
    public var minPersonCoverage: Double
    public var maxSmoothedAngularSpeed: Double
    /// Minimum multi-cue board quality (aspect+geometry+edge+confidence) when CV ran.
    public var minMultiCueBoardQuality: Double
    /// Minimum spatial people signal used by the experimental actor rule.
    public var minPeopleSpatialUsefulness: Double
    /// Minimum mid-band occupancy of people for interaction-zone placement.
    public var minPersonMidBandOccupancy: Double
    /// Minimum person–board co-presence when both cues present.
    public var minPersonBoardCoPresence: Double
    /// Minimum multi-observation CV stability (Derry continuous takes without tip flicker).
    public var minObservationStability: Double

    public init(_ values: Values = Values()) {
        (rollWarningDegrees, rollCriticalDegrees) = (values.rollWarningDegrees, values.rollCriticalDegrees)
        (pitchUpWarningDegrees, pitchUpCriticalDegrees) = (
            values.pitchUpWarningDegrees,
            values.pitchUpCriticalDegrees
        )
        (pitchDownWarningDegrees, pitchDownCriticalDegrees) = (
            values.pitchDownWarningDegrees,
            values.pitchDownCriticalDegrees
        )
        (ceilingWarningFraction, ceilingCriticalFraction) = (
            values.ceilingWarningFraction,
            values.ceilingCriticalFraction
        )
        (floorWarningFraction, floorCriticalFraction) = (
            values.floorWarningFraction,
            values.floorCriticalFraction
        )
        (boardMinScore, boardTooHighY, boardTooLowY) = (
            values.boardMinScore,
            values.boardTooHighY,
            values.boardTooLowY
        )
        (backlightWarningScore, backlightCriticalScore) = (
            values.backlightWarningScore,
            values.backlightCriticalScore
        )
        (imbalanceWarning, emptyEdgeCritical) = (values.imbalanceWarning, values.emptyEdgeCritical)
        (tooDarkLuminance, tooBrightLuminance) = (values.tooDarkLuminance, values.tooBrightLuminance)
        (maxHighlightClipFraction, minGlobalContrast) = (
            values.maxHighlightClipFraction,
            values.minGlobalContrast
        )
        (minEdgeEnergy, minPersonCoverage) = (values.minEdgeEnergy, values.minPersonCoverage)
        (maxSmoothedAngularSpeed, minMultiCueBoardQuality) = (
            values.maxSmoothedAngularSpeed,
            values.minMultiCueBoardQuality
        )
        (minPeopleSpatialUsefulness, minPersonMidBandOccupancy, minPersonBoardCoPresence, minObservationStability) = (
            values.minPeopleSpatialUsefulness,
            values.minPersonMidBandOccupancy,
            values.minPersonBoardCoPresence,
            values.minObservationStability
        )
    }

    public static let `default` = GuidanceConfig()
}
