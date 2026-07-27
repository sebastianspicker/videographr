import Foundation
import SessionCore

extension AppSessionModel {
    func recordingCompletionIsUnknown(_ transaction: RecordingTransaction) async {
        do {
            let persisted = try await mutateRecordingTransaction(transaction) { target, index in
                if [.prepared, .recording].contains(target.takeManifests[index].effectiveLifecycleState) {
                    target.takeManifests[index].lifecycleState = .completionUnknown
                    target.updatedAt = Date()
                }
            }
            if session.id == persisted.id { applyPersistedSession(persisted) }
        } catch {
            lastStoreError = "Unbestätigter Aufnahmeabschluss konnte nicht dauerhaft markiert werden: \(error.localizedDescription)"
        }
    }

    func mutateRecordingTransaction(
        _ transaction: RecordingTransaction,
        _ mutation: @escaping @Sendable (inout CaptureSession, Int) -> Void
    ) async throws -> CaptureSession {
        try await asyncStore.mutateSession(id: transaction.sessionID) { target in
            guard let index = target.takeManifests.firstIndex(where: {
                $0.id == transaction.transactionID
            }) else { return }
            mutation(&target, index)
        }
    }

    func failPreparedRecording(sessionID: UUID, transactionID: UUID, stagedURL: URL?, reason: String) async {
        do {
            if let stagedURL { try? await asyncStore.discardStagedRecording(at: stagedURL) }
            let failedAt = Date()
            let persisted = try await asyncStore.mutateSession(id: sessionID) {
                Self.applyPreparedRecordingFailure(
                    to: &$0,
                    transactionID: transactionID,
                    reason: reason,
                    failedAt: failedAt
                )
            }
            await applyFailedRecordingSession(persisted)
        } catch {
            lastStoreError = "Fehlgeschlagener Take konnte nicht dauerhaft geschlossen werden: \(error.localizedDescription)"
        }
    }

    nonisolated private static func applyPreparedRecordingFailure(
        to target: inout CaptureSession,
        transactionID: UUID,
        reason: String,
        failedAt: Date
    ) {
        guard let index = target.takeManifests.firstIndex(where: { $0.id == transactionID }) else { return }
        guard ![.finalized, .failed].contains(target.takeManifests[index].effectiveLifecycleState) else { return }
        let assetID = target.takeManifests[index].mediaAssetID
        let relativePath = target.mediaAssets.first(where: { $0.id == assetID })?.relativePath
        target.takeManifests[index].lifecycleState = .failed
        target.takeManifests[index].failureReason = reason
        target.takeManifests[index].endedAt = failedAt
        target.mediaAssets.removeAll { $0.id == assetID }
        if target.recordingRelativePath == relativePath { target.recordingRelativePath = nil }
        target.closeCaptureTimeline(at: failedAt)
    }

    private func applyFailedRecordingSession(_ persisted: CaptureSession) async {
        if session.id == persisted.id { applyPersistedSession(persisted) }
        invalidateCachedPackages(for: persisted.id)
        await reloadListAsync()
    }
}
