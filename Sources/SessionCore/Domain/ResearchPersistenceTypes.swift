import Foundation

/// Persisted teaching-situation identifier. Raw values are stable JSON keys.
public enum TeachingSituationID: String, Codable, CaseIterable, Sendable, Identifiable {
    case frontalBoardInstruction, teacherLedDialogue, collaborativeGroupWork, partnerWork
    case studentBoardPresentation, handsOnExperiment, classroomManagementOverview
    case circleOrPlenumDiscussion, individualSeatwork, teacherDemonstration
    case transitionOrganization, formativeAssessmentDialogue

    public var id: String { rawValue }
}

/// Persisted analysis focus, also persisted as the session's `AnalysisIntent`.
public enum CodingAnalysisFocus: String, Codable, CaseIterable, Sendable, Identifiable {
    case professionalVision, classroomManagement, studentThinking, lessonAnalysis, documentationOnly

    public var id: String { rawValue }

    public var titleDE: String {
        switch self {
        case .professionalVision: return "Professionelle Wahrnehmung"
        case .classroomManagement: return "Klassenführung"
        case .studentThinking: return "Schülerdenken / Noticing"
        case .lessonAnalysis: return "Lektionsanalyse (LAF)"
        case .documentationOnly: return "Dokumentation / Portfolio"
        }
    }
}

/// Machine-readable identity carried by every persisted experimental artifact.
public struct ResearchArtifactProvenance: Equatable, Codable, Sendable {
    public typealias Values = (
        semanticVersion: String, buildNumber: String, schemaVersion: Int,
        algorithmVersion: String, evidenceRegistryVersion: String
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

    public var displayVersion: String { "\(semanticVersion) (\(buildNumber))" }
}

public struct ResearchCodeRow: Equatable, Codable, Sendable, Identifiable {
    public var id: String
    public var family: String
    public var code: String
    public var labelDE: String
    public var level: Double
    public var confidence: Double
    public var rationaleDE: String

    public init(id: String, family: String, code: String, labelDE: String, level: Double, confidence: Double, rationaleDE: String) {
        self.id = id
        self.family = family
        self.code = code
        self.labelDE = labelDE
        self.level = level
        self.confidence = confidence
        self.rationaleDE = rationaleDE
    }
}

/// Serializable snapshot stored in session JSON and JSONL journals.
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

        public init(provenance: ResearchArtifactProvenance) { self.provenance = provenance }
    }

    public var id: UUID
    public var createdAt: Date
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
}
