import Foundation
import GuidanceEngine
import SessionCore
import UIKit

extension CameraSessionModel {
    internal func handleRuntimeCaptureEventCarrier(_ event: CaptureSessionController.Event) {
        if handleRuntimeLifecycleEvent(event) { return }
        if handleRuntimeRecordingEvent(event) { return }
        handleRuntimeSampleEvent(event)
    }

    private func handleRuntimeLifecycleEvent(_ event: CaptureSessionController.Event) -> Bool {
        if handleRuntimeStartupEvent(event) { return true }
        return handleRuntimeShutdownEvent(event)
    }

    private func handleRuntimeStartupEvent(_ event: CaptureSessionController.Event) -> Bool {
        if case let .sessionStarted(generation) = event {
            handleSessionStarted(generation: generation)
            return true
        }
        if case let .configuration(generation, videoConfiguration, audioRoute) = event {
            handleSessionConfiguration(generation: generation, videoConfiguration: videoConfiguration, audioRoute: audioRoute)
            return true
        }
        return false
    }

    private func handleRuntimeShutdownEvent(_ event: CaptureSessionController.Event) -> Bool {
        if case let .sessionStopped(generation) = event {
            handleSessionStopped(generation: generation)
            return true
        }
        if case let .fallback(generation, message) = event {
            startSimulatorFallback(reason: message, generation: generation)
            return true
        }
        return false
    }

    private func handleSessionStarted(generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        isSessionRunning = true
        usingSimulatorFallback = false
        lastError = nil
    }

    private func handleSessionConfiguration(generation: Int, videoConfiguration: String, audioRoute: String) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        runtimeStatus.videoConfiguration = videoConfiguration
        runtimeStatus.audioRoute = audioRoute
    }

    private func handleSessionStopped(generation: Int) {
        guard generation == lifecycleGeneration else { return }
        isSessionRunning = false
    }

    private func handleRuntimeRecordingEvent(_ event: CaptureSessionController.Event) -> Bool {
        if case let .recordingCapacityUpdated(transaction, availableBytes) = event {
            updateRecordingCapacity(availableBytes, for: transaction)
            return true
        }
        if case let .recordingStopRequested(transaction, reason) = event {
            handleRecordingStopRequest(transaction, reason: reason)
            return true
        }
        return false
    }

    private func updateRecordingCapacity(_ availableBytes: Int64?, for transaction: RecordingTransaction) {
        guard acceptsRecordingEvent(for: transaction) else { return }
        runtimeStatus.availableCapacityBytes = availableBytes
    }

    private func handleRecordingStopRequest(_ transaction: RecordingTransaction, reason: String) {
        guard acceptsRecordingEvent(for: transaction) else { return }
        isStartingRecording = false
        isRecording = false
        isFinalizingRecording = true
        recordStatusMessage = reason
        onRecordingStopRequested?(transaction, reason)
        persistOperationalObservation(kind: .transition, note: reason)
    }

    private func handleRuntimeSampleEvent(_ event: CaptureSessionController.Event) {
        if case let .frame(generation, analysis) = event {
            handleFrame(analysis, generation: generation)
            return
        }
        if case let .audio(generation, sample) = event {
            handleAudioSample(sample, generation: generation)
        }
    }

    private func handleFrame(_ analysis: LiveFrameAnalysis, generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        if isSessionRunning { runtimeRecoveryAttempts = 0 }
        requiresFreshLiveSample = false
        if appIsActive, !captureIsInterrupted { privacyCoverIsVisible = false }
        frameMetrics = analysis.metrics
        cvFeatures = analysis.cv
        recomputeGuidance()
    }

    private func handleAudioSample(_ sample: AudioLevelSample, generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        audioSample = sample
    }

    internal func handleRecordingCaptureEventCarrier(_ event: CaptureSessionController.Event) {
        if handleRecordingStateEvent(event) { return }
        if handleRecordingCompletionEvent(event) { return }
        handleRecordingFailureEvent(event)
    }

    private func handleRecordingStateEvent(_ event: CaptureSessionController.Event) -> Bool {
        if case let .recordingBegan(transaction) = event {
            handleRecordingBegan(transaction)
            return true
        }
        if case let .recordingFinalizing(transaction) = event {
            handleRecordingFinalizing(transaction)
            return true
        }
        return false
    }

    private func handleRecordingBegan(_ transaction: RecordingTransaction) {
        guard acceptsRecordingEventCarrier(for: transaction) else { return }
        cancelWatchdog(.startAcknowledgement, for: transaction)
        onRecordingBegan?(transaction)
        let finalizationAlreadyRequested = stopRequestedDuringStart || isFinalizingRecording
        isStartingRecording = false
        isRecording = !finalizationAlreadyRequested
        isFinalizingRecording = finalizationAlreadyRequested
        recordStatusMessage = finalizationAlreadyRequested
            ? "Aufnahme wird finalisiert…"
            : "Kontinuierliche Aufnahme läuft"
        disableIdleTimerForRecording()
        persistCaptureObservation(
            from: guidance,
            force: true,
            kind: .transition,
            note: "AVCaptureFileOutput hat den Aufnahmestart bestätigt."
        )
    }

    private func handleRecordingFinalizing(_ transaction: RecordingTransaction) {
        guard acceptsRecordingEvent(for: transaction) else { return }
        cancelWatchdog(.startAcknowledgement, for: transaction)
        armFinalizationWatchdog(for: transaction)
        isStartingRecording = false
        isRecording = false
        isFinalizingRecording = true
        recordStatusMessage = "Aufnahme wird finalisiert…"
    }

    private func handleRecordingCompletionEvent(_ event: CaptureSessionController.Event) -> Bool {
        if case let .recordingFinished(transaction, url) = event {
            handleRecordingFinished(transaction, url: url)
            return true
        }
        if case let .recordingRollbackCompleted(transaction, rollbackError) = event {
            handleRecordingRollback(transaction, rollbackError: rollbackError)
            return true
        }
        return false
    }

    private func handleRecordingFinished(_ transaction: RecordingTransaction, url: URL) {
        cancelWatchdog(.startAcknowledgement, for: transaction)
        cancelWatchdog(.finalization, for: transaction)
        if acceptsRecordingEventCarrier(for: transaction) { armMetadataAttachmentWatchdogCarrier(for: transaction) }
        Task { [weak self] in
            await self?.resolveFinishedRecordingCarrier(transaction: transaction, url: url)
        }
    }

    private func handleRecordingRollback(_ transaction: RecordingTransaction, rollbackError: String?) {
        cancelWatchdog(.finalization, for: transaction)
        cancelWatchdog(.metadataAttachment, for: transaction)
        if acceptsRecordingEventCarrier(for: transaction) {
            completeRecordingTransactionCarrier(transaction, status: rollbackStatus(rollbackError))
            return
        }
        guard deferredArtifactTransactions[transaction] != nil else { return }
        deferredArtifactTransactions.removeValue(forKey: transaction)
        if let rollbackError {
            artifactRecoveryDiagnostic = "Lokale Aufnahmebereinigung fehlgeschlagen: \(rollbackError). Beim nächsten App-Start wird sie erneut geprüft."
        }
    }

    private func rollbackStatus(_ rollbackError: String?) -> String {
        if let rollbackError {
            return "Aufnahme-Metadaten konnten nicht gesichert werden; lokale Bereinigung fehlgeschlagen: \(rollbackError)"
        }
        return "Aufnahme-Metadaten konnten nicht gesichert werden; Datei wurde zurückgerollt."
    }

    private func handleRecordingFailureEvent(_ event: CaptureSessionController.Event) {
        guard case let .recordingFailed(transaction, message) = event, let transaction else { return }
        cancelWatchdogCarrier(.startAcknowledgement, for: transaction)
        cancelWatchdogCarrier(.finalization, for: transaction)
        cancelWatchdogCarrier(.metadataAttachment, for: transaction)
        if acceptsRecordingEventCarrier(for: transaction) {
            onRecordingFailed?(transaction, message)
            completeRecordingTransactionCarrier(transaction, status: message)
            return
        }
        if deferredArtifactTransactions.removeValue(forKey: transaction) != nil {
            onRecordingFailed?(transaction, message)
        }
    }

    internal func acceptsRecordingEventCarrier(for transaction: RecordingTransaction) -> Bool {
        activeRecordingTransaction == transaction
    }

    internal func resolveFinishedRecordingCarrier(transaction: RecordingTransaction, url: URL) async {
        guard acceptsRecordingEventCarrier(for: transaction) || deferredArtifactTransactions[transaction] != nil else { return }
        let metadataAttached = await onRecordingFinalized?(transaction, url, runtimeStatus) ?? false
        cancelWatchdogCarrier(.metadataAttachment, for: transaction)
        if acceptsRecordingEventCarrier(for: transaction) {
            resolveActiveFinishedRecording(transaction, url: url, metadataAttached: metadataAttached)
            return
        }
        resolveDeferredFinishedRecording(transaction, url: url, metadataAttached: metadataAttached)
    }

    private func resolveActiveFinishedRecording(
        _ transaction: RecordingTransaction,
        url: URL,
        metadataAttached: Bool
    ) {
        guard metadataAttached else {
            isStartingRecording = false
            isRecording = false
            isFinalizingRecording = true
            recordStatusMessage = "Aufnahme-Metadaten werden zurückgerollt…"
            capture.rollbackPromotedRecording(url, for: transaction)
            return
        }
        isRecording = false
        isStartingRecording = false
        isFinalizingRecording = false
        lastRecordingURL = url
        capture.confirmPromotedRecording(for: transaction)
        completeRecordingTransactionCarrier(transaction, status: "Aufnahme gespeichert")
    }

    private func resolveDeferredFinishedRecording(
        _ transaction: RecordingTransaction,
        url: URL,
        metadataAttached: Bool
    ) {
        guard deferredArtifactTransactions[transaction] != nil else { return }
        if metadataAttached {
            capture.confirmPromotedRecording(for: transaction)
            deferredArtifactTransactions.removeValue(forKey: transaction)
            return
        }
        capture.rollbackPromotedRecording(url, for: transaction)
    }

}
