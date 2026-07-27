import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
import Darwin
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif

extension SessionCoreTests {
    func testAnalysisIntentMapsToCodingFocus() {
        XCTAssertEqual(AnalysisIntent.classroomManagement.codingFocus, .classroomManagement)
        XCTAssertEqual(AnalysisIntent.studentThinking.codingFocus, .studentThinking)
        XCTAssertEqual(AnalysisIntent.lessonAnalysis.codingFocus, .lessonAnalysis)
    }

    func testReadinessDoesNotBlockOnUnvalidatedSceneOrResearchHeuristics(){
        readinessDoesNotBlockOnUnvalidatedSceneOrResearchHeuristicsAssertions()
    }

    func testCodingTimelinePersistsOnSession() throws {
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Timeline"
    return values
}())
        session.buildProvenance = testCaptureBuildProvenance
        let (scene, coding) = testFrontalCoding()
        let snap = ResearchCodingSnapshot.from(
            coding: coding, scene: scene, provenance: testResearchProvenance
        )
        session.appendCodingSnapshot(snap)
        XCTAssertFalse(session.codingTimeline.segments.isEmpty)
        XCTAssertNotNil(session.codingTimeline.dominantTIMSS)
    }

    // MARK: - V2 data-integrity contracts

    func testCodingSnapshotHistoryRetainsFullTakeInsteadOfTrailingWindow() {
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Long take"
    return values
}())
        session.buildProvenance = testCaptureBuildProvenance
        let (scene, coding) = testFrontalCoding()
        for _ in 0..<30 {
            session.appendCodingSnapshot(ResearchCodingSnapshot.from(
                coding: coding, scene: scene, provenance: testResearchProvenance
            ))
        }

        XCTAssertEqual(session.codingSnapshots.count, 30)
        XCTAssertEqual(
            session.researchCaptureReport(generatorProvenance: testReportBuildProvenance)?.snapshotCount,
            30
        )
    }

    func testClosingCaptureTimelineClosesFinalSegment() {
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Finalized"
    return values
}())
        let scene = TeachingSceneAssessor.assess(cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction)
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(), scene: scene, teachingSituation: .frontalBoardInstruction
        )
        session.appendCodingSnapshot(ResearchCodingSnapshot.from(
            coding: coding, scene: scene, provenance: testResearchProvenance
        ))
        let finalizedAt = Date().addingTimeInterval(10)
        session.closeCaptureTimeline(at: finalizedAt)

        XCTAssertEqual(session.codingTimeline.segments.last?.endedAt, finalizedAt)
        XCTAssertGreaterThanOrEqual(session.codingTimeline.segments.last?.durationSeconds ?? -1, 0)
    }

    func testLegacyMigrationCreatesMediaAssetButDoesNotAuthorizeNewActions() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreMigration")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        let id = UUID()
        var current = CaptureSession({
    var values = CaptureSession.Values()
    values.id = id
    values.title = "Legacy"
    values.recordingRelativePath = "\(id.uuidString).mp4"
    return values
}())
        current.consent.markAllAcknowledged()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(current)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        [
            "schemaVersion", "operatingMode", "experimentalProtocol", "mediaAssets", "evidenceAnnotations",
            "captureDecisions", "takeManifests", "captureObservations", "consentGrants", "retentionPolicy",
            "exportEvents", "buildProvenance", "plannedDurationMinutes"
        ].forEach { object.removeValue(forKey: $0) }
        let legacyData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try legacyData.write(to: directory.appendingPathComponent("\(id.uuidString).json"), options: .atomic)

        let decoded = try XCTUnwrap(store.load(id: id))
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.plannedDurationMinutes, 45)
        XCTAssertEqual(decoded.mediaAssets.map(\.relativePath), ["\(id.uuidString).mp4"])
        XCTAssertFalse(decoded.canStartNewCapture)
        XCTAssertFalse(decoded.canExportExternally)

        let migrated = try XCTUnwrap(store.migrateLegacySession(id: id))
        XCTAssertEqual(migrated.schemaVersion, SessionSchema.currentVersion)
        XCTAssertEqual(migrated.mediaAssets.count, 1)
        XCTAssertTrue((try XCTUnwrap(store.load(id: id))).consentGrants.isEmpty)
    }

    func testStoreRejectsUnsafeImportedMediaPath() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreUnsafeAsset")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = testSessionStore(rootDirectory: directory)
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Unsafe"
    return values
}())
        session.mediaAssets = [SessionMediaAsset({
    var values = SessionMediaAsset.Values()
    values.role = .otherImported
    values.relativePath = "../escape.mp4"
    return values
}())]

        XCTAssertThrowsError(try store.save(session)) { error in
            XCTAssertEqual(error as? SessionStoreError, .unsafeRecordingRelativePath)
        }
    }

    func testImportedMediaUsesCanonicalAssetPathAndValidatedResolver() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreImport")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionCoreSource-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        try Data([0, 1, 2]).write(to: source)
        let store = testSessionStore(rootDirectory: directory)
        let sessionID = UUID()

        let asset = try store.importMedia(from: source, into: sessionID)
        XCTAssertEqual(asset.role, .otherImported)
        XCTAssertEqual(asset.relativePath, "\(asset.id.uuidString).mp4")
        XCTAssertEqual(try store.validatedMediaURL(for: asset, sessionID: sessionID).lastPathComponent, asset.relativePath)
    }

    func testImportedMediaReadsOpenedSourceWhenPathIsReplacedDuringImport() throws {
        let directory = testTemporaryDirectory(named: "SessionCoreImportStableHandle")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionCoreImportStableHandleSource-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        let original = Data(repeating: 0x11, count: 4_096)
        let replacement = Data(repeating: 0x22, count: 4_096)
        try original.write(to: source)
        let store = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = directory
    values.importSourceOpenedHook = {
            try FileManager.default.removeItem(at: source)
            try replacement.write(to: source)
        }
    return values
}())

        let sessionID = UUID()
        let asset = try store.importMedia(from: source, into: sessionID)
        let imported = try Data(contentsOf: try store.validatedMediaURL(for: asset, sessionID: sessionID))
        XCTAssertEqual(imported, original)
    }

    func testImportedMediaPostPromotionFailureCleansArtifactsAndLeavesReconciliationSafe() throws {
        let fixture = try testImportSourceFixture(named: "SessionCoreImportPromotionFailure")
        let directory = fixture.directory
        let source = fixture.source
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        let store = SessionStore({
    var values = SessionStore.Values()
    values.rootDirectory = directory
    values.persistenceFaultHook = { point in
            if case .afterImportPromotion = point {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    return values
}())

        XCTAssertThrowsError(try store.importMedia(from: source, into: UUID()))

        let recordings = try store.recordingsDirectory()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recordings.path), [])
        let report = try store.reconcilePersistenceArtifacts()
        XCTAssertTrue(report.removedOrphanImportedFileNames.isEmpty)
        XCTAssertTrue(report.diagnostics.isEmpty)
    }

}


private let readinessDoesNotBlockOnUnvalidatedSceneOrResearchHeuristicsAssertions: @Sendable () -> Void = {
        var session = testReadySession()
        session.teachingSituation = .frontalBoardInstruction

        let engine = GuidanceEngine()
        let bad = engine.evaluate(GuidanceInput({
    var values = GuidanceInput.Values(orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1), frame: FrameMetrics({
    var values = FrameMetrics.Values()
    values.averageLuminance = 0.45
    values.boardRegionScore = 0.2
    values.boardCenterY = 0.4
    values.ceilingFraction = 0.1
    values.floorFraction = 0.1
    values.backlightScore = 0.1
    values.emptyEdgeFraction = 0.15
    values.globalContrast = 0.35
    return values
}()))
    values.cv = .fixtureEmptyRoom()
    values.motion = .stable
    values.teachingSituation = .frontalBoardInstruction
    return values
}()))
        let result = ReadinessAggregator().evaluate(
            session: session,
            visual: bad,
            audioSample: testReadyAudioSample()
        )
        XCTAssertTrue(result.canRecord, "blockers=\(result.blockers)")
        XCTAssertTrue(result.blockers.isEmpty)
    }
