import XCTest
@testable import SessionCore

final class MediaMetadataNormalizerTests: XCTestCase {
    func testDurationConversionPreservesRoundingAndRejectsInvalidRanges() {
        XCTAssertEqual(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: 1.234), 1_234)
        XCTAssertEqual(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: 0.0001), 0)
        XCTAssertNil(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: 0))
        XCTAssertNil(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: .infinity))
        XCTAssertNil(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: .nan))
        XCTAssertNil(MediaMetadataNormalizer.durationMilliseconds(fromSeconds: Double(Int64.max)))
    }

    func testPixelDimensionPreservesMagnitudeAndTruncationAndRejectsInvalidRanges() {
        XCTAssertEqual(MediaMetadataNormalizer.pixelDimension(from: -1_920.9), 1_920)
        XCTAssertEqual(MediaMetadataNormalizer.pixelDimension(from: 0.5), 0)
        XCTAssertNil(MediaMetadataNormalizer.pixelDimension(from: 0))
        XCTAssertNil(MediaMetadataNormalizer.pixelDimension(from: .infinity))
        XCTAssertNil(MediaMetadataNormalizer.pixelDimension(from: -.infinity))
        XCTAssertNil(MediaMetadataNormalizer.pixelDimension(from: .nan))
        XCTAssertNil(MediaMetadataNormalizer.pixelDimension(from: Double.greatestFiniteMagnitude))
    }
}
