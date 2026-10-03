import Foundation
import SessionCore
import XCTest

@testable import Unterrichtsvideographie

/// The disclosure outbox row is durable before sharing, and each terminal outcome is durable after it.
final class ExportOutcomeDurabilityTests: XCTestCase {
    private let exportScopes: Set<ConsentScope> = [.collection, .secondaryUse, .externalSharing]

    @MainActor
    func testAttemptIsPersistedBeforeSharingAndCompletedOutcomeIsPersisted() async throws {
        let root = try makeRoot()
        let (appStore, sessionID) = try await bootstrappedStore(root: root)

        let prepared = try await prepare(appStore)
        let attempt = try XCTUnwrap(try reloadedEvents(root: root, sessionID: sessionID).last)
        XCTAssertEqual(attempt.id, prepared.id)
        XCTAssertEqual(attempt.status, .attempted)
        XCTAssertEqual(attempt.shareActivityIdentifier, "pending")
        XCTAssertNil(attempt.completedAt)
        XCTAssertNil(attempt.failureDescription)
        XCTAssertEqual(attempt.operatorPseudonym, "group-a")
        XCTAssertEqual(attempt.includedScopes, exportScopes)
        XCTAssertEqual(Set(attempt.fileDigests.keys), Set(StudyPackageContract.expectedContentFiles))
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.packageURL.path))

        await appStore.recordExportOutcome(
            prepared,
            completed: true,
            shareActivityIdentifier: "com.example.share",
            failureDescription: nil
        )

        let events = try reloadedEvents(root: root, sessionID: sessionID)
        XCTAssertEqual(events.count, 1)
        let completed = try XCTUnwrap(events.first)
        XCTAssertEqual(completed.id, prepared.id)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.shareActivityIdentifier, "com.example.share")
        XCTAssertNotNil(completed.completedAt)
        XCTAssertNil(completed.failureDescription)
        XCTAssertEqual(completed.fileDigests, attempt.fileDigests)
        XCTAssertNil(appStore.lastStoreError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.packageURL.path))
    }

    @MainActor
    func testFailedOutcomeIsPersistedForItsOwnAttempt() async throws {
        let root = try makeRoot()
        let (appStore, sessionID) = try await bootstrappedStore(root: root)

        let prepared = try await prepare(appStore)
        XCTAssertEqual(try reloadedEvents(root: root, sessionID: sessionID).map(\.status), [.attempted])

        await appStore.recordExportOutcome(
            prepared,
            completed: false,
            shareActivityIdentifier: nil,
            failureDescription: "synthetic failure"
        )

        let events = try reloadedEvents(root: root, sessionID: sessionID)
        XCTAssertEqual(events.count, 1)
        let failed = try XCTUnwrap(events.first)
        XCTAssertEqual(failed.id, prepared.id)
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.shareActivityIdentifier, "system-share")
        XCTAssertEqual(failed.failureDescription, "synthetic failure")
        XCTAssertNotNil(failed.completedAt)
        XCTAssertNil(appStore.lastStoreError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.packageURL.path))
    }

    // MARK: - Helpers

    @MainActor
    private func bootstrappedStore(root: URL) async throws -> (AppStore, UUID) {
        let store = SessionStore(rootDirectory: root)
        let session = CaptureSession({
            var values = CaptureSession.Values()
            values.title = "Export"
            values.consentGrants = [ConsentGrant({
                var grant = ConsentGrant.Values()
                grant.scopes = exportScopes
                grant.documentIdentifier = "consent-form"
                grant.documentVersion = "1"
                grant.participantGroupPseudonym = "group-a"
                grant.grantedAt = Date().addingTimeInterval(-60)
                return grant
            }())]
            return values
        }())
        try store.save(session)
        let appStore = AppStore(store: store, bootstrapMode: .deferred)
        await appStore.bootstrap()
        XCTAssertEqual(appStore.bootstrapState, .ready)
        XCTAssertEqual(appStore.session.id, session.id)
        return (appStore, session.id)
    }

    @MainActor
    private func prepare(_ appStore: AppStore) async throws -> AppStore.PreparedExport {
        let prepared = await appStore.prepareExportForSharing()
        XCTAssertNil(appStore.lastStoreError)
        let unwrapped = try XCTUnwrap(prepared)
        addTeardownBlock { try? FileManager.default.removeItem(at: unwrapped.packageURL) }
        return unwrapped
    }

    /// Reads through a separate store instance so only durable state is observed.
    private func reloadedEvents(root: URL, sessionID: UUID) throws -> [ExportEvent] {
        try XCTUnwrap(try SessionStore(rootDirectory: root).load(id: sessionID)).exportEvents
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
            .appendingPathComponent("ExportOutcomeDurabilityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}
