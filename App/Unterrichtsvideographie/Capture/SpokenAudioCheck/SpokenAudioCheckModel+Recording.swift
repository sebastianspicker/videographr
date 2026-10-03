@preconcurrency import AVFoundation

extension SpokenAudioCheckModel {
    func prepareProtectedRecording() -> Bool {
        cleanupAbandonedFiles()
        cleanupFile()
        do {
            try reserveProtectedArtifact()
            phase = .preparing
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    func scheduleRecordingStart() {
        preparationTask?.cancel()
        preparationTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                try self?.beginRecording()
            } catch is CancellationError {
                return
            } catch {
                self?.fail(error.localizedDescription)
            }
        }
    }

    func beginRecording() throws {
        try configureAudioSession()
        let recorder = try makeRecorder(for: protectedRecordingURL())
        self.recorder = recorder
        phase = .recording
    }

    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try audioSession.setActive(true)
    }

    func protectedRecordingURL() throws -> URL {
        guard let fileURL, isRegularNonSymlinkFile(fileURL) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Die geschützte temporäre Audiodatei ist nicht verfügbar."
            ])
        }
        return fileURL
    }

    func makeRecorder(for fileURL: URL) throws -> AVAudioRecorder {
        let recorder = try AVAudioRecorder(url: fileURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        recorder.delegate = self
        guard recorder.prepareToRecord(), recorder.record(forDuration: 4) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSLocalizedDescriptionKey: "Mikrofonaufnahme konnte nicht gestartet werden."
            ])
        }
        return recorder
    }

    func makePlayer(for fileURL: URL) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = self
        guard player.prepareToPlay(), player.play() else {
            throw CocoaError(.fileReadUnknown, userInfo: [
                NSLocalizedDescriptionKey: "Wiedergabe konnte nicht gestartet werden."
            ])
        }
        return player
    }

    func recordingFinished(_ finishedRecorder: AVAudioRecorder, successfully: Bool) {
        guard recorder === finishedRecorder, phase == .recording else { return }
        recorder = nil
        guard successfully, let fileURL, isRegularNonSymlinkFile(fileURL) else {
            fail("Die temporäre Audiodatei wurde nicht vollständig geschrieben.")
            return
        }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
        phase = .ready
    }

    func playbackFinished(_ finishedPlayer: AVAudioPlayer, successfully: Bool) {
        guard player === finishedPlayer, phase == .playing else { return }
        player = nil
        guard successfully else {
            fail("Die Wiedergabe wurde nicht vollständig beendet.")
            return
        }
        playbackCompletion?()
        playbackCompletion = nil
        phase = .completed
        cleanupFile()
        deactivateAudioSession()
        let resume = resumeCapture
        resumeCapture = nil
        resume?()
    }

    func fail(_ message: String) {
        stopActiveAudio()
        cleanupFile()
        deactivateAudioSession()
        phase = .failed(message)
        let resume = resumeCapture
        resumeCapture = nil
        playbackCompletion = nil
        resume?()
    }

    func stopActiveAudio() {
        let activeRecorder = recorder
        recorder = nil
        activeRecorder?.stop()
        let activePlayer = player
        player = nil
        activePlayer?.stop()
    }
}
