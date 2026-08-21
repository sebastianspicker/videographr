import XCTest
@testable import GuidanceEngine

final class GuidanceSafetyTests: XCTestCase {
    func testDirectSignalFailureCannotEnableRecording() {
        var frame = FrameMetrics.Values()
        frame.averageLuminance = 0.48
        frame.topBandLuminance = 0.55
        frame.bottomBandLuminance = 0.4
        frame.leftBandLuminance = 0.45
        frame.rightBandLuminance = 0.43
        frame.boardRegionScore = 0.1
        frame.boardCenterY = 0.38
        frame.boardCenterX = 0.5
        frame.ceilingFraction = 0.12
        frame.floorFraction = 0.12
        frame.backlightScore = 0.1
        frame.horizontalBrightnessImbalance = 0.05
        frame.emptyEdgeFraction = 0.15
        frame.globalContrast = 0.4
        frame.midBandVariance = 0.03
        frame.edgeEnergy = 0.1
        frame.clippedHighlightFraction = 0.02
        frame.clippedShadowFraction = 0.02
        frame.brightnessCenterY = 0.48
        let input = GuidanceInput(.init(
            orientation: .init(pitchDegrees: 1, rollDegrees: 1),
            frame: FrameMetrics(frame)
        ))
        let result = GuidanceEngine().evaluate(input)
        XCTAssertFalse(result.placement.directSignalsPass)
        XCTAssertFalse(result.isReadyToRecord)
    }
}
