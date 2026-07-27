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
    func testSessionStoreDeleteRejectsDanglingRecordingsDirectorySymlink() throws {
        let dir = testTemporaryDirectory(named: "uv-store-dangling-directory")
        let missingTarget = dir.deletingLastPathComponent()
            .appendingPathComponent("uv-missing-recordings-dir-\(UUID().uuidString)", isDirectory: true)
        let outsideSentinel = dir.deletingLastPathComponent()
            .appendingPathComponent("uv-dangling-dir-sentinel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("sentinel".utf8).write(to: outsideSentinel)
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: outsideSentinel)
        }

        let store = testSessionStore(rootDirectory: dir)
        let sessionID = UUID()
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.title = "dangling directory"
    values.recordingRelativePath = "\(sessionID.uuidString).mp4"
    return values
}())
        try store.save(session)
        let recordingsURL = dir.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: recordingsURL, withDestinationURL: missingTarget)

        XCTAssertThrowsError(try store.deleteSessionAndMedia(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.prepareRecordingURL(for: session)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertThrowsError(try store.load(id: session.id)) { error in
            XCTAssertEqual(error as? SessionStoreError, .recordingDirectoryIsSymbolicLink)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
        XCTAssertEqual(try Data(contentsOf: outsideSentinel), Data("sentinel".utf8))
    }

    func testSessionStoreSerializesConcurrentSaves() throws {
        let fixture = try testStoreFixture(named: "uv-store-concurrent")
        let dir = fixture.directory
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = fixture.store
        let sessions = (0..<24).map { index in CaptureSession({
    var values = CaptureSession.Values()
    values.title = "session \(index)"
    return values
}()) }
        let group = DispatchGroup()
        let errors = LockedErrorDescriptions()
        for session in sessions {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do { try store.save(session) }
                catch { errors.record(error) }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(errors.snapshot.isEmpty, "unexpected save errors: \(errors.snapshot)")
        XCTAssertEqual(Set(try store.listSessions().map(\.id)), Set(sessions.map(\.id)))
    }

    // MARK: - Teaching-situation presets (session binding)

    func testTeachingSituationDefaultAndPresetResolution() {
        let session = CaptureSession()
        XCTAssertEqual(session.teachingSituation, .frontalBoardInstruction)
        let preset = session.teachingSituationPreset
        XCTAssertEqual(preset.id, .frontalBoardInstruction)
        XCTAssertTrue(preset.requiresBoard)
        XCTAssertFalse(preset.expectedScenes.isEmpty)
    }

    func testTeachingSituationPersistsAcrossAllCatalogueCases() throws {
        let dir = testTemporaryDirectory(named: "uv-preset")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = testSessionStore(rootDirectory: dir)

        XCTAssertGreaterThanOrEqual(TeachingSituationID.allCases.count, 6)
        for situation in TeachingSituationID.allCases {
            var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = situation.rawValue
    return values
}())
            session.teachingSituation = situation
            try store.save(session)
            let loaded = try store.load(id: session.id)
            XCTAssertEqual(loaded?.teachingSituation, situation, "failed for \(situation)")
            XCTAssertEqual(
                loaded?.teachingSituationPreset.titleDE,
                TeachingSituationCatalogue.preset(for: situation).titleDE
            )
        }
    }

    func testDifferentPresetsYieldDifferentSceneExpectations() {
        let frontal = TeachingSituationCatalogue.preset(for: .frontalBoardInstruction)
        let group = TeachingSituationCatalogue.preset(for: .collaborativeGroupWork)
        XCTAssertNotEqual(frontal.expectedScenes, group.expectedScenes)
        XCTAssertTrue(frontal.requiresBoard)
        XCTAssertFalse(group.requiresBoard)
        XCTAssertGreaterThan(group.minPeople, frontal.minPeople)
        XCTAssertGreaterThan(frontal.boardEmphasis, group.boardEmphasis)
        XCTAssertGreaterThan(group.peopleEmphasis, frontal.peopleEmphasis)
    }

    func testSessionCodableIncludesTeachingSituationKey() throws {
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "JSON"
    return values
}())
        session.teachingSituation = .handsOnExperiment
        let data = try JSONEncoder().encode(session)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["teachingSituation"] as? String, TeachingSituationID.handsOnExperiment.rawValue)
    }

    func testCodingSnapshotPersistsAndBuildsReport() throws {
        let dir = testTemporaryDirectory(named: "uv-coding")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = testSessionStore(rootDirectory: dir)

        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.title = "Kodier-Trail"
    return values
}())
        session.buildProvenance = testCaptureBuildProvenance
        session.teachingSituation = .frontalBoardInstruction
        session.analysisIntent = .lessonAnalysis

        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(),
            preset: .frontalBoardInstruction
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(),
            scene: scene,
            teachingSituation: .frontalBoardInstruction,
            analysisFocus: .lessonAnalysis
        )
        let snap = ResearchCodingSnapshot.from(
            coding: coding,
            scene: scene,
            analysisFocus: .lessonAnalysis,
            provenance: testResearchProvenance
        )
        session.appendCodingSnapshot(snap)
        XCTAssertNotNil(session.latestCodingSnapshot)
        XCTAssertEqual(session.codingSnapshots.count, 1)
        XCTAssertFalse(session.reflectionScaffoldNotes().isEmpty)

        try store.save(session)
        let loaded = try store.load(id: session.id)
        XCTAssertNotNil(loaded?.latestCodingSnapshot)
        XCTAssertEqual(loaded?.codingSnapshots.count, 1)
        XCTAssertEqual(loaded?.latestCodingSnapshot?.primaryTIMSS, coding.primaryTIMSS.rawValue)
        XCTAssertNotNil(loaded?.researchCaptureReport(generatorProvenance: testReportBuildProvenance))
        XCTAssertTrue(
            loaded?.researchCaptureReport(generatorProvenance: testReportBuildProvenance)?.summaryDE
                .contains("Report") == true
        )
    }

    func testSessionResearchCaptureReportHasStableIdentityAndTime() {
        guard let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042") else {
            return XCTFail("Invalid fixed UUID")
        }
        let updatedAt = Date(timeIntervalSince1970: 42)
        let snapshot = testResearchCodingSnapshot { values in
            values.teachingSituation = TeachingSituationID.frontalBoardInstruction.rawValue
            values.sceneType = "boardCentricFrontal"
            values.layoutPattern = "frontalRows"
            values.presetMatchScore = 0.8
            values.sceneConfidence = 0.8
            values.primaryTIMSS = "wholeClassInstruction"
            values.primaryGTI = "instructionalQuality"
            values.overallConfidence = 0.8
            values.boardSignal = 0.8
            values.peopleSignal = 0.8
            values.coPresenceSignal = 0.8
            values.layoutSignal = 0.8
        }
        let session = CaptureSession({
    var values = CaptureSession.Values()
    values.id = sessionID
    values.updatedAt = updatedAt
    values.title = "stable report"
    values.codingSnapshots = [snapshot]
    values.buildProvenance = testCaptureBuildProvenance
    return values
}())

        let first = session.researchCaptureReport(generatorProvenance: testReportBuildProvenance)
        let second = session.researchCaptureReport(generatorProvenance: testReportBuildProvenance)
        XCTAssertEqual(first?.id, sessionID)
        XCTAssertEqual(first?.createdAt, updatedAt)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(first?.createdAt, second?.createdAt)
    }

}
