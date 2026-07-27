import Foundation
import GuidanceEngine

/// Actor-isolated facade for callers that must not perform storage work from the main actor.
public actor SessionStoreAsync {
    private let store: SessionStore

    public init(store: SessionStore) { self.store = store }
    public func save(_ session: CaptureSession) throws { try store.save(session) }
    public func load(id: UUID) throws -> CaptureSession? { try store.load(id: id) }
    public func listSessions() throws -> [CaptureSession] { try store.listSessions() }
    public func listSessionsWithDiagnostics() throws -> SessionStoreListing {
        try store.listSessionsWithDiagnostics()
    }
    public func listSessionSummariesWithDiagnostics() throws -> SessionStoreListing {
        try store.listSessionsWithDiagnostics(includeJournals: false)
    }
    public func deleteSessionAndMedia(id: UUID) throws { try store.deleteSessionAndMedia(id: id) }
    public func prepareRecordingURL(for session: CaptureSession) throws -> URL {
        try store.prepareRecordingURL(for: session)
    }
    public func prepareStagedRecordingURL(for sessionID: UUID, transactionID: UUID) throws -> URL {
        try store.prepareStagedRecordingURL(for: sessionID, transactionID: transactionID)
    }
    public func discardStagedRecording(at url: URL) throws { try store.discardStagedRecording(at: url) }
    public func secureFinalizedRecording(at url: URL) throws { try store.secureFinalizedRecording(at: url) }
    public func validatedMediaURL(for asset: SessionMediaAsset, sessionID: UUID) throws -> URL {
        try store.validatedMediaURL(for: asset, sessionID: sessionID)
    }
    public func importMedia(from sourceURL: URL, into sessionID: UUID) throws -> SessionMediaAsset {
        try store.importMedia(from: sourceURL, into: sessionID)
    }
    public func commitImportedMedia(_ asset: SessionMediaAsset, toSession sessionID: UUID) throws {
        try store.commitImportedMedia(asset, toSession: sessionID)
    }
    public func reconcilePersistenceArtifacts() throws -> PersistenceArtifactReconciliationReport {
        try store.reconcilePersistenceArtifacts()
    }
    public func discardUncommittedImportedMedia(_ asset: SessionMediaAsset, from sessionID: UUID) throws {
        try store.discardUncommittedImportedMedia(asset, from: sessionID)
    }
    public func appendCaptureObservation(_ observation: CaptureObservation, toSession id: UUID) throws {
        try store.appendCaptureObservation(observation, toSession: id)
    }
    public func appendCodingSnapshot(_ snapshot: ResearchCodingSnapshot, toSession id: UUID) throws {
        try store.appendCodingSnapshot(snapshot, toSession: id)
    }
    @discardableResult
    public func appendCaptureObservationIfAuthorized(
        _ observation: CaptureObservation,
        toSession id: UUID,
        at date: Date = Date()
    ) throws -> Bool {
        guard let session = try store.load(id: id), session.authorizes(.collection, at: date) else {
            return false
        }
        try store.appendCaptureObservation(observation, toSession: id)
        return true
    }
    public func loadCaptureObservations(forSession id: UUID) throws -> [CaptureObservation] {
        try store.loadCaptureObservations(forSession: id)
    }
    public func loadCodingSnapshots(forSession id: UUID) throws -> [ResearchCodingSnapshot] {
        try store.loadCodingSnapshots(forSession: id)
    }

    /// Executes one read-modify-write transaction without an actor reentrancy point.
    @discardableResult
    public func mutateSession(
        id: UUID,
        includeJournals: Bool = false,
        _ mutation: @Sendable (inout CaptureSession) throws -> Void
    ) throws -> CaptureSession {
        let loaded = includeJournals ? try store.load(id: id) : try store.loadMetadataOnly(id: id)
        guard var session = loaded else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Session \(id.uuidString) wurde nicht gefunden."
            ])
        }
        try mutation(&session)
        try store.save(session)
        return includeJournals
            ? (try store.load(id: id) ?? session)
            : (try store.loadMetadataOnly(id: id) ?? session)
    }

    /// Persists only interactive draft fields, preserving runtime-owned take, media, journal,
    /// provenance, and disclosure state written by concurrent capture operations.
    @discardableResult
    public func mergeDraftSession(_ draft: CaptureSession) throws -> CaptureSession {
        guard var current = try store.loadMetadataOnly(id: draft.id) else {
            try store.save(draft)
            return try store.loadMetadataOnly(id: draft.id) ?? draft
        }
        current.mergeDraftFields(from: draft)
        try store.save(current)
        return try store.loadMetadataOnly(id: draft.id) ?? current
    }
}
