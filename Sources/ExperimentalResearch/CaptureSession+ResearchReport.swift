import Foundation
import GuidanceEngine
import SessionCore

/// Experimental reports and reflection scaffolds. SessionCore persists their DTOs,
/// while ExperimentalResearch owns the algorithms.
extension CaptureSession {
    public func researchCaptureReport(generatorProvenance: BuildProvenance) -> ResearchCaptureReport? {
        guard operatingMode == .experimentalResearch else { return nil }
        let snapshots = codingSnapshots.isEmpty
            ? (latestCodingSnapshot.map { [$0] } ?? [])
            : codingSnapshots
        guard let captureProvenance = buildProvenance?.researchArtifactProvenance,
              let reportProvenance = generatorProvenance.researchArtifactProvenance
        else { return nil }
        var input = ResearchCaptureReport.BuildInput()
        input.id = id
        input.createdAt = updatedAt
        input.sessionTitle = title
        input.teachingSituation = teachingSituation
        input.analysisFocus = analysisIntent
        input.snapshots = snapshots
        input.captureProvenance = captureProvenance
        input.generatorProvenance = reportProvenance
        return ResearchCaptureReport.build(input)
    }

    /// LAF scaffold notes are optional research context, never automatic reflection answers.
    public func reflectionScaffoldNotes() -> [String: String] {
        guard operatingMode == .experimentalResearch,
              let snapshot = latestCodingSnapshot
        else { return [:] }
        return CodingInformedReflection.scaffoldNotes(
            coding: reflectionCodingResult(from: snapshot),
            scene: reflectionSceneAssessment(from: snapshot),
            situation: teachingSituation
        )
    }

    func reflectionCodingResult(from snapshot: ResearchCodingSnapshot) -> PedagogicalCodingResult {
        let assignments = PedagogicalCodingResult.Assignments(
            ipnDimensions: snapshot.ipn.map {
                reflectionAssignment(
                    from: $0,
                    family: PedagogicalCodeFamily(rawValue: $0.family) ?? .ipnProcessQuality
                )
            },
            timssActivities: snapshot.timss.map { reflectionAssignment(from: $0, family: .timssActivityScript) },
            gtiDimensions: snapshot.gti.map { reflectionAssignment(from: $0, family: .gtiQuality) }
        )
        let content = PedagogicalCodingResult.Content(
            assignments: assignments,
            primaryCodes: .init(
                timss: TIMSSActivityCode(rawValue: snapshot.primaryTIMSS) ?? .unclearOrNonInstructional,
                gti: GTIQualityCode(rawValue: snapshot.primaryGTI) ?? .instructionalQuality
            ),
            overallConfidence: snapshot.overallConfidence,
            summaryDE: snapshot.summaryDE
        )
        let context = PedagogicalCodingResult.Context(
            sceneType: TeachingSceneType(rawValue: snapshot.sceneType) ?? .emptyOrUnusable,
            teachingSituation: teachingSituation,
            layoutPattern: ClassroomLayoutPattern(rawValue: snapshot.layoutPattern) ?? .unknown,
            analysisFocus: analysisIntent
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

    func reflectionSceneAssessment(from snapshot: ResearchCodingSnapshot) -> TeachingSceneAssessment {
        TeachingSceneAssessment(
            .init(
                classification: .init(
                    sceneType: TeachingSceneType(rawValue: snapshot.sceneType) ?? .emptyOrUnusable,
                    confidence: snapshot.sceneConfidence,
                    presetMatchScore: snapshot.presetMatchScore,
                    matchesPreset: snapshot.matchesPreset
                ),
                summaryDE: snapshot.summaryDE,
                peopleSignals: .init(
                    peopleSignal: snapshot.peopleSignal,
                    coPresenceSignal: snapshot.coPresenceSignal
                ),
                structureSignals: .init(
                    boardSignal: snapshot.boardSignal,
                    layoutSignal: snapshot.layoutSignal,
                    layoutPattern: ClassroomLayoutPattern(rawValue: snapshot.layoutPattern) ?? .unknown
                )
            )
        )
    }
}
