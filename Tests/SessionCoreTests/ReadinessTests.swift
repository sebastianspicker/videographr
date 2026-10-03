import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

final class ReadinessTests: XCTestCase {
    func testReadinessVisualAndContextWarningsRemainOverrideableButConsentNeverDoes() {
        let ready = readySession(grants: currentCaptureGrants())
        let audio = readyAudioSample()
        let directFailure = visualResult([("level", .fail)])

        let visualBlocking = ReadinessAggregator().evaluate(session: ready, visual: directFailure, audioSample: audio)
        XCTAssertFalse(visualBlocking.canRecord)
        XCTAssertEqual(visualBlocking.blockers, [.visualCritical])
        XCTAssertTrue(visualBlocking.canOverrideQualityWarnings)

        let visualWarning = ReadinessAggregator(blockOnVisualCritical: false).evaluate(
            session: ready,
            visual: directFailure,
            audioSample: audio
        )
        XCTAssertTrue(visualWarning.canRecord)
        XCTAssertEqual(visualWarning.visualSeverity, .critical)
        XCTAssertTrue(visualWarning.canOverrideQualityWarnings)

        var incompleteContext = ready
        incompleteContext.context = SessionContext()
        let contextBlocked = ReadinessAggregator(blockOnVisualCritical: false).evaluate(
            session: incompleteContext,
            visual: visualResult([]),
            audioSample: audio
        )
        XCTAssertEqual(contextBlocked.blockers, [.contextIncomplete])
        XCTAssertTrue(contextBlocked.canOverrideQualityWarnings)

        var missingConsent = ready
        missingConsent.consentGrants = []
        let consentBlocked = ReadinessAggregator(blockOnVisualCritical: false).evaluate(
            session: missingConsent,
            visual: visualResult([]),
            audioSample: audio
        )
        XCTAssertEqual(consentBlocked.blockers, [.consentMissing])
        XCTAssertFalse(consentBlocked.canOverrideQualityWarnings)
    }

    func testReadinessBlockerRawValuesAreFrozen() {
        // Persisted through `CaptureDecision.blockers`; raw values must never change.
        let all: [ReadinessBlocker] = [
            .consentMissing, .contextIncomplete, .visualSampleMissing,
            .visualCritical, .audioNotReady, .titleMissing
        ]
        XCTAssertEqual(all.map(\.rawValue), [
            "consentMissing", "contextIncomplete", "visualSampleMissing",
            "visualCritical", "audioNotReady", "titleMissing"
        ])
    }

    func testReadinessDependsOnEngineDimensionIDsLevelExposureAndCurrentFrame() {
        let aggregator = ReadinessAggregator()
        let ready = readySession(grants: currentCaptureGrants())
        let audio = readyAudioSample()
        func evaluate(_ dimensions: [(String, CaptureObservabilityDimension.Status)]) -> SessionReadiness {
            aggregator.evaluate(session: ready, visual: visualResult(dimensions), audioSample: audio)
        }

        let clean = evaluate([])
        XCTAssertTrue(clean.canRecord)
        XCTAssertEqual(clean.blockers, [])
        XCTAssertEqual(clean.visualSeverity, .ok)

        for id in ["level", "exposure"] {
            let failing = evaluate([(id, .fail)])
            XCTAssertFalse(failing.canRecord, id)
            XCTAssertEqual(failing.blockers, [.visualCritical], id)
            XCTAssertEqual(failing.visualSeverity, .critical, id)
            XCTAssertTrue(failing.canOverrideQualityWarnings, id)

            // Only a failing status of those ids blocks; a warning does not.
            let warning = evaluate([(id, .warn)])
            XCTAssertTrue(warning.canRecord, id)
            XCTAssertEqual(warning.visualSeverity, .warning, id)
        }

        // Failure of any other dimension id raises severity but never blocks.
        let other = evaluate([("sharpness", .fail)])
        XCTAssertTrue(other.canRecord)
        XCTAssertEqual(other.blockers, [])
        XCTAssertEqual(other.visualSeverity, .critical)

        let waiting = evaluate([("currentFrame", .unavailable)])
        XCTAssertFalse(waiting.canRecord)
        XCTAssertEqual(waiting.blockers, [.visualSampleMissing])
        XCTAssertFalse(waiting.canOverrideQualityWarnings)
        XCTAssertEqual(waiting.visualSeverity, .warning)

        // currentFrame only blocks while unavailable.
        let flowing = evaluate([("currentFrame", .pass)])
        XCTAssertTrue(flowing.canRecord)
        XCTAssertEqual(flowing.visualSeverity, .ok)
        // The same status under another id is not the capture generation marker.
        XCTAssertTrue(evaluate([("other", .unavailable)]).canRecord)

        let both = evaluate([("currentFrame", .unavailable), ("level", .fail)])
        XCTAssertEqual(both.blockers, [.visualSampleMissing, .visualCritical])
        XCTAssertFalse(both.canOverrideQualityWarnings)

        let relaxed = ReadinessAggregator(blockOnVisualCritical: false).evaluate(
            session: ready, visual: visualResult([("exposure", .fail)]), audioSample: audio
        )
        XCTAssertTrue(relaxed.canRecord)
    }

    private func grant(
        id: UUID = UUID(),
        scopes: Set<ConsentScope>,
        grantedAt: Date = Date(timeIntervalSinceReferenceDate: 1),
        expiresAt: Date? = nil
    ) -> ConsentGrant {
        ConsentGrant({
            var values = ConsentGrant.Values()
            values.id = id
            values.scopes = scopes
            values.documentIdentifier = "consent-form"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group-a"
            values.grantedAt = grantedAt
            values.expiresAt = expiresAt
            return values
        }())
    }

    private func currentCaptureGrants(at date: Date = Date()) -> [ConsentGrant] {
        [
            grant(scopes: [.collection], grantedAt: date.addingTimeInterval(-1)),
            grant(scopes: [.localReflection], grantedAt: date.addingTimeInterval(-1))
        ]
    }

    private func readySession(grants: [ConsentGrant]) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.title = "Ready session"
            values.context = SessionContext({
                var context = SessionContext.Values()
                context.subject = "Physics"
                context.lessonGoal = "Observe a demonstration"
                return context
            }())
            values.consentGrants = grants
            return values
        }())
    }

    private func readyAudioSample() -> AudioLevelSample {
        AudioLevelSample({
            var values = AudioLevelSample.Values()
            values.peakLevel = 0.2
            values.averageLevel = 0.2
            return values
        }())
    }

    private func visualResult(
        _ statuses: [(String, CaptureObservabilityDimension.Status)]
    ) -> GuidanceResult {
        let frame = FrameMetrics(FrameMetrics.Values())
        let orientation = OrientationSample(pitchDegrees: 0, rollDegrees: 0)
        var values = GuidanceResult.Values(
            tips: [],
            placement: PlacementAssessment.assess(.init(orientation: orientation, frame: frame))
        )
        values.observability = CaptureObservabilityAssessment(dimensions: statuses.map { id, status in
            CaptureObservabilityDimension(.init(id: id, labelDE: id, status: status))
        })
        return GuidanceResult(values)
    }
}
