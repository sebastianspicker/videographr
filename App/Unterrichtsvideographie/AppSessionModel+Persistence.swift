import Foundation
import GuidanceEngine
import SessionCore

@MainActor
extension AppSessionModel {
func scheduleAutosave(delayNanoseconds: UInt64) {
    autosaveTask?.cancel()
    let revision = editRevision
    autosaveTask = Task { [weak self] in
        if delayNanoseconds > 0 {
            do { try await Task.sleep(nanoseconds: delayNanoseconds) }
            catch { return }
        }
        guard !Task.isCancelled else { return }
        _ = await self?.persistCurrentSession(revision: revision)
    }
}

func persistCurrentSession(revision: Int) async -> Bool {
    let snapshot = session
    saveState = .saving
    do {
        let persisted = preservingHydratedHistories(
            in: try await asyncStore.mergeDraftSession(snapshot),
            from: session
        )
        let listing = try await asyncStore.listSessionSummariesWithDiagnostics()
        allSessions = listing.sessions
        applyListingDiagnostics(listing)
        if editRevision == revision {
            session = persisted
            savedRevision = revision
            saveState = .saved
        } else {
            var merged = persisted
            merged.mergeDraftFields(from: session)
            session = merged
            saveState = .unsaved
        }
        await refreshMediaURLs()
        return true
    } catch {
        let message = error.localizedDescription
        saveState = .failed(message)
        lastStoreError = message
        return false
    }
}

func reloadListAsync() async {
    do {
        let listing = try await asyncStore.listSessionSummariesWithDiagnostics()
        allSessions = listing.sessions
        applyListingDiagnostics(listing)
    } catch {
        lastStoreError = error.localizedDescription
    }
}

func applyPersistedSession(_ persisted: CaptureSession) {
    guard session.id == persisted.id else { return }
    let hydrated = preservingHydratedHistories(in: persisted, from: session)
    if savedRevision < editRevision {
        var merged = hydrated
        merged.mergeDraftFields(from: session)
        session = merged
        saveState = .unsaved
    } else {
        session = hydrated
        savedRevision = editRevision
        saveState = .saved
    }
    lastStoreError = nil
}

func preservingHydratedHistories(
    in persisted: CaptureSession,
    from current: CaptureSession
) -> CaptureSession {
    guard persisted.id == current.id else { return persisted }
    var merged = persisted
    if merged.captureObservations.isEmpty, !current.captureObservations.isEmpty {
        merged.captureObservations = current.captureObservations
    }
    if merged.codingSnapshots.isEmpty, !current.codingSnapshots.isEmpty {
        merged.codingSnapshots = current.codingSnapshots
    }
    return merged
}

func refreshMediaURLsSynchronously() {
    var resolved: [UUID: URL] = [:]
    for asset in session.mediaAssets {
        if let url = try? store.validatedMediaURL(for: asset, sessionID: session.id) {
            resolved[asset.id] = url
        }
    }
    mediaURLs = resolved
}

func refreshMediaURLs() async {
    let current = session
    var resolved: [UUID: URL] = [:]
    for asset in current.mediaAssets {
        if let url = try? await asyncStore.validatedMediaURL(for: asset, sessionID: current.id) {
            resolved[asset.id] = url
        }
    }
    guard session.id == current.id else { return }
    mediaURLs = resolved
}

func invalidateCachedPackages(for sessionID: UUID) {
    if session.id == sessionID { studyPackageURL = nil }
    Task { [packageBuilder] in
        await packageBuilder.removeUnleasedPackages(for: sessionID)
    }
}

func verifyStorageCapacity(for plannedMinutes: Int) throws {
    let values = try store.rootDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    guard let available = values.volumeAvailableCapacityForImportantUsage else { return }
    let estimatedBytesPerSecond: Int64 = 1_500_000
    let reserve: Int64 = 500_000_000
    let required = Int64(plannedMinutes) * 60 * estimatedBytesPerSecond + reserve
    guard available >= required else {
        throw CocoaError(.fileWriteOutOfSpace, userInfo: [
            NSLocalizedDescriptionKey: "Zu wenig freier Speicher für \(plannedMinutes) Minuten plus Sicherheitsreserve."
        ])
    }
}

func applyListingDiagnostics(_ listing: SessionStoreListing) {
    guard !listing.failures.isEmpty else {
        if case .failed = saveState { return }
        lastStoreError = nil
        return
    }
    lastStoreError = listing.failures.map {
        "\($0.fileName): \($0.errorDescription)"
    }.joined(separator: "\n")
}

func applyReconciliationStatus(_ report: RecordingArtifactReconciliationReport) {
    var notes = reconciliationSummaryNotes(report)
    notes.append(contentsOf: report.diagnostics.map {
        "Aufnahmeartefakt \($0.fileName) wurde nicht verändert: \($0.reason.localizedDescription)"
    })
    guard !notes.isEmpty else { return }
    lastStoreError = [lastStoreError, notes.joined(separator: "\n")]
        .compactMap { $0 }
        .joined(separator: "\n")
}

private func reconciliationSummaryNotes(
    _ report: RecordingArtifactReconciliationReport
) -> [String] {
    [
        (report.removedStagingFileNames.count, "Unterbrochene Aufnahme bereinigt"),
        (report.relinkedSessionIDs.count, "Abgeschlossene Aufnahme wieder zugeordnet"),
        (report.restoredQuarantineFileNames.count, "Unterbrochene Medienbereinigung zurückgerollt"),
        (report.removedQuarantineFileNames.count, "Abgeschlossene Medienbereinigung abgeschlossen")
    ].compactMap { count, label in
        count == 0 ? nil : "\(label): \(count)"
    }
}

func applyPersistenceReconciliationStatus(_ report: PersistenceArtifactReconciliationReport) {
    var notes: [String] = []
    if !report.removedOrphanJournalFileNames.isEmpty {
        notes.append("Verwaiste Beobachtungsjournale bereinigt: \(report.removedOrphanJournalFileNames.count)")
    }
    if !report.removedOrphanImportedFileNames.isEmpty {
        notes.append("Nicht zugeordnete Videoimporte bereinigt: \(report.removedOrphanImportedFileNames.count)")
    }
    notes.append(contentsOf: report.diagnostics.map {
        "Persistenzartefakt \($0.fileName) wurde nicht verändert: \($0.reason.localizedDescription)"
    })
    guard !notes.isEmpty else { return }
    lastStoreError = [lastStoreError, notes.joined(separator: "\n")]
        .compactMap { $0 }
        .joined(separator: "\n")
}

static var currentBuildProvenance: BuildProvenance {
    captureBuildProvenance(for: .evidenceSafe)
}

static func captureBuildProvenance(for mode: OperatingMode) -> BuildProvenance {
    makeBuildProvenance(
        algorithmVersion: mode == .experimentalResearch
            ? "capture-observability-v1+experimental-coding-rules-v1"
            : "capture-observability-v1"
    )
}

static var currentExportProvenance: BuildProvenance {
    makeBuildProvenance(algorithmVersion: "study-package-v1")
}

static func makeSession(buildProvenance: BuildProvenance) -> CaptureSession {
    var values = CaptureSession.Values()
    values.buildProvenance = buildProvenance
    return CaptureSession(values)
}

static func makeBuildProvenance(algorithmVersion: String) -> BuildProvenance {
    var values = BuildProvenance.Values()
    values.semanticVersion = BuildIdentity.current.semanticVersion
    values.buildNumber = BuildIdentity.current.buildNumber
    values.algorithmVersion = algorithmVersion
    values.evidenceRegistryVersion = String(EvidenceClaimRegistry.version)
    return BuildProvenance(values)
}

static var currentOperatorAuthenticationMethod: String {
    return "deviceOwnerAuthentication"
}

static func defaultStore() -> SessionStore {
    return SessionStore()
}

/// Startup fail-safe for transactions whose staging file was removed after a crash and that
/// never produced a canonical movie. Decisions remain as audit history; unusable assets do not
/// block a retry forever.
static func reconcileAbandonedTakeMetadata(in store: SessionStore) throws {
    for var candidate in try store.listSessionsWithDiagnostics(includeJournals: false).sessions {
        let closedAt = Date()
        let canonicalAssetIDs = Set(candidate.mediaAssets.compactMap { asset -> UUID? in
            guard let url = try? store.validatedMediaURL(for: asset, sessionID: candidate.id),
                  FileManager.default.fileExists(atPath: url.path)
            else { return nil }
            return asset.id
        })
        if candidate.failAbandonedTakes(
            canonicalMediaAssetIDs: canonicalAssetIDs,
            at: closedAt
        ) > 0 {
            try store.save(candidate)
        }
    }
}

static func reconcileOpenExportAttempts(in store: SessionStore) throws {
    for var candidate in try store.listSessionsWithDiagnostics(includeJournals: false).sessions {
        var changed = false
        for index in candidate.exportEvents.indices where candidate.exportEvents[index].status == .attempted {
            candidate.exportEvents[index].finish(
                status: .outcomeUnknown,
                shareActivityIdentifier: "unknown-after-relaunch",
                failureDescription: "App wurde beendet, bevor der Systemdialog einen Abschlussstatus liefern konnte."
            )
            changed = true
        }
        if changed { try store.save(candidate) }
    }
}
}
