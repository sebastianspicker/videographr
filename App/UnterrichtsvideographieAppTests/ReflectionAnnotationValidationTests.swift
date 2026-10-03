import XCTest

@testable import Unterrichtsvideographie

final class ReflectionAnnotationValidationTests: XCTestCase {
    func testTimecodeParserProducesMillisecondsForValidMinuteSecondInput() throws {
        XCTAssertEqual(try ReflectionAnnotationTimecode.parse("02:14").get(), 134_000)
        XCTAssertEqual(try ReflectionAnnotationTimecode.parse("0:00").get(), 0)
    }

    func testTimecodeParserRejectsInvalidSecondsAndOverflow() {
        XCTAssertEqual(
            ReflectionAnnotationTimecode.parse("02:60"),
            .failure(.invalidFormat)
        )
        XCTAssertEqual(
            ReflectionAnnotationTimecode.parse("999999999999999999:00"),
            .failure(.outOfRange)
        )
    }
}
