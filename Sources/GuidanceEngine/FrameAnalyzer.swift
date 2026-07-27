import Foundation

/// Builds `FrameMetrics` from raw luminance samples (testable without Vision/AVFoundation).
/// Production path: convert a video frame to a downscaled grayscale buffer and call `analyze`.
public struct FrameAnalyzer: Sendable {
    public struct SyntheticClassroomConfiguration: Sendable {
        public var width = 64
        public var height = 48
        public var boardDarkness = 0.25
        public var boardRect: (x: Double, y: Double, width: Double, height: Double) = (
            0.2,
            0.25,
            0.6,
            0.35
        )
        public var ceilingBrightness = 0.8
        public var ceilingHeightFraction = 0.15
        public var windowSide: WindowSide?
        public var windowBrightness = 0.95
        public var baseLuminance = 0.45
        public var floorDarkness: Double?
        public var floorHeightFraction = 0.12

        public init() {}
    }

    public init() {}

    /// Analyze a row-major grayscale buffer (values 0...1), width × height.
    public func analyze(luminance: [Double], width: Int, height: Int) -> FrameMetrics {
        precondition(width > 0 && height > 0)
        precondition(luminance.count == width * height)
        let frame = FrameLuminanceBuffer(values: luminance, width: width, height: height)
        let regions = FrameRegionMetrics.measure(frame)
        let board = FrameBoardLocation.measure(frame, regions: regions)
        let exposure = FrameExposureMetrics.measure(frame, regions: regions)

        var values = FrameMetrics.Values()
        values.apply(regions: regions)
        values.apply(board: board)
        values.apply(exposure: exposure)
        return FrameMetrics(values)
    }

    public static func syntheticClassroom(
        _ configuration: SyntheticClassroomConfiguration = SyntheticClassroomConfiguration()
    ) -> (buffer: [Double], width: Int, height: Int) {
        var buffer = Array(
            repeating: configuration.baseLuminance,
            count: configuration.width * configuration.height
        )
        applyCeiling(to: &buffer, configuration: configuration)
        applyFloor(to: &buffer, configuration: configuration)
        applyBoard(to: &buffer, configuration: configuration)
        applyWindow(to: &buffer, configuration: configuration)
        return (buffer, configuration.width, configuration.height)
    }

    private static func applyCeiling(
        to buffer: inout [Double],
        configuration: SyntheticClassroomConfiguration
    ) {
        let ceilingRows = Int(Double(configuration.height) * configuration.ceilingHeightFraction)
        for y in 0..<ceilingRows {
            for x in 0..<configuration.width {
                buffer[y * configuration.width + x] = configuration.ceilingBrightness
            }
        }
    }

    private static func applyFloor(
        to buffer: inout [Double],
        configuration: SyntheticClassroomConfiguration
    ) {
        guard let floorDarkness = configuration.floorDarkness else { return }
        let floorRows = Int(Double(configuration.height) * configuration.floorHeightFraction)
        for y in (configuration.height - floorRows)..<configuration.height {
            for x in 0..<configuration.width {
                buffer[y * configuration.width + x] = floorDarkness
            }
        }
    }

    private static func applyBoard(
        to buffer: inout [Double],
        configuration: SyntheticClassroomConfiguration
    ) {
        let board = configuration.boardRect
        let x = Int(board.x * Double(configuration.width))
        let y = Int(board.y * Double(configuration.height))
        let width = Int(board.width * Double(configuration.width))
        let height = Int(board.height * Double(configuration.height))
        for row in y..<min(configuration.height, y + height) {
            for column in x..<min(configuration.width, x + width) {
                buffer[row * configuration.width + column] = configuration.boardDarkness
            }
        }
    }

    private static func applyWindow(
        to buffer: inout [Double],
        configuration: SyntheticClassroomConfiguration
    ) {
        guard let windowSide = configuration.windowSide else { return }
        let width = max(1, configuration.width / 8)
        let startX = windowSide == .left ? 0 : configuration.width - width
        for y in 0..<configuration.height {
            for x in startX..<(startX + width) {
                buffer[y * configuration.width + x] = configuration.windowBrightness
            }
        }
    }

    public enum WindowSide: Sendable {
        case left, right
    }
}

private extension FrameMetrics.Values {
    mutating func apply(regions: FrameRegionMetrics) {
        averageLuminance = regions.average
        topBandLuminance = regions.topBand
        bottomBandLuminance = regions.bottomBand
        leftBandLuminance = regions.leftBand
        rightBandLuminance = regions.rightBand
        boardRegionScore = regions.boardScore
        backlightScore = regions.backlightScore
        horizontalBrightnessImbalance = regions.horizontalImbalance
        emptyEdgeFraction = regions.emptyEdgeFraction
    }

    mutating func apply(board: FrameBoardLocation) {
        boardCenterY = board.centerY
        boardCenterX = board.centerX
    }

    mutating func apply(exposure: FrameExposureMetrics) {
        ceilingFraction = exposure.ceilingFraction
        floorFraction = exposure.floorFraction
        globalContrast = exposure.globalContrast
        midBandVariance = exposure.midBandVariance
        edgeEnergy = exposure.edgeEnergy
        clippedHighlightFraction = exposure.clippedHighlightFraction
        clippedShadowFraction = exposure.clippedShadowFraction
        brightnessCenterY = exposure.brightnessCenterY
    }
}
