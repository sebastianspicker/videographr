import Foundation
import SessionCore
import UIKit

extension CameraSessionModel {
    internal func completeRecordingTransactionCarrier(_ transaction: RecordingTransaction, status: String) {
        guard acceptsRecordingEventCarrier(for: transaction) else { return }
        isStartingRecording = false
        isRecording = false
        isFinalizingRecording = false
        stopRequestedDuringStart = false
        cancelWatchdogCarrier(.startAcknowledgement, for: transaction)
        cancelWatchdogCarrier(.finalization, for: transaction)
        cancelWatchdogCarrier(.metadataAttachment, for: transaction)
        expirationRecoveryWorkItem?.cancel()
        expirationRecoveryWorkItem = nil
        recordStatusMessage = status
        activeRecordingTransaction = nil
        restoreIdleTimer()
        endRecordingBackgroundTaskCarrier()
    }

    internal func beginRecordingBackgroundTaskCarrier(for transaction: RecordingTransaction) {
        guard recordingBackgroundTask == .invalid else { return }
        recordingBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finalize recording") { [weak self] in
            self?.handleBackgroundExpirationCarrier(for: transaction)
        }
        if recordingBackgroundTask == .invalid, expirationRecoveryWorkItem == nil {
            handleBackgroundExpirationCarrier(for: transaction)
        }
    }

    internal func handleBackgroundExpirationCarrier(for transaction: RecordingTransaction) {
        guard acceptsRecordingEventCarrier(for: transaction) else { return }
        recordStatusMessage = "Aufnahme wird wegen Hintergrundzeit finalisiert…"
        capture.stopRecording(transaction: transaction)
        endRecordingBackgroundTaskCarrier()
        isStartingRecording = false
        isRecording = false
        isFinalizingRecording = true
        canRetryCapture = true
        recordStatusMessage = "Hintergrundzeit abgelaufen - Aufnahme wird beim nächsten Start geprüft."
        scheduleExpirationRecoveryCarrier(for: transaction)
    }

    internal func scheduleExpirationRecoveryCarrier(for transaction: RecordingTransaction) {
        expirationRecoveryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.acceptsRecordingEventCarrier(for: transaction) else { return }
            self.releaseExpiredTransactionUICarrier(transaction)
        }
        expirationRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    internal func releaseExpiredTransactionUICarrier(_ transaction: RecordingTransaction) {
        guard acceptsRecordingEventCarrier(for: transaction) else { return }
        cancelWatchdogCarrier(.startAcknowledgement, for: transaction)
        cancelWatchdogCarrier(.finalization, for: transaction)
        cancelWatchdogCarrier(.metadataAttachment, for: transaction)
        isStartingRecording = false
        isRecording = false
        isFinalizingRecording = false
        stopRequestedDuringStart = false
        recordStatusMessage = "Finalisierung nicht bestätigt. Lokale Aufnahme wird beim nächsten App-Start geprüft."
        activeRecordingTransaction = nil
        restoreIdleTimer()
        deferredArtifactTransactions[transaction] = ()
        onRecordingCompletionUnknown?(transaction, "Finalisierung wurde nicht bestätigt.")
        canRetryCapture = true
        expirationRecoveryWorkItem = nil
        endRecordingBackgroundTaskCarrier()
    }

    internal func armStartAcknowledgementWatchdogCarrier(for transaction: RecordingTransaction) {
        startAcknowledgementWatchdogWorkItem?.cancel()
        recordingWatchdogs.arm(.startAcknowledgement, for: transaction)
        let workItem = DispatchWorkItem { [weak self] in
            self?.expireStartAcknowledgementWatchdogCarrier(for: transaction)
        }
        startAcknowledgementWatchdogWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    internal func armFinalizationWatchdogCarrier(for transaction: RecordingTransaction) {
        finalizationWatchdogWorkItem?.cancel()
        recordingWatchdogs.arm(.finalization, for: transaction)
        let workItem = DispatchWorkItem { [weak self] in
            self?.expireFinalizationWatchdogCarrier(for: transaction)
        }
        finalizationWatchdogWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    internal func armMetadataAttachmentWatchdogCarrier(for transaction: RecordingTransaction) {
        metadataAttachmentWatchdogWorkItem?.cancel()
        recordingWatchdogs.arm(.metadataAttachment, for: transaction)
        let workItem = DispatchWorkItem { [weak self] in
            self?.expireMetadataAttachmentWatchdogCarrier(for: transaction)
        }
        metadataAttachmentWatchdogWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    internal func cancelWatchdogCarrier(
        _ phase: RecordingTransactionWatchdogs<RecordingTransaction>.Phase,
        for transaction: RecordingTransaction
    ) {
        guard recordingWatchdogs.cancel(phase, for: transaction) else { return }
        if phase == .startAcknowledgement {
            startAcknowledgementWatchdogWorkItem?.cancel()
            startAcknowledgementWatchdogWorkItem = nil
            return
        }
        if phase == .finalization {
            finalizationWatchdogWorkItem?.cancel()
            finalizationWatchdogWorkItem = nil
            return
        }
        metadataAttachmentWatchdogWorkItem?.cancel()
        metadataAttachmentWatchdogWorkItem = nil
    }

    internal func expireStartAcknowledgementWatchdogCarrier(for transaction: RecordingTransaction) {
        guard recordingWatchdogs.expire(.startAcknowledgement, for: transaction), acceptsRecordingEventCarrier(for: transaction) else { return }
        startAcknowledgementWatchdogWorkItem = nil
        capture.stopRecording(transaction: transaction)
        releaseExpiredTransactionUICarrier(transaction)
    }

    internal func expireFinalizationWatchdogCarrier(for transaction: RecordingTransaction) {
        guard recordingWatchdogs.expire(.finalization, for: transaction), acceptsRecordingEventCarrier(for: transaction) else { return }
        finalizationWatchdogWorkItem = nil
        releaseExpiredTransactionUICarrier(transaction)
    }

    internal func expireMetadataAttachmentWatchdogCarrier(for transaction: RecordingTransaction) {
        guard recordingWatchdogs.expire(.metadataAttachment, for: transaction), acceptsRecordingEventCarrier(for: transaction) else { return }
        metadataAttachmentWatchdogWorkItem = nil
        releaseExpiredTransactionUICarrier(transaction)
    }

    internal func endRecordingBackgroundTaskCarrier() {
        guard recordingBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(recordingBackgroundTask)
        recordingBackgroundTask = .invalid
    }
}
