import Foundation

// MARK: - Research pack per teaching situation

/// Complete research-capture requirements for one teaching situation (presets × structure × coding).
public struct TeachingSituationResearchBarsValues: Sendable {
    public var minBoard = 0.0
    public var minCoPresence = 0.0
    public var minInteractionDensity = 0.0
    public var minLayoutFit = 0.0
    public var minBoardText = 0.0
    public var minPeopleSpatial = 0.0
    public var minMidBand = 0.0

    public init() {}
}

public struct TeachingSituationResearchPack: Equatable, Sendable, Identifiable {
    public var id: TeachingSituationID
    public var titleDE: String
    public var scriptFamilyDE: String
    public var expectedScenes: [TeachingSceneType]
    public var acceptableScenes: [TeachingSceneType]
    public var preferredLayouts: [ClassroomLayoutPattern]
    public var requiresBoard: Bool
    public var minPeople: Int
    public var researchBars: ResearchBars
    public var ipnEmphasis: [String]
    public var timssExpected: [String]
    public var gtiEmphasis: [String]
    public var checklistDE: [String]
    public var captureGuidanceDE: String
    public var researchAnchorDE: String
    public var mismatchHintDE: String

    public struct ResearchBars: Equatable, Sendable {
        public var minBoard: Double
        public var minCoPresence: Double
        public var minInteractionDensity: Double
        public var minLayoutFit: Double
        public var minBoardText: Double
        public var minPeopleSpatial: Double
        public var minMidBand: Double

        public init(_ values: TeachingSituationResearchBarsValues) {
            minBoard = values.minBoard
            minCoPresence = values.minCoPresence
            minInteractionDensity = values.minInteractionDensity
            minLayoutFit = values.minLayoutFit
            minBoardText = values.minBoardText
            minPeopleSpatial = values.minPeopleSpatial
            minMidBand = values.minMidBand
        }
    }

    public init(from preset: TeachingSituationPreset) {
        let cfg = GuidanceConfig.forTeachingSituation(preset.id)
        self.id = preset.id
        self.titleDE = preset.titleDE
        self.scriptFamilyDE = preset.timssScriptFamilyDE
        self.expectedScenes = preset.expectedScenes
        self.acceptableScenes = preset.acceptableScenes
        self.preferredLayouts = preset.preferredLayouts
        self.requiresBoard = preset.requiresBoard
        self.minPeople = preset.minPeople
        var bars = TeachingSituationResearchBarsValues()
        bars.minBoard = preset.minResearchBoardScore
        bars.minCoPresence = preset.minResearchCoPresence
        bars.minInteractionDensity = preset.minResearchInteractionDensity
        bars.minLayoutFit = preset.minResearchLayoutFit
        bars.minBoardText = preset.minResearchBoardTextDensity
        bars.minPeopleSpatial = cfg.minPeopleSpatialUsefulness
        bars.minMidBand = cfg.minPersonMidBandOccupancy
        self.researchBars = ResearchBars(bars)
        self.ipnEmphasis = preset.ipnEmphasis
        self.timssExpected = preset.expectedTIMSSActivities
        self.gtiEmphasis = preset.gtiEmphasis
        self.checklistDE = preset.researchCaptureChecklistDE
        self.captureGuidanceDE = preset.captureGuidanceDE
        self.researchAnchorDE = preset.researchAnchorDE
        self.mismatchHintDE = preset.mismatchHintDE
    }
}

public extension TeachingSituationCatalogue {
    /// Exhaustive research packs for all 12 situations.
    static var researchPacks: [TeachingSituationResearchPack] {
        all.map { TeachingSituationResearchPack(from: $0) }
    }

    static func researchPack(for id: TeachingSituationID) -> TeachingSituationResearchPack {
        TeachingSituationResearchPack(from: preset(for: id))
    }
}

// MARK: - CV research signal completeness

/// How completely a CVFeatures sample supplies research-required structure signals.
public struct CVResearchSignalCompleteness: Equatable, Sendable {
    public var score: Double
    public var presentSignals: [String]
    public var missingSignals: [String]
    public var summaryDE: String

    public init(score: Double, presentSignals: [String], missingSignals: [String], summaryDE: String) {
        self.score = min(1, max(0, score))
        self.presentSignals = presentSignals
        self.missingSignals = missingSignals
        self.summaryDE = summaryDE
    }

    /// Evaluate against the full research CV contract (not placement geometry).
    public static func evaluate(_ cv: CVFeatures) -> CVResearchSignalCompleteness {
        guard cv.analysisSucceeded else {
            return CVResearchSignalCompleteness(
                score: 0,
                presentSignals: [],
                missingSignals: Self.contractSignalIDs,
                summaryDE: "CV fehlgeschlagen - keine Forschungsstruktur-Signale."
            )
        }

        let signals = signalChecks(for: cv)
        let present = signals.filter(\.isPresent).map(\.id)
        let missing = signals.filter { !$0.isPresent }.map(\.id)

        let score = Double(present.count) / Double(Self.contractSignalIDs.count)
        return CVResearchSignalCompleteness(
            score: score,
            presentSignals: present,
            missingSignals: missing,
            summaryDE: "CV-Forschungssignale \(present.count)/\(Self.contractSignalIDs.count) (\(Int(score * 100)) %)."
        )
    }

    private static func signalChecks(for cv: CVFeatures) -> [(id: String, isPresent: Bool)] {
        boardSignalChecks(for: cv) + peopleSignalChecks(for: cv) + structureSignalChecks(for: cv)
    }

    private static func boardSignalChecks(for cv: CVFeatures) -> [(id: String, isPresent: Bool)] {
        [
            ("boardConfidence", cv.boardConfidence > 0.05 || cv.multiCueBoardQuality > 0.05),
            ("boardAspectGeometry", cv.boardAspectQuality > 0 || cv.boardGeometryQuality > 0),
            ("boardEdgeOrText", boardEdgeOrTextPresent(cv))
        ]
    }

    private static func peopleSignalChecks(for cv: CVFeatures) -> [(id: String, isPresent: Bool)] {
        [
            ("peopleCount", cv.personCount > 0 || cv.faceCount > 0),
            ("peopleSpatial", cv.personCoverage > 0 || cv.peopleSpatialUsefulness > 0),
            ("midBand", cv.personMidBandOccupancy > 0),
            ("centroids", cv.personCentroidX != nil || cv.personCentroidY != nil),
            ("coPresence", coPresencePresent(cv)),
            ("spreadCluster", spreadClusterPresent(cv))
        ]
    }

    private static func structureSignalChecks(for cv: CVFeatures) -> [(id: String, isPresent: Bool)] {
        [
            ("layout", cv.layoutPattern != .unknown && cv.layoutPattern != .empty),
            ("stability", cv.observationStability > 0),
            ("interactionDensity", interactionDensityPresent(cv)),
            ("actorScaleOrPose", actorScaleOrPosePresent(cv))
        ]
    }

    private static func boardEdgeOrTextPresent(_ cv: CVFeatures) -> Bool {
        cv.boardEdgeSupport > 0 || cv.boardTextDensity > 0 || cv.secondaryWritingSurfaceSupport > 0
    }

    private static func coPresencePresent(_ cv: CVFeatures) -> Bool {
        cv.personBoardCoPresence > 0 || CVFeatureFusion.coPresenceScore(from: cv) > 0
    }

    private static func spreadClusterPresent(_ cv: CVFeatures) -> Bool {
        cv.personHorizontalSpread > 0 || cv.personClusteredness > 0 || cv.estimatedClusterCount > 0
    }

    private static func interactionDensityPresent(_ cv: CVFeatures) -> Bool {
        cv.interactionDensity > 0 || CVFeatureFusion.interactionDensity(from: cv) > 0
    }

    private static func actorScaleOrPosePresent(_ cv: CVFeatures) -> Bool {
        cv.actorScaleVariance > 0 || cv.poseConfidenceMean > 0 || cv.faceScaleScore > 0
    }

    public static let contractSignalIDs: [String] = [
        "boardConfidence", "boardAspectGeometry", "boardEdgeOrText",
        "peopleCount", "peopleSpatial", "midBand", "centroids",
        "coPresence", "layout", "spreadCluster", "stability",
        "interactionDensity", "actorScaleOrPose"
    ]
}

public extension CVFeatures {
    var researchSignalCompleteness: CVResearchSignalCompleteness {
        CVResearchSignalCompleteness.evaluate(self)
    }
}

// MARK: - Scene type coverage helpers

public enum TeachingSceneExhaustiveness: Sendable {
    /// All classifiable research scene types (excluding empty).
    public static var classifiableScenes: [TeachingSceneType] {
        TeachingSceneType.allCases.filter { $0 != .emptyOrUnusable }
    }

    /// Map each research fixture to its primary expected scene under its intended preset.
    public static var fixtureSceneExpectations: [(fixture: String, cv: () -> CVFeatures, preset: TeachingSituationID, scenes: [TeachingSceneType])] {
        [
            ("classroom", { .fixtureClassroomPresent() }, .frontalBoardInstruction, [.boardCentricFrontal]),
            ("group", { .fixtureGroupWork() }, .collaborativeGroupWork, [.multiPersonGroup]),
            ("dialogue", { .fixtureDialoguePair() }, .teacherLedDialogue, [.dialoguePair, .boardCentricFrontal]),
            ("partner", { .fixturePartnerWork() }, .partnerWork, [.dialoguePair]),
            ("studentBoard", { .fixtureStudentAtBoard() }, .studentBoardPresentation, [.studentAtBoard]),
            ("experiment", { .fixtureExperimentSpread() }, .handsOnExperiment, [.experimentSpread, .multiPersonGroup]),
            ("circle", { .fixtureCircleDiscussion() }, .circleOrPlenumDiscussion, [.circleDiscussion, .multiPersonGroup]),
            ("management", { .fixtureManagementOverview() }, .classroomManagementOverview, [.wholeRoomOverview, .multiPersonGroup]),
            ("seatwork", { .fixtureSeatworkScattered() }, .individualSeatwork, [.individualSeatwork, .actorsWithoutBoard]),
            ("demo", { .fixtureTeacherDemonstration() }, .teacherDemonstration, [.teacherDemonstration, .studentAtBoard, .boardCentricFrontal]),
            ("transition", { .fixtureTransitionOrganization() }, .transitionOrganization, [.transitionMoment, .wholeRoomOverview]),
            ("formative", { .fixtureFormativeAssessment() }, .formativeAssessmentDialogue, [.dialoguePair, .boardCentricFrontal]),
            ("empty", { .fixtureEmptyRoom() }, .frontalBoardInstruction, [.emptyOrUnusable]),
            ("boardOnly", { .fixtureBoardNoPeople() }, .frontalBoardInstruction, [.boardOnly]),
            ("peopleNoBoard", { .fixturePeopleNoBoard() }, .teacherLedDialogue, [.actorsWithoutBoard, .dialoguePair, .multiPersonGroup, .individualSeatwork])
        ]
    }

}

// MARK: - Production Vision contract

/// Static contract of production Vision → pure feature path (asserted by tests on source).
public enum ProductionMLContract: Sendable {
    public static let visionRequestTypes: [String] = [
        "VNDetectRectanglesRequest",
        "VNDetectHumanRectanglesRequest",
        "VNDetectFaceRectanglesRequest",
        "VNDetectDocumentSegmentationRequest",
        "VNRecognizeTextRequest",
        "VNDetectHumanBodyPoseRequest",
        "VNGenerateAttentionBasedSaliencyImageRequest"
    ]

    public static let livePathSymbols: [String] = [
        "VisionClassroomAnalyzer",
        "analyze(pixelBuffer:",
        "configure(for:",
        "ClassroomLayoutAnalyzer",
        "CVObservationSmoother",
        "analysisSucceeded: false"
    ]

    public static let adapterRelativePath =
        "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift"
    public static let samplerRelativePath =
        "App/Unterrichtsvideographie/Live/FrameSampler.swift"
}

// MARK: - Full-stack research evaluation

public struct ExhaustiveResearchEvaluation: Equatable, Sendable {
    public var pack: TeachingSituationResearchPack
    public var scene: TeachingSceneAssessment
    public var structure: ResearchStructureSufficiency
    public var signalCompleteness: CVResearchSignalCompleteness
    public var coding: PedagogicalCodingResult
    public var codingCompleteness: PedagogicalCodingCompleteness
    public var researchQuality: ResearchCaptureQuality
    public var readiness: ResearchReadinessReport
    public var guidance: GuidanceResult

    public var satisfiesResearchCapture: Bool {
        structure.sufficient
            && scene.matchesPreset
            && codingCompleteness.isCompleteSoftwareLayer
            && researchQuality.level != .unsuitable
            && signalCompleteness.score >= 0.5
    }
}

public enum ExhaustiveResearchEvaluator: Sendable {
    public struct Input: Sendable {
        public var cv = CVFeatures.empty
        public var teachingSituation: TeachingSituationID = .frontalBoardInstruction
        public var frame: FrameMetrics?
        public var orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        public var analysisFocus: CodingAnalysisFocus? = .lessonAnalysis

        public init(cv: CVFeatures, teachingSituation: TeachingSituationID) {
            self.cv = cv
            self.teachingSituation = teachingSituation
        }
    }

    public static func evaluate(_ evaluation: Input) -> ExhaustiveResearchEvaluation {
        let pack = TeachingSituationCatalogue.researchPack(for: evaluation.teachingSituation)
        var input = GuidanceInput.Values(
            orientation: evaluation.orientation,
            frame: evaluation.frame ?? defaultFrame()
        )
        input.cv = evaluation.cv
        input.motion = .stable
        input.teachingSituation = evaluation.teachingSituation
        input.analysisFocus = evaluation.analysisFocus
        input.operatingMode = .experimentalResearch(
            protocolReference: "explicit-unvalidated-exhaustive-evaluation"
        )
        let guidance = GuidanceEngine().evaluate(GuidanceInput(input))
        let completeness = PedagogicalCodingCompleteness.evaluate(
            guidance.pedagogicalCoding,
            cvSucceeded: evaluation.cv.analysisSucceeded
        )
        return ExhaustiveResearchEvaluation(
            pack: pack,
            scene: guidance.scene,
            structure: guidance.structureSufficiency,
            signalCompleteness: evaluation.cv.researchSignalCompleteness,
            coding: guidance.pedagogicalCoding,
            codingCompleteness: completeness,
            researchQuality: guidance.researchQuality,
            readiness: ResearchReadinessReport.build(from: guidance),
            guidance: guidance
        )
    }

    public static func evaluate(
        cv: CVFeatures,
        teachingSituation: TeachingSituationID
    ) -> ExhaustiveResearchEvaluation {
        evaluate(Input(cv: cv, teachingSituation: teachingSituation))
    }

    /// Evaluate all 12 presets against a single CV fixture (preset differentiation proof).
    public static func evaluateAllPresets(cv: CVFeatures) -> [ExhaustiveResearchEvaluation] {
        TeachingSituationID.allCases.map {
            evaluate(Input(cv: cv, teachingSituation: $0))
        }
    }

    private static func defaultFrame() -> FrameMetrics {
        var values = FrameMetrics.Values()
        values.averageLuminance = 0.45
        values.boardRegionScore = 0.5
        values.boardCenterY = 0.38
        values.ceilingFraction = 0.12
        values.floorFraction = 0.12
        values.backlightScore = 0.1
        values.emptyEdgeFraction = 0.15
        values.globalContrast = 0.35
        return FrameMetrics(values)
    }
}
