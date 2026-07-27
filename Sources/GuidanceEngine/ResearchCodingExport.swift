import Foundation

/// Machine-readable identity carried by every experimental coding artifact.
/// `algorithmVersion` identifies the rule implementation, not a validated
/// scientific instrument.
public struct ResearchArtifactProvenance: Equatable, Codable, Sendable {
    public typealias Values = (
        semanticVersion: String,
        buildNumber: String,
        schemaVersion: Int,
        algorithmVersion: String,
        evidenceRegistryVersion: String
    )

    public var semanticVersion: String
    public var buildNumber: String
    public var schemaVersion: Int
    public var algorithmVersion: String
    public var evidenceRegistryVersion: String

    public init(_ values: Values) {
        semanticVersion = values.semanticVersion
        buildNumber = values.buildNumber
        schemaVersion = values.schemaVersion
        algorithmVersion = values.algorithmVersion
        evidenceRegistryVersion = values.evidenceRegistryVersion
    }

    public var displayVersion: String {
        "\(semanticVersion) (\(buildNumber))"
    }
}

// MARK: - Analysis focus (mirrors SessionCore intents; kept pure in GuidanceEngine)

/// Capture / analysis focus that softly reweights IPN/TIMSS/GTI coding priors.
/// Aligns with Blomberg purpose-first design and Santagata LAF / professional vision goals.
public enum CodingAnalysisFocus: String, Codable, CaseIterable, Sendable, Identifiable {
    case professionalVision
    case classroomManagement
    case studentThinking
    case lessonAnalysis
    case documentationOnly

    public var id: String { rawValue }

    public var titleDE: String { Self.titles[self] ?? rawValue }

    private static let titles: [CodingAnalysisFocus: String] = [
        .professionalVision: "Professionelle Wahrnehmung",
        .classroomManagement: "Klassenführung",
        .studentThinking: "Schülerdenken / Noticing",
        .lessonAnalysis: "Lektionsanalyse (LAF)",
        .documentationOnly: "Dokumentation / Portfolio"
    ]

    /// Soft IPN dimension boosts for this analysis focus.
    public var ipnBoosts: [String] {
        switch self {
        case .professionalVision:
            return ["goalOrientation", "cognitiveActivation", "learningSupport"]
        case .classroomManagement:
            return ["classroomOrganization", "socialClimate"]
        case .studentThinking:
            return ["learningSupport", "cognitiveActivation", "errorCulture"]
        case .lessonAnalysis:
            return ["goalOrientation", "cognitiveActivation", "classroomOrganization", "learningSupport"]
        case .documentationOnly:
            return ["classroomOrganization"]
        }
    }

    /// Soft GTI dimension boosts for this analysis focus.
    public var gtiBoosts: [String] {
        switch self {
        case .professionalVision:
            return ["instructionalQuality", "subjectClarity", "cognitiveEngagement"]
        case .classroomManagement:
            return ["classroomManagement", "socialEmotionalSupport"]
        case .studentThinking:
            return ["discourseQuality", "assessmentFeedback", "studentEngagementProxy"]
        case .lessonAnalysis:
            return ["instructionalQuality", "discourseQuality", "subjectClarity", "cognitiveEngagement"]
        case .documentationOnly:
            return ["classroomManagement", "instructionalQuality"]
        }
    }
}

// MARK: - Framework crosswalk (research documentation)

public struct PedagogicalFrameworkLink: Equatable, Sendable, Identifiable {
    public typealias Values = (id: String, ipn: String?, timss: String?, gti: String?, noteDE: String)

    public var id: String
    public var ipn: String?
    public var timss: String?
    public var gti: String?
    public var noteDE: String

    public init(_ values: Values) {
        id = values.id
        ipn = values.ipn
        timss = values.timss
        gti = values.gti
        noteDE = values.noteDE
    }
}

/// Documented links between IPN process quality, TIMSS scripts, and GTI/TALIS Video facets.
public enum PedagogicalFrameworkCrosswalk: Sendable {
    public typealias Link = PedagogicalFrameworkLink

    /// Stable research crosswalk for in-app Learn content and export metadata.
    public static let links: [Link] = [
        Link((
            id: "org-mgmt",
            ipn: IPNDimensionCode.classroomOrganization.rawValue,
            timss: TIMSSActivityCode.transitionOrganization.rawValue,
            gti: GTIQualityCode.classroomManagement.rawValue,
            noteDE: "Organisation / Klassenführung: IPN Organisation ↔ GTI management ↔ TIMSS transition/organization."
        )),
        Link((
            id: "goal-clarity",
            ipn: IPNDimensionCode.goalOrientation.rawValue,
            timss: TIMSSActivityCode.publicBoardWork.rawValue,
            gti: GTIQualityCode.subjectClarity.rawValue,
            noteDE: "Zielklarheit: IPN Zielorientierung ↔ Tafelarbeit/Skript ↔ GTI subject clarity."
        )),
        Link((
            id: "support-climate",
            ipn: IPNDimensionCode.learningSupport.rawValue,
            timss: TIMSSActivityCode.recitationDialogue.rawValue,
            gti: GTIQualityCode.socialEmotionalSupport.rawValue,
            noteDE: "Lernunterstützung / Klima: IPN support ↔ Dialogskripte ↔ GTI social-emotional support."
        )),
        Link((
            id: "activation-instruction",
            ipn: IPNDimensionCode.cognitiveActivation.rawValue,
            timss: TIMSSActivityCode.wholeClassInstruction.rawValue,
            gti: GTIQualityCode.cognitiveEngagement.rawValue,
            noteDE: "Kognitive Aktivierung: IPN ↔ Ganzklassen-/Tafelarbeit ↔ GTI cognitive engagement."
        )),
        Link((
            id: "social-discourse",
            ipn: IPNDimensionCode.socialClimate.rawValue,
            timss: TIMSSActivityCode.discussionPlenum.rawValue,
            gti: GTIQualityCode.discourseQuality.rawValue,
            noteDE: "Sozialklima / Diskurs: Plenum/Gruppe ↔ GTI discourse quality."
        )),
        Link((
            id: "error-assessment",
            ipn: IPNDimensionCode.errorCulture.rawValue,
            timss: TIMSSActivityCode.recitationDialogue.rawValue,
            gti: GTIQualityCode.assessmentFeedback.rawValue,
            noteDE: "Fehlerkultur-Proxy ↔ formatives Feedback (GTI assessment) in Dialogphasen."
        )),
        Link((
            id: "experiment",
            ipn: IPNDimensionCode.experimentation.rawValue,
            timss: TIMSSActivityCode.experimentLab.rawValue,
            gti: GTIQualityCode.instructionalQuality.rawValue,
            noteDE: "Experimentierphasen: IPN experimentation ↔ TIMSS lab ↔ GTI instruction structure."
        )),
        Link((
            id: "group-engagement",
            ipn: IPNDimensionCode.socialClimate.rawValue,
            timss: TIMSSActivityCode.groupWork.rawValue,
            gti: GTIQualityCode.studentEngagementProxy.rawValue,
            noteDE: "Gruppenarbeit: soziale Einbindung und Engagement-Proxy aus Mehrpersonen-Layout."
        ))
    ]
}

// MARK: - Research coding snapshot (exportable)

/// Serializable snapshot of scene + coding for research logs / seminar portfolios.
public struct ResearchCodingSnapshot: Equatable, Codable, Sendable, Identifiable {
    public struct Values: Sendable {
        public var id = UUID()
        public var createdAt = Date()
        public var provenance: ResearchArtifactProvenance
        public var teachingSituation = ""
        public var analysisFocus: String?
        public var sceneType = ""
        public var layoutPattern = ""
        public var presetMatchScore = 0.0
        public var matchesPreset = false
        public var sceneConfidence = 0.0
        public var primaryTIMSS = ""
        public var primaryGTI = ""
        public var overallConfidence = 0.0
        public var summaryDE = ""
        public var ipn: [ResearchCodeRow] = []
        public var timss: [ResearchCodeRow] = []
        public var gti: [ResearchCodeRow] = []
        public var boardSignal = 0.0
        public var peopleSignal = 0.0
        public var coPresenceSignal = 0.0
        public var layoutSignal = 0.0

        public init(provenance: ResearchArtifactProvenance) {
            self.provenance = provenance
        }
    }

    public var id: UUID
    public var createdAt: Date
    /// Retained in the encoded shape for compatibility with early alpha files.
    /// New artifacts derive it from `provenance`; report construction rejects
    /// legacy snapshots that lack structured provenance.
    public private(set) var appVersion: String
    public private(set) var provenance: ResearchArtifactProvenance?
    public var teachingSituation: String
    public var analysisFocus: String?
    public var sceneType: String
    public var layoutPattern: String
    public var presetMatchScore: Double
    public var matchesPreset: Bool
    public var sceneConfidence: Double
    public var primaryTIMSS: String
    public var primaryGTI: String
    public var overallConfidence: Double
    public var summaryDE: String
    public var ipn: [ResearchCodeRow]
    public var timss: [ResearchCodeRow]
    public var gti: [ResearchCodeRow]
    public var boardSignal: Double
    public var peopleSignal: Double
    public var coPresenceSignal: Double
    public var layoutSignal: Double

    public init(_ values: Values) {
        (id, createdAt) = (values.id, values.createdAt)
        (appVersion, provenance) = (values.provenance.displayVersion, values.provenance)
        (teachingSituation, analysisFocus) = (values.teachingSituation, values.analysisFocus)
        (sceneType, layoutPattern) = (values.sceneType, values.layoutPattern)
        (presetMatchScore, matchesPreset) = (values.presetMatchScore, values.matchesPreset)
        sceneConfidence = values.sceneConfidence
        (primaryTIMSS, primaryGTI) = (values.primaryTIMSS, values.primaryGTI)
        (overallConfidence, summaryDE) = (values.overallConfidence, values.summaryDE)
        (ipn, timss, gti) = (values.ipn, values.timss, values.gti)
        (boardSignal, peopleSignal) = (values.boardSignal, values.peopleSignal)
        (coPresenceSignal, layoutSignal) = (values.coPresenceSignal, values.layoutSignal)
    }

    public static func from(
        coding: PedagogicalCodingResult,
        scene: TeachingSceneAssessment,
        analysisFocus: CodingAnalysisFocus? = nil,
        provenance: ResearchArtifactProvenance
    ) -> ResearchCodingSnapshot {
        var values = Values(provenance: provenance)
        values.apply(coding: coding, analysisFocus: analysisFocus)
        values.apply(scene: scene)
        return ResearchCodingSnapshot(values)
    }

    /// JSON for research logs / secondary use archives (not a validated codebook export).
    public func jsonData(pretty: Bool = true) throws -> Data {
        try researchJSONData(self, pretty: pretty)
    }

    public func jsonString(pretty: Bool = true) throws -> String {
        let data = try jsonData(pretty: pretty)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

func researchJSONData<Payload: Encodable>(_ payload: Payload, pretty: Bool) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
    return try encoder.encode(payload)
}

public struct ResearchCodeRow: Equatable, Codable, Sendable, Identifiable {
    public var id: String
    public var family: String
    public var code: String
    public var labelDE: String
    public var level: Double
    public var confidence: Double
    public var rationaleDE: String

    public init(_ a: PedagogicalCodeAssignment) {
        self.id = a.id
        self.family = a.family.rawValue
        self.code = a.code
        self.labelDE = a.labelDE
        self.level = a.level
        self.confidence = a.confidence
        self.rationaleDE = a.rationaleDE
    }
}

private extension ResearchCodingSnapshot.Values {
    mutating func apply(coding: PedagogicalCodingResult, analysisFocus: CodingAnalysisFocus?) {
        teachingSituation = coding.teachingSituation.rawValue
        self.analysisFocus = analysisFocus?.rawValue
        layoutPattern = coding.layoutPattern.rawValue
        primaryTIMSS = coding.primaryTIMSS.rawValue
        primaryGTI = coding.primaryGTI.rawValue
        overallConfidence = coding.overallConfidence
        summaryDE = coding.summaryDE
        ipn = coding.ipnDimensions.map(ResearchCodeRow.init)
        timss = coding.timssActivities.map(ResearchCodeRow.init)
        gti = coding.gtiDimensions.map(ResearchCodeRow.init)
    }

    mutating func apply(scene: TeachingSceneAssessment) {
        sceneType = scene.sceneType.rawValue
        presetMatchScore = scene.presetMatchScore
        matchesPreset = scene.matchesPreset
        sceneConfidence = scene.confidence
        boardSignal = scene.boardSignal
        peopleSignal = scene.peopleSignal
        coPresenceSignal = scene.coPresenceSignal
        layoutSignal = scene.layoutSignal
    }
}
