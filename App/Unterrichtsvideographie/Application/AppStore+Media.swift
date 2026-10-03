import Foundation
import SessionCore

extension AppStore {
    func mediaURL(for asset: SessionMediaAsset) -> URL? {
        mediaURLs[asset.id]
    }

    func importMedia(from sourceURL: URL) async {
        guard persistenceIsReady else { return }
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
            let asset = try await asyncStore.importMedia(from: sourceURL, into: sessionID)
            importedAsset = asset
            let imported = try await inspectImportedMedia(asset, in: sessionID)
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

    private func inspectImportedMedia(
        _ asset: SessionMediaAsset,
        in sessionID: UUID
    ) async throws -> (asset: SessionMediaAsset, url: URL) {
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
        cacheMediaURL(imported.url, for: imported.asset.id, in: persisted)
    }

    private func discardUncommittedMedia(_ asset: SessionMediaAsset?, from sessionID: UUID) async {
        guard let asset else { return }
        try? await asyncStore.discardUncommittedImportedMedia(asset, from: sessionID)
    }
}
