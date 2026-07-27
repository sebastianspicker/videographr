import XCTest
@testable import GuidanceEngine

extension GuidanceEngineTests {
    func testRecordingReadinessRequiresAllDirectSignalDimensionsAndNoWarnings() {
        let good = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 1, rollDegrees: 1), frame: Self.goodClassroomFrame())
        )
        XCTAssertEqual(good.placement.quality, .directSignalsPass)
        XCTAssertTrue(good.placement.dimensions.allSatisfy(\.ok))
        XCTAssertFalse(good.tips.contains { $0.severity >= .warning })
        XCTAssertTrue(good.isReadyToRecord)
    }

    func testBoardTooHighInFrame() {
        var frame = Self.goodClassroomFrame()
        frame.boardRegionScore = 0.8
        frame.boardCenterY = 0.15
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: frame)
        )
        XCTAssertTrue(result.tips.contains { $0.id == "board-too-high" })
        guard let tip = result.tips.first(where: { $0.id == "board-too-high" }) else {
            return XCTFail("Expected board-too-high guidance")
        }
        XCTAssertFalse(tip.actionHint.isEmpty)
    }

    // MARK: - Backlight

    func testContreJourCritical() {
        var frame = Self.goodClassroomFrame()
        frame.backlightScore = 0.85
        frame.leftBandLuminance = 0.95
        frame.averageLuminance = 0.4
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: frame)
        )
        let tip = result.tips.first { $0.id == "backlight-critical" }
        guard let tip else { return XCTFail("Expected backlight-critical guidance") }
        XCTAssertEqual(tip.severity, .critical)
        XCTAssertEqual(tip.category, .backlight)
        XCTAssertTrue(tip.message.localizedCaseInsensitiveContains("gegenlicht"))
        XCTAssertTrue(
            tip.actionHint.localizedCaseInsensitiveContains("fenster")
                || tip.actionHint.localizedCaseInsensitiveContains("standort")
        )
        XCTAssertEqual(result.placement.quality, .defective)
    }

    // MARK: - Interaction zone & good placement

    func testWeakInteractionZoneWarns() {
        var frame = Self.goodClassroomFrame()
        frame.boardRegionScore = 0.05
        frame.ceilingFraction = 0.35
        frame.floorFraction = 0.35
        frame.emptyEdgeFraction = 0.5
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 8, rollDegrees: 0), frame: frame)
        )
        XCTAssertTrue(
            result.tips.contains { $0.category == .interaction },
            "tips=\(result.tips.map(\.id))"
        )
        guard let tip = result.tips.first(where: { $0.category == .interaction }) else {
            return XCTFail("Expected interaction guidance")
        }
        XCTAssertFalse(tip.actionHint.isEmpty)
    }

    func testGoodClassroomPlacementSupportsRecordingReadiness() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: OrientationSample(pitchDegrees: 1, rollDegrees: 1),
                frame: Self.goodClassroomFrame()
            )
        )
        XCTAssertLessThanOrEqual(result.overallSeverity, .warning)
        XCTAssertNotEqual(result.placement.quality, .defective)
        XCTAssertGreaterThanOrEqual(result.placement.score, 0.7)
        XCTAssertTrue(result.placement.dimensions.count >= 6)
        // All critical direct-signal dimensions should be OK.
        for id in ["horizon", "light", "board"] {
            let dim = result.placement.dimensions.first { $0.id == id }
            XCTAssertEqual(dim?.ok, true, "dimension \(id) should be ok")
        }
        XCTAssertTrue(result.isReadyToRecord || result.placement.quality == .needsAdjustment)
    }

    func testPlacementAssessmentDimensionsCoverDirectSignalConcerns() {
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: Self.goodClassroomFrame())
        )
        let ids = Set(result.placement.dimensions.map(\.id))
        for needed in ["horizon", "pitch", "ceiling", "floor", "board", "light", "interaction", "composition"] {
            XCTAssertTrue(ids.contains(needed), "missing dimension \(needed)")
        }
    }

    // MARK: - Frame analyzer path

    func testAnalyzerAgainstLightSyntheticClassroom() {
        let analyzer = FrameAnalyzer()
        var configuration = FrameAnalyzer.SyntheticClassroomConfiguration()
        configuration.boardDarkness = 0.2
        configuration.ceilingBrightness = 0.55
        configuration.ceilingHeightFraction = 0.1
        configuration.windowSide = .left
        configuration.windowBrightness = 0.98
        configuration.baseLuminance = 0.35
        let synthetic = FrameAnalyzer.syntheticClassroom(configuration)
        let metrics = analyzer.analyze(
            luminance: synthetic.buffer,
            width: synthetic.width,
            height: synthetic.height
        )
        XCTAssertGreaterThan(metrics.leftBandLuminance, metrics.rightBandLuminance)
        XCTAssertGreaterThan(metrics.backlightScore, 0.3)

        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: OrientationSample(pitchDegrees: 0, rollDegrees: 0),
                frame: metrics
            )
        )
        let categories = Set(result.tips.map(\.category))
        XCTAssertTrue(
            categories.contains(.backlight) || result.tips.contains { $0.id.contains("backlight") || $0.id.contains("window") },
            "Expected backlight guidance, got: \(result.tips.map(\.id))"
        )
    }

    func testAnalyzerExcessCeiling() {
        let analyzer = FrameAnalyzer()
        var configuration = FrameAnalyzer.SyntheticClassroomConfiguration()
        configuration.ceilingBrightness = 0.95
        configuration.ceilingHeightFraction = 0.45
        configuration.windowSide = nil
        configuration.baseLuminance = 0.4
        let synthetic = FrameAnalyzer.syntheticClassroom(configuration)
        let metrics = analyzer.analyze(
            luminance: synthetic.buffer,
            width: synthetic.width,
            height: synthetic.height
        )
        XCTAssertGreaterThan(metrics.ceilingFraction, 0.35)
        let result = engine.evaluate(
            experimentalGuidanceInput(orientation: .init(pitchDegrees: 8, rollDegrees: 0), frame: metrics)
        )
        XCTAssertTrue(
            result.tips.contains { $0.category == .ceiling || $0.id.contains("pitch-up") },
            "Expected ceiling/pitch guidance, tips=\(result.tips.map(\.id))"
        )
    }

    func testAnalyzerFindsBoardRegion() {
        let analyzer = FrameAnalyzer()
        var configuration = FrameAnalyzer.SyntheticClassroomConfiguration()
        configuration.boardDarkness = 0.15
        configuration.boardRect = (0.25, 0.3, 0.5, 0.3)
        configuration.ceilingHeightFraction = 0.08
        let synthetic = FrameAnalyzer.syntheticClassroom(configuration)
        let metrics = analyzer.analyze(
            luminance: synthetic.buffer,
            width: synthetic.width,
            height: synthetic.height
        )
        XCTAssertGreaterThan(metrics.boardRegionScore, 0.35)
        XCTAssertGreaterThan(metrics.boardCenterY, 0.2)
        XCTAssertLessThan(metrics.boardCenterY, 0.7)
    }

    func testReadyWhenSceneIsGood() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: OrientationSample(pitchDegrees: 1, rollDegrees: 1),
                frame: Self.goodClassroomFrame()
            )
        )
        XCTAssertTrue(
            result.isReadyToRecord || result.placement.quality != .defective,
            "tips=\(result.tips.map { "\($0.id):\($0.severity)" }) placement=\(result.placement.quality)"
        )
        XCTAssertLessThanOrEqual(result.overallSeverity, .warning)
    }

    // MARK: - Fixtures

    static func goodClassroomFrame() -> FrameMetrics {
        testFusionGoodFrame()
    }
}
