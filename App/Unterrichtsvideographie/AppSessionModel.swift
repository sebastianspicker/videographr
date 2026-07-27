import AVFoundation
import Combine
import CryptoKit
import Foundation
import GuidanceEngine
import SessionCore
import UIKit

/// App-wide active capture session and asynchronous local persistence.
@MainActor
final class AppSessionModel: ObservableObject {
    enum SaveState: Equatable {
        case saved
        case unsaved
        case saving
        case failed(String)

        var titleDE: String {
            switch self {
            case .saved: return "Gespeichert"
            case .unsaved: return "Ungespeicherte Änderungen"
            case .saving: return "Speichert…"
            case let .failed(message): return "Speicherfehler: \(message)"
            }
        }
    }

    struct PreparedRecording: Sendable {
        let sessionID: UUID
        let transactionID: UUID
        let mediaAssetID: UUID
        let url: URL
        let stagedURL: URL
        let authorization: CaptureAuthorizationSnapshot
        let plannedDurationMinutes: Int
    }

    struct PreparedExport: Identifiable, Equatable, Sendable {
        let id: UUID
        let sessionID: UUID
        let packageURL: URL
    }

    struct ConsentGrantDraft {
        let scopes: Set<ConsentScope>
        let documentIdentifier: String
        let documentVersion: String
        let participantGroupPseudonym: String
        let expiresAt: Date?
    }

    struct RecordingPreparation {
        let transactionID: UUID
        let readiness: SessionReadiness
        let overrideReason: String
        let operatorPseudonym: String
        let runtimeStatus: CaptureRuntimeStatus
    }

    @Published var session: CaptureSession
    @Published var allSessions: [CaptureSession] = []
    @Published var saveState: SaveState = .saved
    @Published var studyPackageURL: URL?
    @Published var lastStoreError: String?

    let store: SessionStore
    let readiness = ReadinessAggregator()

    let asyncStore: SessionStoreAsync
    let mediaInspector = MediaInspector()
    let packageBuilder = StudyPackageBuilder()
    var mediaURLs: [UUID: URL] = [:]
    var autosaveTask: Task<Void, Never>?
    var editRevision = 0
    var savedRevision = 0

    init(store: SessionStore? = nil) {
        let store = store ?? Self.defaultStore()
        self.store = store
        self.asyncStore = SessionStoreAsync(store: store)
        do {
            let reconciliation = try store.reconcileRecordingArtifacts()
            try Self.reconcileAbandonedTakeMetadata(in: store)
            try Self.reconcileOpenExportAttempts(in: store)
            let persistenceReconciliation = try store.reconcilePersistenceArtifacts()
            let listing = try store.listSessionsWithDiagnostics(includeJournals: false)
            self.session = try listing.sessions.first.flatMap { try store.load(id: $0.id) } ?? CaptureSession()
            self.allSessions = listing.sessions
            applyListingDiagnostics(listing)
            applyReconciliationStatus(reconciliation)
            applyPersistenceReconciliationStatus(persistenceReconciliation)
        } catch {
            self.session = CaptureSession()
            self.lastStoreError = error.localizedDescription
        }
        if session.buildProvenance == nil, session.takeManifests.isEmpty {
            session.buildProvenance = Self.captureBuildProvenance(for: session.operatingMode)
        }
        refreshMediaURLsSynchronously()
    }

    deinit {
        autosaveTask?.cancel()
    }

    /// Marks the active draft dirty and coalesces edits into one background save.
    func markDirty() {
        session.updatedAt = Date()
        editRevision &+= 1
        saveState = .unsaved
        studyPackageURL = nil
        invalidateCachedPackages(for: session.id)
        scheduleAutosave(delayNanoseconds: 650_000_000)
    }

    /// Backward-compatible explicit save action; persistence stays off the main actor.
    func save() {
        if savedRevision == editRevision { markDirty() }
        scheduleAutosave(delayNanoseconds: 0)
    }

    @discardableResult
    func flushPendingChanges() async -> Bool {
        autosaveTask?.cancel()
        autosaveTask = nil
        while savedRevision < editRevision {
            let revision = editRevision
            guard await persistCurrentSession(revision: revision) else { return false }
        }
        return true
    }

    func reloadList() {
        Task { [weak self] in
            await self?.reloadListAsync()
        }
    }

    /// Legacy acknowledgements remain visible for migrated data but grant no v2 authority.
    func updateConsent(
        informedParticipants: Bool,
        secondaryUse: Bool,
        storageResponsibility: Bool
    ) {
        session.consent.applyAcknowledgements(
            informedParticipants: informedParticipants,
            secondaryUse: secondaryUse,
            storageResponsibility: storageResponsibility
        )
        markDirty()
        scheduleAutosave(delayNanoseconds: 0)
    }

    /// Replaces active scoped grants while retaining withdrawn records for auditability.
    func updateConsentGrant(_ draft: ConsentGrantDraft) {
        let now = Date()
        for index in session.consentGrants.indices where session.consentGrants[index].withdrawnAt == nil {
            session.consentGrants[index].withdrawnAt = now
        }
        let documentID = draft.documentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = draft.documentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let pseudonym = draft.participantGroupPseudonym.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.scopes.isEmpty, !documentID.isEmpty, !version.isEmpty, !pseudonym.isEmpty {
            var values = ConsentGrant.Values()
            values.scopes = draft.scopes
            values.documentIdentifier = documentID
            values.documentVersion = version
            values.participantGroupPseudonym = pseudonym
            values.grantedAt = now
            values.expiresAt = draft.expiresAt
            session.consentGrants.append(ConsentGrant(values))
        }
        markDirty()
        scheduleAutosave(delayNanoseconds: 0)
    }

    func newSession() {
        Task { [weak self] in
            guard let self, await self.flushPendingChanges() else { return }
            self.session = Self.makeSession(buildProvenance: Self.currentBuildProvenance)
            self.mediaURLs = [:]
            self.studyPackageURL = nil
            self.markDirty()
            _ = await self.flushPendingChanges()
        }
    }

    func select(_ id: UUID) {
        Task { [weak self] in
            guard let self, await self.flushPendingChanges() else { return }
            do {
                guard var loaded = try await self.asyncStore.load(id: id) else {
                    self.lastStoreError = "Die ausgewählte Sitzung wurde nicht gefunden."
                    return
                }
                if loaded.buildProvenance == nil, loaded.takeManifests.isEmpty {
                    loaded.buildProvenance = Self.captureBuildProvenance(for: loaded.operatingMode)
                }
                self.session = loaded
                self.editRevision = 0
                self.savedRevision = 0
                self.saveState = .saved
                self.lastStoreError = nil
                await self.refreshMediaURLs()
                self.studyPackageURL = nil
            } catch {
                self.lastStoreError = error.localizedDescription
            }
        }
    }

    func evaluateReadiness(visual: GuidanceResult, audio: AudioLevelSample) -> SessionReadiness {
        readiness.evaluate(session: session, visual: visual, audioSample: audio)
    }

}
