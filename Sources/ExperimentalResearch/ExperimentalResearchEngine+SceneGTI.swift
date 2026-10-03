import Foundation
import GuidanceEngine
import SessionCore

extension ExperimentalResearchEngine {
    func gtiCaptureExpectationTips(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        situation: TeachingSituationID,
        preset: TeachingSituationPreset?
    ) -> [ExperimentalResearchTip] {
        guard cv.analysisSucceeded else { return [] }
        let activePreset = preset ?? TeachingSituationCatalogue.preset(for: situation)
        let emphasis = Set(activePreset.gtiEmphasis)
        let board = max(cv.multiCueBoardQuality, cv.boardConfidence)
        let people = cv.peopleSpatialUsefulness
        let coPresence = CVFeatureFusion.coPresenceScore(from: cv)
        var tips = gtiBoardTips(activePreset, emphasis: emphasis, board: board)
        tips += gtiActorTips(cv, emphasis: emphasis, people: people)
        tips += gtiManagementTips(cv, scene: scene, emphasis: emphasis)
        tips += gtiClimateTips(cv, emphasis: emphasis, people: people)
        tips += gtiCognitiveTips(activePreset, emphasis: emphasis, board: board, coPresence: coPresence)
        return tips
    }

    private func gtiBoardTips(
        _ preset: TeachingSituationPreset,
        emphasis: Set<String>,
        board: Double
    ) -> [ExperimentalResearchTip] {
        guard gtiEmphasizes(emphasis, .subjectClarity, .instructionalQuality) else { return [] }
        guard preset.requiresBoard else { return [] }
        guard board < 0.35 else { return [] }
        return [ExperimentalResearchTip((
            id: "gti-subject-clarity-board",
            category: .teachingScene,
            severity: .info,
            message: "GTI fachliche Klarheit / Instruction: Schreibfläche schwach (\(percent(board))) - Zielsichtbarkeit im Capture begrenzt.",
            actionHint: "Tafel/Board vollständig und lesbar halten (Text-Dichte, multi-cue)."
        ))]
    }

    private func gtiActorTips(
        _ cv: CVFeatures,
        emphasis: Set<String>,
        people: Double
    ) -> [ExperimentalResearchTip] {
        guard gtiEmphasizes(emphasis, .discourseQuality, .assessmentFeedback) else { return [] }
        let peopleN = max(cv.personCount, cv.faceCount)
        guard peopleN < 2 || people < 0.28 else { return [] }
        return [ExperimentalResearchTip((
            id: "gti-discourse-actors",
            category: .teachingScene,
            severity: .info,
            message: "GTI Diskurs/Feedback: zu wenige lesbare Akteure für Dialogstruktur (n=\(peopleN)).",
            actionHint: "Dialogpartner zentrieren; Gesichter im Mittelband; engerer Ausschnitt."
        ))]
    }

    private func gtiManagementTips(
        _ cv: CVFeatures,
        scene: TeachingSceneAssessment,
        emphasis: Set<String>
    ) -> [ExperimentalResearchTip] {
        guard emphasis.contains(GTIQualityCode.classroomManagement.rawValue) else { return [] }
        guard scene.multiPersonSignal < 0.25 else { return [] }
        guard max(cv.personCount, cv.faceCount) < 3 else { return [] }
        return [ExperimentalResearchTip((
            id: "gti-management-overview",
            category: .teachingScene,
            severity: .info,
            message: "GTI Klassenführung: Raumübersicht mit mehreren SuS fehlt (Multi \(percent(scene.multiPersonSignal))).",
            actionHint: "Weiterer Winkel / höherer Standpunkt für Managementereignisse."
        ))]
    }

    private func gtiClimateTips(
        _ cv: CVFeatures,
        emphasis: Set<String>,
        people: Double
    ) -> [ExperimentalResearchTip] {
        guard gtiEmphasizes(emphasis, .socialEmotionalSupport, .studentEngagementProxy) else { return [] }
        guard cv.personMidBandOccupancy < 0.3 else { return [] }
        guard people > 0.1 else { return [] }
        return [ExperimentalResearchTip((
            id: "gti-climate-midband",
            category: .teachingScene,
            severity: .info,
            message: "GTI Sozialklima/Engagement: Akteure außerhalb des Interaktionsbandes (Mittelband \(percent(cv.personMidBandOccupancy))).",
            actionHint: "Interaktionszone zentrieren - Partizipation im Bild halten."
        ))]
    }

    private func gtiCognitiveTips(
        _ preset: TeachingSituationPreset,
        emphasis: Set<String>,
        board: Double,
        coPresence: Double
    ) -> [ExperimentalResearchTip] {
        guard emphasis.contains(GTIQualityCode.cognitiveEngagement.rawValue) else { return [] }
        guard preset.requiresBoard else { return [] }
        guard coPresence < 0.3 else { return [] }
        guard board >= 0.4 else { return [] }
        return [ExperimentalResearchTip((
            id: "gti-cognitive-copresence",
            category: .teachingScene,
            severity: .info,
            message: "GTI kognitive Aktivierung: Tafel ok, aber Person–Tafel-Co-Präsenz schwach (\(percent(coPresence))).",
            actionHint: "Lehrperson/Präsentierende an der Schreibfläche mit erfassen."
        ))]
    }

    private func gtiEmphasizes(
        _ emphasis: Set<String>,
        _ first: GTIQualityCode,
        _ second: GTIQualityCode
    ) -> Bool {
        emphasis.contains(first.rawValue) || emphasis.contains(second.rawValue)
    }
}
