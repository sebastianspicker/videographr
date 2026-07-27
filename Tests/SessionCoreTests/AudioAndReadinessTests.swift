import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif

extension SessionCoreTests {
    func testReadinessOverrideNeverPermitsMissingConsent() {
        let audio = AudioGuidance(status: .good, message: "fixture", actionHint: "fixture", isReady: true)
        let missingConsent = SessionReadiness({
    var values = SessionReadiness.Values()
    values.canRecord = false
    values.blockers = [.consentMissing, .visualCritical]
    values.visualSeverity = .critical
    values.audio = audio
    values.setupComplete = false
    values.summaryDE = "fixture"
    return values
}())
        let qualityOnly = SessionReadiness({
    var values = SessionReadiness.Values()
    values.canRecord = false
    values.blockers = [.visualCritical, .contextIncomplete]
    values.visualSeverity = .critical
    values.audio = audio
    values.setupComplete = false
    values.summaryDE = "fixture"
    return values
}())
        XCTAssertFalse(missingConsent.canOverrideQualityWarnings)
        XCTAssertTrue(qualityOnly.canOverrideQualityWarnings)
    }

    func testContextRequiresSubjectAndLessonGoal() {
        var ctx = SessionContext({
    var values = SessionContext.Values()
    values.subject = "Mathematik"
    values.lessonGoal = ""
    return values
}())
        XCTAssertFalse(ctx.isMinimallyComplete)
        ctx.lessonGoal = "Brüche multiplizieren"
        XCTAssertTrue(ctx.isMinimallyComplete)
    }

    func testSessionSetupCompleteCombinesTitleContextConsent() {
        var session = testSession { $0.title = "Stunde 3" }
        XCTAssertFalse(session.setupComplete)
        session = testReadySession()
        XCTAssertTrue(session.setupComplete)
    }

    // MARK: - Audio readiness (real evaluator)

    // MARK: - PCM level meter (int16 vs float32 - shipped path)

    func testPCMLevelMeterInt16FullScale() {
        // One mono sample at full scale Int16
        var sample = Int16.max
        let bytes = withUnsafeBytes(of: &sample) { Array($0) }
        let (peak, avg) = PCMLevelMeter.levels(data: bytes, format: .int16, channels: 1)
        XCTAssertEqual(peak, 1.0, accuracy: 0.001)
        XCTAssertEqual(avg, 1.0, accuracy: 0.001)
    }

    func testPCMLevelMeterFloat32DoesNotMisreadAsInt16() {
        // Three mono float frames - correct peak/avg only if samples are Float32-sized.
        let samples: [Float32] = [0.10, 0.80, 0.20]
        let floatBytes = samples.withUnsafeBufferPointer { buf in
            Array(UnsafeRawBufferPointer(buf))
        }
        XCTAssertEqual(floatBytes.count, 12)

        let (peakF, avgF) = PCMLevelMeter.levels(data: floatBytes, format: .float32, channels: 1)
        XCTAssertEqual(peakF, 0.80, accuracy: 0.001)
        XCTAssertEqual(avgF, (0.10 + 0.80 + 0.20) / 3.0, accuracy: 0.001)

        // Same bytes as Int16: 6 integer samples, not 3 floats - average cannot match.
        let (peakI, avgI) = PCMLevelMeter.levels(data: floatBytes, format: .int16, channels: 1)
        XCTAssertNotEqual(avgI, avgF, accuracy: 0.05)
        // Peak under int16 mis-parse is almost never exactly the float peak 0.8
        // (integer magnitudes / Int16.max are a different domain).
        XCTAssertTrue(abs(peakI - 0.80) > 0.05 || abs(avgI - avgF) > 0.05)
    }

    func testPCMLevelMeterInt32HalfScale() {
        var sample = Int32(Int32.max / 2)
        let bytes = withUnsafeBytes(of: &sample) { Array($0) }
        let (peak, avg) = PCMLevelMeter.levels(data: bytes, format: .int32, channels: 1)
        XCTAssertEqual(peak, 0.5, accuracy: 0.01)
        XCTAssertEqual(avg, 0.5, accuracy: 0.01)
    }

    func testPCMLevelMeterEmptyBuffer() {
        let (peak, avg) = PCMLevelMeter.levels(data: [], format: .float32)
        XCTAssertEqual(peak, 0)
        XCTAssertEqual(avg, 0)
    }

    func testPCMLevelMeterReadsMisalignedInputSafely() {
        var sample: Float32 = 0.5
        let encoded = withUnsafeBytes(of: &sample) { Array($0) }
        let bytes = [UInt8(0)] + encoded

        let levels = bytes.withUnsafeBytes { raw -> (peak: Double, average: Double) in
            guard let base = raw.baseAddress else { return (0, 0) }
            return PCMLevelMeter.levels(
                bytes: base.advanced(by: 1),
                byteCount: encoded.count,
                format: .float32
            )
        }

        XCTAssertEqual(levels.peak, 0.5, accuracy: 0.001)
        XCTAssertEqual(levels.average, 0.5, accuracy: 0.001)
    }

    func testPCMLevelMeterTreatsNonFiniteFloatAsUnsafeFullScale() {
        var sample = Float32.nan
        let bytes = withUnsafeBytes(of: &sample) { Array($0) }
        let levels = PCMLevelMeter.metrics(data: bytes, format: .float32)

        XCTAssertEqual(levels.peak, 1)
        XCTAssertEqual(levels.average, 1)
        XCTAssertEqual(
            AudioReadinessEvaluator.default.evaluate(
                AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = levels.peak
    values.averageLevel = levels.average
    values.clippingFraction = levels.clippedSampleFraction
    return values
}())
            ).status,
            .clipping
        )
    }

    func testPCMLevelsFeedReadinessEvaluator() {
        // Quiet float32 frames → not ready
        var quiet: Float32 = 0.005
        let quietBytes = withUnsafeBytes(of: &quiet) { Array($0) }
        let (p, a) = PCMLevelMeter.levels(data: quietBytes, format: .float32)
        let guidance = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = p
    values.averageLevel = a
    return values
}())
        )
        XCTAssertFalse(guidance.isReady)
        XCTAssertEqual(guidance.status, .silent)
    }

    func testSilentAudioNotReady() {
        let g = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.005
    values.averageLevel = 0.002
    return values
}())
        )
        XCTAssertEqual(g.status, .silent)
        XCTAssertFalse(g.isReady)
        XCTAssertTrue(g.message.localizedCaseInsensitiveContains("audio") || g.message.contains("Audiosignal"))
    }

    func testGoodAudioReady() {
        let g = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.25
    values.averageLevel = 0.18
    values.externalMicIndicated = true
    return values
}())
        )
        XCTAssertEqual(g.status, .good)
        XCTAssertTrue(g.isReady)
    }

    func testClippingAudioNotReady() {
        let g = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 1
    values.averageLevel = 0.9
    values.clippingFraction = 0.02
    return values
}())
        )
        XCTAssertEqual(g.status, .clipping)
        XCTAssertFalse(g.isReady)
    }

    func testHighAmplitudeWithoutFullScaleSamplesIsNotCalledClipping() {
        let g = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.95
    values.averageLevel = 0.9
    values.clippingFraction = 0
    return values
}())
        )
        XCTAssertEqual(g.status, .hot)
        XCTAssertFalse(g.isReady)
        XCTAssertFalse(g.message.localizedCaseInsensitiveContains("erkannt"))
    }

    func testTimestampDropoutIsReportedAsDirectFailure() {
        let g = AudioReadinessEvaluator.default.evaluate(
            AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.25
    values.averageLevel = 0.18
    values.dropoutDetected = true
    return values
}())
        )
        XCTAssertEqual(g.status, .dropout)
        XCTAssertFalse(g.isReady)
    }

    // MARK: - Readiness aggregator (real shipped path)

    func testReadinessBlocksWithoutConsent() {
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Test"
    return values
}())
        session.context = SessionContext({
    var values = SessionContext.Values()
    values.subject = "D"
    values.lessonGoal = "Ziel"
    return values
}())
        // no consent
        let visual = GuidanceResult(tips: [
            GuidanceTip((id: "ready", category: .general, severity: .ok, message: "ok", actionHint: "ok"))
        ])
        let audio = AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    return values
}())
        let result = ReadinessAggregator().evaluate(session: session, visual: visual, audioSample: audio)
        XCTAssertFalse(result.canRecord)
        XCTAssertTrue(result.blockers.contains(.consentMissing))
    }

}
