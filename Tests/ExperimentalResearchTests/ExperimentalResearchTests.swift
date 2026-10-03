import ExperimentalResearch
import GuidanceEngine
import SessionCore
import XCTest

final class ExperimentalResearchTests: XCTestCase {
    func testFixtureCatalogueAndEvaluationRemainExperimental() {
        let fixture = CVFeatures.fixtureGroupWork()
        let result = ExperimentalResearchEngine().evaluate(
            orientation: .init(pitchDegrees: 1, rollDegrees: 1),
            frame: FrameMetrics(),
            cv: fixture,
            teachingSituation: .collaborativeGroupWork,
            analysisFocus: .lessonAnalysis
        )
        XCTAssertEqual(result.teachingSituation, .collaborativeGroupWork)
        XCTAssertFalse(TeachingSituationCatalogue.all.isEmpty)
        XCTAssertEqual(result.hypotheses.validationStatus, .unvalidated)
        XCTAssertFalse(result.hypotheses.hypotheses.isEmpty)
    }

    func testSnapshotKeepsPersistedRawValues() {
        let provenance = ResearchArtifactProvenance(("1.0", "1", 2, "test", "registry"))
        let snapshot = ResearchCodingSnapshot(ResearchCodingSnapshot.Values(provenance: provenance))
        XCTAssertEqual(snapshot.appVersion, "1.0 (1)")
        XCTAssertEqual(CodingAnalysisFocus.lessonAnalysis.rawValue, "lessonAnalysis")
    }

    func testResearchEngineOwnsSceneTipsAndInterpretedSignals() {
        let engine = ExperimentalResearchEngine()
        let cv = CVFeatures.fixtureGroupWork()
        let signals = ExperimentalCaptureSignals(cv: cv)
        let scene = TeachingSceneAssessor.assess(signals: signals, preset: .collaborativeGroupWork)

        XCTAssertNotEqual(signals.layoutPattern, .unknown)
        XCTAssertGreaterThan(signals.interactionDensity, 0)
        XCTAssertTrue(engine.evaluatePresetExpectations(
            cv: cv,
            scene: scene,
            situation: .collaborativeGroupWork
        ).allSatisfy { $0.category == .teachingScene })
    }

    func testResearchEngineReusesCallerProvidedDirectObservability() {
        var input = GuidanceInput.Values(
            orientation: .init(pitchDegrees: 30, rollDegrees: 20),
            frame: FrameMetrics()
        )
        input.cv = .fixtureClassroomPresent()
        let direct = GuidanceEngine().evaluate(GuidanceInput(input))

        let result = ExperimentalResearchEngine().evaluate(
            observability: direct,
            frame: FrameMetrics(),
            cv: .fixtureGroupWork(),
            teachingSituation: .collaborativeGroupWork,
            analysisFocus: .lessonAnalysis
        )

        XCTAssertEqual(result.observability, direct)
        XCTAssertEqual(result.teachingSituation, .collaborativeGroupWork)
    }

    func testPedagogicalWindowPreservesMeansRecencyAndRationaleAfterIndexing() throws {
        let engine = ExperimentalResearchEngine()
        let features: [CVFeatures] = [
            .fixtureBoardNoPeople(),
            .fixtureGroupWork(),
            .fixtureTeacherDemonstration()
        ]
        let samples = features.map {
            engine.evaluate(
                orientation: .init(pitchDegrees: 0, rollDegrees: 0),
                frame: FrameMetrics(),
                cv: $0,
                teachingSituation: .teacherDemonstration,
                analysisFocus: .lessonAnalysis
            ).coding
        }
        var window = PedagogicalCodingWindow(capacity: samples.count)
        samples.forEach { window.push($0) }

        let aggregate = try XCTUnwrap(window.aggregate())
        assertAggregates(aggregate.ipnDimensions, source: samples.map(\.ipnDimensions))
        assertAggregates(aggregate.timssActivities, source: samples.map(\.timssActivities))
        assertAggregates(aggregate.gtiDimensions, source: samples.map(\.gtiDimensions))
    }

    private func assertAggregates(
        _ actual: [PedagogicalCodeAssignment],
        source: [[PedagogicalCodeAssignment]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for assignment in actual {
            let values = source.flatMap { $0 }.filter { $0.code == assignment.code }
            guard let recent = values.last else {
                XCTFail("Missing source assignment for \(assignment.code)", file: file, line: line)
                continue
            }
            XCTAssertEqual(
                assignment.level,
                values.reduce(0) { $0 + $1.level } / Double(values.count),
                accuracy: 1e-12,
                file: file,
                line: line
            )
            XCTAssertEqual(
                assignment.confidence,
                values.reduce(0) { $0 + $1.confidence } / Double(values.count),
                accuracy: 1e-12,
                file: file,
                line: line
            )
            XCTAssertEqual(assignment.labelDE, recent.labelDE, file: file, line: line)
            XCTAssertEqual(
                assignment.rationaleDE,
                "Fenster-Aggregation (\(source.count) Beobachtungen). \(recent.rationaleDE)",
                file: file,
                line: line
            )
        }

        let lastIndexByCode = Dictionary(uniqueKeysWithValues: Set(actual.map(\.code)).map { code in
            (code, source.lastIndex { $0.contains { $0.code == code } } ?? -1)
        })
        let expectedOrder = actual.sorted { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level > rhs.level }
            let left = lastIndexByCode[lhs.code] ?? -1
            let right = lastIndexByCode[rhs.code] ?? -1
            return left == right ? lhs.code < rhs.code : left > right
        }
        XCTAssertEqual(actual.map(\.code), expectedOrder.map(\.code), file: file, line: line)
    }
}
