import Foundation
import GuidanceEngine
import SessionCore

@MainActor
private struct ExportPreparation {
    let eventID: UUID
    let projection: StudyExportProjection
    let authorizationTime: Date
    let source: CaptureSession
}

extension AppSessionModel {
func attachCodingSnapshot(_ snapshot: ResearchCodingSnapshot, for id: UUID, recordingIsActive: Bool) async {
    guard recordingIsActive else { return }
    do {
        try await asyncStore.appendCodingSnapshot(snapshot, toSession: id)
        if session.id == id {
            session.appendCodingSnapshot(snapshot)
        }
        invalidateCachedPackages(for: id)
    } catch {
        lastStoreError = error.localizedDescription
    }
}

func mediaURL(for asset: SessionMediaAsset) -> URL? {
    mediaURLs[asset.id]
}

func importMedia(from sourceURL: URL) async {
    guard session.authorizes(.localReflection) else {
        lastStoreError = "Videoimport blockiert: aktiver lokaler Freigabedatensatz für Reflexion fehlt."
        return
    }
    let accessed = sourceURL.startAccessingSecurityScopedResource()
    defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
    await importAuthorizedMedia(from: sourceURL, into: session.id)
}

private func importAuthorizedMedia(from sourceURL: URL, into sessionID: UUID) async {
    var importedAsset: SessionMediaAsset?
    do {
        let imported = try await importAndInspectMedia(from: sourceURL, into: sessionID)
        importedAsset = imported.asset
        let persisted = try await persistImportedMedia(imported.asset, in: sessionID)
        try? await asyncStore.commitImportedMedia(imported.asset, toSession: persisted.id)
        applyImportedMedia(imported, to: persisted)
        invalidateCachedPackages(for: persisted.id)
        await reloadListAsync()
    } catch {
        await discardUncommittedMedia(importedAsset, from: sessionID)
        lastStoreError = error.localizedDescription
    }
}

private func importAndInspectMedia(
    from sourceURL: URL,
    into sessionID: UUID
) async throws -> (asset: SessionMediaAsset, url: URL) {
    let asset = try await asyncStore.importMedia(from: sourceURL, into: sessionID)
    let url = try await asyncStore.validatedMediaURL(for: asset, sessionID: sessionID)
    let metadata = try await mediaInspector.inspect(url: url)
    var enriched = asset
    enriched.durationMilliseconds = metadata.durationMilliseconds
    enriched.sha256 = metadata.sha256
    enriched.codec = metadata.codec
    enriched.resolution = metadata.resolution
    enriched.frameRate = metadata.frameRate
    return (enriched, url)
}

private func persistImportedMedia(_ asset: SessionMediaAsset, in sessionID: UUID) async throws -> CaptureSession {
    try await asyncStore.mutateSession(id: sessionID) { current in
        guard current.authorizes(.localReflection) else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "Die Reflexionsfreigabe ist während des Imports abgelaufen oder widerrufen worden."
            ])
        }
        guard !current.mediaAssets.contains(where: { $0.id == asset.id }) else { return }
        current.mediaAssets.append(asset)
        current.updatedAt = Date()
    }
}

private func applyImportedMedia(_ imported: (asset: SessionMediaAsset, url: URL), to persisted: CaptureSession) {
    guard session.id == persisted.id else { return }
    applyPersistedSession(persisted)
    mediaURLs[imported.asset.id] = imported.url
}

private func discardUncommittedMedia(_ asset: SessionMediaAsset?, from sessionID: UUID) async {
    guard let asset else { return }
    try? await asyncStore.discardUncommittedImportedMedia(asset, from: sessionID)
}

/// Builds from a fresh persisted snapshot and durably writes an outbox row before disclosure.
func prepareExportForSharing() async -> PreparedExport? {
    guard await flushPendingChanges() else { return nil }
    do {
        return try await preparePersistedExport(sessionID: session.id)
    } catch {
        studyPackageURL = nil
        lastStoreError = "Forschungspaket konnte nicht freigegeben werden: \(error.localizedDescription)"
        return nil
    }
}

private func preparePersistedExport(sessionID: UUID) async throws -> PreparedExport {
    guard let source = try await asyncStore.load(id: sessionID) else {
        throw CocoaError(.fileNoSuchFile)
    }
    let preparation = try makeExportPreparation(from: source)
    let packageURL = try await packageBuilder.build(
        session: source,
        exportID: preparation.eventID,
        provenance: Self.currentExportProvenance
    )
    do {
        let manifest = try await packageBuilder.validatedManifest(at: packageURL, expectedSessionID: sessionID)
        let attempt = makeExportAttempt(preparation, manifest: manifest)
        let persisted = try await persistExportAttempt(attempt, sessionID: sessionID, projection: preparation.projection)
        applyPersistedSession(persisted)
        studyPackageURL = packageURL
        await reloadListAsync()
        return PreparedExport(id: preparation.eventID, sessionID: sessionID, packageURL: packageURL)
    } catch {
        await packageBuilder.discardFailedPreparation(at: packageURL)
        throw error
    }
}

private func makeExportPreparation(from source: CaptureSession) throws -> ExportPreparation {
    let projection = StudyExportProjection.make(from: source)
    let authorizationTime = Date()
    guard projection.requiredScopes.allSatisfy({ source.authorizes($0, at: authorizationTime) }) else {
        throw CocoaError(.fileWriteNoPermission, userInfo: [
            NSLocalizedDescriptionKey: "Für Sekundärnutzung und externe Freigabe fehlen aktive, inhaltsbezogene Freigaben."
        ])
    }
    return ExportPreparation(
        eventID: UUID(),
        projection: projection,
        authorizationTime: authorizationTime,
        source: source
    )
}

private func makeExportAttempt(
    _ preparation: ExportPreparation,
    manifest: StudyExportManifest
) -> ExportEvent {
    var values = ExportEvent.Values()
    values.id = preparation.eventID
    values.exportedAt = preparation.authorizationTime
    values.operatorPseudonym = preparation.source.consentGrants
        .last(where: { $0.authorizes(.externalSharing, at: preparation.authorizationTime) })?
        .participantGroupPseudonym ?? "local-operator"
    values.operatorAuthenticationMethod = Self.currentOperatorAuthenticationMethod
    values.includedScopes = manifest.includedScopes
    values.fileDigests = manifest.fileDigests
    values.shareActivityIdentifier = "pending"
    values.status = .attempted
    return ExportEvent(values)
}

private func persistExportAttempt(
    _ attempt: ExportEvent,
    sessionID: UUID,
    projection: StudyExportProjection
) async throws -> CaptureSession {
    try await asyncStore.mutateSession(id: sessionID, includeJournals: true) { target in
        guard projection.requiredScopes.allSatisfy({ target.authorizes($0) }),
              StudyExportProjection.make(from: target) == projection
        else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "Die Sitzung oder Freigabe hat sich während der Exportvorbereitung geändert. Bitte erneut versuchen."
            ])
        }
        target.exportEvents.append(attempt)
        target.updatedAt = Date()
    }
}

/// Finalizes an existing disclosure outbox row even if consent expires during the share sheet.
func recordExportOutcome(
    _ prepared: PreparedExport,
    completed: Bool,
    shareActivityIdentifier: String?,
    failureDescription: String?
) async {
    let status = exportStatus(completed: completed, failureDescription: failureDescription)
    do {
        let persisted = try await persistExportOutcome(
            prepared,
            status: status,
            shareActivityIdentifier: shareActivityIdentifier,
            failureDescription: failureDescription
        )
        applyPersistedSession(persisted)
        await reloadListAsync()
    } catch {
        lastStoreError = exportOutcomeError(completed: completed, error: error)
    }
    await clearPreparedExport(prepared)
}

private func exportStatus(completed: Bool, failureDescription: String?) -> ExportEventStatus {
    guard completed else { return failureDescription == nil ? .cancelled : .failed }
    return .completed
}

private func persistExportOutcome(
    _ prepared: PreparedExport,
    status: ExportEventStatus,
    shareActivityIdentifier: String?,
    failureDescription: String?
) async throws -> CaptureSession {
    try await asyncStore.mutateSession(id: prepared.sessionID) { target in
        guard let index = target.exportEvents.firstIndex(where: { $0.id == prepared.id }) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Der vorbereitete Exportversuch fehlt im lokalen Auditprotokoll."
            ])
        }
        guard target.exportEvents[index].finish(
            status: status,
            shareActivityIdentifier: shareActivityIdentifier,
            failureDescription: failureDescription
        ) else { return }
        target.updatedAt = Date()
    }
}

private func exportOutcomeError(completed: Bool, error: Error) -> String {
    completed
        ? "Export wurde geteilt; der vorbereitete Auditdatensatz bleibt offen, weil der Abschluss nicht gespeichert werden konnte: \(error.localizedDescription)"
        : "Exportstatus konnte nicht gespeichert werden: \(error.localizedDescription)"
}

private func clearPreparedExport(_ prepared: PreparedExport) async {
    await packageBuilder.removePackage(at: prepared.packageURL)
    if studyPackageURL == prepared.packageURL { studyPackageURL = nil }
}

func deleteSessionAndMedia(_ id: UUID) {
    Task { [weak self] in
        guard let self, await self.flushPendingChanges() else { return }
        do {
            try await self.asyncStore.deleteSessionAndMedia(id: id)
            await self.packageBuilder.removeUnleasedPackages(for: id)
            self.lastStoreError = nil
            await self.reloadListAsync()
            if self.session.id == id {
                if let nextID = self.allSessions.first?.id,
                   let loaded = try await self.asyncStore.load(id: nextID)
                {
                    self.session = loaded
                } else {
                    self.session = Self.makeSession(buildProvenance: Self.currentBuildProvenance)
                }
                self.editRevision = 0
                self.savedRevision = 0
                self.saveState = .saved
                await self.refreshMediaURLs()
                self.studyPackageURL = nil
            }
        } catch {
            self.lastStoreError = error.localizedDescription
        }
    }
}
}
