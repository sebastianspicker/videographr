import Foundation
import XCTest
@testable import SessionCore
import GuidanceEngine

func testTemporaryDirectory(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
}

func testSessionStore(rootDirectory: URL) -> SessionStore {
    SessionStore({
        var values = SessionStore.Values()
        values.rootDirectory = rootDirectory
        return values
    }())
}

func testSession(
    configure: (inout CaptureSession.Values) -> Void = { _ in }
) -> CaptureSession {
    CaptureSession({
        var values = CaptureSession.Values()
        configure(&values)
        return values
    }())
}

func testRecordingSession(id: UUID, title: String) -> CaptureSession {
    testSession { values in
        values.id = id
        values.title = title
        values.recordingRelativePath = "\(id.uuidString).mp4"
    }
}

func testTakeSession(
    lifecycleState: CaptureTakeLifecycleState,
    includesAsset: Bool = true
) -> CaptureSession {
    let sessionID = UUID()
    var assetValues = SessionMediaAsset.Values()
    assetValues.role = .ownRecorded
    assetValues.relativePath = "\(sessionID.uuidString).mp4"
    let asset = SessionMediaAsset(assetValues)
    var manifestValues = CaptureTakeManifest.Values()
    manifestValues.sessionID = sessionID
    manifestValues.mediaAssetID = asset.id
    manifestValues.lifecycleState = lifecycleState
    return testSession { values in
        values.id = sessionID
        values.title = "recording transaction"
        values.mediaAssets = includesAsset ? [asset] : []
        values.takeManifests = [CaptureTakeManifest(manifestValues)]
    }
}

func testReadyAudioSample() -> AudioLevelSample {
    AudioLevelSample({
        var values = AudioLevelSample.Values()
        values.peakLevel = 0.28
        values.averageLevel = 0.2
        values.externalMicIndicated = true
        return values
    }())
}

func testReadyReadiness(audioSample: AudioLevelSample) -> SessionReadiness {
    ReadinessAggregator().evaluate(
        session: testReadySession(),
        visual: GuidanceResult(tips: [
            GuidanceTip((id: "ready", category: .general, severity: .ok, message: "ok", actionHint: "ok"))
        ]),
        audioSample: audioSample
    )
}

func testResearchConsentGrant(at date: Date) -> ConsentGrant {
    ConsentGrant({
        var values = ConsentGrant.Values()
        values.scopes = [.researchProcessing]
        values.documentIdentifier = "research"
        values.documentVersion = "1"
        values.participantGroupPseudonym = "group"
        values.grantedAt = date
        return values
    }())
}

func testFrontalCoding() -> (scene: TeachingSceneAssessment, coding: PedagogicalCodingResult) {
    let scene = TeachingSceneAssessor.assess(
        cv: .fixtureClassroomPresent(),
        preset: .frontalBoardInstruction
    )
    let coding = PedagogicalCoder.code(
        cv: .fixtureClassroomPresent(),
        scene: scene,
        teachingSituation: .frontalBoardInstruction
    )
    return (scene, coding)
}

func testImportSourceFixture(named name: String) throws -> (directory: URL, source: URL) {
    let directory = testTemporaryDirectory(named: name)
    let source = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(name)Source-\(UUID().uuidString).mp4")
    try Data([0, 1, 2, 3]).write(to: source)
    return (directory, source)
}

func testStoreFixture(named name: String) throws -> (directory: URL, store: SessionStore) {
    let directory = testTemporaryDirectory(named: name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return (directory, testSessionStore(rootDirectory: directory))
}

func testJournalStoreFixture(named name: String) -> (directory: URL, store: SessionStore, session: CaptureSession) {
    let directory = testTemporaryDirectory(named: name)
    return (directory, testSessionStore(rootDirectory: directory), testSession { $0.title = "Journal" })
}

func testStoreFixtureWithExternalSentinel(
    named name: String,
    externalName: String
) throws -> (directory: URL, outsideURL: URL, store: SessionStore) {
    let directory = testTemporaryDirectory(named: name)
    let outsideURL = directory.deletingLastPathComponent()
        .appendingPathComponent("\(externalName)-\(UUID().uuidString).mp4")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("sentinel".utf8).write(to: outsideURL)
    return (directory, outsideURL, testSessionStore(rootDirectory: directory))
}

func testNestedStoreFixture(
    named name: String,
    outsideData: Data
) throws -> (container: URL, rootDirectory: URL, outsideTarget: URL, store: SessionStore) {
    let container = testTemporaryDirectory(named: name)
    let rootDirectory = container.appendingPathComponent("Sessions", isDirectory: true)
    let outsideTarget = container.appendingPathComponent("outside.mp4")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try outsideData.write(to: outsideTarget)
    return (container, rootDirectory, outsideTarget, testSessionStore(rootDirectory: rootDirectory))
}

func assertUnsafeImportArtifactIsPreserved(
    report: PersistenceArtifactReconciliationReport,
    marker: URL,
    destination: URL,
    outsideDestination: URL
) throws {
    XCTAssertEqual(report.removedOrphanImportedFileNames, [])
    XCTAssertEqual(report.diagnostics, [RecordingArtifactDiagnostic(
        fileName: destination.lastPathComponent,
        reason: .artifactIsSymbolicLink
    )])
    XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    XCTAssertNotNil(try FileManager.default.destinationOfSymbolicLink(atPath: destination.path))
    XCTAssertEqual(try Data(contentsOf: outsideDestination), Data([1, 2, 3]))
}

func assertMetadataSymlinkIsRejected(
    by store: SessionStore,
    sessionID: UUID,
    metadataLink: URL
) throws {
    XCTAssertThrowsError(try store.load(id: sessionID)) { error in
        XCTAssertEqual(error as? SessionStoreError, .sessionMetadataIsSymbolicLink)
    }
    let listing = try store.listSessionsWithDiagnostics()
    XCTAssertTrue(listing.sessions.isEmpty)
    XCTAssertEqual(listing.failures.map(\.fileName), [metadataLink.lastPathComponent])
    XCTAssertThrowsError(try store.deleteSessionAndMedia(id: sessionID)) { error in
        XCTAssertEqual(error as? SessionStoreError, .sessionMetadataIsSymbolicLink)
    }
}

func testResearchCodingSnapshot(
    configure: (inout ResearchCodingSnapshot.Values) -> Void = { _ in }
) -> ResearchCodingSnapshot {
    ResearchCodingSnapshot({
        var values = ResearchCodingSnapshot.Values(provenance: testResearchProvenance)
        values.teachingSituation = "fixture"
        values.sceneType = "fixture"
        values.layoutPattern = "fixture"
        values.presetMatchScore = 0.5
        values.matchesPreset = true
        values.sceneConfidence = 0.5
        values.primaryTIMSS = "fixture"
        values.primaryGTI = "fixture"
        values.overallConfidence = 0.5
        values.summaryDE = "fixture"
        values.ipn = []
        values.timss = []
        values.gti = []
        values.boardSignal = 0.5
        values.peopleSignal = 0.5
        values.coPresenceSignal = 0.5
        values.layoutSignal = 0.5
        configure(&values)
        return values
    }())
}

func testReadySession() -> CaptureSession {
    var session = CaptureSession({
        var values = CaptureSession.Values()
        values.title = "Test"
        return values
    }())
    session.context = SessionContext({
        var values = SessionContext.Values()
        values.subject = "Mathe"
        values.gradeLevel = "7"
        values.lessonGoal = "Prozent"
        return values
    }())
    session.consent.markAllAcknowledged()
    session.consentGrants = [ConsentGrant({
        var values = ConsentGrant.Values()
        values.scopes = [.collection, .localReflection]
        values.documentIdentifier = "consent"
        values.documentVersion = "2"
        values.participantGroupPseudonym = "test-group"
        return values
    }())]
    return session
}

func testResearchAuthorizedSession(title: String, protocolIdentifier: String) -> CaptureSession {
    testSession { values in
        values.title = title
        values.operatingMode = .experimentalResearch
        values.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: protocolIdentifier,
            oversightReference: "test",
            expiresAt: Date().addingTimeInterval(3_600)
        )
        values.consentGrants = [ConsentGrant({
            var values = ConsentGrant.Values()
            values.scopes = [.collection, .localReflection, .researchProcessing]
            values.documentIdentifier = "test"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group"
            return values
        }())]
    }
}

func testObservationJournalFixture(
    named name: String
) throws -> (directory: URL, store: SessionStore, session: CaptureSession, journal: URL) {
    let fixture = try testStoreFixture(named: name)
    let directory = fixture.directory
    let store = fixture.store
    let session = testSession { $0.title = "Bounded journal" }
    try store.save(session)
    let observations = directory.appendingPathComponent("Observations", isDirectory: true)
    try FileManager.default.createDirectory(at: observations, withIntermediateDirectories: true)
    let journal = observations.appendingPathComponent("\(session.id.uuidString).jsonl")
    return (directory, store, session, journal)
}
