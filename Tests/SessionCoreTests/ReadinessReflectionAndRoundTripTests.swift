import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif

extension SessionCoreTests {
    func testReadinessBlocksOnVisualCritical() {
        let session = testReadySession()
        var visual = GuidanceResult(tips: [])
        visual.observability = CaptureObservabilityAssessment(dimensions: [
            CaptureObservabilityDimension({
                var values = CaptureObservabilityDimension.Values(
                    id: "level",
                    labelDE: "Horizont",
                    status: .fail
                )
                values.value = 0.1
                values.detailDE = "fixture"
                return values
            }())
        ])
        let result = ReadinessAggregator().evaluate(
            session: session,
            visual: visual,
            audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.3
    values.averageLevel = 0.2
    return values
}())
        )
        XCTAssertFalse(result.canRecord)
        XCTAssertTrue(result.blockers.contains(.visualCritical))
    }

    func testReadinessBlocksOnBadAudio() {
        let result = testReadyReadiness(audioSample: AudioLevelSample({
    var values = AudioLevelSample.Values()
    values.peakLevel = 0.0
    values.averageLevel = 0.0
    return values
}()))
        XCTAssertFalse(result.canRecord)
        XCTAssertTrue(result.blockers.contains(.audioNotReady))
    }

    func testReadinessAllowsWhenAllGreen() {
        let result = testReadyReadiness(audioSample: testReadyAudioSample())
        XCTAssertTrue(result.canRecord, "blockers=\(result.blockers)")
        XCTAssertTrue(result.blockers.isEmpty)
        XCTAssertTrue(result.summaryDE.localizedCaseInsensitiveContains("bereit"))
    }

    // MARK: - Reflection scaffold

    func testReflectionPromptsCoverLAFFourSteps() {
        let scaffold = ReflectionScaffold()
        let ids = Set(scaffold.prompts.map(\.rawValue))
        XCTAssertTrue(ids.contains("lessonGoals"))
        XCTAssertTrue(ids.contains("studentLearningEvidence"))
        XCTAssertTrue(ids.contains("instructionalStrategies"))
        XCTAssertTrue(ids.contains("alternatives"))
        for p in scaffold.prompts {
            XCTAssertFalse(p.promptDE.isEmpty)
            XCTAssertFalse(p.titleDE.isEmpty)
        }
    }

    func testReflectionAnswersSubscriptAndCompleteness() {
        var answers = ReflectionAnswers()
        XCTAssertFalse(answers.isComplete)
        XCTAssertEqual(ReflectionScaffold().validate(answers).count, 4)
        answers[.lessonGoals] = "Ziel X"
        answers[.studentLearningEvidence] = "SuS nennt…"
        answers[.instructionalStrategies] = "Impulsfrage"
        answers[.alternatives] = "Wartezeit erhöhen"
        XCTAssertTrue(answers.isComplete)
        XCTAssertTrue(ReflectionScaffold().validate(answers).isEmpty)
    }

    // MARK: - Session store persistence (real module)

    func testSessionStoreRoundTrip() throws {
        let fixture = try testStoreFixture(named: "uv-tests")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Persistenztest"
    return values
}())
        session.purpose = .otherTeaching
        session.analysisIntent = .studentThinking
        session.teachingSituation = .collaborativeGroupWork
        session.context = SessionContext({
    var values = SessionContext.Values()
    values.subject = "Biologie"
    values.lessonGoal = "Fotosynthese"
    return values
}())
        session.consent.markAllAcknowledged()
        session.reflection[.lessonGoals] = "Lernziel notiert"

        try store.save(session)
        let loaded = try store.load(id: session.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "Persistenztest")
        XCTAssertEqual(loaded?.purpose, .otherTeaching)
        XCTAssertEqual(loaded?.teachingSituation, .collaborativeGroupWork)
        XCTAssertEqual(loaded?.context.subject, "Biologie")
        XCTAssertTrue(loaded?.consent.isFullyAcknowledged == true)
        XCTAssertEqual(loaded?.reflection.lessonGoals, "Lernziel notiert")

        let list = try store.listSessions()
        XCTAssertTrue(list.contains { $0.id == session.id })
    }

    func testSessionStorePersistsConsentRevocationAcrossRelaunch() throws {
        let fixture = try testStoreFixture(named: "uv-store-consent-revoke")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "durable consent revoke"
    return values
}())
        session.consent.markAllAcknowledged(at: Date(timeIntervalSince1970: 100))
        try store.save(session)

        session.consent.applyAcknowledgements(
            informedParticipants: true,
            secondaryUse: false,
            storageResponsibility: true,
            at: Date(timeIntervalSince1970: 200)
        )
        try store.save(session)

        let relaunchedStore = testSessionStore(rootDirectory: dir)
        let loaded = try XCTUnwrap(relaunchedStore.load(id: session.id))
        XCTAssertFalse(loaded.consent.secondaryUseAcknowledged)
        XCTAssertFalse(loaded.consent.isFullyAcknowledged)
        XCTAssertNil(loaded.consent.acknowledgedAt)
    }

    func testSessionStoreSaveRollsBackExistingAndNewMetadataOnPolicyFailure() throws{
        try sessionStoreSaveRollsBackExistingAndNewMetadataOnPolicyFailureAssertions()
    }

}


private let sessionStoreSaveRollsBackExistingAndNewMetadataOnPolicyFailureAssertions: @Sendable () throws -> Void = {
        let dir = testTemporaryDirectory(named: "uv-store-policy-rollback")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let baselineStore = testSessionStore(rootDirectory: dir)
        let original = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "original metadata"
    return values
}())
        try baselineStore.save(original)
        let originalURL = dir.appendingPathComponent("\(original.id.uuidString).json")
        let originalData = try Data(contentsOf: originalURL)

        let existingLock = NSLock()
        var existingFailuresRemaining = 1
        let failingExistingStore = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = dir
    values.policyVerificationHook = { url in
            guard url.pathExtension == "json" else { return }
            existingLock.lock()
            defer { existingLock.unlock() }
            if existingFailuresRemaining > 0 {
                existingFailuresRemaining -= 1
                throw CocoaError(.fileWriteUnknown)
            }
        }
    return values
}())
        var changed = original
        changed.title = "must roll back"
        XCTAssertThrowsError(try failingExistingStore.save(changed))
        XCTAssertEqual(try Data(contentsOf: originalURL), originalData)
        XCTAssertEqual(try baselineStore.load(id: original.id)?.title, "original metadata")

        let newSession = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "must disappear"
    return values
}())
        let newURL = dir.appendingPathComponent("\(newSession.id.uuidString).json")
        let newLock = NSLock()
        var newFailuresRemaining = 1
        let failingNewStore = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = dir
    values.policyVerificationHook = { url in
            guard url.pathExtension == "json" else { return }
            newLock.lock()
            defer { newLock.unlock() }
            if newFailuresRemaining > 0 {
                newFailuresRemaining -= 1
                throw CocoaError(.fileWriteUnknown)
            }
        }
    return values
}())
        XCTAssertThrowsError(try failingNewStore.save(newSession))
        XCTAssertFalse(FileManager.default.fileExists(atPath: newURL.path))
        XCTAssertNil(try baselineStore.load(id: newSession.id))
    }
