import Foundation
import GuidanceEngine
import SessionCore

/// Experimental-only temporal aggregation of unvalidated IPN/TIMSS/GTI rules.
/// Owns the smoothing windows and transition detector; persistence and publication stay with the caller.
public struct ExperimentalAnalysisSession: Equatable, Sendable {
    /// Scene confidence below this keeps the aggregate coding as-is instead of re-contextualizing it.
    public static let sceneConfidenceThreshold = 0.35
    public static let recentTransitionLimit = 8

    public struct Output: Equatable, Sendable {
        public let coding: PedagogicalCodingResult
        /// Temporally smoothed scene.
        public let scene: TeachingSceneAssessment
        /// Last transitions; `nil` when no new transition was observed, so the caller keeps its previous value.
        public let recentTransitions: [SceneTransitionEvent]?
        public let snapshot: ResearchCodingSnapshot
    }

    private var codingWindow = PedagogicalCodingWindow(capacity: 8)
    private var sceneWindow = TeachingSceneWindow(capacity: 6)
    private var transitionDetector = SceneTransitionDetector()

    public init() {}

    public mutating func reset() {
        codingWindow.reset()
        sceneWindow.reset()
        transitionDetector.reset()
    }

    /// Advances the windows exactly once for a newly analyzed frame.
    public mutating func advance(
        with experimental: ExperimentalResearchResult,
        analysisFocus: CodingAnalysisFocus,
        provenance: ResearchArtifactProvenance
    ) -> Output {
        // Temporal scene smoothing is experimental-only and never changes direct observability.
        sceneWindow.push(experimental.scene)
        let smoothedScene = sceneWindow.aggregate() ?? experimental.scene
        let coding = smoothedCoding(from: experimental.coding, scene: smoothedScene)
        let transitions = observeTransition(scene: smoothedScene, coding: coding)
        let snapshot = ResearchCodingSnapshot.from(
            coding: coding,
            scene: smoothedScene,
            analysisFocus: analysisFocus,
            provenance: provenance
        )
        return Output(coding: coding, scene: smoothedScene, recentTransitions: transitions, snapshot: snapshot)
    }

    private mutating func observeTransition(
        scene: TeachingSceneAssessment,
        coding: PedagogicalCodingResult
    ) -> [SceneTransitionEvent]? {
        guard transitionDetector.observe(
            scene: scene,
            coding: coding
        ) != nil else { return nil }
        return transitionDetector.events.suffix(Self.recentTransitionLimit).map { $0 }
    }

    private mutating func smoothedCoding(
        from source: PedagogicalCodingResult,
        scene: TeachingSceneAssessment
    ) -> PedagogicalCodingResult {
        guard hasResearchCoding(source) else { return source }
        codingWindow.push(source)
        guard let aggregate = codingWindow.aggregate() else { return source }
        guard scene.confidence >= Self.sceneConfidenceThreshold else { return aggregate }
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
