import XCTest
@testable import GuidanceEngine

/// Gates the scientific-alpha acceptance criteria by driving shipped pure APIs
/// (fixtures → scene → guidance/coding) and asserting production Vision source wiring.
final class AcceptanceCriteriaTests: XCTestCase {

    // MARK: AC1 - Rich presets; same geometry can match one situation and fail another

    func testAC1_presetsDistinctAndSameGeometryDiffersBySituation(){
        aC1_presetsDistinctAndSameGeometryDiffersBySituationAssertions()
    }

    // MARK: AC2 - Structured CV + teaching-scene assessment drive unvalidated rule-set outcomes

    func testAC2_structureCVAndSceneDriveUnvalidatedRuleSetBeyondPlacement() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        let frame = Self.goodFrame() // good placement geometry

        let good = engine.evaluate(experimentalGuidanceInput(
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: .fixtureClassroomPresent(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertEqual(good.scene.sceneType, .boardCentricFrontal)
        XCTAssertTrue(good.scene.matchesPreset)
        XCTAssertGreaterThan(good.cvFeaturesBoardOrScene(), 0.4)
        XCTAssertGreaterThan(good.researchQuality.score, 0.4)
        XCTAssertNotEqual(good.researchQuality.level, .unsuitable)

        let empty = engine.evaluate(experimentalGuidanceInput(
            // same placement metrics
            orientation: orientation,
            frame: frame,
            options: ExperimentalGuidanceOptions(
                cv: .fixtureEmptyRoom(),
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        XCTAssertEqual(empty.scene.sceneType, .emptyOrUnusable)
        XCTAssertFalse(empty.scene.matchesPreset)
        XCTAssertTrue(
            empty.researchQuality.level == .unsuitable
                || empty.researchQuality.level == .needsAdjustment
        )
        XCTAssertFalse(empty.isReadyToRecord)

        // Layout is first-class in scene assessment output.
        XCTAssertNotEqual(good.scene.layoutPattern, .empty)
        XCTAssertGreaterThan(good.scene.layoutSignal, 0)
    }

    // MARK: AC3 - Production Vision adapter (static source evidence of shipped path)

    func testAC3_productionVisionAdapterWiredWithoutInventedStructure() throws {
        let src = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/VisionClassroomAnalyzer.swift",
            additionalPrefixes: ["VisionPeopleObservation"]
        )
        let samplerSrc = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/FrameSampler.swift"
        )
        let cameraSrc = try repositorySwiftSources(
            "App/Unterrichtsvideographie/Live/CameraSessionModel.swift"
        )

        // System Vision models
        assertSource(src, contains: [
            "VNDetectRectanglesRequest",
            "VNDetectHumanRectanglesRequest",
            "VNDetectFaceRectanglesRequest",
            "VNDetectDocumentSegmentationRequest",
            "VNRecognizeTextRequest",
            "VNDetectHumanBodyPoseRequest",
            "VNGenerateAttentionBasedSaliencyImageRequest"
        ], context: "Vision model")
        // Structured feature contract
        assertSource(src, contains: [
            "CVFeatures",
            "boardEdgeSupport",
            "personBoardCoPresence",
            "ClassroomLayoutAnalyzer",
            "layoutPattern",
            "secondaryWritingSurfaceSupport",
            "interactionDensity",
            "analysisSucceeded: false",
            "configure(for:"
        ], context: "feature/wiring")
        // Live path
        XCTAssertTrue(samplerSrc.contains("VisionClassroomAnalyzer"))
        XCTAssertTrue(samplerSrc.contains("analyze(pixelBuffer:"))
        XCTAssertTrue(cameraSrc.contains("teachingSituation"))
        XCTAssertTrue(cameraSrc.contains("recomputeGuidance"))
        XCTAssertTrue(cameraSrc.contains("configureVision") || samplerSrc.contains("configureVision"))
    }

}

private func assertSource(
    _ source: String,
    contains tokens: [String],
    context: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    for token in tokens {
        XCTAssertTrue(source.contains(token), "missing \(context) \(token)", file: file, line: line)
    }
}


private let aC1_presetsDistinctAndSameGeometryDiffersBySituationAssertions: @Sendable () -> Void = {
        XCTAssertGreaterThanOrEqual(
            TeachingSituationCatalogue.count,
            TeachingSituationCatalogue.richMinimumCount
        )
        XCTAssertEqual(TeachingSituationID.allCases.count, TeachingSituationCatalogue.all.count)
        XCTAssertEqual(TeachingSituationID.allCases.count, 12)

        var seen = Set<String>()
        for preset in TeachingSituationCatalogue.all {
            XCTAssertFalse(preset.titleDE.isEmpty)
            XCTAssertFalse(preset.expectedScenes.isEmpty)
            XCTAssertFalse(preset.ipnEmphasis.isEmpty)
            XCTAssertFalse(preset.expectedTIMSSActivities.isEmpty)
            XCTAssertFalse(preset.gtiEmphasis.isEmpty)
            XCTAssertFalse(preset.preferredLayouts.isEmpty)
            XCTAssertFalse(preset.mismatchHintDE.isEmpty)
            XCTAssertTrue(seen.insert(preset.id.rawValue).inserted)
        }

        let geometry = CVFeatures.fixtureClassroomPresent()
        let frontal = TeachingSceneAssessor.assess(
            cv: geometry,
            frame: AcceptanceCriteriaTests.goodFrame(),
            preset: .frontalBoardInstruction
        )
        let group = TeachingSceneAssessor.assess(
            cv: geometry,
            frame: AcceptanceCriteriaTests.goodFrame(),
            preset: .collaborativeGroupWork
        )
        XCTAssertTrue(frontal.matchesPreset, "classroom geometry must match frontal preset")
        XCTAssertGreaterThan(frontal.presetMatchScore, group.presetMatchScore)

        let engine = GuidanceEngine()
        let frontalR = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: AcceptanceCriteriaTests.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: geometry,
                motion: .stable,
                teachingSituation: .frontalBoardInstruction,
                analysisFocus: nil
            )
        ))
        let groupR = engine.evaluate(experimentalGuidanceInput(
            orientation: OrientationSample(pitchDegrees: 2, rollDegrees: 1),
            frame: AcceptanceCriteriaTests.goodFrame(),
            options: ExperimentalGuidanceOptions(
                cv: geometry,
                motion: .stable,
                teachingSituation: .collaborativeGroupWork,
                analysisFocus: nil
            )
        ))
        // Same geometry → different unvalidated rule-set, scene-match, and recording-readiness outcomes.
        XCTAssertNotEqual(frontalR.scene.matchesPreset, groupR.scene.matchesPreset)
        XCTAssertNotEqual(frontalR.researchQuality.sceneMatchScore, groupR.researchQuality.sceneMatchScore)
        XCTAssertTrue(
            frontalR.isReadyToRecord != groupR.isReadyToRecord
                || frontalR.researchQuality.level != groupR.researchQuality.level
                || Set(frontalR.tips.map(\.id)) != Set(groupR.tips.map(\.id)),
            "preset must change tips, recording readiness, or the unvalidated rule-set composite for the same geometry"
        )
    }
