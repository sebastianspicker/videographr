import Foundation
import GuidanceEngine

extension CaptureObservation {
    public static let directSignalsNote = "Direkte Aufnahmesignale; keine pädagogische Bewertung."

    /// Direct observability values plus audio meter facts; unavailable dimensions are omitted.
    public static func directMeasurements(guidance: GuidanceResult, audio: AudioLevelSample) -> [String: Double] {
        let dimensions = guidance.observability.dimensions
        var measurements = Dictionary(uniqueKeysWithValues: dimensions.compactMap { dimension in
            dimension.value.map { (dimension.id, $0) }
        })
        measurements["audioPeak"] = audio.peakLevel
        measurements["audioAverage"] = audio.averageLevel
        measurements.merge(optionalAudioMeasurements(audio), uniquingKeysWith: { _, replacement in replacement })
        measurements["audioDropoutDetected"] = audio.dropoutDetected ? 1 : 0
        return measurements
    }

    /// Audio-only measurements attached to operational (non-periodic) observations.
    public static func operationalMeasurements(audio: AudioLevelSample) -> [String: Double] {
        [
            "audioPeak": audio.peakLevel,
            "audioAverage": audio.averageLevel,
            "audioDropoutDetected": audio.dropoutDetected ? 1 : 0
        ]
    }

    /// `nil` when every observability dimension is available.
    public static func unavailableReason(guidance: GuidanceResult) -> String? {
        let unavailable = guidance.observability.dimensions.filter { $0.status == .unavailable }.map(\.id)
        return unavailable.isEmpty ? nil : "Nicht verfügbar: \(unavailable.sorted().joined(separator: ", "))"
    }

    private static func optionalAudioMeasurements(_ audio: AudioLevelSample) -> [String: Double] {
        var measurements: [String: Double] = [:]
        if let value = audio.clippingFraction { measurements["audioClippingFraction"] = value }
        if let value = audio.channelCount { measurements["audioChannelCount"] = Double(value) }
        if let value = audio.sampleRate { measurements["audioSampleRate"] = value }
        if let value = audio.baselineLevelEstimate { measurements["audioBaselineEstimate"] = value }
        return measurements
    }
}
