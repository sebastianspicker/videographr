import AVFoundation
import Foundation
import GuidanceEngine
import QuartzCore
import SessionCore

final class CaptureSessionController: NSObject {
    enum Event: Sendable {
        case sessionStarted(Int)
        case sessionStopped(Int)
        case configuration(Int, videoConfiguration: String, audioRoute: String)
        case fallback(Int, String)
        case frame(Int, LiveFrameAnalysis)
        case audio(Int, AudioLevelSample)
        case recordingBegan(RecordingTransaction)
        case recordingFinalizing(RecordingTransaction)
        case recordingFinished(RecordingTransaction, URL)
        case recordingRollbackCompleted(RecordingTransaction, String?)
        case recordingFailed(RecordingTransaction?, String)
        case recordingCapacityUpdated(RecordingTransaction, Int64?)
        case recordingStopRequested(RecordingTransaction, String)
    }

    let session = AVCaptureSession()
    var onEvent: ((Event) -> Void)?

    let sessionQueue = DispatchQueue(label: "uv.camera.session")
    let videoQueue = DispatchQueue(label: "uv.camera.video", qos: .userInitiated)
    let audioQueue = DispatchQueue(label: "uv.camera.audio", qos: .userInitiated)
    let sampler = FrameSampler()
    var videoOutput: AVCaptureVideoDataOutput?
    var movieOutput: AVCaptureMovieFileOutput?
    var activeGeneration: Int?
    var videoGeneration: Int?
    var audioGeneration: Int?
    var isActive = false
    var pendingStop = false
    var recording: Recording?
    var promotedArtifacts = RecordingArtifactOwnership<RecordingTransaction>()
    var queuedStart: StartRequest?
    var audioDeliveryScheduled = false
    var latestAudio: (generation: Int, sample: AudioLevelSample)?
    var minimumObservedAudioAverage: Double?
    var expectedNextAudioPresentationTime: CMTime?
    var capacityMonitor: DispatchSourceTimer?

    struct Recording {
        let transaction: RecordingTransaction
        let store: SessionStore
        let temporaryURL: URL
        let destinationURL: URL
        var didStart: Bool
        var stopRequested: Bool
        var finalizing: Bool
    }

    struct RecordingStartRequest {
        let destinationURL: URL
        let stagedURL: URL
        let transaction: RecordingTransaction
        let store: SessionStore
        let maximumDuration: CMTime
        let maximumFileSize: Int64
    }

    struct StartRequest {
        let generation: Int
        let teachingSituation: TeachingSituationID
        let rotationAngle: CGFloat
    }

    func prepareVision(for situation: TeachingSituationID, generation: Int) {
        videoQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.videoGeneration = generation
            self.sampler.configureVision(for: situation)
            self.sampler.resetVisionTemporalState()
        })
    }

    func resetVisionTemporalState() {
        videoQueue.async(execute: DispatchWorkItem { [weak self] in self?.sampler.resetVisionTemporalState() })
    }

    func start(generation: Int, teachingSituation: TeachingSituationID, rotationAngle: CGFloat) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.recording != nil {
                self.isActive = true
                self.activeGeneration = generation
                self.queuedStart = StartRequest(
                    generation: generation,
                    teachingSituation: teachingSituation,
                    rotationAngle: rotationAngle
                )
                return
            }
            self.activeGeneration = generation
            self.isActive = true
            self.pendingStop = false
            self.videoQueue.async(execute: DispatchWorkItem { [weak self] in self?.videoGeneration = generation })
            self.audioQueue.async(execute: DispatchWorkItem { [weak self] in
                self?.audioGeneration = generation
                self?.latestAudio = nil
                self?.audioDeliveryScheduled = false
                self?.minimumObservedAudioAverage = nil
                self?.expectedNextAudioPresentationTime = nil
            })
            self.configureSession(
                generation: generation,
                teachingSituation: teachingSituation,
                rotationAngle: rotationAngle
            )
        })
    }

    func stopAfterRecordingFinalizes() {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self else { return }
            let stoppingGeneration = self.activeGeneration
            self.isActive = false
            self.activeGeneration = nil
            self.queuedStart = nil
            self.videoQueue.async(execute: DispatchWorkItem { [weak self] in self?.videoGeneration = nil })
            self.audioQueue.async(execute: DispatchWorkItem { [weak self] in
                self?.audioGeneration = nil
                self?.latestAudio = nil
                self?.minimumObservedAudioAverage = nil
                self?.expectedNextAudioPresentationTime = nil
            })
            if self.recording != nil {
                self.pendingStop = true
                if var recording = self.recording {
                    recording.stopRequested = true
                    self.recording = recording
                    if recording.didStart {
                        self.finishRecordingIfNeeded()
                    }
                }
            } else {
                self.stopSession(generation: stoppingGeneration)
            }
        })
    }

    func startRecording(_ request: RecordingStartRequest) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self,
                  self.isActive,
                  self.activeGeneration == request.transaction.generation,
                  self.recording == nil,
                  self.session.isRunning,
                  let movieOutput = self.movieOutput
            else {
                self?.emit(.recordingFailed(request.transaction, "Capture-Session nicht bereit."))
                return
            }

            movieOutput.maxRecordedDuration = request.maximumDuration
            movieOutput.maxRecordedFileSize = request.maximumFileSize
            self.recording = Recording(
                transaction: request.transaction,
                store: request.store,
                temporaryURL: request.stagedURL,
                destinationURL: request.destinationURL,
                didStart: false,
                stopRequested: false,
                finalizing: false
            )
            movieOutput.startRecording(to: request.stagedURL, recordingDelegate: self)
        })
    }

    func stopRecording(transaction: RecordingTransaction) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self, var recording = self.recording, recording.transaction == transaction else { return }
            recording.stopRequested = true
            self.recording = recording
            if recording.didStart {
                self.finishRecordingIfNeeded()
            }
        })
    }

    func rollbackPromotedRecording(_ url: URL, for transaction: RecordingTransaction) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self,
                  let promotedURL = self.promotedArtifacts.validatedDestination(
                    for: transaction,
                    matching: url
                  )
            else {
                self?.emit(.recordingRollbackCompleted(
                    transaction,
                    "Die zugehörige Aufnahme konnte nicht eindeutig verifiziert werden."
                ))
                return
            }
            do {
                try FileManager.default.removeItem(at: promotedURL)
                self.promotedArtifacts.confirm(transaction)
                self.emit(.recordingRollbackCompleted(transaction, nil))
            } catch {
                // Retain the transaction marker: a later start cannot mistake this canonical
                // artifact for a successful recording, and startup reconciliation can report it.
                self.emit(.recordingRollbackCompleted(transaction, error.localizedDescription))
            }
        })
    }

    func confirmPromotedRecording(for transaction: RecordingTransaction) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            self?.promotedArtifacts.confirm(transaction)
        })
    }

    func updateVideoRotation(angle: CGFloat) {
        sessionQueue.async(execute: DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setRotation(angle, for: self.videoOutput?.connection(with: .video))
            self.setRotation(angle, for: self.movieOutput?.connection(with: .video))
        })
    }

    func finishRecordingIfNeeded() {
        guard var recording else { return }
        guard recording.didStart else { return }
        guard !recording.finalizing else { return }
        recording.finalizing = true
        self.recording = recording
        stopCapacityMonitor()
        emit(.recordingFinalizing(recording.transaction))
        movieOutput?.stopRecording()
    }

    func stopSession(generation: Int?) {
        guard let generation else { return }
        guard session.isRunning else {
            emit(.sessionStopped(generation))
            return
        }
        session.stopRunning()
        emit(.sessionStopped(generation))
    }

    func setRotation(_ angle: CGFloat, for connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    func emit(_ event: Event) {
        onEvent?(event)
    }
}
