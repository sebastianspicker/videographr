import Foundation
import GuidanceEngine
import XCTest
@testable import SessionCore

/// Freezes the persisted and exported byte-level formats. Literals below were generated once from
/// the current implementation; a failure here means a stored or exported format changed.
final class PersistedFormatContractTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_767_323_045) // 2026-01-02T03:04:05Z
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!

    // MARK: - Study package manifest

    func testStudyManifestCanonicalJSONIsFrozen() throws {
        let manifest = fixtureManifest()
        let expected = #"{"contentFiles":["annotations.jsonl","coding-snapshots.jsonl","observations.jsonl","session.json"],"fileDigests":{"annotations.jsonl":"0000000000000000000000000000000000000000000000000000000000000000","coding-snapshots.jsonl":"1111111111111111111111111111111111111111111111111111111111111111","observations.jsonl":"2222222222222222222222222222222222222222222222222222222222222222","session.json":"3333333333333333333333333333333333333333333333333333333333333333"},"generatedAt":"2026-01-02T03:04:05Z","includedScopes":["collection","secondaryUse"],"operatingMode":"evidenceSafe","provenance":{"algorithmVersion":"fixture-algorithm","buildNumber":"1","evidenceRegistryVersion":"fixture-registry","schemaVersion":2,"semanticVersion":"1.0.0"},"schemaVersion":3,"sessionID":"00000000-0000-0000-0000-0000000000A1"}"#
        XCTAssertEqual(String(decoding: try manifest.canonicalJSONData(), as: UTF8.self), expected)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(StudyExportManifest.self, from: Data(expected.utf8))
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.schemaVersion, 3)
        XCTAssertEqual(decoded.sessionID, sessionID)
        XCTAssertEqual(decoded.generatedAt, fixedDate)
        XCTAssertEqual(decoded.includedScopes, [.collection, .secondaryUse])
        XCTAssertEqual(StudyExportManifest.schemaVersion, 3)
    }

    func testStudyPackageMemberNamesAndLimitsAreFrozen() {
        XCTAssertEqual(StudyPackageContract.manifestFile, "manifest.json")
        XCTAssertEqual(
            StudyPackageContract.expectedContentFiles,
            ["annotations.jsonl", "coding-snapshots.jsonl", "observations.jsonl", "session.json"]
        )
        XCTAssertEqual(
            StudyPackageContract.expectedPackageFiles,
            ["manifest.json", "annotations.jsonl", "coding-snapshots.jsonl", "observations.jsonl", "session.json"]
        )
        XCTAssertEqual(StudyPackageContract.maximumContentFileBytes, 33_554_432)
    }

    func testStudyPackageFailureCodesAreFrozen() {
        var manifest = fixtureManifest()
        let files = Dictionary(uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.map {
            ($0, Data($0.utf8))
        })
        manifest.schemaVersion = 0
        manifest.operatingMode = .experimentalResearch
        manifest.contentFiles = []
        manifest.fileDigests = [:]
        manifest.includedScopes = []
        manifest.provenance.algorithmVersion = nil
        XCTAssertEqual(
            StudyPackageContract.validate(manifest: manifest, expectedSessionID: UUID(), fileData: files),
            [
                "digest-mismatch:annotations.jsonl", "digest-mismatch:coding-snapshots.jsonl",
                "digest-mismatch:observations.jsonl", "digest-mismatch:session.json",
                "experimental-scope-missing", "incomplete-generator-provenance",
                "missing-required-scope", "session-mismatch", "unexpected-content-files",
                "unexpected-digest-files", "unsupported-schema"
            ]
        )
    }

    // MARK: - Session metadata

    private let frozenSessionJSON = """
    {
      "analysisIntent" : "lessonAnalysis",
      "captureDecisions" : [],
      "captureObservations" : [],
      "codingSnapshots" : [],
      "codingTimeline" : { "minSegmentSeconds" : 3, "segments" : [] },
      "consent" : {
        "informedParticipantsAcknowledged" : false,
        "secondaryUseAcknowledged" : false,
        "storageResponsibilityAcknowledged" : false
      },
      "consentGrants" : [],
      "context" : { "gradeLevel" : "", "lessonGoal" : "", "notes" : "", "schoolOrSite" : "", "subject" : "" },
      "createdAt" : "2026-01-02T03:04:05Z",
      "evidenceAnnotations" : [],
      "exportEvents" : [],
      "id" : "00000000-0000-0000-0000-0000000000A1",
      "mediaAssets" : [],
      "operatingMode" : "evidenceSafe",
      "plannedDurationMinutes" : 45,
      "purpose" : "ownTeaching",
      "reflection" : {
        "alternatives" : "",
        "instructionalStrategies" : "",
        "lessonGoals" : "",
        "studentLearningEvidence" : ""
      },
      "retentionPolicy" : { "actionAfterExpiry" : "manualReview" },
      "schemaVersion" : 2,
      "takeManifests" : [],
      "teachingSituation" : "frontalBoardInstruction",
      "title" : "Neue Aufnahme",
      "updatedAt" : "2026-01-02T03:04:05Z"
    }
    """

    func testSessionMetadataFileMatchesFrozenCurrentSchema() throws {
        let root = try makeRoot()
        let store = SessionStore(rootDirectory: root)
        try store.save(fixtureSession())

        let url = root.appendingPathComponent("\(sessionID.uuidString).json")
        var onDisk = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        // `save` stamps `updatedAt` with the wall clock; every other key is deterministic.
        XCTAssertNotNil(onDisk.removeValue(forKey: "updatedAt") as? String)
        var frozen = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(frozenSessionJSON.utf8)) as? [String: Any]
        )
        frozen.removeValue(forKey: "updatedAt")
        XCTAssertEqual(Set(onDisk.keys), Set(frozen.keys))
        XCTAssertEqual(onDisk as NSDictionary, frozen as NSDictionary)
    }

    func testFrozenCurrentSchemaSessionDecodesAndReencodesWithSameKeys() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CaptureSession.self, from: Data(frozenSessionJSON.utf8))
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(SessionSchema.currentVersion, 2)
        XCTAssertEqual(decoded.id, sessionID)
        XCTAssertEqual(decoded.createdAt, fixedDate)
        XCTAssertEqual(decoded.title, "Neue Aufnahme")
        XCTAssertEqual(decoded.plannedDurationMinutes, 45)
        XCTAssertEqual(decoded.purpose, .ownTeaching)
        XCTAssertEqual(decoded.analysisIntent, .lessonAnalysis)
        XCTAssertEqual(decoded.teachingSituation, .frontalBoardInstruction)
        XCTAssertEqual(decoded.operatingMode, .evidenceSafe)
        XCTAssertEqual(decoded.retentionPolicy, RetentionPolicy())
        XCTAssertEqual(decoded, fixtureSession())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reencoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(decoded)) as? [String: Any]
        )
        let frozen = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(frozenSessionJSON.utf8)) as? [String: Any]
        )
        XCTAssertEqual(Set(reencoded.keys), Set(frozen.keys))
        XCTAssertEqual(reencoded as NSDictionary, frozen as NSDictionary)
    }

    func testLegacySessionWithoutSchemaVersionDecodesAsVersionOneAndMigratesOnRequest() throws {
        let legacy = """
        {
          "id": "00000000-0000-0000-0000-0000000000A1",
          "createdAt": "2026-01-02T03:04:05Z",
          "updatedAt": "2026-01-02T03:04:05Z",
          "title": "Legacy",
          "purpose": "ownTeaching",
          "analysisIntent": "lessonAnalysis",
          "context": { "gradeLevel": "", "lessonGoal": "", "notes": "", "schoolOrSite": "", "subject": "" },
          "consent": {
            "informedParticipantsAcknowledged": true,
            "secondaryUseAcknowledged": true,
            "storageResponsibilityAcknowledged": true
          },
          "recordingRelativePath": "legacy-take.mp4",
          "reflection": { "alternatives": "", "instructionalStrategies": "", "lessonGoals": "", "studentLearningEvidence": "" }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var decoded = try decoder.decode(CaptureSession.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.plannedDurationMinutes, 45)
        XCTAssertEqual(decoded.teachingSituation, .frontalBoardInstruction)
        XCTAssertEqual(decoded.operatingMode, .evidenceSafe)
        XCTAssertEqual(decoded.retentionPolicy, RetentionPolicy())
        XCTAssertEqual(decoded.recordingRelativePath, "legacy-take.mp4")
        XCTAssertEqual(decoded.mediaAssets.map(\.relativePath), ["legacy-take.mp4"])
        XCTAssertEqual(decoded.mediaAssets.map(\.role), [.ownRecorded])
        XCTAssertTrue(decoded.consentGrants.isEmpty)
        XCTAssertTrue(decoded.captureObservations.isEmpty)
        XCTAssertTrue(decoded.codingSnapshots.isEmpty)
        XCTAssertFalse(decoded.authorizes(.collection))

        decoded.migrateLegacyDataIfNeeded()
        XCTAssertEqual(decoded.schemaVersion, SessionSchema.currentVersion)
        XCTAssertEqual(decoded.mediaAssets.map(\.relativePath), ["legacy-take.mp4"])
        XCTAssertTrue(decoded.consentGrants.isEmpty)
    }

    // MARK: - Persisted enum raw values

    func testPersistedEnumRawValuesAreFrozen() {
        XCTAssertEqual(OperatingMode.allCases.map(\.rawValue), ["evidenceSafe", "experimentalResearch"])
        XCTAssertEqual(MediaAssetRole.allCases.map(\.rawValue), ["ownRecorded", "otherImported"])
        XCTAssertEqual(
            ConsentScope.allCases.map(\.rawValue),
            ["collection", "localReflection", "researchProcessing", "secondaryUse", "externalSharing"]
        )
        XCTAssertEqual(CapturePurpose.allCases.map(\.rawValue), ["ownTeaching", "otherTeaching", "mixed"])
        XCTAssertEqual(
            AnalysisIntent.allCases.map(\.rawValue),
            ["professionalVision", "classroomManagement", "studentThinking", "lessonAnalysis", "documentationOnly"]
        )
        XCTAssertEqual(
            CodingAnalysisFocus.allCases.map(\.rawValue),
            ["professionalVision", "classroomManagement", "studentThinking", "lessonAnalysis", "documentationOnly"]
        )
        XCTAssertEqual(
            TeachingSituationID.allCases.map(\.rawValue),
            [
                "frontalBoardInstruction", "teacherLedDialogue", "collaborativeGroupWork", "partnerWork",
                "studentBoardPresentation", "handsOnExperiment", "classroomManagementOverview",
                "circleOrPlenumDiscussion", "individualSeatwork", "teacherDemonstration",
                "transitionOrganization", "formativeAssessmentDialogue"
            ]
        )
        XCTAssertEqual(
            ReflectionPromptID.allCases.map(\.rawValue),
            ["lessonGoals", "studentLearningEvidence", "instructionalStrategies", "alternatives"]
        )
    }

    func testPersistedEnumsWithoutCaseIterableKeepTheirRawValues() {
        let observationKinds: [(CaptureObservationKind, String)] = [
            (.periodic, "periodic"), (.transition, "transition"), (.interruption, "interruption"),
            (.audioRouteChange, "audioRouteChange"), (.error, "error"), (.missing, "missing")
        ]
        observationKinds.forEach { XCTAssertEqual($0.0.rawValue, $0.1) }
        let exportStatuses: [(ExportEventStatus, String)] = [
            (.attempted, "attempted"), (.completed, "completed"), (.cancelled, "cancelled"),
            (.failed, "failed"), (.outcomeUnknown, "outcomeUnknown")
        ]
        exportStatuses.forEach { XCTAssertEqual($0.0.rawValue, $0.1) }
        let lifecycleStates: [(CaptureTakeLifecycleState, String)] = [
            (.prepared, "prepared"), (.recording, "recording"), (.completionUnknown, "completionUnknown"),
            (.finalized, "finalized"), (.failed, "failed")
        ]
        lifecycleStates.forEach { XCTAssertEqual($0.0.rawValue, $0.1) }
        XCTAssertEqual(RetentionPolicy().actionAfterExpiry, "manualReview")
    }

    // MARK: - On-disk layout and journal bytes

    func testStoreLayoutAndJournalNamingAreFrozen() throws {
        let root = try makeRoot()
        let store = SessionStore(rootDirectory: root)
        let id = sessionID.uuidString
        try store.save(fixtureSession(codingSnapshots: [fixtureSnapshot()]))
        try store.appendCaptureObservation(fixtureObservation(), toSession: sessionID)

        let source = root.appendingPathComponent("source.mp4")
        try Data("synthetic".utf8).write(to: source)
        let asset = try store.importMedia(from: source, into: sessionID)
        let marker = "Recordings/.videographr-import-\(id)-\(asset.id.uuidString).pending"
        let media = "Recordings/\(asset.id.uuidString).mp4"
        XCTAssertEqual(asset.relativePath, "\(asset.id.uuidString).mp4")
        XCTAssertEqual(try relativeFiles(in: root), [
            "\(id).json", "CodingSnapshots", "CodingSnapshots/\(id).jsonl", "Observations",
            "Observations/\(id).jsonl", "Recordings", marker, media, "source.mp4"
        ])

        var imported = fixtureSession(codingSnapshots: [fixtureSnapshot()])
        imported.mediaAssets = [asset]
        try store.save(imported)
        try store.commitImportedMedia(asset, toSession: sessionID)
        XCTAssertEqual(try relativeFiles(in: root), [
            "\(id).json", "CodingSnapshots", "CodingSnapshots/\(id).jsonl", "Observations",
            "Observations/\(id).jsonl", "Recordings", media, "source.mp4"
        ])
    }

    func testObservationJournalLineBytesAreFrozen() throws {
        let root = try makeRoot()
        let store = SessionStore(rootDirectory: root)
        try store.save(fixtureSession())
        try store.appendCaptureObservation(fixtureObservation(), toSession: sessionID)

        let journal = root.appendingPathComponent("Observations/\(sessionID.uuidString).jsonl")
        let expected = #"{"id":"00000000-0000-0000-0000-0000000000B1","kind":"audioRouteChange","measurements":{"alpha":1,"zeta":0.5},"missingReason":"none","note":"n","observedAt":"2026-01-02T03:04:05Z"}"# + "\n"
        XCTAssertEqual(String(decoding: try Data(contentsOf: journal), as: UTF8.self), expected)
        XCTAssertEqual(try store.loadCaptureObservations(forSession: sessionID), [fixtureObservation()])
    }

    func testCodingSnapshotJournalLineBytesAreFrozen() throws {
        let root = try makeRoot()
        let store = SessionStore(rootDirectory: root)
        try store.save(fixtureSession(codingSnapshots: [fixtureSnapshot()]))

        let journal = root.appendingPathComponent("CodingSnapshots/\(sessionID.uuidString).jsonl")
        let expected = #"{"appVersion":"1.0.0 (1)","boardSignal":0,"coPresenceSignal":0,"createdAt":"2026-01-02T03:04:05Z","gti":[],"id":"00000000-0000-0000-0000-0000000000C1","ipn":[],"layoutPattern":"","layoutSignal":0,"matchesPreset":false,"overallConfidence":0,"peopleSignal":0,"presetMatchScore":0,"primaryGTI":"","primaryTIMSS":"","provenance":{"algorithmVersion":"a","buildNumber":"1","evidenceRegistryVersion":"r","schemaVersion":1,"semanticVersion":"1.0.0"},"sceneConfidence":0,"sceneType":"","summaryDE":"","teachingSituation":"","timss":[]}"# + "\n"
        XCTAssertEqual(String(decoding: try Data(contentsOf: journal), as: UTF8.self), expected)
        XCTAssertEqual(try store.loadCodingSnapshots(forSession: sessionID), [fixtureSnapshot()])
    }

    // MARK: - Fully populated session metadata

    /// Every nested persisted type populated with fixed values, generated once with
    /// `SessionCoding.sessionFileEncoder()` from `populatedFixtureSession()`.
    private let frozenPopulatedSessionJSON = """
    {
      "analysisIntent" : "classroomManagement",
      "buildProvenance" : {
        "algorithmVersion" : "fixture-algorithm",
        "buildNumber" : "45",
        "evidenceRegistryVersion" : "fixture-registry",
        "schemaVersion" : 2,
        "semanticVersion" : "1.2.3"
      },
      "captureDecisions" : [
        {
          "blockers" : [
            "batteryLow",
            "spokenAudioPlaybackCheckMissing"
          ],
          "decidedAt" : "2026-01-02T03:04:25Z",
          "operatingMode" : "experimentalResearch",
          "operatorAuthenticationMethod" : "deviceOwnerAuthentication",
          "operatorPseudonym" : "operator-a",
          "overrideReason" : "synthetic override"
        }
      ],
      "captureObservations" : [
        {
          "id" : "00000000-0000-0000-0000-0000000000B2",
          "kind" : "periodic",
          "measurements" : {
            "audioPeak" : 0.25,
            "level" : 0.5
          },
          "missingReason" : "Nicht verfügbar: actors",
          "note" : "note",
          "observedAt" : "2026-01-02T03:04:45Z"
        }
      ],
      "codingSnapshots" : [
        {
          "analysisFocus" : "classroomManagement",
          "appVersion" : "1.2.3 (45)",
          "boardSignal" : 0.125,
          "coPresenceSignal" : 0.375,
          "createdAt" : "2026-01-02T03:04:35Z",
          "gti" : [
            {
              "code" : "discourseQuality",
              "confidence" : 0.125,
              "family" : "gti",
              "id" : "gti-1",
              "labelDE" : "Diskurs",
              "level" : 0.25,
              "rationaleDE" : "r-gti"
            }
          ],
          "id" : "00000000-0000-0000-0000-0000000000C2",
          "ipn" : [
            {
              "code" : "learningSupport",
              "confidence" : 0.25,
              "family" : "ipn",
              "id" : "ipn-1",
              "labelDE" : "Unterstützung",
              "level" : 0.5,
              "rationaleDE" : "r-ipn"
            }
          ],
          "layoutPattern" : "pairs",
          "layoutSignal" : 0.875,
          "matchesPreset" : true,
          "overallConfidence" : 0.25,
          "peopleSignal" : 0.625,
          "presetMatchScore" : 0.75,
          "primaryGTI" : "discourseQuality",
          "primaryTIMSS" : "partnerWork",
          "provenance" : {
            "algorithmVersion" : "fixture-algorithm",
            "buildNumber" : "45",
            "evidenceRegistryVersion" : "fixture-registry",
            "schemaVersion" : 1,
            "semanticVersion" : "1.2.3"
          },
          "sceneConfidence" : 0.5,
          "sceneType" : "dialoguePair",
          "summaryDE" : "Synthetische Zusammenfassung",
          "teachingSituation" : "partnerWork",
          "timss" : [
            {
              "code" : "partnerWork",
              "confidence" : 0.5,
              "family" : "timss",
              "id" : "timss-1",
              "labelDE" : "Partnerarbeit",
              "level" : 0.75,
              "rationaleDE" : "r-timss"
            }
          ]
        }
      ],
      "codingTimeline" : {
        "minSegmentSeconds" : 2,
        "segments" : [
          {
            "durationSeconds" : 60,
            "endedAt" : "2026-01-02T03:05:35Z",
            "id" : "00000000-0000-0000-0000-0000000000D1",
            "layoutPattern" : "pairs",
            "overallConfidence" : 0.25,
            "presetMatchScore" : 0.75,
            "primaryGTI" : "discourseQuality",
            "primaryTIMSS" : "partnerWork",
            "sceneType" : "dialoguePair",
            "snapshot" : {
              "analysisFocus" : "classroomManagement",
              "appVersion" : "1.2.3 (45)",
              "boardSignal" : 0.125,
              "coPresenceSignal" : 0.375,
              "createdAt" : "2026-01-02T03:04:35Z",
              "gti" : [
                {
                  "code" : "discourseQuality",
                  "confidence" : 0.125,
                  "family" : "gti",
                  "id" : "gti-1",
                  "labelDE" : "Diskurs",
                  "level" : 0.25,
                  "rationaleDE" : "r-gti"
                }
              ],
              "id" : "00000000-0000-0000-0000-0000000000C2",
              "ipn" : [
                {
                  "code" : "learningSupport",
                  "confidence" : 0.25,
                  "family" : "ipn",
                  "id" : "ipn-1",
                  "labelDE" : "Unterstützung",
                  "level" : 0.5,
                  "rationaleDE" : "r-ipn"
                }
              ],
              "layoutPattern" : "pairs",
              "layoutSignal" : 0.875,
              "matchesPreset" : true,
              "overallConfidence" : 0.25,
              "peopleSignal" : 0.625,
              "presetMatchScore" : 0.75,
              "primaryGTI" : "discourseQuality",
              "primaryTIMSS" : "partnerWork",
              "provenance" : {
                "algorithmVersion" : "fixture-algorithm",
                "buildNumber" : "45",
                "evidenceRegistryVersion" : "fixture-registry",
                "schemaVersion" : 1,
                "semanticVersion" : "1.2.3"
              },
              "sceneConfidence" : 0.5,
              "sceneType" : "dialoguePair",
              "summaryDE" : "Synthetische Zusammenfassung",
              "teachingSituation" : "partnerWork",
              "timss" : [
                {
                  "code" : "partnerWork",
                  "confidence" : 0.5,
                  "family" : "timss",
                  "id" : "timss-1",
                  "labelDE" : "Partnerarbeit",
                  "level" : 0.75,
                  "rationaleDE" : "r-timss"
                }
              ]
            },
            "startedAt" : "2026-01-02T03:04:35Z"
          }
        ]
      },
      "consent" : {
        "acknowledgedAt" : "2026-01-02T03:04:07Z",
        "informedParticipantsAcknowledged" : true,
        "secondaryUseAcknowledged" : true,
        "storageResponsibilityAcknowledged" : true
      },
      "consentGrants" : [
        {
          "documentIdentifier" : "doc",
          "documentVersion" : "2",
          "expiresAt" : "2026-01-03T03:04:05Z",
          "grantedAt" : "2026-01-02T03:04:06Z",
          "id" : "00000000-0000-0000-0000-0000000000E1",
          "participantGroupPseudonym" : "group-a",
          "scopes" : [
            "collection",
            "externalSharing",
            "localReflection",
            "researchProcessing",
            "secondaryUse"
          ],
          "withdrawnAt" : "2026-01-02T15:04:05Z"
        }
      ],
      "context" : {
        "gradeLevel" : "9",
        "lessonGoal" : "Ziel",
        "notes" : "Notizen",
        "schoolOrSite" : "Schule",
        "subject" : "Physik"
      },
      "createdAt" : "2026-01-02T03:04:05Z",
      "evidenceAnnotations" : [
        {
          "authorPseudonym" : "author-a",
          "createdAt" : "2026-01-02T03:05:45Z",
          "endMilliseconds" : 5000,
          "id" : "00000000-0000-0000-0000-0000000000A4",
          "lockedAt" : "2026-01-02T03:06:05Z",
          "mediaAssetID" : "00000000-0000-0000-0000-0000000000A2",
          "note" : "Synthetische Notiz",
          "promptIdentifier" : "studentLearningEvidence",
          "revisedAt" : "2026-01-02T03:05:55Z",
          "startMilliseconds" : 1000
        }
      ],
      "experimentalProtocol" : {
        "disclosureAcknowledgedAt" : "2026-01-02T03:04:08Z",
        "expiresAt" : "2026-01-03T03:04:05Z",
        "oversightReference" : "oversight-1",
        "protocolIdentifier" : "protocol-1"
      },
      "exportEvents" : [
        {
          "completedAt" : "2026-01-02T03:07:35Z",
          "exportedAt" : "2026-01-02T03:07:25Z",
          "failureDescription" : "synthetic failure",
          "fileDigests" : {
            "session.json" : "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"
          },
          "id" : "00000000-0000-0000-0000-0000000000A5",
          "includedScopes" : [
            "collection",
            "externalSharing",
            "secondaryUse"
          ],
          "operatorAuthenticationMethod" : "deviceOwnerAuthentication",
          "operatorPseudonym" : "group-a",
          "shareActivityIdentifier" : "system-share",
          "status" : "failed"
        }
      ],
      "id" : "00000000-0000-0000-0000-0000000000A1",
      "latestCodingSnapshot" : {
        "analysisFocus" : "classroomManagement",
        "appVersion" : "1.2.3 (45)",
        "boardSignal" : 0.125,
        "coPresenceSignal" : 0.375,
        "createdAt" : "2026-01-02T03:04:35Z",
        "gti" : [
          {
            "code" : "discourseQuality",
            "confidence" : 0.125,
            "family" : "gti",
            "id" : "gti-1",
            "labelDE" : "Diskurs",
            "level" : 0.25,
            "rationaleDE" : "r-gti"
          }
        ],
        "id" : "00000000-0000-0000-0000-0000000000C2",
        "ipn" : [
          {
            "code" : "learningSupport",
            "confidence" : 0.25,
            "family" : "ipn",
            "id" : "ipn-1",
            "labelDE" : "Unterstützung",
            "level" : 0.5,
            "rationaleDE" : "r-ipn"
          }
        ],
        "layoutPattern" : "pairs",
        "layoutSignal" : 0.875,
        "matchesPreset" : true,
        "overallConfidence" : 0.25,
        "peopleSignal" : 0.625,
        "presetMatchScore" : 0.75,
        "primaryGTI" : "discourseQuality",
        "primaryTIMSS" : "partnerWork",
        "provenance" : {
          "algorithmVersion" : "fixture-algorithm",
          "buildNumber" : "45",
          "evidenceRegistryVersion" : "fixture-registry",
          "schemaVersion" : 1,
          "semanticVersion" : "1.2.3"
        },
        "sceneConfidence" : 0.5,
        "sceneType" : "dialoguePair",
        "summaryDE" : "Synthetische Zusammenfassung",
        "teachingSituation" : "partnerWork",
        "timss" : [
          {
            "code" : "partnerWork",
            "confidence" : 0.5,
            "family" : "timss",
            "id" : "timss-1",
            "labelDE" : "Partnerarbeit",
            "level" : 0.75,
            "rationaleDE" : "r-timss"
          }
        ]
      },
      "mediaAssets" : [
        {
          "codec" : "hvc1",
          "createdAt" : "2026-01-02T03:04:15Z",
          "durationMilliseconds" : 61000,
          "frameRate" : 30,
          "id" : "00000000-0000-0000-0000-0000000000A2",
          "originalFileName" : "ownRecorded.mov",
          "relativePath" : "00000000-0000-0000-0000-0000000000A2.mp4",
          "resolution" : "1920×1080",
          "role" : "ownRecorded",
          "sha256" : "abababababababababababababababababababababababababababababababab"
        },
        {
          "codec" : "hvc1",
          "createdAt" : "2026-01-02T03:04:15Z",
          "durationMilliseconds" : 61000,
          "frameRate" : 30,
          "id" : "00000000-0000-0000-0000-0000000000A3",
          "originalFileName" : "otherImported.mov",
          "relativePath" : "00000000-0000-0000-0000-0000000000A3.mp4",
          "resolution" : "1920×1080",
          "role" : "otherImported",
          "sha256" : "abababababababababababababababababababababababababababababababab"
        }
      ],
      "operatingMode" : "experimentalResearch",
      "plannedDurationMinutes" : 50,
      "purpose" : "mixed",
      "recordingRelativePath" : "legacy-take.mp4",
      "reflection" : {
        "alternatives" : "Alternativen",
        "instructionalStrategies" : "Strategien",
        "lessonGoals" : "Ziele",
        "studentLearningEvidence" : "Evidenz",
        "updatedAt" : "2026-01-02T03:06:15Z"
      },
      "retentionPolicy" : {
        "actionAfterExpiry" : "delete",
        "retainUntil" : "2027-01-02T03:04:05Z"
      },
      "schemaVersion" : 2,
      "takeManifests" : [
        {
          "audioConfiguration" : {
            "route" : "builtInMic",
            "sampleRate" : "48000"
          },
          "authorization" : {
            "effectiveExpiresAt" : "2026-01-03T03:04:05Z",
            "grantIDByScope" : [
              "collection",
              "00000000-0000-0000-0000-0000000000E1",
              "localReflection",
              "00000000-0000-0000-0000-0000000000E1",
              "researchProcessing",
              "00000000-0000-0000-0000-0000000000E1"
            ],
            "grantIDs" : [
              "00000000-0000-0000-0000-0000000000E1"
            ],
            "preparedAt" : "2026-01-02T03:04:24Z",
            "requiredScopes" : [
              "collection",
              "localReflection",
              "researchProcessing"
            ],
            "researchProtocolIdentifier" : "protocol-1"
          },
          "cameraConfiguration" : {
            "format" : "1920x1080",
            "frameRate" : "30"
          },
          "decision" : {
            "blockers" : [
              "batteryLow",
              "spokenAudioPlaybackCheckMissing"
            ],
            "decidedAt" : "2026-01-02T03:04:25Z",
            "operatingMode" : "experimentalResearch",
            "operatorAuthenticationMethod" : "deviceOwnerAuthentication",
            "operatorPseudonym" : "operator-a",
            "overrideReason" : "synthetic override"
          },
          "deviceDescription" : "synthetic-device",
          "durationMilliseconds" : 61000,
          "endedAt" : "2026-01-02T03:05:26Z",
          "failureReason" : "synthetic failure",
          "finalizedAt" : "2026-01-02T03:05:27Z",
          "id" : "00000000-0000-0000-0000-0000000000F1",
          "lifecycleState" : "failed",
          "mediaAssetID" : "00000000-0000-0000-0000-0000000000A2",
          "operatingSystemVersion" : "17.0",
          "provenance" : {
            "algorithmVersion" : "fixture-algorithm",
            "buildNumber" : "45",
            "evidenceRegistryVersion" : "fixture-registry",
            "schemaVersion" : 2,
            "semanticVersion" : "1.2.3"
          },
          "sessionID" : "00000000-0000-0000-0000-0000000000A1",
          "startedAt" : "2026-01-02T03:04:25Z"
        }
      ],
      "teachingSituation" : "partnerWork",
      "title" : "Synthetische Sitzung",
      "updatedAt" : "2026-01-02T03:09:05Z"
    }
    """

    private let snapshotKeys: Set<String> = [
        "analysisFocus", "appVersion", "boardSignal", "coPresenceSignal", "createdAt", "gti", "id", "ipn",
        "layoutPattern", "layoutSignal", "matchesPreset", "overallConfidence", "peopleSignal", "presetMatchScore",
        "primaryGTI", "primaryTIMSS", "provenance", "sceneConfidence", "sceneType", "summaryDE", "teachingSituation",
        "timss"
    ]
    private let codeRowKeys: Set<String> = ["code", "confidence", "family", "id", "labelDE", "level", "rationaleDE"]
    private let provenanceKeys: Set<String> = ["algorithmVersion", "buildNumber", "evidenceRegistryVersion", "schemaVersion", "semanticVersion"]

    /// Exact key set of every JSON object in the populated session; `[]` marks array elements.
    private var populatedSessionKeySets: [String: Set<String>] {
        [
            "": [
                "analysisIntent", "buildProvenance", "captureDecisions", "captureObservations", "codingSnapshots",
                "codingTimeline", "consent", "consentGrants", "context", "createdAt", "evidenceAnnotations",
                "experimentalProtocol", "exportEvents", "id", "latestCodingSnapshot", "mediaAssets", "operatingMode",
                "plannedDurationMinutes", "purpose", "recordingRelativePath", "reflection", "retentionPolicy",
                "schemaVersion", "takeManifests", "teachingSituation", "title", "updatedAt"
            ],
            "buildProvenance": provenanceKeys,
            "captureDecisions[]": [
                "blockers", "decidedAt", "operatingMode", "operatorAuthenticationMethod", "operatorPseudonym",
                "overrideReason"
            ],
            "captureObservations[]": ["id", "kind", "measurements", "missingReason", "note", "observedAt"],
            "captureObservations[].measurements": ["audioPeak", "level"],
            "codingSnapshots[]": snapshotKeys,
            "codingSnapshots[].gti[]": codeRowKeys,
            "codingSnapshots[].ipn[]": codeRowKeys,
            "codingSnapshots[].provenance": provenanceKeys,
            "codingSnapshots[].timss[]": codeRowKeys,
            "codingTimeline": ["minSegmentSeconds", "segments"],
            "codingTimeline.segments[]": [
                "durationSeconds", "endedAt", "id", "layoutPattern", "overallConfidence", "presetMatchScore",
                "primaryGTI", "primaryTIMSS", "sceneType", "snapshot", "startedAt"
            ],
            "codingTimeline.segments[].snapshot": snapshotKeys,
            "codingTimeline.segments[].snapshot.gti[]": codeRowKeys,
            "codingTimeline.segments[].snapshot.ipn[]": codeRowKeys,
            "codingTimeline.segments[].snapshot.provenance": provenanceKeys,
            "codingTimeline.segments[].snapshot.timss[]": codeRowKeys,
            "consent": [
                "acknowledgedAt", "informedParticipantsAcknowledged", "secondaryUseAcknowledged",
                "storageResponsibilityAcknowledged"
            ],
            "consentGrants[]": [
                "documentIdentifier", "documentVersion", "expiresAt", "grantedAt", "id", "participantGroupPseudonym",
                "scopes", "withdrawnAt"
            ],
            "context": ["gradeLevel", "lessonGoal", "notes", "schoolOrSite", "subject"],
            "evidenceAnnotations[]": [
                "authorPseudonym", "createdAt", "endMilliseconds", "id", "lockedAt", "mediaAssetID", "note",
                "promptIdentifier", "revisedAt", "startMilliseconds"
            ],
            "experimentalProtocol": ["disclosureAcknowledgedAt", "expiresAt", "oversightReference", "protocolIdentifier"],
            "exportEvents[]": [
                "completedAt", "exportedAt", "failureDescription", "fileDigests", "id", "includedScopes",
                "operatorAuthenticationMethod", "operatorPseudonym", "shareActivityIdentifier", "status"
            ],
            "exportEvents[].fileDigests": ["session.json"],
            "latestCodingSnapshot": snapshotKeys,
            "latestCodingSnapshot.gti[]": codeRowKeys,
            "latestCodingSnapshot.ipn[]": codeRowKeys,
            "latestCodingSnapshot.provenance": provenanceKeys,
            "latestCodingSnapshot.timss[]": codeRowKeys,
            "mediaAssets[]": [
                "codec", "createdAt", "durationMilliseconds", "frameRate", "id", "originalFileName", "relativePath",
                "resolution", "role", "sha256"
            ],
            "reflection": ["alternatives", "instructionalStrategies", "lessonGoals", "studentLearningEvidence", "updatedAt"],
            "retentionPolicy": ["actionAfterExpiry", "retainUntil"],
            "takeManifests[]": [
                "audioConfiguration", "authorization", "cameraConfiguration", "decision", "deviceDescription",
                "durationMilliseconds", "endedAt", "failureReason", "finalizedAt", "id", "lifecycleState",
                "mediaAssetID", "operatingSystemVersion", "provenance", "sessionID", "startedAt"
            ],
            "takeManifests[].audioConfiguration": ["route", "sampleRate"],
            "takeManifests[].authorization": [
                "effectiveExpiresAt", "grantIDByScope", "grantIDs", "preparedAt", "requiredScopes",
                "researchProtocolIdentifier"
            ],
            "takeManifests[].cameraConfiguration": ["format", "frameRate"],
            "takeManifests[].decision": [
                "blockers", "decidedAt", "operatingMode", "operatorAuthenticationMethod", "operatorPseudonym",
                "overrideReason"
            ],
            "takeManifests[].provenance": provenanceKeys,
        ]
    }

    func testPopulatedSessionEncodesToFrozenStructure() throws {
        let encoded = try JSONSerialization.jsonObject(
            with: SessionCoding.sessionFileEncoder().encode(populatedFixtureSession())
        )
        let frozen = try JSONSerialization.jsonObject(with: Data(frozenPopulatedSessionJSON.utf8))
        XCTAssertEqual(try XCTUnwrap(encoded as? NSDictionary), try XCTUnwrap(frozen as? NSDictionary))
    }

    func testFrozenPopulatedSessionDecodesAndReencodesUnchanged() throws {
        let frozenData = Data(frozenPopulatedSessionJSON.utf8)
        let decoded = try SessionCoding.decoder().decode(CaptureSession.self, from: frozenData)
        XCTAssertEqual(decoded, try populatedFixtureSession())

        let reencoded = try JSONSerialization.jsonObject(with: SessionCoding.sessionFileEncoder().encode(decoded))
        let frozen = try JSONSerialization.jsonObject(with: frozenData)
        XCTAssertEqual(try XCTUnwrap(reencoded as? NSDictionary), try XCTUnwrap(frozen as? NSDictionary))
    }

    func testPopulatedSessionNestedKeySetsAreFrozen() throws {
        let frozen = try JSONSerialization.jsonObject(with: Data(frozenPopulatedSessionJSON.utf8))
        let encoded = try JSONSerialization.jsonObject(
            with: SessionCoding.sessionFileEncoder().encode(populatedFixtureSession())
        )
        for object in [frozen, encoded] {
            var keySets: [String: Set<String>] = [:]
            collectKeySets(object, path: "", into: &keySets)
            XCTAssertEqual(Set(keySets.keys), Set(populatedSessionKeySets.keys))
            for (path, keys) in populatedSessionKeySets {
                XCTAssertEqual(keySets[path], keys, "key set of \(path.isEmpty ? "<session>" : path)")
            }
        }
    }

    // MARK: - Direct measurement keys

    func testRealObservabilityDimensionIDsAreThePersistedMeasurementKeys() {
        let audio = AudioLevelSample(AudioLevelSample.Values())
        let audioKeys: Set<String> = ["audioPeak", "audioAverage", "audioDropoutDetected"]

        var measured = GuidanceInput.Values(orientation: .init(pitchDegrees: 0, rollDegrees: 0), frame: FrameMetrics())
        measured.cv = CVFeatures(CVFeatures.Values())
        let guidance = GuidanceEngine().evaluate(GuidanceInput(measured))
        XCTAssertEqual(
            guidance.observability.dimensions.map(\.id),
            ["level", "stability", "exposure", "writingSurface", "actors", "coPresence", "signalStability"]
        )
        XCTAssertEqual(
            Set(CaptureObservation.directMeasurements(guidance: guidance, audio: audio).keys),
            audioKeys.union(["level", "stability", "exposure", "writingSurface", "actors", "coPresence", "signalStability"])
        )

        // Without structural analysis the unavailable dimensions are omitted, never zero-filled.
        let unavailable = GuidanceEngine().evaluate(GuidanceInput(.init(
            orientation: .init(pitchDegrees: 0, rollDegrees: 0),
            frame: FrameMetrics()
        )))
        XCTAssertEqual(
            Set(CaptureObservation.directMeasurements(guidance: unavailable, audio: audio).keys),
            audioKeys.union(["level", "stability", "exposure"])
        )
    }

    // MARK: - Fixtures

    private func fixtureManifest() -> StudyExportManifest {
        StudyExportManifest({
            var values = StudyExportManifest.Values()
            values.sessionID = sessionID
            values.generatedAt = fixedDate
            values.provenance = BuildProvenance({
                var provenance = BuildProvenance.Values()
                provenance.semanticVersion = "1.0.0"
                provenance.buildNumber = "1"
                provenance.algorithmVersion = "fixture-algorithm"
                provenance.evidenceRegistryVersion = "fixture-registry"
                return provenance
            }())
            values.fileDigests = Dictionary(
                uniqueKeysWithValues: StudyPackageContract.expectedContentFiles.enumerated().map {
                    ($0.element, String(repeating: String($0.offset), count: 64))
                }
            )
            values.includedScopes = [.collection, .secondaryUse]
            return values
        }())
    }

    private func fixtureSession(codingSnapshots: [ResearchCodingSnapshot] = []) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.id = sessionID
            values.createdAt = fixedDate
            values.updatedAt = fixedDate
            values.codingSnapshots = codingSnapshots
            return values
        }())
    }

    private func fixtureObservation() -> CaptureObservation {
        CaptureObservation({
            var values = CaptureObservation.Values()
            values.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
            values.observedAt = fixedDate
            values.kind = .audioRouteChange
            values.measurements = ["zeta": 0.5, "alpha": 1]
            values.missingReason = "none"
            values.note = "n"
            return values
        }())
    }

    private func fixtureSnapshot() -> ResearchCodingSnapshot {
        var values = ResearchCodingSnapshot.Values(provenance: ResearchArtifactProvenance((
            semanticVersion: "1.0.0", buildNumber: "1", schemaVersion: 1,
            algorithmVersion: "a", evidenceRegistryVersion: "r"
        )))
        values.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        values.createdAt = fixedDate
        return ResearchCodingSnapshot(values)
    }

    private func populatedDate(_ offset: TimeInterval) -> Date { fixedDate.addingTimeInterval(offset) }

    private func populatedID(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)")!
    }

    private func populatedProvenance() -> BuildProvenance {
        BuildProvenance({
            var values = BuildProvenance.Values()
            values.semanticVersion = "1.2.3"
            values.buildNumber = "45"
            values.algorithmVersion = "fixture-algorithm"
            values.evidenceRegistryVersion = "fixture-registry"
            return values
        }())
    }

    private func populatedSnapshot() -> ResearchCodingSnapshot {
        var values = ResearchCodingSnapshot.Values(provenance: ResearchArtifactProvenance((
            semanticVersion: "1.2.3", buildNumber: "45", schemaVersion: 1,
            algorithmVersion: "fixture-algorithm", evidenceRegistryVersion: "fixture-registry"
        )))
        values.id = populatedID("C2")
        values.createdAt = populatedDate(30)
        values.teachingSituation = "partnerWork"
        values.analysisFocus = "classroomManagement"
        values.sceneType = "dialoguePair"
        values.layoutPattern = "pairs"
        values.presetMatchScore = 0.75
        values.matchesPreset = true
        values.sceneConfidence = 0.5
        values.primaryTIMSS = "partnerWork"
        values.primaryGTI = "discourseQuality"
        values.overallConfidence = 0.25
        values.summaryDE = "Synthetische Zusammenfassung"
        values.ipn = [ResearchCodeRow(
            id: "ipn-1", family: "ipn", code: "learningSupport",
            labelDE: "Unterstützung", level: 0.5, confidence: 0.25, rationaleDE: "r-ipn"
        )]
        values.timss = [ResearchCodeRow(
            id: "timss-1", family: "timss", code: "partnerWork",
            labelDE: "Partnerarbeit", level: 0.75, confidence: 0.5, rationaleDE: "r-timss"
        )]
        values.gti = [ResearchCodeRow(
            id: "gti-1", family: "gti", code: "discourseQuality",
            labelDE: "Diskurs", level: 0.25, confidence: 0.125, rationaleDE: "r-gti"
        )]
        values.boardSignal = 0.125
        values.peopleSignal = 0.625
        values.coPresenceSignal = 0.375
        values.layoutSignal = 0.875
        return ResearchCodingSnapshot(values)
    }

    private func populatedTimeline(snapshot: ResearchCodingSnapshot) throws -> CodingSegmentTimeline {
        var values = CodingSegment.Values()
        values.id = populatedID("D1")
        values.startedAt = populatedDate(30)
        values.endedAt = populatedDate(90)
        values.durationSeconds = 60
        values.sceneType = "dialoguePair"
        values.layoutPattern = "pairs"
        values.primaryTIMSS = "partnerWork"
        values.primaryGTI = "discourseQuality"
        values.presetMatchScore = 0.75
        values.overallConfidence = 0.25
        values.snapshot = snapshot
        // Segments are append-only through `observe`, which mints random IDs; decode a fixed one.
        let segment = String(decoding: try SessionCoding.canonicalEncoder().encode(CodingSegment(values)), as: UTF8.self)
        let timeline = #"{"minSegmentSeconds":2,"segments":["# + segment + "]}"
        return try SessionCoding.decoder().decode(CodingSegmentTimeline.self, from: Data(timeline.utf8))
    }

    private func populatedMediaAsset(role: MediaAssetRole, suffix: String) -> SessionMediaAsset {
        var values = SessionMediaAsset.Values()
        values.id = populatedID(suffix)
        values.role = role
        values.relativePath = "\(values.id.uuidString).mp4"
        values.originalFileName = "\(role.rawValue).mov"
        values.durationMilliseconds = 61_000
        values.sha256 = String(repeating: "ab", count: 32)
        values.codec = "hvc1"
        values.resolution = "1920×1080"
        values.frameRate = 30
        values.createdAt = populatedDate(10)
        return SessionMediaAsset(values)
    }

    private func populatedGrant() -> ConsentGrant {
        var values = ConsentGrant.Values()
        values.id = populatedID("E1")
        values.scopes = Set(ConsentScope.allCases)
        values.documentIdentifier = "doc"
        values.documentVersion = "2"
        values.participantGroupPseudonym = "group-a"
        values.grantedAt = populatedDate(1)
        values.expiresAt = populatedDate(86_400)
        values.withdrawnAt = populatedDate(43_200)
        return ConsentGrant(values)
    }

    private func populatedDecision() -> CaptureDecision {
        var values = CaptureDecision.Values()
        values.decidedAt = populatedDate(20)
        values.blockers = ["spokenAudioPlaybackCheckMissing", "batteryLow"]
        values.overrideReason = "synthetic override"
        values.operatorPseudonym = "operator-a"
        values.operatingMode = .experimentalResearch
        values.operatorAuthenticationMethod = "deviceOwnerAuthentication"
        return CaptureDecision(values)
    }

    private func populatedTakeManifest() -> CaptureTakeManifest {
        var authorization = CaptureAuthorizationSnapshot.Values()
        authorization.requiredScopes = [.collection, .localReflection, .researchProcessing]
        authorization.grantIDs = [populatedID("E1")]
        authorization.grantIDByScope = [
            .collection: populatedID("E1"), .localReflection: populatedID("E1"), .researchProcessing: populatedID("E1")
        ]
        authorization.effectiveExpiresAt = populatedDate(86_400)
        authorization.preparedAt = populatedDate(19)
        authorization.researchProtocolIdentifier = "protocol-1"

        var values = CaptureTakeManifest.Values()
        values.id = populatedID("F1")
        values.sessionID = sessionID
        values.mediaAssetID = populatedID("A2")
        values.startedAt = populatedDate(20)
        values.endedAt = populatedDate(81)
        values.durationMilliseconds = 61_000
        values.decision = populatedDecision()
        values.provenance = populatedProvenance()
        values.cameraConfiguration = ["format": "1920x1080", "frameRate": "30"]
        values.audioConfiguration = ["route": "builtInMic", "sampleRate": "48000"]
        values.deviceDescription = "synthetic-device"
        values.operatingSystemVersion = "17.0"
        values.finalizedAt = populatedDate(82)
        values.lifecycleState = .failed
        values.authorization = CaptureAuthorizationSnapshot(authorization)
        values.failureReason = "synthetic failure"
        return CaptureTakeManifest(values)
    }

    private func populatedObservation() -> CaptureObservation {
        var values = CaptureObservation.Values()
        values.id = populatedID("B2")
        values.observedAt = populatedDate(40)
        values.kind = .periodic
        values.measurements = ["level": 0.5, "audioPeak": 0.25]
        values.missingReason = "Nicht verfügbar: actors"
        values.note = "note"
        return CaptureObservation(values)
    }

    private func populatedAnnotation() -> EvidenceAnnotation {
        var values = EvidenceAnnotation.Values()
        values.id = populatedID("A4")
        values.promptIdentifier = "studentLearningEvidence"
        values.mediaAssetID = populatedID("A2")
        values.startMilliseconds = 1_000
        values.endMilliseconds = 5_000
        values.note = "Synthetische Notiz"
        values.authorPseudonym = "author-a"
        values.createdAt = populatedDate(100)
        values.revisedAt = populatedDate(110)
        values.lockedAt = populatedDate(120)
        return EvidenceAnnotation(values)
    }

    private func populatedExportEvent() -> ExportEvent {
        var values = ExportEvent.Values()
        values.id = populatedID("A5")
        values.exportedAt = populatedDate(200)
        values.operatorPseudonym = "group-a"
        values.operatorAuthenticationMethod = "deviceOwnerAuthentication"
        values.includedScopes = [.collection, .secondaryUse, .externalSharing]
        values.fileDigests = ["session.json": String(repeating: "cd", count: 32)]
        values.shareActivityIdentifier = "system-share"
        values.status = .failed
        values.completedAt = populatedDate(210)
        values.failureDescription = "synthetic failure"
        return ExportEvent(values)
    }

    private func populatedFixtureSession() throws -> CaptureSession {
        let snapshot = populatedSnapshot()
        var values = CaptureSession.Values()
        values.id = sessionID
        values.createdAt = fixedDate
        values.updatedAt = populatedDate(300)
        values.title = "Synthetische Sitzung"
        values.plannedDurationMinutes = 50
        values.purpose = .mixed
        values.analysisIntent = .classroomManagement
        values.teachingSituation = .partnerWork
        values.context = SessionContext({
            var context = SessionContext.Values()
            context.subject = "Physik"
            context.gradeLevel = "9"
            context.lessonGoal = "Ziel"
            context.schoolOrSite = "Schule"
            context.notes = "Notizen"
            return context
        }())
        values.consent = ConsentRecord(
            informedParticipantsAcknowledged: true,
            secondaryUseAcknowledged: true,
            storageResponsibilityAcknowledged: true,
            acknowledgedAt: populatedDate(2)
        )
        values.recordingRelativePath = "legacy-take.mp4"
        values.reflection = ReflectionAnswers({
            var reflection = ReflectionAnswers.Values()
            reflection.lessonGoals = "Ziele"
            reflection.studentLearningEvidence = "Evidenz"
            reflection.instructionalStrategies = "Strategien"
            reflection.alternatives = "Alternativen"
            reflection.updatedAt = populatedDate(130)
            return reflection
        }())
        values.latestCodingSnapshot = snapshot
        values.codingSnapshots = [snapshot]
        values.codingTimeline = try populatedTimeline(snapshot: snapshot)
        values.operatingMode = .experimentalResearch
        values.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "protocol-1",
            oversightReference: "oversight-1",
            expiresAt: populatedDate(86_400),
            disclosureAcknowledgedAt: populatedDate(3)
        )
        values.mediaAssets = [
            populatedMediaAsset(role: .ownRecorded, suffix: "A2"),
            populatedMediaAsset(role: .otherImported, suffix: "A3")
        ]
        values.evidenceAnnotations = [populatedAnnotation()]
        values.captureDecisions = [populatedDecision()]
        values.takeManifests = [populatedTakeManifest()]
        values.captureObservations = [populatedObservation()]
        values.consentGrants = [populatedGrant()]
        values.retentionPolicy = RetentionPolicy(retainUntil: populatedDate(31_536_000), actionAfterExpiry: "delete")
        values.exportEvents = [populatedExportEvent()]
        values.buildProvenance = populatedProvenance()
        return CaptureSession(values)
    }

    private func collectKeySets(_ value: Any, path: String, into keySets: inout [String: Set<String>]) {
        if let object = value as? [String: Any] {
            keySets[path, default: []].formUnion(object.keys)
            for (key, child) in object {
                collectKeySets(child, path: path.isEmpty ? key : "\(path).\(key)", into: &keySets)
            }
        } else if let array = value as? [Any] {
            array.forEach { collectKeySets($0, path: path + "[]", into: &keySets) }
        }
    }

    private func relativeFiles(in root: URL) throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: root.path).sorted()
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}
