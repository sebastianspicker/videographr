import Foundation
import XCTest
@testable import SessionCore

final class CaptureRuntimeStatusTests: XCTestCase {
    func testDefaultsMatchPersistedStrings() {
        let status = CaptureRuntimeStatus()
        XCTAssertEqual(status.videoConfiguration, "Noch nicht ausgehandelt")
        XCTAssertEqual(status.audioRoute, "Keine Audioroute")
        XCTAssertEqual(status.thermalState, "unbekannt")
        XCTAssertNil(status.batteryPercent)
        XCTAssertNil(status.availableCapacityBytes)
        XCTAssertFalse(status.spokenAudioCheckCompleted)
        XCTAssertFalse(status.hasResourceWarning)
    }

    func testBatteryWarningBoundary() {
        XCTAssertTrue(CaptureRuntimeStatus(batteryPercent: 15).hasResourceWarning)
        XCTAssertFalse(CaptureRuntimeStatus(batteryPercent: 16).hasResourceWarning)
    }

    func testThermalWarningStates() {
        XCTAssertTrue(CaptureRuntimeStatus(thermalState: "ernst").hasResourceWarning)
        XCTAssertTrue(CaptureRuntimeStatus(thermalState: "kritisch").hasResourceWarning)
        XCTAssertFalse(CaptureRuntimeStatus(thermalState: "erhöht").hasResourceWarning)
        XCTAssertFalse(CaptureRuntimeStatus(thermalState: "normal").hasResourceWarning)
    }

    func testCapacityWarningBoundary() {
        XCTAssertTrue(CaptureRuntimeStatus(availableCapacityBytes: 499_999_999).hasResourceWarning)
        XCTAssertFalse(CaptureRuntimeStatus(availableCapacityBytes: 500_000_000).hasResourceWarning)
        XCTAssertFalse(CaptureRuntimeStatus(availableCapacityBytes: nil).hasResourceWarning)
    }

    func testMaximumFileSizeClampsPlannedDuration() {
        XCTAssertEqual(CaptureCapacity.estimatedBytesPerSecond, 1_500_000)
        XCTAssertEqual(CaptureCapacity.minimumFreeCapacityBytes, 500_000_000)
        let perMinute: Int64 = 60 * 1_500_000
        XCTAssertEqual(CaptureCapacity.maximumFileSize(forPlannedDurationMinutes: 0), perMinute)
        XCTAssertEqual(CaptureCapacity.maximumFileSize(forPlannedDurationMinutes: 1), perMinute)
        XCTAssertEqual(CaptureCapacity.maximumFileSize(forPlannedDurationMinutes: 240), 240 * perMinute)
        XCTAssertEqual(CaptureCapacity.maximumFileSize(forPlannedDurationMinutes: 241), 240 * perMinute)
    }

    func testNormalizedAudioRouteStrings() {
        XCTAssertEqual(CaptureCapacity.normalizedAudioRoute(portTypeRawValues: []), "Keine Audioroute")
        XCTAssertEqual(
            CaptureCapacity.normalizedAudioRoute(portTypeRawValues: ["MicrophoneBuiltIn", "MicrophoneBuiltIn"]),
            "Eingangstypen: MicrophoneBuiltIn · extern: nein"
        )
        XCTAssertEqual(
            CaptureCapacity.normalizedAudioRoute(portTypeRawValues: ["USBAudio", "MicrophoneBuiltIn", "USBAudio"]),
            "Eingangstypen: MicrophoneBuiltIn, USBAudio · extern: ja"
        )
    }
}
