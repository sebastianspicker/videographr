import XCTest
@testable import SessionCore
import GuidanceEngine
import CryptoKit
#if os(macOS)
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif
#if os(macOS)
#endif

extension SessionCoreTests {
    func testExportEventUsesAccurateShareActivityNameAndDecodesLegacyField() throws {
        let event = ExportEvent({
    var values = ExportEvent.Values()
    values.operatorPseudonym = "operator"
    values.includedScopes = [.collection, .externalSharing]
    values.fileDigests = ["session.json": "digest"]
    values.shareActivityIdentifier = "com.apple.UIKit.activity.Mail"
    return values
}())
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(event)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(
            object["shareActivityIdentifier"] as? String,
            "com.apple.UIKit.activity.Mail"
        )
        XCTAssertNil(object["recipientCategory"])

        object["recipientCategory"] = object.removeValue(forKey: "shareActivityIdentifier")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(ExportEvent.self, from: legacyData)
        XCTAssertEqual(decoded.shareActivityIdentifier, "com.apple.UIKit.activity.Mail")
    }

    func testStudyExportProjectionNormalizesCollectionsAndIsolatesSafeMode(){
        studyExportProjectionNormalizesCollectionsAndIsolatesSafeModeAssertions()
    }

    func testStudyExportProjectionRequiresResearchScopeOnlyForExperimentalArtifacts() {
        let protocolReference = ResearchProtocolReference(
            protocolIdentifier: "study",
            oversightReference: "oversight",
            expiresAt: Date().addingTimeInterval(60)
        )
        let experimental = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = protocolReference
    return values
}())

        let projection = StudyExportProjection.make(from: experimental)

        XCTAssertEqual(projection.session.experimentalProtocol, protocolReference)
        XCTAssertTrue(projection.requiredScopes.contains(.researchProcessing))
        XCTAssertFalse(projection.requiredScopes.contains(.localReflection))
    }

    func testExperimentalProtocolRequiresCurrentProtocolAndResearchScope() {
        let active = ResearchProtocolReference(
            protocolIdentifier: "study",
            oversightReference: "oversight",
            expiresAt: Date().addingTimeInterval(60)
        )
        let expired = ResearchProtocolReference(
            protocolIdentifier: "study",
            oversightReference: "oversight",
            expiresAt: Date().addingTimeInterval(-1)
        )
        let collectionOnly = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection]
    values.documentIdentifier = "consent"
    values.documentVersion = "2"
    values.participantGroupPseudonym = "group"
    return values
}())
        let research = ConsentGrant({
    var values = ConsentGrant.Values()
    values.scopes = [.collection, .localReflection, .researchProcessing]
    values.documentIdentifier = "consent"
    values.documentVersion = "2"
    values.participantGroupPseudonym = "group"
    return values
}())

        XCTAssertFalse(CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = active
    values.consentGrants = [collectionOnly]
    return values
}()).hasUsableExperimentalProtocol)
        XCTAssertFalse(CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = expired
    values.consentGrants = [research]
    return values
}()).hasUsableExperimentalProtocol)
        XCTAssertTrue(CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .experimentalResearch
    values.experimentalProtocol = active
    values.consentGrants = [research]
    return values
}()).hasUsableExperimentalProtocol)
    }

    @discardableResult
    func writeSessionFixture(
        _ session: CaptureSession,
        to directory: URL,
        fileID: UUID? = nil
    ) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = directory.appendingPathComponent("\((fileID ?? session.id).uuidString).json")
        try encoder.encode(session).write(to: url, options: .atomic)
        return url
    }

}


private let studyExportProjectionNormalizesCollectionsAndIsolatesSafeModeAssertions: @Sendable () -> Void = {
        let scene = TeachingSceneAssessor.assess(
            cv: .fixtureClassroomPresent(), preset: .frontalBoardInstruction
        )
        let coding = PedagogicalCoder.code(
            cv: .fixtureClassroomPresent(), scene: scene,
            teachingSituation: .frontalBoardInstruction
        )
        let snapshot = ResearchCodingSnapshot.from(
            coding: coding, scene: scene, provenance: testResearchProvenance
        )
        let mediaID = UUID()
        var session = CaptureSession({
    var values = CaptureSession.Values()
    values.operatingMode = .evidenceSafe
    values.experimentalProtocol = ResearchProtocolReference(
                protocolIdentifier: "must-not-export",
                oversightReference: "must-not-export",
                expiresAt: Date().addingTimeInterval(60)
            )
    values.evidenceAnnotations = [EvidenceAnnotation({
    var values = EvidenceAnnotation.Values()
    values.promptIdentifier = "lessonGoals"
    values.mediaAssetID = mediaID
    values.startMilliseconds = 1_000
    values.note = "fixture"
    values.authorPseudonym = "tester"
    return values
}())]
    values.captureObservations = [CaptureObservation({
    var values = CaptureObservation.Values()
    values.kind = .periodic
    return values
}())]
    return values
}())
        session.latestCodingSnapshot = snapshot
        session.codingSnapshots = [snapshot]
        session.reflection.lessonGoals = "fixture"

        let projection = StudyExportProjection.make(from: session)

        XCTAssertNil(projection.session.latestCodingSnapshot)
        XCTAssertTrue(projection.session.codingSnapshots.isEmpty)
        XCTAssertNil(projection.session.experimentalProtocol)
        XCTAssertTrue(projection.session.evidenceAnnotations.isEmpty)
        XCTAssertTrue(projection.session.captureObservations.isEmpty)
        XCTAssertEqual(projection.annotations.count, 1)
        XCTAssertEqual(projection.observations.count, 1)
        XCTAssertEqual(
            projection.requiredScopes,
            [.collection, .localReflection, .secondaryUse, .externalSharing]
        )
    }
