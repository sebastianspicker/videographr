import XCTest
@testable import GuidanceEngine

/// Core placement/tip regression suite for pure `GuidanceEngine` (orientation, board, composition).
/// Uses synthetic fixtures only - no Vision/AVFoundation.
final class GuidanceEngineTests: XCTestCase {
    let engine = GuidanceEngine()

    // MARK: - Orientation placement

    func testLevelOrientationProducesNoRollOrPitchCritical() {
        let input = experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: Self.goodClassroomFrame()
        )
        let result = engine.evaluate(input)
        XCTAssertFalse(result.tips.contains { $0.id.contains("roll") })
        XCTAssertFalse(result.tips.contains { $0.id.contains("pitch") })
        XCTAssertEqual(result.placement.quality, .directSignalsPass)
        XCTAssertTrue(result.placement.directSignalsPass)
    }

    func testExcessiveRollYieldsCriticalGuidanceWithAction() {
        let input = experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 0, rollDegrees: 18),
            frame: Self.goodClassroomFrame()
        )
        let result = engine.evaluate(input)
        let roll = result.tips.first { $0.id == "roll-critical" }
        guard let roll else { return XCTFail("Expected roll-critical guidance") }
        XCTAssertEqual(roll.severity, .critical)
        XCTAssertEqual(roll.category, .orientation)
        XCTAssertTrue(roll.message.localizedCaseInsensitiveContains("roll") || roll.message.contains("verkippt"))
        XCTAssertFalse(roll.actionHint.isEmpty)
        XCTAssertTrue(
            roll.actionHint.localizedCaseInsensitiveContains("stativ")
                || roll.actionHint.localizedCaseInsensitiveContains("waagerecht")
                || roll.actionHint.localizedCaseInsensitiveContains("nivell")
        )
        XCTAssertEqual(result.placement.quality, .defective)
        XCTAssertFalse(result.isReadyToRecord)
    }

    func testPitchUpCriticalAndWarning() {
        let critical = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 30, rollDegrees: 0), frame: Self.goodClassroomFrame())
        )
        XCTAssertTrue(critical.tips.contains { $0.id == "pitch-up-critical" })
        XCTAssertEqual(critical.overallSeverity, .critical)
        XCTAssertFalse(critical.isReadyToRecord)
        guard let tip = critical.tips.first(where: { $0.id == "pitch-up-critical" }) else {
            return XCTFail("Expected pitch-up-critical guidance")
        }
        XCTAssertTrue(tip.actionHint.localizedCaseInsensitiveContains("neig") || tip.actionHint.contains("unten"))

        let warning = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 15, rollDegrees: 0), frame: Self.goodClassroomFrame())
        )
        XCTAssertTrue(warning.tips.contains { $0.id == "pitch-up-warning" })
        XCTAssertEqual(warning.tips.first { $0.id == "pitch-up-warning" }?.severity, .warning)
    }

    func testPitchDownCriticalYieldsFloorPlacementAction() {
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: -25, rollDegrees: 0), frame: Self.goodClassroomFrame())
        )
        let tip = result.tips.first { $0.id == "pitch-down-critical" }
        guard let tip else { return XCTFail("Expected pitch-down-critical guidance") }
        XCTAssertEqual(tip.severity, .critical)
        XCTAssertTrue(tip.actionHint.localizedCaseInsensitiveContains("anheb") || tip.actionHint.contains("oben"))
        XCTAssertEqual(result.placement.quality, .defective)
    }

    // MARK: - Ceiling / floor

    func testHighCeilingFractionCriticalWithPlacementSteps() {
        var frame = Self.goodClassroomFrame()
        frame.ceilingFraction = 0.5
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: frame)
        )
        let tip = result.tips.first { $0.category == .ceiling && $0.severity >= .warning }
        guard let tip else { return XCTFail("Expected ceiling guidance") }
        XCTAssertTrue(tip.message.localizedCaseInsensitiveContains("decke"))
        XCTAssertFalse(tip.actionHint.isEmpty)
        XCTAssertTrue(
            tip.actionHint.localizedCaseInsensitiveContains("unten")
                || tip.actionHint.localizedCaseInsensitiveContains("neig")
                || tip.actionHint.localizedCaseInsensitiveContains("absenk")
        )
    }

    func testHighFloorFractionWarnsOrCritical() {
        var frame = Self.goodClassroomFrame()
        frame.floorFraction = 0.5
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: -5, rollDegrees: 0), frame: frame)
        )
        XCTAssertTrue(result.tips.contains { $0.id.hasPrefix("floor-") })
        guard let tip = result.tips.first(where: { $0.id.hasPrefix("floor-") }) else {
            return XCTFail("Expected floor guidance")
        }
        XCTAssertGreaterThanOrEqual(tip.severity, .warning)
        XCTAssertTrue(tip.actionHint.localizedCaseInsensitiveContains("anheb") || tip.actionHint.contains("oben"))
    }

    // MARK: - Board

    func testMissingBoardWarnsWithLateralPlacementAction() {
        var frame = Self.goodClassroomFrame()
        frame.boardRegionScore = 0.1
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: frame)
        )
        let tip = result.tips.first { $0.id == "board-missing" }
        guard let tip else { return XCTFail("Expected board-missing guidance") }
        XCTAssertEqual(tip.category, .blackboard)
        XCTAssertEqual(tip.severity, .warning)
        XCTAssertTrue(tip.actionHint.localizedCaseInsensitiveContains("seitlich") || tip.actionHint.contains("Tafel"))
        // A failed board signal must prevent direct-signal recording readiness.
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        XCTAssertFalse(result.placement.directSignalsPass)
        let boardDim = result.placement.dimensions.first { $0.id == "board" }
        XCTAssertEqual(boardDim?.ok, false)
    }

    func testSingleFailedDimensionNeverPassesDirectSignalReadiness() {
        // Each case breaks one direct capture dimension; the rest match goodClassroomFrame.
        struct Case {
            var name: String
            var mutate: (inout OrientationSample, inout FrameMetrics) -> Void
            var dimensionId: String
        }
        let cases: [Case] = [
            Case(name: "roll", mutate: { o, _ in o.pitchDegrees = 0; o.rollDegrees = 8 }, dimensionId: "horizon"),
            Case(name: "board", mutate: { _, f in f.boardRegionScore = 0.1 }, dimensionId: "board"),
            Case(name: "backlight", mutate: { _, f in f.backlightScore = 0.5 }, dimensionId: "light"),
            Case(name: "ceiling", mutate: { _, f in f.ceilingFraction = 0.30 }, dimensionId: "ceiling"),
            Case(name: "floor", mutate: { _, f in f.floorFraction = 0.32 }, dimensionId: "floor"),
            Case(name: "composition", mutate: { _, f in f.emptyEdgeFraction = 0.45 }, dimensionId: "composition"),
        ]
        for c in cases {
            var o = OrientationSample(pitchDegrees: 1, rollDegrees: 1)
            var f = Self.goodClassroomFrame()
            c.mutate(&o, &f)
            let result = engine.evaluate(experimentalGuidanceInput(orientation: o, frame: f))
            XCTAssertNotEqual(
                result.placement.quality,
                .directSignalsPass,
                "\(c.name): single-dimension defect must not pass; tips=\(result.tips.map(\.id))"
            )
            XCTAssertFalse(
                result.placement.directSignalsPass,
                "\(c.name): directSignalsPass must be false"
            )
            if let dim = result.placement.dimensions.first(where: { $0.id == c.dimensionId }) {
                XCTAssertFalse(dim.ok, "\(c.name): dimension \(c.dimensionId) should be !ok")
            }
        }
    }

}
