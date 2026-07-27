import Foundation

/// Declares whether callers want capture observability only or explicitly
/// unvalidated research hypotheses. Evidence-safe is the product default.
public enum GuidanceOperatingMode: Equatable, Sendable {
    case evidenceSafe
    case experimentalResearch(protocolReference: String)

    public var isExperimental: Bool {
        if case .experimentalResearch = self { return true }
        return false
    }
}

/// A direct, non-pedagogical measurement reported by the capture pipeline.
public struct CaptureObservabilityDimension: Equatable, Identifiable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case pass
        case warn
        case fail
        case unavailable
    }

    public var id: String
    public var labelDE: String
    public var status: Status
    public var value: Double?
    public var detailDE: String

    public struct Values: Equatable, Sendable {
        public var id: String
        public var labelDE: String
        public var status: Status
        public var value: Double?
        public var detailDE = ""

        public init(id: String, labelDE: String, status: Status) {
            self.id = id
            self.labelDE = labelDE
            self.status = status
        }
    }

    public init(_ values: Values) {
        id = values.id
        labelDE = values.labelDE
        status = values.status
        value = values.value.map { min(1, max(0, $0)) }
        detailDE = values.detailDE
    }
}

/// Capture-only evidence. It deliberately does not infer teaching quality,
/// engagement, discourse, feedback, or other pedagogical constructs.
public struct CaptureObservabilityAssessment: Equatable, Sendable {
    public var dimensions: [CaptureObservabilityDimension]

    public init(dimensions: [CaptureObservabilityDimension]) {
        self.dimensions = dimensions
    }

    public var unavailableDimensionIDs: [String] {
        dimensions.filter { $0.status == .unavailable }.map(\.id)
    }

    public static func assess(
        orientation: OrientationSample,
        frame: FrameMetrics,
        cv: CVFeatures,
        motion: MotionMetrics
    ) -> CaptureObservabilityAssessment {
        let cvUnavailable = !cv.analysisSucceeded
        let levelError = min(1, abs(orientation.rollDegrees) / 12)
        let level = thresholdStatus(value: levelError, passMaximum: 0.25, warnMaximum: 0.6)
        let exposure = max(frame.clippedHighlightFraction, frame.clippedShadowFraction, frame.backlightScore)
        let exposureStatus = thresholdStatus(value: exposure, passMaximum: 0.12, warnMaximum: 0.28)
        let stable = motion.isStable && motion.smoothedAngularSpeed <= 12

        return CaptureObservabilityAssessment(dimensions: [
            dimension((
                identity: ("level", "Horizont"),
                status: level,
                value: 1 - levelError,
                detail: "Gemessen aus Geräte-Rollwinkel."
            )),
            dimension((
                identity: ("stability", "Kameraruhe"),
                status: stable ? .pass : .warn,
                value: min(1, 1 - motion.smoothedAngularSpeed / 24),
                detail: "Gemessen aus geglätteter Winkelgeschwindigkeit."
            )),
            dimension((
                identity: ("exposure", "Belichtung"),
                status: exposureStatus,
                value: 1 - exposure,
                detail: "Gemessen aus Clipping- und Gegenlichtsignalen."
            )),
            cvDimension(("writingSurface", "Schreibfläche sichtbar", cv.multiCueBoardQuality, 0.45, 0.22), unavailable: cvUnavailable),
            cvDimension(("actors", "Akteure sichtbar", cv.peopleSpatialUsefulness, 0.35, 0.12), unavailable: cvUnavailable),
            cvDimension(("coPresence", "Akteure und Schreibfläche gemeinsam sichtbar", cv.personBoardCoPresence, 0.35, 0.12), unavailable: cvUnavailable),
            cvDimension(("signalStability", "Struktursignal stabil", cv.observationStability, 0.65, 0.35), unavailable: cvUnavailable)
        ])
    }

    private typealias CVDimensionValues = (
        id: String,
        label: String,
        value: Double,
        passMinimum: Double,
        warnMinimum: Double
    )

    private static func cvDimension(
        _ input: CVDimensionValues,
        unavailable: Bool
    ) -> CaptureObservabilityDimension {
        guard !unavailable else {
            return dimension((
                identity: (input.id, input.label),
                status: .unavailable,
                value: nil,
                detail: "Strukturmessung nicht verfügbar."
            ))
        }
        let status = thresholdStatus(
            value: input.value,
            passMinimum: input.passMinimum,
            warnMinimum: input.warnMinimum
        )
        return dimension((
            identity: (input.id, input.label),
            status: status,
            value: input.value,
            detail: "Direktes Bildsignal; keine pädagogische Bewertung."
        ))
    }

    private typealias DimensionValues = (
        identity: (id: String, label: String),
        status: CaptureObservabilityDimension.Status,
        value: Double?,
        detail: String
    )

    private static func dimension(_ input: DimensionValues) -> CaptureObservabilityDimension {
        var values = CaptureObservabilityDimension.Values(
            id: input.identity.id,
            labelDE: input.identity.label,
            status: input.status
        )
        values.value = input.value
        values.detailDE = input.detail
        return CaptureObservabilityDimension(values)
    }

    private static func thresholdStatus(
        value: Double,
        passMinimum: Double,
        warnMinimum: Double
    ) -> CaptureObservabilityDimension.Status {
        if value >= passMinimum { return .pass }
        return value >= warnMinimum ? .warn : .fail
    }

    private static func thresholdStatus(
        value: Double,
        passMaximum: Double,
        warnMaximum: Double
    ) -> CaptureObservabilityDimension.Status {
        if value <= passMaximum { return .pass }
        return value <= warnMaximum ? .warn : .fail
    }
}

public enum ExperimentalValidationStatus: String, Codable, Equatable, Sendable {
    case unvalidated
}

/// Explicitly unvalidated output from the historic rule set. `ruleSupport`
/// describes rule activation only; it is not a probability or rater confidence.
public struct ExperimentalHypothesis: Equatable, Identifiable, Sendable {
    public var id: String
    public var family: PedagogicalCodeFamily
    public var code: String
    public var labelDE: String
    public var ruleSupport: Double
    public var rationaleDE: String
    public var validationStatus: ExperimentalValidationStatus

    public init(assignment: PedagogicalCodeAssignment) {
        self.id = assignment.id
        self.family = assignment.family
        self.code = assignment.code
        self.labelDE = assignment.labelDE
        self.ruleSupport = assignment.level
        self.rationaleDE = assignment.rationaleDE
        self.validationStatus = .unvalidated
    }
}

public struct ExperimentalHypothesisSet: Equatable, Sendable {
    public var hypotheses: [ExperimentalHypothesis]
    public var validationStatus: ExperimentalValidationStatus
    public var limitationDE: String

    public init(hypotheses: [ExperimentalHypothesis]) {
        self.hypotheses = hypotheses
        self.validationStatus = .unvalidated
        self.limitationDE = "Regelbasierte, unvalidierte Hypothesen. Sie sind keine pädagogischen Bewertungen und ersetzen keine menschliche Kodierung."
    }

    public static let empty = ExperimentalHypothesisSet(hypotheses: [])

    static func fromLegacyCoding(_ coding: PedagogicalCodingResult) -> ExperimentalHypothesisSet {
        ExperimentalHypothesisSet(hypotheses: (coding.ipnDimensions + coding.timssActivities + coding.gtiDimensions).map(ExperimentalHypothesis.init))
    }
}

