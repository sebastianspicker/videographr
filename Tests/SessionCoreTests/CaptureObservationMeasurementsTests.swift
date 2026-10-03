import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

final class CaptureObservationMeasurementsTests: XCTestCase {
    func testDirectMeasurementsKeyNamesWithAllOptionalAudioFacts() {
        var audioValues = AudioLevelSample.Values()
        audioValues.peakLevel = 0.8
        audioValues.averageLevel = 0.2
        audioValues.clippingFraction = 0.01
        audioValues.channelCount = 2
        audioValues.sampleRate = 48_000
        audioValues.baselineLevelEstimate = 0.05
        audioValues.dropoutDetected = true
        let measurements = CaptureObservation.directMeasurements(
            guidance: guidance([("brightness", .pass, 0.6), ("blur", .unavailable, nil)]),
            audio: AudioLevelSample(audioValues)
        )
        XCTAssertEqual(Set(measurements.keys), [
            "brightness", "audioPeak", "audioAverage", "audioClippingFraction",
            "audioChannelCount", "audioSampleRate", "audioBaselineEstimate", "audioDropoutDetected"
        ])
        XCTAssertEqual(measurements["brightness"], 0.6)
        XCTAssertEqual(measurements["audioChannelCount"], 2)
        XCTAssertEqual(measurements["audioDropoutDetected"], 1)
    }

    func testDirectMeasurementsOmitMissingOptionalAudioFacts() {
        let measurements = CaptureObservation.directMeasurements(
            guidance: guidance([]), audio: AudioLevelSample(AudioLevelSample.Values())
        )
        XCTAssertEqual(Set(measurements.keys), ["audioPeak", "audioAverage", "audioDropoutDetected"])
        XCTAssertEqual(measurements["audioDropoutDetected"], 0)
    }

    func testOperationalMeasurementsKeyNames() {
        var values = AudioLevelSample.Values()
        values.peakLevel = 0.5
        values.averageLevel = 0.25
        let measurements = CaptureObservation.operationalMeasurements(audio: AudioLevelSample(values))
        XCTAssertEqual(measurements, ["audioPeak": 0.5, "audioAverage": 0.25, "audioDropoutDetected": 0])
    }

    func testUnavailableReasonAndNote() {
        XCTAssertNil(CaptureObservation.unavailableReason(guidance: guidance([("a", .pass, 1)])))
        XCTAssertEqual(
            CaptureObservation.unavailableReason(guidance: guidance([("zeta", .unavailable, nil), ("alpha", .unavailable, nil), ("m", .warn, 0.4)])),
            "Nicht verfügbar: alpha, zeta"
        )
        XCTAssertEqual(CaptureObservation.directSignalsNote, "Direkte Aufnahmesignale; keine pädagogische Bewertung.")
    }

    private func guidance(_ rows: [(String, CaptureObservabilityDimension.Status, Double?)]) -> GuidanceResult {
        var result = GuidanceResult(tips: [])
        result.observability = CaptureObservabilityAssessment(dimensions: rows.map { id, status, value in
            var values = CaptureObservabilityDimension.Values(id: id, labelDE: id, status: status)
            values.value = value
            return CaptureObservabilityDimension(values)
        })
        return result
    }
}
