import Foundation
import XCTest
import SessionCore

/// Persisted consent-scope collections must not depend on the per-process hash seed:
/// the same session or package must produce the same bytes (and digests) on every run.
final class DeterministicEncodingTests: XCTestCase {
    private let allScopes = Set(ConsentScope.allCases)
    private let canonicalScopes = #"["collection","externalSharing","localReflection","researchProcessing","secondaryUse"]"#
    private let fixedDate = Date(timeIntervalSince1970: 1_767_323_045)
    private let grantID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!

    func testConsentGrantEncodesScopesInCanonicalOrder() throws {
        var values = ConsentGrant.Values()
        values.id = grantID
        values.scopes = allScopes
        values.documentIdentifier = "doc"
        values.documentVersion = "1"
        values.participantGroupPseudonym = "group"
        values.grantedAt = fixedDate
        let grant = ConsentGrant(values)

        let json = try encode(grant)
        XCTAssertEqual(
            json,
            #"{"documentIdentifier":"doc","documentVersion":"1","grantedAt":"2026-01-02T03:04:05Z","id":"00000000-0000-0000-0000-0000000000B1","participantGroupPseudonym":"group","scopes":"#
                + canonicalScopes + "}"
        )
        XCTAssertEqual(try decode(ConsentGrant.self, json), grant)
    }

    func testStudyManifestEncodesScopesInCanonicalOrder() throws {
        var values = StudyExportManifest.Values()
        values.includedScopes = allScopes
        let json = try String(decoding: StudyExportManifest(values).canonicalJSONData(), as: UTF8.self)
        XCTAssertTrue(json.contains(#""includedScopes":"# + canonicalScopes), json)
    }

    func testExportEventEncodesScopesInCanonicalOrder() throws {
        var values = ExportEvent.Values()
        values.exportedAt = fixedDate
        values.includedScopes = allScopes
        let event = ExportEvent(values)
        let json = try encode(event)
        XCTAssertTrue(json.contains(#""includedScopes":"# + canonicalScopes), json)
        XCTAssertEqual(try decode(ExportEvent.self, json), event)
    }

    func testAuthorizationSnapshotEncodesScopesAndBindingsInCanonicalOrder() throws {
        var values = CaptureAuthorizationSnapshot.Values()
        values.requiredScopes = allScopes
        values.grantIDs = [grantID]
        values.grantIDByScope = Dictionary(uniqueKeysWithValues: ConsentScope.allCases.map { ($0, grantID) })
        values.preparedAt = fixedDate
        let snapshot = CaptureAuthorizationSnapshot(values)

        let id = grantID.uuidString
        let bindings = ConsentScope.allCases.map(\.rawValue).sorted().map { #""\#($0)","\#(id)""# }
        let json = try encode(snapshot)
        XCTAssertEqual(
            json,
            #"{"grantIDByScope":[\#(bindings.joined(separator: ","))],"grantIDs":["\#(id)"],"preparedAt":"2026-01-02T03:04:05Z","requiredScopes":"#
                + canonicalScopes + "}"
        )
        XCTAssertEqual(try decode(CaptureAuthorizationSnapshot.self, json), snapshot)
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try SessionCoding.canonicalEncoder().encode(value), as: UTF8.self)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try SessionCoding.decoder().decode(type, from: Data(json.utf8))
    }
}
