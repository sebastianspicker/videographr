import Foundation
import SessionCore

extension AppStore {
    func recordingCompletionIsUnknown(_ transaction: RecordingTransaction) async {
        do {
            let persisted = try await mutateRecordingTransaction(transaction) { target, index in
                _ = RecordingStateMachine.completionUnknown(
                    transactionID: target.takeManifests[index].id,
                    in: &target,
                    at: Date()
                )
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
                _ = RecordingStateMachine.failed(
                    transactionID: transactionID,
                    reason: reason,
                    in: &$0,
                    at: failedAt
                )
            }
            await applyFailedRecordingSession(persisted)
        } catch {
            lastStoreError = "Fehlgeschlagener Take konnte nicht dauerhaft geschlossen werden: \(error.localizedDescription)"
        }
    }

    private func applyFailedRecordingSession(_ persisted: CaptureSession) async {
        if session.id == persisted.id { applyPersistedSession(persisted) }
        invalidateCachedPackages(for: persisted.id)
        await reloadListAsync()
    }
}
