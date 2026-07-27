import Foundation
import XCTest
@testable import GuidanceEngine

final class EvidenceBoundaryTests: XCTestCase {
    func testObservabilityIsInvariantAcrossPresetFocusAndOperatingMode() {
        let engine = GuidanceEngine()
        let orientation = OrientationSample(pitchDegrees: 2, rollDegrees: 1)
        let frame = FrameMetrics()
        let cv = CVFeatures.fixtureClassroomPresent()

        let safe = engine.evaluate(GuidanceInput({
    var values = GuidanceInput.Values(orientation: orientation, frame: frame)
    values.cv = cv
    values.motion = .stable
    values.teachingSituation = .frontalBoardInstruction
    values.analysisFocus = .lessonAnalysis
    values.operatingMode = .evidenceSafe
    return values
}()))
        let experimental = engine.evaluate(GuidanceInput({
    var values = GuidanceInput.Values(orientation: orientation, frame: frame)
    values.cv = cv
    values.motion = .stable
    values.teachingSituation = .collaborativeGroupWork
    values.analysisFocus = .studentThinking
    values.operatingMode = .experimentalResearch(protocolReference: "IRB-2026-01")
    return values
}()))

        XCTAssertEqual(safe.observability, experimental.observability)
        XCTAssertTrue(safe.experimentalHypotheses.hypotheses.isEmpty)
        XCTAssertFalse(experimental.experimentalHypotheses.hypotheses.isEmpty)
        XCTAssertEqual(safe.scene, .unavailable)
        XCTAssertTrue(safe.pedagogicalCoding.ipnDimensions.isEmpty)
        XCTAssertTrue(safe.pedagogicalCoding.timssActivities.isEmpty)
        XCTAssertTrue(safe.pedagogicalCoding.gtiDimensions.isEmpty)
        XCTAssertTrue(safe.researchQuality.dimensions.isEmpty)
        XCTAssertTrue(safe.structureSufficiency.checks.isEmpty)

        let unsupportedFrameworkTerms = [
            "ipn", "timss", "gti", "talis", "framework",
            "unterrichtsqualität", "forschungsqualität", "pädagogische qualität"
        ]
        for tip in safe.tips {
            let copy = "\(tip.message) \(tip.actionHint)".lowercased()
            XCTAssertFalse(
                unsupportedFrameworkTerms.contains { copy.contains($0) },
                "Evidence-safe tip leaked framework or quality wording: \(copy)"
            )
        }
    }

    func testObservabilityExplicitlyAbstainsWhenCVIsUnavailable() {
        let assessment = CaptureObservabilityAssessment.assess(
            orientation: .init(pitchDegrees: 0, rollDegrees: 0),
            frame: .init(),
            cv: .empty,
            motion: .stable
        )

        XCTAssertEqual(Set(assessment.unavailableDimensionIDs), [
            "writingSurface", "actors", "coPresence", "signalStability"
        ])
        XCTAssertFalse(assessment.dimensions.contains { $0.labelDE.contains("Unterrichtsqualität") })
    }

    func testExperimentalHypothesesUseRuleSupportAndUnvalidatedStatus() {
        let result = GuidanceEngine().evaluate(GuidanceInput({
    var values = GuidanceInput.Values(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: .init())
    values.cv = .fixtureClassroomPresent()
    values.motion = .stable
    values.operatingMode = .experimentalResearch(protocolReference: "protocol-v1")
    return values
}()))

        XCTAssertEqual(result.experimentalHypotheses.validationStatus, .unvalidated)
        XCTAssertTrue(result.experimentalHypotheses.hypotheses.allSatisfy { $0.validationStatus == .unvalidated })
        XCTAssertTrue(result.experimentalHypotheses.hypotheses.allSatisfy { $0.ruleSupport >= 0 && $0.ruleSupport <= 1 })
    }

    func testEvidenceRegistryIsDeterministicallyValidAndRejectsForbiddenCopy() {
        XCTAssertEqual(EvidenceClaimRegistry.version, 2)
        XCTAssertEqual(EvidenceClaimRegistry.claims.count, 8)
        XCTAssertTrue(EvidenceClaimRegistry.validate().isEmpty)
        XCTAssertTrue(EvidenceClaimRegistry.claims.allSatisfy { claim in
            !EvidenceClaimRegistry.containsProhibitedWording(claim.allowedWordingDE)
        })
        XCTAssertTrue(EvidenceClaimRegistry.claims.allSatisfy { claim in
            claim.validationTier != .deviceTested
                && claim.validationTier != .humanValidated
                && claim.validationTier != .effectivenessTested
        })
    }

    func testProhibitedCopyMatcherHandlesInflectionsSynonymsAndDiacritics() {
        let unsupportedClaims = [
            "Diese Aufnahme ist forschungstauglich.",
            "Wir liefern forschungsgeeignete Aufnahmen.",
            "Das System ist wissenschaftlich bereit.",
            "Die App hat Unterrichtsqualität erkannt.",
            "Der Pegel ist clipfrei und im guten Arbeitsbereich.",
            "Sprachverständlichkeit geprüft.",
            "Die Aufnahme ist datenschutzkonform.",
            "Das ist eine gültige Einwilligung.",
            "International vergleichbare GTI-Kodierung.",
            "Psychometrisch validierte Kodierungen."
        ]

        for claim in unsupportedClaims {
            XCTAssertTrue(
                EvidenceClaimRegistry.containsProhibitedWording(claim),
                "Expected unsupported positive claim to be rejected: \(claim)"
            )
        }
    }

    func testProhibitedCopyMatcherAllowsExplicitLimitationsAndNegativeLists() {
        let limitations = [
            "Keine forschungstaugliche Aufnahme wird beansprucht.",
            "Die App ist nicht wissenschaftlich bereit.",
            "Clipping wird nicht erkannt.",
            "Der Pegeltest misst weder Sprachverständlichkeit noch Aussetzerfreiheit.",
            "Kein validiertes Kodierinstrument.",
            "Psychometrische Validierung wird ausdrücklich nicht beansprucht.",
            "Die lokale Bestätigung ist keine gültige Einwilligung."
        ]

        for limitation in limitations {
            XCTAssertFalse(
                EvidenceClaimRegistry.containsProhibitedWording(limitation),
                "Expected explicit limitation to remain permitted: \(limitation)"
            )
        }
    }

}
