import Foundation
import XCTest
@testable import SessionCore

final class SessionStoreJournalTests: XCTestCase {
    func testSessionStoreAsyncMergeAndMutationPreservePersistedCaptureJournal() async throws {
        let root = try makeStoreRoot()
        let id = UUID()
        let observation = CaptureObservation({
            var values = CaptureObservation.Values()
            values.id = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
            values.observedAt = Date(timeIntervalSinceReferenceDate: 10)
            return values
        }())
        let persisted = CaptureSession({
            var values = CaptureSession.Values()
            values.id = id
            values.title = "Persisted title"
            values.captureObservations = [observation]
            return values
        }())
        let store = SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            return values
        }())
        let asyncStore = SessionStoreAsync(store: store)
        try await asyncStore.save(persisted)

        var draft = persisted
        draft.title = "Draft title"
        draft.captureObservations = []
        let merged = try await asyncStore.mergeDraftSession(draft)
        XCTAssertEqual(merged.title, "Draft title")

        let mutated = try await asyncStore.mutateSession(id: id) { session in
            session.plannedDurationMinutes = 90
        }
        XCTAssertEqual(mutated.plannedDurationMinutes, 90)
        let loaded = try await asyncStore.load(id: id)
        let reloaded = try XCTUnwrap(loaded)
        XCTAssertEqual(reloaded.captureObservations, [observation])
        XCTAssertEqual(reloaded.title, "Draft title")
    }

    func testSessionStoreAsyncOnlyAppendsObservationsForCurrentCollectionConsent() async throws {
        let root = try makeStoreRoot()
        let store = SessionStore({
            var values = SessionStore.Values()
            values.rootDirectory = root
            return values
        }())
        let asyncStore = SessionStoreAsync(store: store)
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        let unauthorized = readySession(grants: [])
        try await asyncStore.save(unauthorized)
        let observation = CaptureObservation({
            var values = CaptureObservation.Values()
            values.observedAt = now
            return values
        }())
        let rejected = try await asyncStore.appendCaptureObservationIfAuthorized(
            observation,
            toSession: unauthorized.id,
            at: now
        )
        let unauthorizedObservations = try await asyncStore.loadCaptureObservations(forSession: unauthorized.id)
        XCTAssertFalse(rejected)
        XCTAssertEqual(unauthorizedObservations, [])

        let authorized = readySession(grants: currentCaptureGrants(at: now))
        try await asyncStore.save(authorized)
        let appended = try await asyncStore.appendCaptureObservationIfAuthorized(
            observation,
            toSession: authorized.id,
            at: now
        )
        let authorizedObservations = try await asyncStore.loadCaptureObservations(forSession: authorized.id)
        XCTAssertTrue(appended)
        XCTAssertEqual(authorizedObservations, [observation])

        var revoked = authorized
        for index in revoked.consentGrants.indices {
            revoked.consentGrants[index].withdrawnAt = now.addingTimeInterval(1)
        }
        try await asyncStore.save(revoked)
        var laterValues = CaptureObservation.Values()
        laterValues.observedAt = now.addingTimeInterval(2)
        let rejectedAfterRevocation = try await asyncStore.appendCaptureObservationIfAuthorized(
            CaptureObservation(laterValues),
            toSession: authorized.id,
            at: laterValues.observedAt
        )
        XCTAssertFalse(rejectedAfterRevocation)
        let observationsAfterRevocation = try await asyncStore.loadCaptureObservations(
            forSession: authorized.id
        )
        XCTAssertEqual(observationsAfterRevocation, [observation])
    }

    private func grant(
        id: UUID = UUID(),
        scopes: Set<ConsentScope>,
        grantedAt: Date = Date(timeIntervalSinceReferenceDate: 1),
        expiresAt: Date? = nil
    ) -> ConsentGrant {
        ConsentGrant({
            var values = ConsentGrant.Values()
            values.id = id
            values.scopes = scopes
            values.documentIdentifier = "consent-form"
            values.documentVersion = "1"
            values.participantGroupPseudonym = "group-a"
            values.grantedAt = grantedAt
            values.expiresAt = expiresAt
            return values
        }())
    }

    private func currentCaptureGrants(at date: Date = Date()) -> [ConsentGrant] {
        [
            grant(scopes: [.collection], grantedAt: date.addingTimeInterval(-1)),
            grant(scopes: [.localReflection], grantedAt: date.addingTimeInterval(-1))
        ]
    }

    private func readySession(grants: [ConsentGrant]) -> CaptureSession {
        CaptureSession({
            var values = CaptureSession.Values()
            values.title = "Ready session"
            values.context = SessionContext({
                var context = SessionContext.Values()
                context.subject = "Physics"
                context.lessonGoal = "Observe a demonstration"
                return context
            }())
            values.consentGrants = grants
            return values
        }())
    }

    private func makeStoreRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}
