import ExperimentalResearch
import GuidanceEngine
import SessionCore
import XCTest

final class ExperimentalAnalysisSessionTests: XCTestCase {
    private let provenance = ResearchArtifactProvenance(("9.9", "42", 7, "algo-test", "registry-test"))

    func testLowSceneConfidenceKeepsAggregateContext() {
        var session = ExperimentalAnalysisSession()
        var experimental = fixtureResult()
        XCTAssertGreaterThan(experimental.coding.overallConfidence, 0)
        let injected = differentScene(from: experimental.coding.sceneType)
        experimental.scene.sceneType = injected
        experimental.scene.confidence = 0.34
        let output = session.advance(with: experimental, analysisFocus: .lessonAnalysis, provenance: provenance)
        XCTAssertEqual(output.coding, experimental.coding)
        XCTAssertNotEqual(output.coding.sceneType, injected)
    }

    func testSceneConfidenceAtThresholdRecontextualizesCoding() {
        var session = ExperimentalAnalysisSession()
        var experimental = fixtureResult()
        let injected = differentScene(from: experimental.coding.sceneType)
        experimental.scene.sceneType = injected
        experimental.scene.confidence = 0.35
        let output = session.advance(with: experimental, analysisFocus: .lessonAnalysis, provenance: provenance)
        XCTAssertEqual(output.coding.sceneType, injected)
        XCTAssertEqual(output.coding.primaryTIMSS, experimental.coding.primaryTIMSS)
        XCTAssertEqual(output.coding.primaryGTI, experimental.coding.primaryGTI)
        XCTAssertEqual(output.coding.analysisFocus, experimental.coding.analysisFocus)
        XCTAssertEqual(output.scene.sceneType, injected)
    }

    func testSnapshotCarriesProvenanceAndFocus() {
        var session = ExperimentalAnalysisSession()
        let output = session.advance(with: fixtureResult(), analysisFocus: .classroomManagement, provenance: provenance)
        XCTAssertEqual(output.snapshot.provenance, provenance)
        XCTAssertEqual(output.snapshot.analysisFocus, CodingAnalysisFocus.classroomManagement.rawValue)
        XCTAssertEqual(output.snapshot.sceneType, output.scene.sceneType.rawValue)
        XCTAssertEqual(output.snapshot.primaryTIMSS, output.coding.primaryTIMSS.rawValue)
    }

    func testFirstFrameReportsNoTransition() {
        var session = ExperimentalAnalysisSession()
        let output = session.advance(with: fixtureResult(), analysisFocus: .lessonAnalysis, provenance: provenance)
        XCTAssertNil(output.recentTransitions)
    }

    func testSceneChangeReportsRecentTransitionsCappedAtEight() {
        var session = ExperimentalAnalysisSession()
        var seen: [SceneTransitionEvent]?
        let scenes: [TeachingSceneType] = [.boardOnly, .circleDiscussion]
        for index in 0..<40 {
            var experimental = fixtureResult()
            experimental.scene.sceneType = scenes[index % 2]
            experimental.scene.confidence = 1
            let output = session.advance(with: experimental, analysisFocus: .lessonAnalysis, provenance: provenance)
            if let transitions = output.recentTransitions { seen = transitions }
        }
        XCTAssertNotNil(seen)
        XCTAssertLessThanOrEqual(seen?.count ?? 0, 8)
    }

    func testResetClearsWindowsAndTransitionHistory() {
        var session = ExperimentalAnalysisSession()
        var first = fixtureResult()
        first.scene.sceneType = .boardOnly
        first.scene.confidence = 1
        _ = session.advance(with: first, analysisFocus: .lessonAnalysis, provenance: provenance)
        session.reset()
        XCTAssertEqual(session, ExperimentalAnalysisSession())
        // After reset the next frame is again a "first" frame: no transition, unsmoothed scene.
        var second = fixtureResult()
        second.scene.sceneType = .circleDiscussion
        second.scene.confidence = 1
        let output = session.advance(with: second, analysisFocus: .lessonAnalysis, provenance: provenance)
        XCTAssertNil(output.recentTransitions)
        XCTAssertEqual(output.scene.sceneType, .circleDiscussion)
    }

    func testWithoutResetTemporalSmoothingKeepsDominantScene() {
        var session = ExperimentalAnalysisSession()
        var board = fixtureResult()
        board.scene.sceneType = .boardOnly
        board.scene.confidence = 1
        _ = session.advance(with: board, analysisFocus: .lessonAnalysis, provenance: provenance)
        _ = session.advance(with: board, analysisFocus: .lessonAnalysis, provenance: provenance)
        var circle = board
        circle.scene.sceneType = .circleDiscussion
        let output = session.advance(with: circle, analysisFocus: .lessonAnalysis, provenance: provenance)
        XCTAssertEqual(output.scene.sceneType, .boardOnly)
    }

    private func differentScene(from scene: TeachingSceneType) -> TeachingSceneType {
        scene == .boardOnly ? .circleDiscussion : .boardOnly
    }

    private func fixtureResult() -> ExperimentalResearchResult {
        ExperimentalResearchEngine().evaluate(
            orientation: .init(pitchDegrees: 1, rollDegrees: 1),
            frame: FrameMetrics(),
            cv: CVFeatures.fixtureGroupWork(),
            teachingSituation: .collaborativeGroupWork,
            analysisFocus: .lessonAnalysis
        )
    }
}
