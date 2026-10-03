import Foundation
@testable import GuidanceEngine
import XCTest

// Public API only, so these can move to GuidanceEngineTests by changing the imports.
final class AudioReadinessCharacterizationTests: XCTestCase {
    private let evaluator = AudioReadinessEvaluator.default

    func testDefaultThresholdsAreFrozen() {
        XCTAssertEqual(evaluator.silentMax, 0.02)
        XCTAssertEqual(evaluator.lowMax, 0.08)
        XCTAssertEqual(evaluator.goodMax, 0.55)
        XCTAssertEqual(evaluator.hotMax, 0.85)
        XCTAssertEqual(AudioStatus.silent.rawValue, "silent")
        XCTAssertEqual(
            [AudioStatus.silent, .low, .good, .hot, .clipping, .dropout].map(\.rawValue),
            ["silent", "low", "good", "hot", "clipping", "dropout"]
        )
    }

    func testLevelStatusBranchesAtThresholdBoundaries() {
        let cases: [(level: Double, status: AudioStatus, ready: Bool)] = [
            (0, .silent, false), (0.02, .silent, false),
            (0.0201, .low, false), (0.08, .low, false),
            (0.0801, .good, true), (0.55, .good, true),
            (0.5501, .hot, true), (0.85, .hot, true),
            (0.8501, .hot, false), (1, .hot, false)
        ]
        for item in cases {
            let guidance = evaluator.evaluate(sample(peak: item.level, average: 0))
            XCTAssertEqual(guidance.status, item.status, "peak \(item.level)")
            XCTAssertEqual(guidance.isReady, item.ready, "peak \(item.level)")
            // The level is max(peak, average), so the average alone must classify identically.
            let viaAverage = evaluator.evaluate(sample(peak: 0, average: item.level))
            XCTAssertEqual(viaAverage, guidance, "average \(item.level)")
        }
    }

    func testGuidanceCopyPerStatus() {
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.01, average: 0.01)), AudioGuidance(
            status: .silent, message: "Sehr niedriger gemessener Audiopegel.",
            actionHint: "Mikrofonroute prüfen und eine kurze Aufnahme abhören.", isReady: false
        ))
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.01, average: 0.01, external: true)).actionHint,
                       "Pegel am externen Mikrofon / Interface prüfen.")
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.05, average: 0.05)), AudioGuidance(
            status: .low,
            message: "Gemessener Audiopegel liegt unter dem konfigurierten Arbeitsbereich.",
            actionHint: "Route, Abstand und Gain prüfen; anschließend eine kurze Aufnahme abhören.",
            isReady: false
        ))
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.3, average: 0.3)), AudioGuidance(
            status: .good,
            message: "Audiopegel im konfigurierten Arbeitsbereich. Internes Mikrofon aktiv - externes Audio bleibt empfehlenswert.",
            actionHint: "Die Verständlichkeit wird nicht gemessen; eine kurze Aufnahme abhören.",
            isReady: true
        ))
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.3, average: 0.3, external: true)).message,
                       "Audiopegel im konfigurierten Arbeitsbereich.")
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.7, average: 0.7)), AudioGuidance(
            status: .hot, message: "Audiopegel hoch - Gefahr von Verzerrung bei Lautstärkespitzen.",
            actionHint: "Gain etwas reduzieren.", isReady: true
        ))
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.9, average: 0.9)), AudioGuidance(
            status: .hot,
            message: "Sehr hoher Audiopegel; ohne PCM-Vollaussteuerung ist digitales Clipping nicht belegt.",
            actionHint: "Gain reduzieren und eine kurze Aufnahme abhören.", isReady: false
        ))
    }

    func testClippingAndDropoutOverrideLevelAndDropoutWins() {
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.3, average: 0.3, clipping: 0.001)), AudioGuidance(
            status: .clipping, message: "Digitale Vollaussteuerung in PCM-Samples erkannt.",
            actionHint: "Pegel reduzieren und eine kurze Aufnahme abhören.", isReady: false
        ))
        // A zero clipping fraction is evidence of no clipping and does not trigger the branch.
        XCTAssertEqual(evaluator.evaluate(sample(peak: 0.3, average: 0.3, clipping: 0)).status, .good)
        let dropout = evaluator.evaluate(sample(peak: 0.3, average: 0.3, clipping: 0.5, dropout: true))
        XCTAssertEqual(dropout, AudioGuidance(
            status: .dropout, message: "Zeitstempel-Lücke im Audiosignal erkannt.",
            actionHint: "Audioroute und Kabel prüfen; eine kurze Aufnahme abhören.", isReady: false
        ))
    }

    func testCustomThresholdsMoveTheBoundaries() {
        let custom = AudioReadinessEvaluator(silentMax: 0.1, lowMax: 0.2, goodMax: 0.3, hotMax: 0.4)
        XCTAssertEqual(custom.evaluate(sample(peak: 0.1, average: 0)).status, .silent)
        XCTAssertEqual(custom.evaluate(sample(peak: 0.2, average: 0)).status, .low)
        XCTAssertEqual(custom.evaluate(sample(peak: 0.3, average: 0)).status, .good)
        XCTAssertEqual(custom.evaluate(sample(peak: 0.4, average: 0)).isReady, true)
        XCTAssertEqual(custom.evaluate(sample(peak: 0.41, average: 0)).isReady, false)
    }

    func testAudioLevelSampleClampsAndSanitizesInputs() {
        var values = AudioLevelSample.Values()
        values.peakLevel = 1.5
        values.averageLevel = -0.5
        values.clippingFraction = 2
        values.channelCount = 0
        values.sampleRate = -44_100
        values.baselineLevelEstimate = 3
        let clamped = AudioLevelSample(values)
        XCTAssertEqual(clamped.peakLevel, 1)
        XCTAssertEqual(clamped.averageLevel, 0)
        XCTAssertEqual(clamped.clippingFraction, 1)
        XCTAssertEqual(clamped.channelCount, 1)
        XCTAssertNil(clamped.sampleRate)
        XCTAssertEqual(clamped.baselineLevelEstimate, 1)
        values.sampleRate = .nan
        XCTAssertNil(AudioLevelSample(values).sampleRate)
        values.sampleRate = 48_000
        XCTAssertEqual(AudioLevelSample(values).sampleRate, 48_000)
    }

    func testPCMLevelMetricsForEachSampleFormat() {
        let floats = PCMLevelMeter.metrics(data: bytes([Float32](arrayLiteral: 0, 0.5, -1, 0.25)), format: .float32)
        XCTAssertEqual(floats, PCMLevelMetrics(peak: 1, average: 0.4375, clippedSampleFraction: 0.25, sampleCount: 4))

        // Interleaved stereo: per-frame maximum across channels, clipping counted per sample.
        let stereo = PCMLevelMeter.metrics(
            data: bytes([Float32](arrayLiteral: 0.5, 0.25, 1, 0)), format: .float32, channels: 2
        )
        XCTAssertEqual(stereo, PCMLevelMetrics(peak: 1, average: 0.75, clippedSampleFraction: 0.25, sampleCount: 4))

        let ints = PCMLevelMeter.metrics(data: bytes([Int16](arrayLiteral: 0, 16_384)), format: .int16)
        XCTAssertEqual(ints.peak, 16_384.0 / 32_767.0, accuracy: 1e-12)
        XCTAssertEqual(ints.average, 8_192.0 / 32_767.0, accuracy: 1e-12)
        XCTAssertEqual(ints.clippedSampleFraction, 0)
        XCTAssertEqual(ints.sampleCount, 2)

        let wide = PCMLevelMeter.metrics(data: bytes([Int32](arrayLiteral: Int32.max, 0)), format: .int32)
        XCTAssertEqual(wide, PCMLevelMetrics(peak: 1, average: 0.5, clippedSampleFraction: 0.5, sampleCount: 2))

        let tuple = PCMLevelMeter.levels(data: bytes([Float32](arrayLiteral: 0.5)), format: .float32)
        XCTAssertEqual(tuple.peak, 0.5)
        XCTAssertEqual(tuple.average, 0.5)
        XCTAssertEqual(PCMLevelMeter.metrics(data: [], format: .int16), .empty)
        XCTAssertEqual(PCMLevelMeter.metrics(data: [1], format: .int16), .empty)
        XCTAssertEqual(
            PCMLevelMeter.metrics(data: bytes([Float32](arrayLiteral: .nan)), format: .float32).peak, 1
        )
    }

    // MARK: - FilmingGuidancePolicy

    func testPreRollFusesAudioAndVisualTipsByRankSeverityAndID() {
        let snapshot = FilmingGuidancePolicy().evaluate(
            visual: visualResult(tips: representativeVisualTips()),
            audioSample: sample(peak: 0.05, average: 0.05),
            isRecording: false
        )
        XCTAssertEqual(snapshot.phase, .preRoll)
        XCTAssertTrue(snapshot.liveUpdatesActive)
        XCTAssertEqual(snapshot.audio.status, .low)
        XCTAssertEqual(snapshot.rankedTips.map(\.id), [
            "backlight-1:active", "audio-low:active", "composition-1:active", "ok-1:active"
        ])
        XCTAssertEqual(snapshot.rankedTips.map(\.rank), [0, 10, 10, 50])
        XCTAssertEqual(snapshot.rankedTips.map(\.presentation), [.active, .active, .active, .active])
        XCTAssertEqual(snapshot.rankedTips.map(\.phaseNoteDE), [nil, nil, nil, nil])
        XCTAssertEqual(snapshot.rankedTips[1].tip, GuidanceTip((
            id: "audio-low", category: .general, severity: .warning,
            message: "Gemessener Audiopegel liegt unter dem konfigurierten Arbeitsbereich.",
            actionHint: "Route, Abstand und Gain prüfen; anschließend eine kurze Aufnahme abhören."
        )))
        XCTAssertEqual(snapshot.headlineDE, "Vor der Aufnahme: 1 kritische Punkte beheben.")
        XCTAssertEqual(snapshot.criticalCount, 1)
        XCTAssertEqual(snapshot.visibleTips.count, 4)
    }

    func testRecordingReclassifiesTipsAndSuppressesPureOK() {
        let snapshot = FilmingGuidancePolicy().evaluate(
            visual: visualResult(tips: representativeVisualTips()),
            audioSample: sample(peak: 0.05, average: 0.05),
            isRecording: true
        )
        XCTAssertEqual(snapshot.phase, .recording)
        XCTAssertEqual(snapshot.rankedTips.map(\.id), [
            "backlight-1:active", "audio-low:active", "composition-1:postTakeNote", "ok-1:suppressed"
        ])
        XCTAssertEqual(snapshot.rankedTips.map(\.rank), [0, 10, 50, 90])
        XCTAssertEqual(snapshot.rankedTips.map(\.phaseNoteDE), [
            "Während der Aufnahme",
            "Während der Aufnahme · Audio",
            "Nach dem Take (kontinuierliche Aufnahme nicht unterbrechen)",
            nil
        ])
        XCTAssertEqual(
            snapshot.rankedTips[0].tip.actionHint,
            "Belichtung nicht wild ändern; Take fortsetzen, Standort beim nächsten Take wechseln."
        )
        XCTAssertEqual(
            snapshot.rankedTips[1].tip.actionHint,
            "Gain leicht erhöhen, wenn möglich ohne den Take zu stoppen."
        )
        XCTAssertEqual(snapshot.rankedTips[2].tip.actionHint, "Nach dem Take prüfen: Bild ausrichten")
        XCTAssertEqual(snapshot.visibleTips.map(\.tip.id), ["backlight-1", "audio-low", "composition-1"])
        XCTAssertEqual(snapshot.criticalCount, 1)
        XCTAssertEqual(snapshot.headlineDE, "Aufnahme läuft - 1 kritische Hinweise (Take möglichst fortsetzen).")
    }

    func testReadyAudioWithoutVisualTipsProducesNoTipsAndPhaseHeadlines() {
        let good = sample(peak: 0.3, average: 0.3)
        let preRoll = FilmingGuidancePolicy().evaluate(visual: visualResult(tips: []), audioSample: good, isRecording: false)
        XCTAssertTrue(preRoll.rankedTips.isEmpty)
        XCTAssertEqual(
            preRoll.headlineDE,
            "Pre-Roll: Bild, Lage und Audio prüfen - dann kontinuierliche Aufnahme starten."
        )
        let recording = FilmingGuidancePolicy().evaluate(visual: visualResult(tips: []), audioSample: good, isRecording: true)
        XCTAssertEqual(recording.headlineDE, "Aufnahme läuft - Live-Überwachung aktiv (kontinuierlicher Take).")

        let notReady = FilmingGuidancePolicy().evaluate(
            visual: visualResult(tips: []), audioSample: sample(peak: 0.9, average: 0), isRecording: false
        )
        XCTAssertEqual(notReady.headlineDE, "Vor der Aufnahme: Audio pegelein.")
    }

    func testAudioTipSeverityAndMidTakeActionPerStatus() {
        let policy = FilmingGuidancePolicy()
        let expected: [(AudioLevelSample, String, GuidanceSeverity, String)] = [
            (sample(peak: 0.01, average: 0), "audio-silent", .critical,
             "Sofort Pegel/Mikrofon prüfen - ohne Audio fehlt das Audiosignal der Sequenz."),
            (sample(peak: 0.3, average: 0.3, clipping: 0.1), "audio-clipping", .critical,
             "Sofort Pegel/Mikrofon prüfen - ohne Audio fehlt das Audiosignal der Sequenz."),
            (sample(peak: 0.3, average: 0.3, dropout: true), "audio-dropout", .info,
             "Sofort Pegel/Mikrofon prüfen - ohne Audio fehlt das Audiosignal der Sequenz."),
            (sample(peak: 0.7, average: 0.7), "audio-hot", .info, "Gain leicht senken bei Spitzen.")
        ]
        for (audio, id, severity, action) in expected {
            let snapshot = policy.evaluate(visual: visualResult(tips: []), audioSample: audio, isRecording: true)
            XCTAssertEqual(snapshot.rankedTips.map(\.tip.id), [id])
            XCTAssertEqual(snapshot.rankedTips.first?.tip.severity, severity, id)
            XCTAssertEqual(snapshot.rankedTips.first?.tip.actionHint, action, id)
        }
    }

    // MARK: - Helpers

    private func sample(
        peak: Double,
        average: Double,
        external: Bool = false,
        clipping: Double? = nil,
        dropout: Bool = false
    ) -> AudioLevelSample {
        var values = AudioLevelSample.Values()
        values.peakLevel = peak
        values.averageLevel = average
        values.externalMicIndicated = external
        values.clippingFraction = clipping
        values.dropoutDetected = dropout
        values.timestamp = Date(timeIntervalSince1970: 0)
        return AudioLevelSample(values)
    }

    private func bytes<T>(_ values: [T]) -> [UInt8] {
        values.withUnsafeBytes { Array($0) }
    }

    private func representativeVisualTips() -> [GuidanceTip] {
        [
            GuidanceTip((id: "ok-1", category: .composition, severity: .ok, message: "Bild passt", actionHint: "Nichts tun")),
            GuidanceTip((id: "composition-1", category: .composition, severity: .warning,
                         message: "Bildausschnitt schief", actionHint: "Bild ausrichten")),
            GuidanceTip((id: "backlight-1", category: .backlight, severity: .critical,
                         message: "Gegenlicht", actionHint: "Standort wechseln"))
        ]
    }

    private func visualResult(tips: [GuidanceTip]) -> GuidanceResult {
        let frame = FrameMetrics(FrameMetrics.Values())
        let orientation = OrientationSample(pitchDegrees: 0, rollDegrees: 0)
        return GuidanceResult(GuidanceResult.Values(
            tips: tips,
            placement: PlacementAssessment.assess(.init(orientation: orientation, frame: frame))
        ))
    }
}
