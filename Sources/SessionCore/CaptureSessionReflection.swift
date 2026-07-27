import Foundation
import GuidanceEngine

extension CaptureSession {
    /// LAF scaffold notes from latest coding (keys = ReflectionPromptID.rawValue).
    public func reflectionScaffoldNotes() -> [String: String] {
        guard let snap = latestCodingSnapshot else { return [:] }
        return CodingInformedReflection.scaffoldNotes(
            coding: reflectionCodingResult(from: snap),
            scene: reflectionSceneAssessment(from: snap),
            situation: teachingSituation
        )
    }

    private func reflectionCodingResult(from snap: ResearchCodingSnapshot) -> PedagogicalCodingResult {
        let assignments = PedagogicalCodingResult.Assignments(
            ipnDimensions: snap.ipn.map {
                reflectionAssignment(
                    from: $0,
                    family: PedagogicalCodeFamily(rawValue: $0.family) ?? .ipnProcessQuality
                )
            },
            timssActivities: snap.timss.map {
                reflectionAssignment(from: $0, family: .timssActivityScript)
            },
            gtiDimensions: snap.gti.map {
                reflectionAssignment(from: $0, family: .gtiQuality)
            }
        )
        let content = PedagogicalCodingResult.Content(
            assignments: assignments,
            primaryCodes: .init(
                timss: TIMSSActivityCode(rawValue: snap.primaryTIMSS) ?? .unclearOrNonInstructional,
                gti: GTIQualityCode(rawValue: snap.primaryGTI) ?? .instructionalQuality
            ),
            overallConfidence: snap.overallConfidence,
            summaryDE: snap.summaryDE
        )
        let context = PedagogicalCodingResult.Context(
            sceneType: TeachingSceneType(rawValue: snap.sceneType) ?? .emptyOrUnusable,
            teachingSituation: teachingSituation,
            layoutPattern: ClassroomLayoutPattern(rawValue: snap.layoutPattern) ?? .unknown,
            analysisFocus: analysisIntent.codingFocus
        )
        return PedagogicalCodingResult(.init(content: content, context: context))
    }

    private func reflectionAssignment(
        from row: ResearchCodeRow,
        family: PedagogicalCodeFamily
    ) -> PedagogicalCodeAssignment {
        PedagogicalCodeAssignment(
            .init(
                identity: .init(id: row.id, family: family),
                descriptor: .init(code: row.code, labelDE: row.labelDE),
                measurement: .init(level: row.level, confidence: row.confidence),
                rationaleDE: row.rationaleDE
            )
        )
    }

    private func reflectionSceneAssessment(from snap: ResearchCodingSnapshot) -> TeachingSceneAssessment {
        TeachingSceneAssessment(
            .init(
                classification: .init(
                    sceneType: TeachingSceneType(rawValue: snap.sceneType) ?? .emptyOrUnusable,
                    confidence: snap.sceneConfidence,
                    presetMatchScore: snap.presetMatchScore,
                    matchesPreset: snap.matchesPreset
                ),
                summaryDE: snap.summaryDE,
                peopleSignals: .init(
                    peopleSignal: snap.peopleSignal,
                    coPresenceSignal: snap.coPresenceSignal
                ),
                structureSignals: .init(
                    boardSignal: snap.boardSignal,
                    layoutSignal: snap.layoutSignal,
                    layoutPattern: ClassroomLayoutPattern(rawValue: snap.layoutPattern) ?? .unknown
                )
            )
        )
    }

}
