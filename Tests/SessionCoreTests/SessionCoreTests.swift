import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif

let testCaptureBuildProvenance = BuildProvenance({
    var values = BuildProvenance.Values()
    values.semanticVersion = "test"
    values.buildNumber = "1"
    values.algorithmVersion = "experimental-coding-rules-test"
    values.evidenceRegistryVersion = "1"
    return values
}())

let testReportBuildProvenance = BuildProvenance({
    var values = BuildProvenance.Values()
    values.semanticVersion = "test"
    values.buildNumber = "1"
    values.algorithmVersion = "research-report-test"
    values.evidenceRegistryVersion = "1"
    return values
}())

let testResearchProvenance: ResearchArtifactProvenance = {
    guard let provenance = testCaptureBuildProvenance.researchArtifactProvenance else {
        preconditionFailure("Test capture provenance must produce research provenance")
    }
    return provenance
}()

/// Test-only synchronized storage used from `DispatchQueue` sendable closures.
final class LockedErrorDescriptions: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func record(_ error: any Error) {
        lock.lock()
        values.append(String(describing: error))
        lock.unlock()
    }

    var snapshot: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

/// Session store, readiness aggregator, mid-take policy, reflection, and preset wiring.
final class SessionCoreTests: XCTestCase {

    // MARK: - Mid-take filming guidance policy (scientific alpha)

    func testPreRollShowsCompositionTipsAsActive() {
        let policy = FilmingGuidancePolicy()
        let visual = GuidanceResult(tips: [
            GuidanceTip((
                id: "composition-loose",
                category: .composition,
                severity: .warning,
                message: "Ausschnitt zu weit",
                actionHint: "Heranzoomen"
            ))
        ])
        let snap = policy.evaluate(
            visual: visual,
            audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    return values
}()),
            isRecording: false
        )
        XCTAssertEqual(snap.phase, .preRoll)
        XCTAssertTrue(snap.liveUpdatesActive)
        let tip = snap.visibleTips.first { $0.tip.id == "composition-loose" }
        XCTAssertNotNil(tip)
        XCTAssertEqual(tip?.presentation, .active)
        XCTAssertTrue(snap.headlineDE.localizedCaseInsensitiveContains("pre-roll")
                      || snap.headlineDE.localizedCaseInsensitiveContains("vor der aufnahme")
                      || snap.headlineDE.localizedCaseInsensitiveContains("prüfen"))
    }

    func testRecordingDeprioritizesCompositionToPostTake() {
        let policy = FilmingGuidancePolicy()
        let visual = GuidanceResult(tips: [
            GuidanceTip((
                id: "composition-loose",
                category: .composition,
                severity: .warning,
                message: "Ausschnitt zu weit",
                actionHint: "Heranzoomen"
            )),
            GuidanceTip((
                id: "board-missing",
                category: .blackboard,
                severity: .warning,
                message: "Tafel kaum sichtbar",
                actionHint: "Standpunkt ändern"
            ))
        ])
        let snap = policy.evaluate(
            visual: visual,
            audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    values.externalMicIndicated = true
    return values
}()),
            isRecording: true
        )
        XCTAssertEqual(snap.phase, .recording)
        XCTAssertTrue(snap.liveUpdatesActive)
        let composition = snap.rankedTips.first { $0.tip.id == "composition-loose" }
        XCTAssertEqual(composition?.presentation, .postTakeNote)
        XCTAssertTrue(composition?.tip.actionHint.contains("Nach dem Take") == true
                      || composition?.phaseNoteDE?.contains("Take") == true)
        let board = snap.rankedTips.first { $0.tip.id == "board-missing" }
        XCTAssertEqual(board?.presentation, .postTakeNote)
        XCTAssertTrue(snap.headlineDE.localizedCaseInsensitiveContains("aufnahme läuft"))
    }

    func testRecordingKeepsCriticalBacklightActive() {
        let policy = FilmingGuidancePolicy()
        let visual = GuidanceResult(tips: [
            GuidanceTip((
                id: "backlight-critical",
                category: .backlight,
                severity: .critical,
                message: "Gegenlicht",
                actionHint: "Standort wechseln"
            )),
            GuidanceTip((
                id: "composition-loose",
                category: .composition,
                severity: .warning,
                message: "Weit",
                actionHint: "Zoom"
            ))
        ])
        let snap = policy.evaluate(
            visual: visual,
            audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    return values
}()),
            isRecording: true
        )
        let bl = snap.visibleTips.first { $0.tip.id == "backlight-critical" }
        XCTAssertNotNil(bl)
        XCTAssertEqual(bl?.presentation, .active)
        XCTAssertGreaterThan(snap.criticalCount, 0)
        // Critical ranked before post-take composition
        let ranks = Dictionary(uniqueKeysWithValues: snap.rankedTips.map { ($0.tip.id, $0.rank) })
        XCTAssertLessThan(ranks["backlight-critical"] ?? 99, ranks["composition-loose"] ?? 0)
    }

    func testRecordingSurfacesSilentAudioAsActiveCritical() {
        let policy = FilmingGuidancePolicy()
        let visual = GuidanceResult(tips: [
            GuidanceTip((id: "ready", category: .general, severity: .ok, message: "ok", actionHint: "ok"))
        ])
        let snap = policy.evaluate(
            visual: visual,
            audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.0
    values.averageLevel = 0.0
    return values
}()),
            isRecording: true
        )
        let audioTips = snap.visibleTips.filter { $0.tip.id.hasPrefix("audio-") }
        XCTAssertFalse(audioTips.isEmpty)
        XCTAssertEqual(audioTips.first?.presentation, .active)
        XCTAssertEqual(audioTips.first?.tip.severity, .critical)
        // OK visual tip suppressed mid-take
        XCTAssertFalse(snap.visibleTips.contains { $0.tip.id == "ready" })
    }

    func testPreRollVsRecordingDifferForSameInputs() {
        let policy = FilmingGuidancePolicy()
        let visual = GuidanceResult(tips: [
            GuidanceTip((
                id: "composition-loose",
                category: .composition,
                severity: .warning,
                message: "Weit",
                actionHint: "Zoom"
            ))
        ])
        let audio = AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.25
    values.averageLevel = 0.2
    return values
}())
        let pre = policy.evaluate(visual: visual, audioSample: audio, isRecording: false)
        let mid = policy.evaluate(visual: visual, audioSample: audio, isRecording: true)
        XCTAssertNotEqual(pre.phase, mid.phase)
        let prePres = pre.rankedTips.first { $0.tip.id == "composition-loose" }?.presentation
        let midPres = mid.rankedTips.first { $0.tip.id == "composition-loose" }?.presentation
        XCTAssertEqual(prePres, .active)
        XCTAssertEqual(midPres, .postTakeNote)
    }

    func testFilmingGuidanceEqualRankTipsIgnoreInputOrder() {
        let alpha = GuidanceTip((id: "alpha", category: .composition, severity: .warning, message: "a", actionHint: "a"))
        let zeta = GuidanceTip((id: "zeta", category: .composition, severity: .warning, message: "z", actionHint: "z"))
        var forward = GuidanceResult(tips: [alpha, zeta])
        var backward = GuidanceResult(tips: [alpha, zeta])
        forward.tips = [zeta, alpha]
        backward.tips = [alpha, zeta]
        let audio = AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    return values
}())

        let forwardIDs = FilmingGuidancePolicy().evaluate(
            visual: forward, audioSample: audio, isRecording: false
        ).rankedTips.map { $0.tip.id }
        let backwardIDs = FilmingGuidancePolicy().evaluate(
            visual: backward, audioSample: audio, isRecording: false
        ).rankedTips.map { $0.tip.id }
        XCTAssertEqual(forwardIDs, ["alpha", "zeta"])
        XCTAssertEqual(forwardIDs, backwardIDs)
    }

    // MARK: - Setup / consent / context

    func testConsentRequiresAllThreeFlags() {
        var consent = ConsentRecord()
        XCTAssertFalse(consent.isFullyAcknowledged)
        consent.informedParticipantsAcknowledged = true
        consent.secondaryUseAcknowledged = true
        XCTAssertFalse(consent.isFullyAcknowledged)
        consent.storageResponsibilityAcknowledged = true
        XCTAssertTrue(consent.isFullyAcknowledged)
    }

    func testConsentAcknowledgementTransitionTracksEntryRevocationAndReentry() {
        var consent = ConsentRecord()
        let first = Date(timeIntervalSince1970: 10)
        let second = Date(timeIntervalSince1970: 20)
        consent.applyAcknowledgements(
            informedParticipants: true, secondaryUse: true, storageResponsibility: true, at: first
        )
        XCTAssertEqual(consent.acknowledgedAt, first)

        consent.applyAcknowledgements(
            informedParticipants: true, secondaryUse: true, storageResponsibility: true, at: second
        )
        XCTAssertEqual(consent.acknowledgedAt, first)

        consent.applyAcknowledgements(
            informedParticipants: true, secondaryUse: false, storageResponsibility: true, at: second
        )
        XCTAssertNil(consent.acknowledgedAt)

        consent.applyAcknowledgements(
            informedParticipants: true, secondaryUse: true, storageResponsibility: true, at: second
        )
        XCTAssertEqual(consent.acknowledgedAt, second)

        var legacyFullyAcknowledged = ConsentRecord(
            informedParticipantsAcknowledged: true,
            secondaryUseAcknowledged: true,
            storageResponsibilityAcknowledged: true,
            acknowledgedAt: nil
        )
        legacyFullyAcknowledged.applyAcknowledgements(
            informedParticipants: true, secondaryUse: true, storageResponsibility: true, at: first
        )
        XCTAssertEqual(legacyFullyAcknowledged.acknowledgedAt, first)
    }

}
