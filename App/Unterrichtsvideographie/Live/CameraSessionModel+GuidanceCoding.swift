import GuidanceEngine

extension CameraSessionModel {
    func smoothedCoding(
        from source: PedagogicalCodingResult,
        scene: TeachingSceneAssessment
    ) -> PedagogicalCodingResult {
        guard hasResearchCoding(source) else { return source }
        codingWindow.push(source)
        guard let aggregate = codingWindow.aggregate() else { return source }
        guard scene.confidence >= 0.35 else { return aggregate }
        let assignments = PedagogicalCodingResult.Assignments(
            ipnDimensions: aggregate.ipnDimensions,
            timssActivities: aggregate.timssActivities,
            gtiDimensions: aggregate.gtiDimensions
        )
        let content = PedagogicalCodingResult.Content(
            assignments: assignments,
            primaryCodes: PedagogicalCodingResult.PrimaryCodes(
                timss: aggregate.primaryTIMSS,
                gti: aggregate.primaryGTI
            ),
            overallConfidence: aggregate.overallConfidence,
            summaryDE: aggregate.summaryDE
        )
        let context = PedagogicalCodingResult.Context(
            sceneType: scene.sceneType,
            teachingSituation: aggregate.teachingSituation,
            layoutPattern: scene.layoutPattern != .unknown ? scene.layoutPattern : aggregate.layoutPattern,
            analysisFocus: aggregate.analysisFocus
        )
        return PedagogicalCodingResult(.init(content: content, context: context))
    }

    private func hasResearchCoding(_ coding: PedagogicalCodingResult) -> Bool {
        coding.overallConfidence > 0
            || !coding.ipnDimensions.isEmpty
            || !coding.timssActivities.isEmpty
            || !coding.gtiDimensions.isEmpty
    }
}
