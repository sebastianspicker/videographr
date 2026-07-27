import XCTest
@testable import GuidanceEngine

extension TeachingSceneAndCodingTests {
    func testGTICaptureTipsWhenEmphasisUnmet() {
        let engine = GuidanceEngine()
        // Single actor, no board - formative dialogue expects discourse partners.
        let singleActor = CVFeatures.make {
            $0.source = .fixture
            $0.boardConfidence = 0.1
            $0.personCount = 1
            $0.personCoverage = 0.08
            $0.faceCount = 1
            $0.personMidBandOccupancy = 0.2
            $0.personCentroidY = 0.55
            $0.personCentroidX = 0.5
            $0.personBoardCoPresence = 0.05
            $0.observationStability = 0.9
            $0.layoutPattern = .seatworkScattered
            $0.analysisSucceeded = true
        }
        let scene = TeachingSceneAssessor.assess(cv: singleActor, preset: .formativeAssessmentDialogue)
        let tips = engine.evaluateGTICaptureExpectations(
            cv: singleActor,
            scene: scene,
            situation: .formativeAssessmentDialogue
        )
        XCTAssertTrue(
            tips.contains { $0.id == "gti-discourse-actors" },
            "expected discourse actors tip, got \(tips.map(\.id))"
        )

        // Board-required frontal with weak board → subject clarity tip.
        let weakBoard = CVFeatures.fixturePeopleNoBoard()
        let frontalTips = engine.evaluateGTICaptureExpectations(
            cv: weakBoard,
            scene: TeachingSceneAssessor.assess(cv: weakBoard, preset: .frontalBoardInstruction),
            situation: .frontalBoardInstruction
        )
        XCTAssertTrue(
            frontalTips.contains { $0.id.hasPrefix("gti-") },
            "expected GTI tip for frontal on weak board, got \(frontalTips.map(\.id))"
        )
    }

    func testResearchCaptureReportFromSnapshots() throws {
        let s1 = testLessonAnalysisSnapshot()
        let s2 = testLessonAnalysisSnapshot()
        var input = ResearchCaptureReport.BuildInput()
        input.sessionTitle = "Teststunde"
        input.teachingSituation = .frontalBoardInstruction
        input.analysisFocus = .lessonAnalysis
        input.snapshots = [s1, s2]
        input.captureProvenance = testResearchProvenance
        input.generatorProvenance = testReportGeneratorProvenance
        let report = ResearchCaptureReport.build(input)
        guard let report else { return XCTFail("Expected research capture report") }
        XCTAssertEqual(report.snapshotCount, 2)
        XCTAssertEqual(report.captureProvenance, testResearchProvenance)
        XCTAssertEqual(report.generatorProvenance, testReportGeneratorProvenance)
        XCTAssertEqual(report.appVersion, testReportGeneratorProvenance.displayVersion)
        XCTAssertFalse(report.meanIPN.isEmpty)
        XCTAssertFalse(report.meanGTI.isEmpty)
        XCTAssertTrue(report.summaryDE.contains("Report"))
        let json = try report.jsonString()
        XCTAssertTrue(json.contains("meanIPN") || json.contains("meanGTI") || json.contains("primaryTIMSS"))
    }

    func testResearchReportRejectsMixedCaptureProvenance() {
        let snapshot = testLessonAnalysisSnapshot()
        let mismatched = ResearchArtifactProvenance((semanticVersion: "test", buildNumber: "2", schemaVersion: 2, algorithmVersion: "experimental-coding-rules-test", evidenceRegistryVersion: "1"))

        var input = ResearchCaptureReport.BuildInput()
        input.sessionTitle = "fixture"
        input.teachingSituation = .frontalBoardInstruction
        input.analysisFocus = nil
        input.snapshots = [snapshot]
        input.captureProvenance = mismatched
        input.generatorProvenance = testReportGeneratorProvenance
        XCTAssertNil(ResearchCaptureReport.build(input))
    }

    func testResearchCaptureReportUsesMostRecentSnapshotForEqualVotes() {
        func snapshot(
            scene: String,
            layout: String,
            timss: String,
            gti: String
        ) -> ResearchCodingSnapshot {
            testResearchCodingSnapshot { values in
                values.sceneType = scene
                values.layoutPattern = layout
                values.primaryTIMSS = timss
                values.primaryGTI = gti
            }
        }

        let earlier = snapshot(scene: "boardCentricFrontal", layout: "frontalRows", timss: "wholeClassInstruction", gti: "classroomManagement")
        let later = snapshot(scene: "multiPersonGroup", layout: "multiCluster", timss: "groupWork", gti: "instructionalQuality")
        guard let reportID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
            return XCTFail("Invalid fixed UUID")
        }
        for (first, second, expected) in [(earlier, later, later), (later, earlier, earlier)] {
            var input = ResearchCaptureReport.BuildInput()
            input.id = reportID
            input.createdAt = Date(timeIntervalSince1970: 1)
            input.sessionTitle = "fixture"
            input.teachingSituation = .frontalBoardInstruction
            input.analysisFocus = nil
            input.snapshots = [first, second]
            input.captureProvenance = testResearchProvenance
            input.generatorProvenance = testReportGeneratorProvenance
            let report = ResearchCaptureReport.build(input)
            XCTAssertEqual(report?.dominantSceneType, expected.sceneType)
            XCTAssertEqual(report?.dominantLayout, expected.layoutPattern)
            XCTAssertEqual(report?.primaryTIMSS, expected.primaryTIMSS)
            XCTAssertEqual(report?.primaryGTI, expected.primaryGTI)
        }
    }

    func testCodingSegmentTimelineUsesMostRecentSegmentForEqualDurations() {
        func snapshot(timss: String) -> ResearchCodingSnapshot {
            testResearchCodingSnapshot { values in
                values.primaryTIMSS = timss
            }
        }

        let earlier = snapshot(timss: "wholeClassInstruction")
        let later = snapshot(timss: "groupWork")
        let start = Date(timeIntervalSince1970: 1)
        for (first, second, expected) in [(earlier, later, later), (later, earlier, earlier)] {
            var timeline = CodingSegmentTimeline(minSegmentSeconds: 1)
            timeline.observe(snapshot: first, at: start)
            timeline.observe(snapshot: second, at: start.addingTimeInterval(5))
            timeline.close(at: start.addingTimeInterval(10))
            XCTAssertEqual(timeline.dominantTIMSS, expected.primaryTIMSS)
        }
    }

    func testCodingSegmentTimelineClampsOutOfOrderTimestamps() {
        let snapshot = testResearchCodingSnapshot()
        let start = Date(timeIntervalSince1970: 20)
        var timeline = CodingSegmentTimeline(minSegmentSeconds: 1)
        timeline.observe(snapshot: snapshot, at: start)
        timeline.observe(snapshot: snapshot, at: start.addingTimeInterval(-5))
        XCTAssertEqual(timeline.segments.last?.durationSeconds, 0)
        timeline.close(at: start.addingTimeInterval(-10))
        XCTAssertEqual(timeline.segments.last?.durationSeconds, 0)
    }
}
