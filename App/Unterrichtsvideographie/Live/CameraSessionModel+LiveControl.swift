import AVFoundation
import Foundation
import GuidanceEngine
import SessionCore
import UIKit

extension CameraSessionModel {
    func start() {
        viewWantsLive = true
        activateLive()
    }

    private func activateLive() {
        guard viewWantsLive else { return }
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        liveIsActive = true
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        // Vision is configured by the serial capture owner only after this generation's
        // session has been configured and started. Retagging here could mislabel an old frame.
        isSessionRunning = false
        usingSimulatorFallback = false
        lastError = nil
        canRetryCapture = false
        // A capture transaction outlives preview generations. A foreground resume can arrive
        // before the serial capture queue emits `recordingFinalizing`; keep ownership until a
        // tagged terminal event closes it.
        if activeRecordingTransaction == nil {
            isStartingRecording = false
            isRecording = false
            isFinalizingRecording = false
        }
        lastRecordingURL = nil
        recordStatusMessage = nil
        frameMetrics = FrameMetrics()
        cvFeatures = .empty
        guidance = GuidanceResult(tips: [])
        latestCodingSnapshot = nil
        requiresFreshLiveSample = true
        privacyCoverIsVisible = true
        audioSample = AudioLevelSample()
        codingWindow.reset()
        sceneWindow.reset()
        transitionDetector.reset()
        recentTransitions = []
        windowedCoding = .empty()
        lastPersistedSnapshotAt = 0
        motion.start()
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["VIDEOGRAPHR_E2E_SESSION"] != nil {
            startSimulatorFallback(reason: "Stabile Simulatorvorschau für UI-Prüfung.", generation: generation)
            return
        }
        #endif
        requestMicThenVideo(generation: generation)
    }

    func bind(to sessionID: UUID) {
        guard boundSessionID != sessionID else { return }
        boundSessionID = sessionID
        latestCodingSnapshot = nil
        lastPersistedSnapshotAt = 0
        requiresFreshLiveSample = true
        privacyCoverIsVisible = true
        frameMetrics = FrameMetrics()
        cvFeatures = .empty
        audioSample = AudioLevelSample()
        runtimeStatus.spokenAudioCheckCompleted = false
        guidance = GuidanceResult(tips: [])
        windowedCoding = .empty()
        codingWindow.reset()
        sceneWindow.reset()
        transitionDetector.reset()
        recentTransitions = []
    }

    private func requestMicThenVideo(generation: Int) {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneAuthorizationStatus = micStatus
        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.microphoneAuthorizationStatus = granted ? .authorized : .denied
                    self?.requestVideo(generation: generation)
                }
            }
        } else {
            requestVideo(generation: generation)
        }
    }

    private func requestVideo(generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneAuthorizationStatus = micStatus
        guard micStatus == .authorized else {
            startSimulatorFallback(
                reason: "Mikrofonzugriff erforderlich - Berechtigung in Einstellungen aktivieren.",
                generation: generation
            )
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        if status == .authorized {
            configureAndStartSession(generation: generation)
            return
        }
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.handleVideoAuthorization(granted, generation: generation)
                }
            }
            return
        }
        startSimulatorFallback(
            reason: "Keine Kamera-Berechtigung - Demo-Modus mit synthetischem Klassenzimmer",
            generation: generation
        )
    }

    private func handleVideoAuthorization(_ granted: Bool, generation: Int) {
        authorizationStatus = granted ? .authorized : .denied
        guard liveIsActive, lifecycleGeneration == generation else { return }
        if granted {
            configureAndStartSession(generation: generation)
            return
        }
        startSimulatorFallback(reason: "Kamerazugriff verweigert - Demo-Modus", generation: generation)
    }

    /// Tear down motion, timers, Vision state, and the capture session (stop recording first if needed).
    func stop() {
        viewWantsLive = false
        suspend()
    }

    internal func suspend() {
        guard liveIsActive || isRecording || isFinalizingRecording else { return }
        liveIsActive = false
        isSessionRunning = false
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        lifecycleGeneration &+= 1
        motion.stop()
        simulatorTimer?.invalidate()
        simulatorTimer = nil
        capture.resetVisionTemporalState()
        cvFeatures = .empty
        if let transaction = activeRecordingTransaction {
            beginRecordingBackgroundTask(for: transaction)
        }
        capture.stopAfterRecordingFinalizes()
    }

    internal func resumeIfDesired() {
        guard viewWantsLive, appIsActive, !captureIsInterrupted, !liveIsActive else { return }
        activateLive()
    }

    func retryCapture() {
        guard canRetryCapture, viewWantsLive, appIsActive, !captureIsInterrupted else { return }
        runtimeRecoveryAttempts = 0
        canRetryCapture = false
        suspend()
        resumeIfDesired()
    }

    /// Surfaces a synchronous SessionStore preparation failure beside the Live controls.
    func showRecordingPreparationError(_ message: String) {
        guard !isStartingRecording, !isRecording, !isFinalizingRecording else { return }
        recordStatusMessage = "Aufnahme konnte nicht vorbereitet werden: \(message)"
    }

    func markSpokenAudioCheckCompleted() {
        runtimeStatus.spokenAudioCheckCompleted = true
    }

    func invalidateSpokenAudioCheck() {
        runtimeStatus.spokenAudioCheckCompleted = false
    }

    /// Live/UI callers should invoke this whenever local collection/reflection authority changes.
    /// A revoked or expired authority stops an active take rather than merely disabling the next one.
    func enforceCaptureAuthorization(
        _ isAuthorized: Bool,
        transactionID: UUID? = nil,
        reason: String = "Lokale Freigabe ist nicht mehr aktiv - Aufnahme wird finalisiert."
    ) {
        guard !isAuthorized, let transaction = activeRecordingTransaction else { return }
        if let transactionID, transaction.transactionID != transactionID { return }
        requestRecordingStop(
            transaction: transaction,
            reason: reason
        )
    }

    /// Continuous classroom recording to a local movie file (Derry continuous take).
    /// - Parameters:
    ///   - url: Destination `.mp4`; the capture owner records to a temporary sibling first.
    ///   - allowDespiteWarnings: When true, start even if `readiness.canRecord` is false.
    ///   - readiness: Latest Setup+sensor gate from the Live view.
    @discardableResult
    func startRecording(_ request: RecordingStartRequest) -> Bool {
        guard canStartRecording(request) else { return false }
        let transaction = RecordingTransaction(
            sessionID: request.sessionID,
            transactionID: request.transactionID,
            generation: lifecycleGeneration
        )
        prepareRecordingStart(transaction, request: request)
        capture.startRecording(
            CaptureSessionController.RecordingStartRequest(
                destinationURL: request.url,
                stagedURL: request.stagedURL,
                transaction: transaction,
                store: request.store,
                maximumDuration: CaptureGuardrails.duration(for: request.plannedDurationMinutes),
                maximumFileSize: CaptureGuardrails.maximumFileSize(for: request.plannedDurationMinutes)
            )
        )
        return true
    }

    private func canStartRecording(_ request: RecordingStartRequest) -> Bool {
        guard hasValidRecordingReadiness(request) else { return false }
        if usingSimulatorFallback {
            recordStatusMessage = "Demo-Modus zeigt Vorschau, erzeugt aber keine Medienaufnahme."
            return false
        }
        guard captureSessionIsReadyForRecording() else {
            recordStatusMessage = "Capture-Session nicht bereit oder Aufnahme wird finalisiert."
            return false
        }
        return true
    }

    private func hasValidRecordingReadiness(_ request: RecordingStartRequest) -> Bool {
        if !request.readiness.canOverrideQualityWarnings {
            recordStatusMessage = "Aufnahme blockiert: aktiver lokaler Freigabedatensatz fehlt."
            return false
        }
        if !request.readiness.canRecord, !request.allowDespiteWarnings {
            recordStatusMessage = "Aufnahme blockiert: \(request.readiness.summaryDE)"
            return false
        }
        return true
    }

    private func captureSessionIsReadyForRecording() -> Bool {
        [
            liveIsActive,
            isSessionRunning,
            !isStartingRecording,
            !isRecording,
            !isFinalizingRecording
        ].allSatisfy { $0 }
    }

    private func prepareRecordingStart(_ transaction: RecordingTransaction, request: RecordingStartRequest) {
        activeRecordingTransaction = transaction
        lastPersistedObservationAt = 0
        lastPersistedSnapshotAt = 0
        stopRequestedDuringStart = false
        isStartingRecording = true
        // `isRecording` becomes true exclusively in the AVFoundation didStart delegate event.
        isRecording = false
        isFinalizingRecording = false
        recordStatusMessage = request.allowDespiteWarnings && !request.readiness.canRecord
            ? "Aufnahme wird gestartet (trotz unvollständiger Readiness)"
            : "Kontinuierliche Aufnahme wird gestartet"
        armStartAcknowledgementWatchdog(for: transaction)
    }

    /// Simulator previews are intentionally non-recording; reject before callers create recording metadata.
    func rejectSimulatorRecordingAttempt() {
        guard usingSimulatorFallback else { return }
        recordStatusMessage = "Demo-Modus zeigt Vorschau, erzeugt aber keine Medienaufnahme."
    }

    /// End the continuous take; file finalize is handled by the movie-output delegate.
    func stopRecording() {
        if usingSimulatorFallback {
            isRecording = false
            recordStatusMessage = "Demo-Aufnahme beendet"
            return
        }
        guard let transaction = activeRecordingTransaction else { return }
        requestRecordingStop(transaction: transaction, reason: "Stopp angefordert.")
    }

    private func requestRecordingStop(transaction: RecordingTransaction, reason: String) {
        guard activeRecordingTransaction == transaction, !isFinalizingRecording else { return }
        persistCaptureObservation(from: guidance, force: true, kind: .transition, note: reason)
        onRecordingStopRequested?(transaction, reason)
        if isStartingRecording {
            stopRequestedDuringStart = true
            recordStatusMessage = "Stopp nach Startbestätigung wird angefordert…"
        } else if isRecording {
            isFinalizingRecording = true
            recordStatusMessage = "Aufnahme wird finalisiert…"
        } else {
            return
        }
        capture.stopRecording(transaction: transaction)
    }
}
