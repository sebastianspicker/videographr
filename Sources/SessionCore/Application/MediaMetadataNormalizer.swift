import Foundation

/// Pure conversion boundary for scalar metadata returned by platform media parsers.
public enum MediaMetadataNormalizer {
    public static func durationMilliseconds(fromSeconds seconds: Double) -> Int64? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        return Int64(exactly: (seconds * 1_000).rounded())
    }

    public static func pixelDimension(from value: Double) -> Int? {
        let magnitude = abs(value)
        guard magnitude.isFinite, magnitude > 0 else { return nil }
        return Int(exactly: magnitude.rounded(.towardZero))
    }
}
