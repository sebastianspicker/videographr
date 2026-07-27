import XCTest
@testable import GuidanceEngine

/// Contract coverage for unvalidated experimental metadata across all teaching-situation presets.
final class ResearchPackContractTests: XCTestCase {

    // MARK: Preset experimental metadata

    func testAllPresetsHaveCompleteResearchPacks() {
        let packs = TeachingSituationCatalogue.researchPacks
        XCTAssertEqual(packs.count, 12)
        for pack in packs {
            assertResearchPackMetadata(pack)
            assertResearchPackCodesResolve(pack)
        }
        // Distinct threshold profiles exist
        guard let frontal = packs.first(where: { $0.id == .frontalBoardInstruction }),
              let group = packs.first(where: { $0.id == .collaborativeGroupWork }) else {
            return XCTFail("Expected frontal and group research packs")
        }
        XCTAssertGreaterThan(frontal.researchBars.minBoard, group.researchBars.minBoard)
        XCTAssertGreaterThan(group.researchBars.minInteractionDensity, frontal.researchBars.minInteractionDensity - 0.05)
    }

    // MARK: CV signals and scene coverage

    func testCVSignalCompletenessAndFixtureScenes() {
        let good = CVFeatures.fixtureClassroomPresent().researchSignalCompleteness
        XCTAssertGreaterThanOrEqual(good.score, 0.6, good.summaryDE)
        XCTAssertTrue(good.missingSignals.count < good.presentSignals.count)

        let failed = CVFeatures.fixtureAnalysisFailed().researchSignalCompleteness
        XCTAssertEqual(failed.score, 0)
        XCTAssertEqual(failed.missingSignals.count, CVResearchSignalCompleteness.contractSignalIDs.count)

        for row in TeachingSceneExhaustiveness.fixtureSceneExpectations {
            let scene = TeachingSceneAssessor.assess(cv: row.cv(), preset: row.preset)
            XCTAssertTrue(
                row.scenes.contains(scene.sceneType),
                "\(row.fixture): got \(scene.sceneType), expected one of \(row.scenes)"
            )
        }
        XCTAssertGreaterThanOrEqual(TeachingSceneExhaustiveness.classifiableScenes.count, 10)
    }

    func testSameCVDifferentPresetsHaveDifferentSceneMatches() {
        let cv = CVFeatures.fixtureClassroomPresent()
        let results = ExhaustiveResearchEvaluator.evaluateAllPresets(cv: cv)
        XCTAssertEqual(results.count, 12)
        guard let frontal = results.first(where: { $0.pack.id == .frontalBoardInstruction }),
              let group = results.first(where: { $0.pack.id == .collaborativeGroupWork }) else {
            return XCTFail("Expected frontal and group evaluations")
        }
        XCTAssertTrue(frontal.scene.matchesPreset)
        XCTAssertFalse(group.scene.matchesPreset)
        XCTAssertGreaterThan(frontal.structure.score, group.structure.score)
        XCTAssertNotEqual(frontal.satisfiesResearchCapture, group.satisfiesResearchCapture)
    }

    // MARK: Production Vision contract (source wiring)

    func testProductionVisionContractOnDisk() throws {
        let adapter = try repositorySwiftSources(
            ProductionMLContract.adapterRelativePath,
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        let sampler = try repositorySwiftSources(ProductionMLContract.samplerRelativePath)
        for req in ProductionMLContract.visionRequestTypes {
            XCTAssertTrue(adapter.contains(req), "missing Vision request \(req)")
        }
        for sym in ProductionMLContract.livePathSymbols {
            XCTAssertTrue(
                adapter.contains(sym) || sampler.contains(sym),
                "missing live symbol \(sym)"
            )
        }
        for feat in ["secondaryWritingSurfaceSupport", "actorScaleVariance", "poseConfidenceMean",
                     "interactionDensity", "layoutPattern", "boardTextDensity"] {
            XCTAssertTrue(adapter.contains(feat), "missing feature emission \(feat)")
        }
        XCTAssertTrue(adapter.contains("analysisSucceeded: false"))
        XCTAssertTrue(sampler.contains("analyze(pixelBuffer:"))
    }

    // MARK: IPN / TIMSS / GTI completeness and calibration

    func testCodingCompletenessAndCalibration() {
        XCTAssertEqual(IPNDimensionCode.allCases.count, 7)
        XCTAssertEqual(TIMSSActivityCode.allCases.count, 12)
        XCTAssertEqual(GTIQualityCode.allCases.count, 8)
        XCTAssertEqual(ResearchCodebookCatalogue.allEntries.count, 7 + 12 + 8)

        let pairs: [(CVFeatures, TeachingSituationID)] = [
            (.fixtureClassroomPresent(), .frontalBoardInstruction),
            (.fixtureGroupWork(), .collaborativeGroupWork),
            (.fixtureDialoguePair(), .teacherLedDialogue),
            (.fixtureExperimentSpread(), .handsOnExperiment),
            (.fixtureCircleDiscussion(), .circleOrPlenumDiscussion),
            (.fixtureTeacherDemonstration(), .teacherDemonstration),
            (.fixtureFormativeAssessment(), .formativeAssessmentDialogue),
            (.fixtureStudentAtBoard(), .studentBoardPresentation)
        ]
        for (cv, situation) in pairs {
            let ev = ExhaustiveResearchEvaluator.evaluate(cv: cv, teachingSituation: situation)
            XCTAssertTrue(ev.codingCompleteness.isCompleteSoftwareLayer, "\(situation) \(ev.codingCompleteness.summaryDE)")
            XCTAssertEqual(ev.coding.ipnDimensions.count, 7)
            XCTAssertEqual(ev.coding.gtiDimensions.count, 8)
            XCTAssertFalse(ev.coding.timssActivities.isEmpty)
            XCTAssertTrue(
                PedagogicalCalibrationTable.ipnElevationHolds(coding: ev.coding, scene: ev.scene.sceneType),
                "IPN elevation \(situation) scene=\(ev.scene.sceneType)"
            )
            XCTAssertTrue(
                PedagogicalCalibrationTable.gtiElevationHolds(coding: ev.coding, scene: ev.scene.sceneType),
                "GTI elevation \(situation) scene=\(ev.scene.sceneType)"
            )
            XCTAssertFalse(ev.coding.topTIMSS(k: 3).isEmpty)
            XCTAssertFalse(ev.coding.topGTI(k: 3).isEmpty)
        }

        // Honest empty / failed paths
        let empty = ExhaustiveResearchEvaluator.evaluate(
            cv: .fixtureEmptyRoom(),
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(empty.codingCompleteness.honestEmptyPath || empty.coding.ipnDimensions.isEmpty)
        XCTAssertEqual(empty.coding.primaryTIMSS, .unclearOrNonInstructional)

        let failed = ExhaustiveResearchEvaluator.evaluate(
            cv: .fixtureAnalysisFailed(),
            teachingSituation: .frontalBoardInstruction
        )
        XCTAssertTrue(failed.coding.ipnDimensions.isEmpty)
        XCTAssertTrue(failed.coding.gtiDimensions.isEmpty)
        XCTAssertEqual(failed.coding.overallConfidence, 0)
    }

    // MARK: Full integration matrix and readiness

    func testExhaustiveMatrixAndReadiness(){
        exhaustiveMatrixAndReadinessAssertions()
    }

    func testEveryPresetHasFixtureThatCanMatch() {
        // For each preset, at least one default research fixture should match or score well
        let excludedFixtureNames: Set<String> = ["failed", "empty"]
        let fixtures = ResearchStructureMatrixExport.defaultFixtures.filter {
            !excludedFixtureNames.contains($0.name)
        }
        for id in TeachingSituationID.allCases {
            let coverage = researchFixtureCoverage(for: id, fixtures: fixtures)
            XCTAssertTrue(
                [coverage.anyMatch, coverage.bestScore >= 0.4].contains(true),
                "preset \(id) has no usable fixture (best=\(coverage.bestScore))"
            )
        }
    }
}

private func assertResearchPackMetadata(_ pack: TeachingSituationResearchPack) {
    XCTAssertFalse(pack.titleDE.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.expectedScenes.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.ipnEmphasis.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.timssExpected.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.gtiEmphasis.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.preferredLayouts.isEmpty, "\(pack.id)")
    XCTAssertGreaterThanOrEqual(pack.checklistDE.count, 3, "\(pack.id)")
    XCTAssertFalse(pack.captureGuidanceDE.isEmpty, "\(pack.id)")
    XCTAssertFalse(pack.researchAnchorDE.isEmpty, "\(pack.id)")
    let validBoardThreshold = pack.requiresBoard
        ? pack.researchBars.minBoard > 0.2
        : abs(pack.researchBars.minBoard) < 0.001
    XCTAssertTrue(validBoardThreshold, "\(pack.id)")
}

private func assertResearchPackCodesResolve(_ pack: TeachingSituationResearchPack) {
    for raw in pack.ipnEmphasis {
        XCTAssertNotNil(IPNDimensionCode(rawValue: raw), "\(pack.id) ipn \(raw)")
    }
    for raw in pack.timssExpected {
        XCTAssertNotNil(TIMSSActivityCode(rawValue: raw), "\(pack.id) timss \(raw)")
    }
    for raw in pack.gtiEmphasis {
        XCTAssertNotNil(GTIQualityCode(rawValue: raw), "\(pack.id) gti \(raw)")
    }
}

private func researchFixtureCoverage(
    for id: TeachingSituationID,
    fixtures: [(name: String, cv: CVFeatures)]
) -> (bestScore: Double, anyMatch: Bool) {
    var bestScore = 0.0
    var anyMatch = false
    for fixture in fixtures {
        let scene = TeachingSceneAssessor.assess(cv: fixture.cv, preset: id)
        let structure = ResearchStructureAssessor.assess(
            cv: fixture.cv,
            scene: scene,
            teachingSituation: id
        )
        bestScore = max(bestScore, structure.score)
        anyMatch = [anyMatch, scene.matchesPreset, structure.sufficient].contains(true)
    }
    return (bestScore, anyMatch)
}


private let exhaustiveMatrixAndReadinessAssertions: @Sendable () -> Void = {
        // Intended pairs should satisfy the unvalidated capture rule set or show strong structure.
        for pair in ResearchStructureMatrixExport.intendedPairs {
            guard let fixture = ResearchStructureMatrixExport.defaultFixtures.first(where: { $0.name == pair.fixture }) else {
                return XCTFail("Missing fixture \(pair.fixture)")
            }
            let cv = fixture.cv
            let ev = ExhaustiveResearchEvaluator.evaluate(cv: cv, teachingSituation: pair.preset)
            XCTAssertTrue(
                ev.satisfiesResearchCapture
                    || (ev.structure.score >= 0.45 && ev.scene.matchesPreset)
                    || (ev.structure.sufficient && ev.codingCompleteness.isCompleteSoftwareLayer),
                "intended \(pair.fixture)/\(pair.preset): structure=\(ev.structure.score) match=\(ev.scene.matchesPreset) coding=\(ev.codingCompleteness.summaryDE) rq=\(ev.researchQuality.level)"
            )
            XCTAssertTrue(ev.readiness.sceneMatchesPreset || ev.scene.presetMatchScore >= 0.45
                          || ev.structure.score >= 0.4)
        }

        // Full matrix size
        let cells = ResearchStructureMatrixExport.build()
        XCTAssertEqual(
            cells.count,
            TeachingSituationID.allCases.count * ResearchStructureMatrixExport.defaultFixtures.count
        )

        // Guidance surfaces structure + coding for frontal classroom
        let g = GuidanceEngine().evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: FrameMetrics({
                    var values = FrameMetrics.Values()
                    values.averageLuminance = 0.45
                    values.boardRegionScore = 0.55
                    values.boardCenterY = 0.38
                    values.ceilingFraction = 0.12
                    values.floorFraction = 0.12
                    values.backlightScore = 0.1
                    values.emptyEdgeFraction = 0.15
                    values.globalContrast = 0.4
                    return values
                }()),
            options: ExperimentalGuidanceOptions(
                cv: .fixtureClassroomPresent(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: .lessonAnalysis
            )
        ))
        XCTAssertEqual(g.pedagogicalCoding.ipnDimensions.count, 7)
        XCTAssertEqual(g.pedagogicalCoding.gtiDimensions.count, 8)
        XCTAssertFalse(g.structureSufficiency.checks.isEmpty)
        XCTAssertTrue(g.placement.dimensions.contains { $0.id == "teachingScene" })
        XCTAssertTrue(g.placement.dimensions.contains { $0.id == "structureSufficiency" })
        let report = ResearchReadinessReport.build(from: g)
        XCTAssertEqual(report.ipnCount, 7)
        XCTAssertEqual(report.gtiCount, 8)

        // Cross-preset: same geometry different research outcome
        let all = ExhaustiveResearchEvaluator.evaluateAllPresets(cv: .fixtureClassroomPresent())
        let matchCount = all.filter(\.scene.matchesPreset).count
        XCTAssertGreaterThanOrEqual(matchCount, 1)
        XCTAssertLessThan(matchCount, 12, "classroom geometry must not match every preset")
    }
