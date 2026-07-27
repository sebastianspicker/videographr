import XCTest
@testable import GuidanceEngine

extension CVAndMetricsTests {
    func testTemporalSmootherRaisesStabilityOnConsistentSeries() {
        var smoother = CVObservationSmoother(alpha: 0.4)
        var lastStability = 0.0
        for _ in 0..<6 {
            let out = smoother.push(.fixtureClassroomPresent())
            lastStability = out.observationStability
        }
        XCTAssertGreaterThan(lastStability, 0.7)

        var jitter = CVObservationSmoother(alpha: 0.5)
        let series: [CVFeatures] = [
            .fixtureClassroomPresent(),
            .fixtureEmptyRoom(),
            .fixtureClassroomPresent(),
            .fixtureEmptyRoom(),
            .fixtureBoardNoPeople(),
            .fixturePeopleNoBoard()
        ]
        var unstable = 1.0
        for f in series {
            unstable = jitter.push(f).observationStability
        }
        XCTAssertLessThan(unstable, lastStability)
        XCTAssertLessThan(unstable, 0.75)

        let staticScore = CVObservationSmoother.stabilityScore(
            boardSeries: [0.8, 0.82, 0.79, 0.81],
            peopleSeries: [0.6, 0.58, 0.61, 0.59]
        )
        let noisyScore = CVObservationSmoother.stabilityScore(
            boardSeries: [0.9, 0.1, 0.85, 0.05],
            peopleSeries: [0.7, 0.0, 0.65, 0.05]
        )
        XCTAssertGreaterThan(staticScore, noisyScore)
        XCTAssertGreaterThan(staticScore, 0.7)
    }

    func testEffectiveBoardScoreUsesMultiCueOverWeakHeuristic() {
        let frame = testFrameWithWeakBoardPosition()
        let cv = CVFeatures.fixtureClassroomPresent()
        let score = CVFeatureFusion.effectiveBoardScore(frame: frame, cv: cv)
        XCTAssertGreaterThan(score, 0.55)
        let c = CVFeatureFusion.effectiveBoardCenter(frame: frame, cv: cv)
        guard let board = cv.boardRect else { return XCTFail("Expected fixture board") }
        XCTAssertEqual(c.x, board.centerX, accuracy: 0.01)
    }

    func testFixtureEmptyRoomYieldsPeopleOrBoardTips() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureEmptyRoom(),
                motion: .stable
            )
        )
        XCTAssertTrue(
            result.tips.contains { $0.id == "people-missing" || $0.id == "board-missing" },
            "tips=\(result.tips.map(\.id))"
        )
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        let people = result.placement.dimensions.first { $0.id == "people" }
        XCTAssertEqual(people?.ok, false)
    }

    func testFixtureClassroomPresentImprovesPeopleDimension() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureClassroomPresent(),
                motion: .stable
            )
        )
        let people = result.placement.dimensions.first { $0.id == "people" }
        XCTAssertEqual(people?.ok, true)
        XCTAssertFalse(result.tips.contains { $0.id == "people-missing" })
        XCTAssertFalse(result.tips.contains { $0.id == "people-off-zone" })
        XCTAssertFalse(result.tips.contains { $0.id == "copresence-weak" })
    }

    func testPeopleNoBoardFixture() {
        var frame = goodFrame()
        frame.boardRegionScore = 0.1
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 0, rollDegrees: 0),
                frame: frame,
                cv: .fixturePeopleNoBoard(),
                motion: .stable
            )
        )
        XCTAssertTrue(result.tips.contains { $0.id == "board-missing" })
        let people = result.placement.dimensions.first { $0.id == "people" }
        XCTAssertEqual(people?.ok, true)
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
    }

    func testBoardNoPeopleFixtureFailsPeopleAndReadiness() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureBoardNoPeople(),
                motion: .stable
            )
        )
        XCTAssertTrue(
            result.tips.contains { $0.id == "people-missing" },
            "tips=\(result.tips.map(\.id))"
        )
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "people" }?.ok, false)
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "board" }?.ok, true)
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        XCTAssertFalse(result.isReadyToRecord)
    }

    func testPeopleOffZoneYieldsSpatialOrCopresenceTips() {
        let cv = CVFeatures.fixturePeopleOffZone()
        // Fixture is designed as mid-band failure (Lehr-Lern zone), not mere missing count.
        XCTAssertLessThan(cv.personMidBandOccupancy, GuidanceConfig.default.minPersonMidBandOccupancy)
        XCTAssertTrue(cv.hasPeople)

        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: cv,
                motion: .stable
            )
        )
        XCTAssertTrue(
            result.tips.contains { $0.id == "people-off-zone" },
            "tips=\(result.tips.map(\.id))"
        )
        // Placement people dimension must fail off-zone (aligned with tip mid-band gate).
        let people = result.placement.dimensions.first { $0.id == "people" }
        XCTAssertEqual(people?.ok, false, "detail=\(people?.detailDE ?? "nil")")
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        XCTAssertFalse(result.isReadyToRecord)
    }

    func testSmootherDoesNotBlendBoardConfidenceTowardMultiCue() {
        // conf high, multi-cue moderate (aspect/geometry/edge weak relative to conf).
        let steady = CVFeatures.make {
            $0.source = .fixture
            $0.boardConfidence = 0.90
            $0.boardRect = ImageNormalizedRect(x: 0.25, y: 0.2, width: 0.5, height: 0.28)
            $0.boardAspectQuality = 0.20
            $0.boardGeometryQuality = 0.15
            $0.boardEdgeSupport = 0.10
            $0.personCount = 2
            $0.personCoverage = 0.12
            $0.faceCount = 1
            $0.personMidBandOccupancy = 0.6
            $0.personCentroidY = 0.55
            $0.personCentroidX = 0.5
            $0.personBoardCoPresence = 0.5
            $0.observationStability = 1
            $0.analysisSucceeded = true
        }
        let multiCue = steady.multiCueBoardQuality
        // 0.4*0.9 + 0.22*0.2 + 0.22*0.15 + 0.16*0.1 ≈ 0.453
        XCTAssertLessThan(multiCue, 0.55, "fixture must keep multiCue well below conf=0.9; got \(multiCue)")
        XCTAssertGreaterThan(multiCue, 0.35)
        XCTAssertEqual(steady.boardConfidence, 0.90, accuracy: 1e-9)

        var smoother = CVObservationSmoother(alpha: 0.35)
        var last = steady
        for _ in 0..<8 {
            last = smoother.push(steady)
        }
        // Like-with-like: confidence stays at the steady conf, never pulled toward multiCue (~0.45).
        XCTAssertEqual(last.boardConfidence, 0.90, accuracy: 0.02)
        XCTAssertGreaterThan(last.boardConfidence, multiCue + 0.25)
        // multiCue from output must still reflect aspect/geometry fields, not inflated by conf rewrite.
        XCTAssertEqual(last.multiCueBoardQuality, multiCue, accuracy: 0.02)
        // Regression: pre-fix bug produced conf≈0.57 by blending toward multiCue EMA.
        XCTAssertGreaterThan(last.boardConfidence, 0.85)
    }

    func testUnstableCVObservationSurfacesTipAndStabilityDimension() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureUnstableObservation(),
                motion: .stable
            )
        )
        XCTAssertTrue(
            result.tips.contains { $0.id == "cv-unstable" },
            "tips=\(result.tips.map(\.id))"
        )
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "stability" }?.ok, false)
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
    }

    func testUnstableMotionYieldsMotionTip() {
        let motion = MotionMetrics(
            angularSpeedDegreesPerSecond: 40,
            isStable: false,
            smoothedAngularSpeed: 35
        )
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureClassroomPresent(),
                motion: motion
            )
        )
        let tip = result.tips.first { $0.id == "motion-unstable" }
        XCTAssertNotNil(tip)
        XCTAssertEqual(tip?.category, .motion)
        XCTAssertNotEqual(result.placement.quality, .directSignalsPass)
        XCTAssertEqual(result.placement.dimensions.first { $0.id == "stability" }?.ok, false)
    }

    func testStableCVAndMotionSupportRecordingReadiness() {
        let result = engine.evaluate(
            experimentalGuidanceInput(
                orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                frame: goodFrame(),
                cv: .fixtureClassroomPresent(),
                motion: .stable
            )
        )
        XCTAssertEqual(result.placement.quality, .directSignalsPass, "tips=\(result.tips.map { "\($0.id):\($0.severity)" })")
        XCTAssertTrue(result.placement.dimensions.allSatisfy(\.ok))
        XCTAssertTrue(result.isReadyToRecord)
        // Direct-signal dimensions are present and OK when CV succeeds.
        for id in ["board", "people", "interaction", "stability"] {
            XCTAssertEqual(result.placement.dimensions.first { $0.id == id }?.ok, true, id)
        }
    }

    func testInteractionZoneScoreBoostedByCoPresence() {
        let o = OrientationSample(pitchDegrees: 1, rollDegrees: 1)
        let frame = goodFrame()
        let good = PlacementAssessment.interactionZoneScore(
            frame: frame, orientation: o, cv: .fixtureClassroomPresent()
        )
        let off = PlacementAssessment.interactionZoneScore(
            frame: frame, orientation: o, cv: .fixturePeopleOffZone()
        )
        let empty = PlacementAssessment.interactionZoneScore(
            frame: frame, orientation: o, cv: .fixtureEmptyRoom()
        )
        XCTAssertGreaterThan(good, off)
        XCTAssertGreaterThan(good, empty)
    }

    func testCVFusionPrefersVisionBoardCenter() {
        let frame = testFrameWithWeakBoardPosition()
        let cv = CVFeatures.fixtureClassroomPresent()
        let score = CVFeatureFusion.effectiveBoardScore(frame: frame, cv: cv)
        XCTAssertGreaterThan(score, 0.7)
        let c = CVFeatureFusion.effectiveBoardCenter(frame: frame, cv: cv)
        guard let board = cv.boardRect else { return XCTFail("Expected fixture board") }
        XCTAssertEqual(c.x, board.centerX, accuracy: 0.01)
    }

    func testGermanActionableTipsForResearchScenarios() {
        let scenarios: [(name: String, cv: CVFeatures, tipIDs: Set<String>, boardScore: Double)] = [
            ("empty", .fixtureEmptyRoom(), ["people-missing"], 0.75),
            ("boardOnly", .fixtureBoardNoPeople(), ["people-missing"], 0.75),
            ("peopleNoBoard", .fixturePeopleNoBoard(), ["board-missing"], 0.1),
            ("offZone", .fixturePeopleOffZone(), ["people-off-zone", "copresence-weak"], 0.75)
        ]
        let actionableTerms = ["tafel", "person", "lehr", "interaktion", "kamera", "standort"]

        for scenario in scenarios {
            var frame = goodFrame()
            frame.boardRegionScore = scenario.boardScore
            let result = engine.evaluate(
                experimentalGuidanceInput(
                    orientation: .init(pitchDegrees: 1, rollDegrees: 1),
                    frame: frame,
                    cv: scenario.cv,
                    motion: .stable
                )
            )
            guard let tip = result.tips.first(where: { scenario.tipIDs.contains($0.id) }) else {
                XCTFail("\(scenario.name): missing \(scenario.tipIDs); tips=\(result.tips.map(\.id))")
                continue
            }
            XCTAssertFalse(tip.message.isEmpty, scenario.name)
            XCTAssertFalse(tip.actionHint.isEmpty, scenario.name)
            let blob = (tip.message + tip.actionHint).lowercased()
            XCTAssertTrue(
                actionableTerms.contains(where: blob.contains),
                "\(scenario.name): tip not research-actionable DE: \(blob)"
            )
        }
    }
}
