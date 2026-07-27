import XCTest
@testable import GuidanceEngine

/// FrameAnalyzer luminance metrics + CVFeatures fusion / fixture contracts.
final class CVAndMetricsTests: XCTestCase {
    let engine = GuidanceEngine()
    let analyzer = FrameAnalyzer()

    // MARK: - Richer pure metrics from synthetic frames

    func testClassroomMetricsDifferFromEmptyHighCeiling() {
        var classroomConfiguration = FrameAnalyzer.SyntheticClassroomConfiguration()
        classroomConfiguration.boardDarkness = 0.2
        classroomConfiguration.ceilingHeightFraction = 0.1
        classroomConfiguration.baseLuminance = 0.45
        let classroom = FrameAnalyzer.syntheticClassroom(classroomConfiguration)
        var emptyConfiguration = FrameAnalyzer.SyntheticClassroomConfiguration()
        emptyConfiguration.boardDarkness = 0.45
        emptyConfiguration.boardRect = (0, 0, 0.01, 0.01)
        emptyConfiguration.ceilingBrightness = 0.95
        emptyConfiguration.ceilingHeightFraction = 0.5
        emptyConfiguration.baseLuminance = 0.7
        let empty = FrameAnalyzer.syntheticClassroom(emptyConfiguration)
        let mClass = analyzer.analyze(luminance: classroom.buffer, width: classroom.width, height: classroom.height)
        let mEmpty = analyzer.analyze(luminance: empty.buffer, width: empty.width, height: empty.height)

        XCTAssertGreaterThan(mClass.boardRegionScore, mEmpty.boardRegionScore)
        XCTAssertLessThan(mClass.ceilingFraction, mEmpty.ceilingFraction)
        XCTAssertGreaterThan(mEmpty.clippedHighlightFraction + mEmpty.ceilingFraction, 0.3)
        XCTAssertGreaterThan(mClass.globalContrast, 0.1)
        XCTAssertGreaterThanOrEqual(mClass.edgeEnergy, 0)
        XCTAssertGreaterThan(mClass.midBandVariance, 0)
    }

    func testWindowSceneRaisesBacklightAndImbalance() {
        var configuration = FrameAnalyzer.SyntheticClassroomConfiguration()
        configuration.windowSide = .left
        configuration.windowBrightness = 0.99
        configuration.baseLuminance = 0.35
        let synth = FrameAnalyzer.syntheticClassroom(configuration)
        let m = analyzer.analyze(luminance: synth.buffer, width: synth.width, height: synth.height)
        XCTAssertGreaterThan(m.leftBandLuminance, m.rightBandLuminance)
        XCTAssertGreaterThan(m.backlightScore, 0.25)
        XCTAssertGreaterThan(m.horizontalBrightnessImbalance, 0.1)
        XCTAssertGreaterThan(m.globalContrast, 0.2)
    }

    func testMotionStabilityTrackerDetectsShake() {
        var tracker = MotionStabilityTracker(stableMaxDegreesPerSecond: 10)
        let t0 = Date()
        _ = tracker.update(orientation: .init(pitchDegrees: 0, rollDegrees: 0), at: t0)
        let m = tracker.update(
            orientation: .init(pitchDegrees: 25, rollDegrees: -20, yawDegrees: 15),
            at: t0.addingTimeInterval(0.1)
        )
        XCTAssertGreaterThan(m.angularSpeedDegreesPerSecond, 50)
        XCTAssertFalse(m.isStable)

        let speed = MotionStabilityTracker.angularSpeed(
            from: .init(pitchDegrees: 0, rollDegrees: 0),
            to: .init(pitchDegrees: 10, rollDegrees: 0),
            deltaSeconds: 0.5
        )
        XCTAssertEqual(speed, 20, accuracy: 0.01)
    }

    // MARK: - Multi-cue board & spatial fusion (shipped pure helpers)

    func testMultiCueBoardQualityDistinguishesGoodVsWeakBoard() {
        let good = CVFeatures.fixtureClassroomPresent()
        let empty = CVFeatures.fixtureEmptyRoom()
        let weak = CVFeatures.make {
            $0.source = .fixture
            $0.boardConfidence = 0.7
            $0.boardRect = ImageNormalizedRect(x: 0.4, y: 0.7, width: 0.08, height: 0.5)
            $0.boardAspectQuality = 0.15
            $0.boardGeometryQuality = 0.12
            $0.boardEdgeSupport = 0.1
            $0.analysisSucceeded = true
        }
        let goodQ = CVFeatureFusion.multiCueBoardQuality(from: good)
        let emptyQ = CVFeatureFusion.multiCueBoardQuality(from: empty)
        let weakQ = CVFeatureFusion.multiCueBoardQuality(from: weak)
        XCTAssertGreaterThan(goodQ, 0.55)
        XCTAssertLessThan(emptyQ, 0.25)
        XCTAssertGreaterThan(goodQ, weakQ)
        XCTAssertGreaterThan(goodQ, emptyQ)
    }

    func testBoardAspectAndGeometryHelpersPreferClassroomBoards() {
        let classroomBoard = ImageNormalizedRect(x: 0.2, y: 0.15, width: 0.55, height: 0.28)
        let tinyCorner = ImageNormalizedRect(x: 0.9, y: 0.9, width: 0.05, height: 0.08)
        let tallDoor = ImageNormalizedRect(x: 0.4, y: 0.1, width: 0.15, height: 0.8)
        XCTAssertGreaterThan(
            CVFeatureFusion.boardAspectQuality(for: classroomBoard),
            CVFeatureFusion.boardAspectQuality(for: tallDoor)
        )
        XCTAssertGreaterThan(
            CVFeatureFusion.boardGeometryQuality(for: classroomBoard),
            CVFeatureFusion.boardGeometryQuality(for: tinyCorner)
        )
    }

    func testPeopleSpatialUsefulnessGoodVsOffZoneVsMissing() {
        let good = CVFeatures.fixtureClassroomPresent()
        let off = CVFeatures.fixturePeopleOffZone()
        let missing = CVFeatures.fixtureEmptyRoom()
        let boardOnly = CVFeatures.fixtureBoardNoPeople()
        let g = CVFeatureFusion.peopleSpatialUsefulness(from: good)
        let o = CVFeatureFusion.peopleSpatialUsefulness(from: off)
        let m = CVFeatureFusion.peopleSpatialUsefulness(from: missing)
        let b = CVFeatureFusion.peopleSpatialUsefulness(from: boardOnly)
        XCTAssertGreaterThan(g, 0.4)
        XCTAssertGreaterThan(g, o)
        XCTAssertEqual(m, 0, accuracy: 0.001)
        XCTAssertEqual(b, 0, accuracy: 0.001)
        XCTAssertLessThan(o, g - 0.05)
        XCTAssertLessThan(o, 0.55)
    }

    func testCoPresenceScoreGoodVsPeopleNoBoardVsBoardNoPeople() {
        let good = CVFeatureFusion.coPresenceScore(from: .fixtureClassroomPresent())
        let peopleNoBoard = CVFeatureFusion.coPresenceScore(from: .fixturePeopleNoBoard())
        let boardNoPeople = CVFeatureFusion.coPresenceScore(from: .fixtureBoardNoPeople())
        let off = CVFeatureFusion.coPresenceScore(from: .fixturePeopleOffZone())
        XCTAssertGreaterThan(good, 0.55)
        XCTAssertLessThan(peopleNoBoard, 0.25)
        XCTAssertLessThan(boardNoPeople, 0.2)
        XCTAssertGreaterThan(good, off)
        XCTAssertLessThan(off, 0.35)
    }

    func testMidBandOccupancyAndCentroidFromRects() {
        let midPeople = [
            ImageNormalizedRect(x: 0.3, y: 0.4, width: 0.15, height: 0.25),
            ImageNormalizedRect(x: 0.55, y: 0.45, width: 0.12, height: 0.22)
        ]
        let floorPeople = [
            ImageNormalizedRect(x: 0.1, y: 0.88, width: 0.2, height: 0.1)
        ]
        let mid = CVFeatureFusion.midBandOccupancy(personRects: midPeople)
        let floor = CVFeatureFusion.midBandOccupancy(personRects: floorPeople)
        XCTAssertGreaterThan(mid, 0.7)
        XCTAssertLessThan(floor, 0.35)
        let c = CVFeatureFusion.peopleCentroid(personRects: midPeople)
        guard let c else { return XCTFail("Expected people centroid") }
        XCTAssertEqual(c.y, 0.5, accuracy: 0.15)
    }

    func testGeometricCoPresenceFromRects() {
        let board = ImageNormalizedRect(x: 0.2, y: 0.15, width: 0.55, height: 0.3)
        let underBoard = [
            ImageNormalizedRect(x: 0.3, y: 0.5, width: 0.2, height: 0.3)
        ]
        let farCorner = [
            ImageNormalizedRect(x: 0.0, y: 0.9, width: 0.1, height: 0.08)
        ]
        let good = CVFeatureFusion.coPresence(
            board: board, boardConfidence: 0.8, personRects: underBoard, personCoverage: 0.15
        )
        let bad = CVFeatureFusion.coPresence(
            board: board, boardConfidence: 0.8, personRects: farCorner, personCoverage: 0.05
        )
        XCTAssertGreaterThan(good, bad)
        XCTAssertGreaterThan(good, 0.4)
    }

    func testBoardTextSupportHigherWhenTextOverlapsBoard() {
        let board = ImageNormalizedRect(x: 0.2, y: 0.15, width: 0.55, height: 0.3)
        let onBoard = [
            ImageNormalizedRect(x: 0.25, y: 0.2, width: 0.2, height: 0.06),
            ImageNormalizedRect(x: 0.4, y: 0.28, width: 0.18, height: 0.05),
            ImageNormalizedRect(x: 0.3, y: 0.32, width: 0.25, height: 0.05)
        ]
        let offBoard = [
            ImageNormalizedRect(x: 0.05, y: 0.85, width: 0.15, height: 0.04),
            ImageNormalizedRect(x: 0.7, y: 0.9, width: 0.12, height: 0.03)
        ]
        let withText = CVFeatureFusion.boardTextSupport(board: board, textRects: onBoard)
        let without = CVFeatureFusion.boardTextSupport(board: board, textRects: offBoard)
        let empty = CVFeatureFusion.boardTextSupport(board: board, textRects: [])
        XCTAssertGreaterThan(withText, 0.4)
        XCTAssertGreaterThan(withText, without)
        XCTAssertEqual(empty, 0, accuracy: 0.001)
        // Writing-band text without an explicit board still yields moderate support.
        let bandOnly = CVFeatureFusion.boardTextSupport(board: nil, textRects: onBoard)
        XCTAssertGreaterThan(bandOnly, 0.25)
    }

    func testBuildCVFeaturesFromShippedFusionApisMatchesResearchOrdering(){
        buildCVFeaturesFromShippedFusionApisMatchesResearchOrderingAssertions()
    }





    // MARK: - CV feature → shipped guidance (research scenarios)











    /// Steady Vision frames must not drag raw boardConfidence toward multiCue quality.














    func goodFrame() -> FrameMetrics {
        testFusionGoodFrame()
    }
}


private let buildCVFeaturesFromShippedFusionApisMatchesResearchOrderingAssertions: @Sendable () -> Void = {
        // Drive the same pure APIs the Vision adapter feeds - no fixture-only oracle.
        let goodBoard = ImageNormalizedRect(x: 0.22, y: 0.18, width: 0.56, height: 0.32)
        let weakBoard = ImageNormalizedRect(x: 0.85, y: 0.85, width: 0.08, height: 0.1)
        let peopleUnder: [ImageNormalizedRect] = [
            ImageNormalizedRect(x: 0.3, y: 0.52, width: 0.18, height: 0.28),
            ImageNormalizedRect(x: 0.52, y: 0.55, width: 0.14, height: 0.25)
        ]
        let peopleFloor: [ImageNormalizedRect] = [
            ImageNormalizedRect(x: 0.05, y: 0.9, width: 0.12, height: 0.08)
        ]
        let textOnBoard = [
            ImageNormalizedRect(x: 0.28, y: 0.22, width: 0.2, height: 0.05),
            ImageNormalizedRect(x: 0.4, y: 0.3, width: 0.18, height: 0.04)
        ]

        let goodEdge = CVFeatureFusion.fuseBoardEdgeSupport(
            documentOverlap: 0.7,
            saliencyOverlap: 0.5,
            textSupport: CVFeatureFusion.boardTextSupport(board: goodBoard, textRects: textOnBoard),
            geometryFallback: CVFeatureFusion.boardGeometryQuality(for: goodBoard) * 0.2
        )
        let weakEdge = CVFeatureFusion.fuseBoardEdgeSupport(
            documentOverlap: 0.05,
            saliencyOverlap: 0.05,
            textSupport: 0.05,
            geometryFallback: CVFeatureFusion.boardGeometryQuality(for: weakBoard) * 0.2
        )

        let goodCV = CVFeatures.make {
            $0.source = .fixture
            $0.boardConfidence = 0.8
            $0.boardRect = goodBoard
            $0.boardAspectQuality = CVFeatureFusion.boardAspectQuality(for: goodBoard)
            $0.boardGeometryQuality = CVFeatureFusion.boardGeometryQuality(for: goodBoard)
            $0.boardEdgeSupport = goodEdge
            $0.personCount = 2
            $0.personCoverage = peopleUnder.reduce(0) { $0 + $1.area }
            $0.faceCount = 1
            $0.personMidBandOccupancy = CVFeatureFusion.midBandOccupancy(personRects: peopleUnder)
            $0.personCentroidY = CVFeatureFusion.peopleCentroid(personRects: peopleUnder)?.y
            $0.personCentroidX = CVFeatureFusion.peopleCentroid(personRects: peopleUnder)?.x
            $0.personBoardCoPresence = CVFeatureFusion.coPresence(
                board: goodBoard,
                boardConfidence: 0.8,
                personRects: peopleUnder,
                personCoverage: 0.15
            )
            $0.observationStability = 0.9
            $0.analysisSucceeded = true
        }
        let emptyCV = CVFeatures.make {
            $0.source = .fixture
            $0.boardConfidence = 0.1
            $0.boardRect = nil
            $0.boardAspectQuality = 0.1
            $0.boardGeometryQuality = 0.05
            $0.boardEdgeSupport = weakEdge
            $0.personCount = 0
            $0.personCoverage = 0
            $0.analysisSucceeded = true
        }
        let offZoneCV = CVFeatures.make {
            $0.personCount = 1
            $0.personCoverage = peopleFloor[0].area
            $0.faceCount = 0
            $0.personMidBandOccupancy = CVFeatureFusion.midBandOccupancy(personRects: peopleFloor)
            $0.personCentroidY = CVFeatureFusion.peopleCentroid(personRects: peopleFloor)?.y
            $0.personCentroidX = CVFeatureFusion.peopleCentroid(personRects: peopleFloor)?.x
            $0.personBoardCoPresence = CVFeatureFusion.coPresence(
                board: goodBoard,
                boardConfidence: 0.8,
                personRects: peopleFloor,
                personCoverage: 0.05
            )
            $0.source = .fixture
            $0.boardConfidence = 0.8
            $0.boardRect = goodBoard
            $0.boardAspectQuality = CVFeatureFusion.boardAspectQuality(for: goodBoard)
            $0.boardGeometryQuality = CVFeatureFusion.boardGeometryQuality(for: goodBoard)
            $0.boardEdgeSupport = goodEdge
            $0.analysisSucceeded = true
        }

        XCTAssertGreaterThan(goodCV.multiCueBoardQuality, emptyCV.multiCueBoardQuality)
        XCTAssertGreaterThan(goodCV.peopleSpatialUsefulness, offZoneCV.peopleSpatialUsefulness)
        XCTAssertGreaterThan(
            CVFeatureFusion.coPresenceScore(from: goodCV),
            CVFeatureFusion.coPresenceScore(from: offZoneCV)
        )
        XCTAssertGreaterThan(CVFeatureFusion.coPresenceScore(from: goodCV), 0.4)
        XCTAssertEqual(emptyCV.peopleSpatialUsefulness, 0, accuracy: 0.001)
    }
