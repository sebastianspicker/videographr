@preconcurrency import AVFoundation
import SwiftUI

/// Records one ephemeral pre-roll speech sample and counts the check only after
/// the operator has played it to completion. Amplitude metrics alone never set
/// this acknowledgement.
@MainActor
final class SpokenAudioCheckModel: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case recording
        case ready
        case playing
        case completed
        case failed(String)
    }

    @Published var phase: Phase = .idle
    var recorder: AVAudioRecorder?
    var player: AVAudioPlayer?
    var fileURL: URL?
    var preparationTask: Task<Void, Never>?
    var resumeCapture: (() -> Void)?
    var playbackCompletion: (() -> Void)?

    override init() {
        super.init()
        cleanupAbandonedFiles()
    }

    func start(
        pauseCapture: @escaping () -> Void,
        resumeCapture: @escaping () -> Void,
        playbackCompleted: @escaping () -> Void
    ) {
        guard !blocksCapture, prepareProtectedRecording() else { return }
        self.resumeCapture = resumeCapture
        self.playbackCompletion = playbackCompleted
        pauseCapture()
        scheduleRecordingStart()
    }

    func play() {
        guard phase == .ready, let fileURL else { return }
        do {
            let player = try makePlayer(for: fileURL)
            self.player = player
            phase = .playing
        } catch {
            fail(error.localizedDescription)
        }
    }

    func cancel(resumeCapture shouldResume: Bool) {
        preparationTask?.cancel()
        preparationTask = nil
        stopActiveAudio()
        cleanupFile()
        let resume = resumeCapture
        resumeCapture = nil
        playbackCompletion = nil
        phase = .idle
        deactivateAudioSession()
        if shouldResume { resume?() }
    }
}

extension SpokenAudioCheckModel: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.recordingFinished(recorder, successfully: flag) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.playbackFinished(player, successfully: flag) }
    }
}
