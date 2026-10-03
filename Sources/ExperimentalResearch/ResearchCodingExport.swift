import Foundation
import GuidanceEngine
import SessionCore

/// Experimental-only rule output. It is deliberately not part of `GuidanceResult`.
public enum ExperimentalValidationStatus: String, Codable, Equatable, Sendable { case unvalidated }

public struct ExperimentalHypothesis: Equatable, Identifiable, Sendable {
    public var id: String
    public var family: PedagogicalCodeFamily
    public var code: String
    public var labelDE: String
    public var ruleSupport: Double
    public var rationaleDE: String
    public var validationStatus: ExperimentalValidationStatus

    public init(assignment: PedagogicalCodeAssignment) {
        id = assignment.id
        family = assignment.family
        code = assignment.code
        labelDE = assignment.labelDE
        ruleSupport = assignment.level
        rationaleDE = assignment.rationaleDE
        validationStatus = .unvalidated
    }
}

public struct ExperimentalHypothesisSet: Equatable, Sendable {
    public var hypotheses: [ExperimentalHypothesis]
    public var validationStatus: ExperimentalValidationStatus
    public var limitationDE: String

    public init(hypotheses: [ExperimentalHypothesis]) {
        self.hypotheses = hypotheses
        validationStatus = .unvalidated
        limitationDE = "Regelbasierte, unvalidierte Hypothesen. Sie sind keine pädagogischen Bewertungen und ersetzen keine menschliche Kodierung."
    }
}

public extension CodingAnalysisFocus {
    var ipnBoosts: [String] {
        switch self {
        case .professionalVision: return ["goalOrientation", "cognitiveActivation", "learningSupport"]
        case .classroomManagement: return ["classroomOrganization", "socialClimate"]
        case .studentThinking: return ["learningSupport", "cognitiveActivation", "errorCulture"]
        case .lessonAnalysis: return ["goalOrientation", "cognitiveActivation", "classroomOrganization", "learningSupport"]
        case .documentationOnly: return ["classroomOrganization"]
        }
    }

    var gtiBoosts: [String] {
        switch self {
        case .professionalVision: return ["instructionalQuality", "subjectClarity", "cognitiveEngagement"]
        case .classroomManagement: return ["classroomManagement", "socialEmotionalSupport"]
        case .studentThinking: return ["discourseQuality", "assessmentFeedback", "studentEngagementProxy"]
        case .lessonAnalysis: return ["instructionalQuality", "discourseQuality", "subjectClarity", "cognitiveEngagement"]
        case .documentationOnly: return ["classroomManagement", "instructionalQuality"]
        }
    }
}

public extension ResearchCodeRow {
    init(_ assignment: PedagogicalCodeAssignment) {
        self.init(
            id: assignment.id,
            family: assignment.family.rawValue,
            code: assignment.code,
            labelDE: assignment.labelDE,
            level: assignment.level,
            confidence: assignment.confidence,
            rationaleDE: assignment.rationaleDE
        )
    }
}

public extension ResearchCodingSnapshot {
    static func from(
        coding: PedagogicalCodingResult,
        scene: TeachingSceneAssessment,
        analysisFocus: CodingAnalysisFocus? = nil,
        provenance: ResearchArtifactProvenance
    ) -> ResearchCodingSnapshot {
        var values = Values(provenance: provenance)
        values.teachingSituation = coding.teachingSituation.rawValue
        values.analysisFocus = analysisFocus?.rawValue
        values.layoutPattern = coding.layoutPattern.rawValue
        values.primaryTIMSS = coding.primaryTIMSS.rawValue
        values.primaryGTI = coding.primaryGTI.rawValue
        values.overallConfidence = coding.overallConfidence
        values.summaryDE = coding.summaryDE
        values.ipn = coding.ipnDimensions.map(ResearchCodeRow.init)
        values.timss = coding.timssActivities.map(ResearchCodeRow.init)
        values.gti = coding.gtiDimensions.map(ResearchCodeRow.init)
        values.sceneType = scene.sceneType.rawValue
        values.presetMatchScore = scene.presetMatchScore
        values.matchesPreset = scene.matchesPreset
        values.sceneConfidence = scene.confidence
        values.boardSignal = scene.boardSignal
        values.peopleSignal = scene.peopleSignal
        values.coPresenceSignal = scene.coPresenceSignal
        values.layoutSignal = scene.layoutSignal
        return ResearchCodingSnapshot(values)
    }
}
