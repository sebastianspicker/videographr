import Foundation
import AVFoundation
import GuidanceEngine
import SessionCore
import QuartzCore
import UIKit

/// Immutable identity carried by every asynchronous recording event.
/// A later capture run must never accept an event for an earlier transaction.
struct RecordingTransaction: Hashable, Sendable {
    let sessionID: UUID
    let transactionID: UUID
    let generation: Int
}

/// Immutable recording inputs prepared by the persistence layer before AVFoundation starts.
struct RecordingStartRequest {
    let url: URL
    let stagedURL: URL
    let allowDespiteWarnings: Bool
    let readiness: SessionReadiness
    let plannedDurationMinutes: Int
    let sessionID: UUID
    let transactionID: UUID
    let store: SessionStore
}

/// Device/capture facts shown to the operator and copied into the durable take manifest.
struct CaptureRuntimeStatus: Equatable, Sendable {
    var videoConfiguration = "Noch nicht ausgehandelt"
    var audioRoute = "Keine Audioroute"
    var batteryPercent: Int?
    var thermalState = "unbekannt"
    var spokenAudioCheckCompleted = false
    /// `nil` means the platform did not provide an important-usage capacity value.
    var availableCapacityBytes: Int64?

    var hasResourceWarning: Bool {
        (batteryPercent.map { $0 <= 15 } ?? false)
            || thermalState == "ernst"
            || thermalState == "kritisch"
            || (availableCapacityBytes.map { $0 < CaptureGuardrails.minimumFreeCapacityBytes } ?? false)
    }
}

/// Capture limits shared by the preflight estimate and AVFoundation's in-flight guardrails.
/// The duration is bounded by `CaptureSession` (1...240 minutes) before it reaches this layer.
internal enum CaptureGuardrails {
    static let estimatedBytesPerSecond: Int64 = 1_500_000
    static let minimumFreeCapacityBytes: Int64 = 500_000_000

    static func duration(for plannedDurationMinutes: Int) -> CMTime {
        CMTime(seconds: Double(min(240, max(1, plannedDurationMinutes)) * 60), preferredTimescale: 1_000)
    }

    static func maximumFileSize(for plannedDurationMinutes: Int) -> Int64 {
        Int64(min(240, max(1, plannedDurationMinutes))) * 60 * estimatedBytesPerSecond
    }

    /// Never retain a device-provided route name: port types are stable capability categories.
    static func normalizedAudioRoute(portTypeRawValues: [String]) -> String {
        let types = Array(Set(portTypeRawValues)).sorted()
        guard !types.isEmpty else { return "Keine Audioroute" }
        let externalTypes: Set<String> = ["HeadsetMic", "USBAudio", "BluetoothHFP", "BluetoothLE"]
        let hasExternalInput = !externalTypes.isDisjoint(with: Set(types))
        return "Eingangstypen: \(types.joined(separator: ", ")) · extern: \(hasExternalInput ? "ja" : "nein")"
    }
}

/// Publishes capture state and guidance; `CaptureSessionController` owns AVFoundation objects.
///
/// Production path: sample buffers → `FrameSampler` (luminance + Vision) + `MotionService` →
/// pure `GuidanceEngine` / coding windows → published `guidance` for the Live UI.
/// Simulator path: synthetic classroom fixtures so demos work without hardware.
@MainActor
final class CameraSessionModel: NSObject, ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var microphoneAuthorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var isSessionRunning = false
    @Published var lastError: String?
    @Published var frameMetrics = FrameMetrics()
    @Published var cvFeatures = CVFeatures.empty
    @Published var guidance = GuidanceResult(tips: [])
    @Published var usingSimulatorFallback = false
    @Published var audioSample = AudioLevelSample()
    @Published var isStartingRecording = false
    @Published var isRecording = false
    @Published var isFinalizingRecording = false
    @Published var lastRecordingURL: URL?
    @Published var recordStatusMessage: String?
    /// Blocks the preview whenever an inactive/interrupted capture could expose stale pixels.
    @Published var privacyCoverIsVisible = true
    @Published var canRetryCapture = false
    /// In-memory recovery notice for Live UI; never replaces a newer take's status.
    @Published var artifactRecoveryDiagnostic: String?
    @Published var runtimeStatus = CaptureRuntimeStatus()
    /// Teaching-situation preset from Setup - drives scene expectations and coding.
    @Published var teachingSituation: TeachingSituationID = .frontalBoardInstruction {
        didSet {
            if oldValue != teachingSituation {
                capture.prepareVision(for: teachingSituation, generation: lifecycleGeneration)
                codingWindow.reset()
                sceneWindow.reset()
                transitionDetector.reset()
                recentTransitions = []
                recomputeGuidance()
            }
        }
    }
    /// Experimental-only analysis focus for unvalidated IPN/GTI rule priors.
    @Published var analysisFocus: CodingAnalysisFocus = .lessonAnalysis {
        didSet {
            if oldValue != analysisFocus {
                codingWindow.reset()
                sceneWindow.reset()
                transitionDetector.reset()
                recentTransitions = []
                recomputeGuidance()
            }
        }
    }
    /// Evidence-safe by default; experimental hypotheses require a persisted, usable protocol.
    @Published var operatingMode: GuidanceOperatingMode = .evidenceSafe {
        didSet {
            if oldValue != operatingMode {
                codingWindow.reset()
                transitionDetector.reset()
                recentTransitions = []
                recomputeGuidance()
            }
        }
    }
    /// Experimental-only temporal aggregation of unvalidated IPN/TIMSS/GTI rules.
    @Published var windowedCoding: PedagogicalCodingResult = .empty()
    /// Latest research-exportable coding snapshot (JSON via `jsonString()`).
    @Published var latestCodingSnapshot: ResearchCodingSnapshot?
    /// Callback when a durable coding snapshot should be persisted on the capture session.
    var onCodingSnapshot: ((UUID, ResearchCodingSnapshot) -> Void)?
    /// Direct measured observations are the normal durable capture trail.
    var onCaptureObservation: ((UUID, CaptureObservation) -> Void)?
    /// Must attach verified metadata; `false` rolls the promoted movie back.
    var onRecordingFinalized: ((RecordingTransaction, URL, CaptureRuntimeStatus) async -> Bool)?
    var onRecordingBegan: ((RecordingTransaction) -> Void)?
    /// A bounded callback wait ended without an AVFoundation failure; ownership remains recoverable.
    var onRecordingCompletionUnknown: ((RecordingTransaction, String) -> Void)?
    var onRecordingFailed: ((RecordingTransaction, String) -> Void)?
    /// Reports a mandatory local stop (consent withdrawal or low remaining capacity) to an owner
    /// that needs to add independent audit behaviour. The model always requests the stop itself.
    var onRecordingStopRequested: ((RecordingTransaction, String) -> Void)?
    internal var activeRecordingTransaction: RecordingTransaction?
    /// Terminal ownership retained after background expiry so a late delegate callback can still
    /// attach or roll back its artifact without changing a newer take's UI state.
    internal var deferredArtifactTransactions: [RecordingTransaction: Void] = [:]
    internal var stopRequestedDuringStart = false
    internal var recordingBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    internal var expirationRecoveryWorkItem: DispatchWorkItem?
    internal var startAcknowledgementWatchdogWorkItem: DispatchWorkItem?
    internal var finalizationWatchdogWorkItem: DispatchWorkItem?
    internal var metadataAttachmentWatchdogWorkItem: DispatchWorkItem?
    internal var recordingWatchdogs = RecordingTransactionWatchdogs<RecordingTransaction>()
    internal var boundSessionID: UUID?
    internal var requiresFreshLiveSample = true

    internal let capture = CaptureSessionController()
    /// Read-only preview handle. Configuration and start/stop stay inside `capture`.
    var session: AVCaptureSession { capture.session }
    internal let motion = MotionService()
    internal let engine = GuidanceEngine()
    internal var codingWindow = PedagogicalCodingWindow(capacity: 8)
    internal var sceneWindow = TeachingSceneWindow(capacity: 6)
    internal var transitionDetector = SceneTransitionDetector()
    /// Experimental-only scene/TIMSS rule transitions.
    @Published var recentTransitions: [SceneTransitionEvent] = []
    internal var lastPersistedSnapshotAt: CFTimeInterval = 0
    internal var lastPersistedObservationAt: CFTimeInterval = 0
    internal let observerStorage = CaptureObserverStorage()
    internal var simulatorTimer: Timer?
    internal var simulatorTick = 0
    internal var simAudioPhase = 0
    internal var lifecycleGeneration = 0
    internal var liveIsActive = false
    internal var viewWantsLive = false
    internal var appIsActive = true
    internal var captureIsInterrupted = false
    internal var runtimeRecoveryAttempts = 0
    internal let maximumRuntimeRecoveryAttempts = 1
    internal var previousIdleTimerDisabled: Bool?

    override init() {
        super.init()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshRuntimeStatus()
        configureCaptureObservers()
    }

    /// Begin permission flow, motion updates, and capture session (or simulator fallback).

    /// Wire video + audio inputs/outputs on the capture owner's serial queue.

    internal func persistOperationalObservation(kind: CaptureObservationKind, note: String) {
        guard isStartingRecording || isRecording || isFinalizingRecording,
              let transaction = activeRecordingTransaction,
              let boundSessionID,
              boundSessionID == transaction.sessionID
        else { return }
        var observationValues = CaptureObservation.Values()
        observationValues.kind = kind
        observationValues.measurements = [
            "audioPeak": audioSample.peakLevel,
            "audioAverage": audioSample.averageLevel,
            "audioDropoutDetected": audioSample.dropoutDetected ? 1 : 0
        ]
        observationValues.note = note
        let observation = CaptureObservation(observationValues)
        onCaptureObservation?(boundSessionID, observation)
    }

    internal func handleCaptureEvent(_ event: CaptureSessionController.Event) {
        switch event {
        case .sessionStarted, .configuration, .recordingCapacityUpdated, .recordingStopRequested,
             .sessionStopped, .fallback, .frame, .audio:
            handleRuntimeCaptureEvent(event)
        default:
            handleRecordingCaptureEvent(event)
        }
    }

    internal func handleRuntimeCaptureEvent(_ event: CaptureSessionController.Event) {
        handleRuntimeCaptureEventCarrier(event)
    }

    internal func handleRecordingCaptureEvent(_ event: CaptureSessionController.Event) {
        handleRecordingCaptureEventCarrier(event)
    }

    internal func acceptsRecordingEvent(for transaction: RecordingTransaction) -> Bool {
        acceptsRecordingEventCarrier(for: transaction)
    }

    internal func resolveFinishedRecording(transaction: RecordingTransaction, url: URL) async {
        await resolveFinishedRecordingCarrier(transaction: transaction, url: url)
    }

    internal func completeRecordingTransaction(_ transaction: RecordingTransaction, status: String) {
        completeRecordingTransactionCarrier(transaction, status: status)
    }

    internal func beginRecordingBackgroundTask(for transaction: RecordingTransaction) {
        beginRecordingBackgroundTaskCarrier(for: transaction)
    }

    private func handleBackgroundExpiration(for transaction: RecordingTransaction) {
        handleBackgroundExpirationCarrier(for: transaction)
    }

    private func scheduleExpirationRecovery(for transaction: RecordingTransaction) {
        scheduleExpirationRecoveryCarrier(for: transaction)
    }

    /// Releases the UI after the bounded background window while retaining only artifact
    /// ownership. Late callbacks resolve this transaction silently and cannot affect a new take.
    private func releaseExpiredTransactionUI(_ transaction: RecordingTransaction) {
        releaseExpiredTransactionUICarrier(transaction)
    }

    /// A missing `didStartRecordingTo` must not leave foreground controls locked forever.
    internal func armStartAcknowledgementWatchdog(for transaction: RecordingTransaction) {
        armStartAcknowledgementWatchdogCarrier(for: transaction)
    }

    /// A missing `didFinishRecordingTo` releases the foreground UI but retains artifact recovery.
    internal func armFinalizationWatchdog(for transaction: RecordingTransaction) {
        armFinalizationWatchdogCarrier(for: transaction)
    }

    private func armMetadataAttachmentWatchdog(for transaction: RecordingTransaction) {
        armMetadataAttachmentWatchdogCarrier(for: transaction)
    }

    internal func cancelWatchdog(
        _ phase: RecordingTransactionWatchdogs<RecordingTransaction>.Phase,
        for transaction: RecordingTransaction
    ) {
        cancelWatchdogCarrier(phase, for: transaction)
    }

    private func expireStartAcknowledgementWatchdog(for transaction: RecordingTransaction) {
        expireStartAcknowledgementWatchdogCarrier(for: transaction)
    }

    private func expireFinalizationWatchdog(for transaction: RecordingTransaction) {
        expireFinalizationWatchdogCarrier(for: transaction)
    }

    private func expireMetadataAttachmentWatchdog(for transaction: RecordingTransaction) {
        expireMetadataAttachmentWatchdogCarrier(for: transaction)
    }

    internal func endRecordingBackgroundTask() {
        endRecordingBackgroundTaskCarrier()
    }

}

/// Serial owner for AVFoundation capture objects. UI state is never mutated here; callers receive
/// value events and publish them on the main actor. The session, movie output, and their lifecycle
/// are confined to `sessionQueue`; Vision state is confined to `videoQueue`.
