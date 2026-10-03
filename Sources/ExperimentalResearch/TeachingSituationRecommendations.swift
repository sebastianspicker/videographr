import Foundation
import GuidanceEngine
import SessionCore

// MARK: - Preset recommendations (analysis focus → situations)

private let recommendedSituationsByFocus: [String: [TeachingSituationID]] = [
    CodingAnalysisFocus.professionalVision.rawValue: [
        .frontalBoardInstruction, .teacherLedDialogue, .formativeAssessmentDialogue,
        .studentBoardPresentation, .teacherDemonstration
    ],
    CodingAnalysisFocus.classroomManagement.rawValue: [
        .classroomManagementOverview, .transitionOrganization,
        .circleOrPlenumDiscussion, .collaborativeGroupWork
    ],
    CodingAnalysisFocus.studentThinking.rawValue: [
        .formativeAssessmentDialogue, .partnerWork, .collaborativeGroupWork,
        .circleOrPlenumDiscussion, .handsOnExperiment
    ],
    CodingAnalysisFocus.lessonAnalysis.rawValue: [
        .frontalBoardInstruction, .teacherLedDialogue, .studentBoardPresentation,
        .collaborativeGroupWork, .handsOnExperiment, .circleOrPlenumDiscussion
    ],
    CodingAnalysisFocus.documentationOnly.rawValue: TeachingSituationID.allCases
]

private let teachingSituationFamilies: [String: String] = [
    TeachingSituationID.frontalBoardInstruction.rawValue: "Ganzklasse / Tafel",
    TeachingSituationID.teacherDemonstration.rawValue: "Ganzklasse / Tafel",
    TeachingSituationID.studentBoardPresentation.rawValue: "Ganzklasse / Tafel",
    TeachingSituationID.teacherLedDialogue.rawValue: "Dialog / Feedback",
    TeachingSituationID.formativeAssessmentDialogue.rawValue: "Dialog / Feedback",
    TeachingSituationID.collaborativeGroupWork.rawValue: "Arbeitsformen",
    TeachingSituationID.partnerWork.rawValue: "Arbeitsformen",
    TeachingSituationID.individualSeatwork.rawValue: "Arbeitsformen",
    TeachingSituationID.handsOnExperiment.rawValue: "Experiment",
    TeachingSituationID.classroomManagementOverview.rawValue: "Organisation / Führung",
    TeachingSituationID.transitionOrganization.rawValue: "Organisation / Führung",
    TeachingSituationID.circleOrPlenumDiscussion.rawValue: "Plenum / Diskurs"
]

public extension TeachingSituationCatalogue {
    /// Unvalidated rule mapping from an analysis focus to candidate presets.
    static func recommended(for focus: CodingAnalysisFocus) -> [TeachingSituationID] {
        recommendedSituationsByFocus[focus.rawValue] ?? []
    }

    /// Family grouping for UI (TIMSS-script families).
    static func family(for id: TeachingSituationID) -> String {
        teachingSituationFamilies[id.rawValue] ?? "Unbekannt"
    }

    static var families: [(name: String, presets: [TeachingSituationPreset])] {
        let order = [
            "Ganzklasse / Tafel", "Dialog / Feedback", "Arbeitsformen",
            "Experiment", "Organisation / Führung", "Plenum / Diskurs"
        ]
        var buckets: [String: [TeachingSituationPreset]] = [:]
        for p in all {
            buckets[family(for: p.id), default: []].append(p)
        }
        return order.compactMap { name in
            guard let list = buckets[name], !list.isEmpty else { return nil }
            return (name, list)
        }
    }
}
