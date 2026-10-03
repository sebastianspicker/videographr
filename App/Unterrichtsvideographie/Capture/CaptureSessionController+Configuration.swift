import AVFoundation
import GuidanceEngine
import QuartzCore
import SessionCore

extension CaptureSessionController {
    func configureSession(
        generation: Int,
        teachingSituation: TeachingSituationID,
        rotationAngle: CGFloat
    ) {
        guard isActive, activeGeneration == generation else { return }
        session.beginConfiguration()
        let negotiatedPreset = configureSessionPreset()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)

        if let failureMessage = installCaptureInputs() ?? installCaptureOutputs() {
            finishFailedConfiguration(generation, message: failureMessage)
            return
        }

        setRotation(rotationAngle, for: videoOutput?.connection(with: .video))
        setRotation(rotationAngle, for: movieOutput?.connection(with: .video))
        session.commitConfiguration()
        startConfiguredSession(
            generation: generation,
            teachingSituation: teachingSituation,
            presetDescription: negotiatedPreset.description
        )
    }

    private func configureSessionPreset() -> (preset: AVCaptureSession.Preset, description: String) {
        let negotiatedPreset: (AVCaptureSession.Preset, String)
        if session.canSetSessionPreset(.hd1920x1080) {
            negotiatedPreset = (.hd1920x1080, "1920×1080")
        } else if session.canSetSessionPreset(.hd1280x720) {
            negotiatedPreset = (.hd1280x720, "1280×720 (Fallback)")
        } else {
            negotiatedPreset = (.high, "Gerätequalität hoch (Fallback)")
        }
        session.sessionPreset = negotiatedPreset.0
        return (negotiatedPreset.0, negotiatedPreset.1)
    }

    private func installVideoInput() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return false }
        session.addInput(input)
        return true
    }

    private func installAudioInput() -> Bool {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return false }
        session.addInput(input)
        return true
    }

    private func installCaptureInputs() -> String? {
        guard installVideoInput() else { return "Keine Rückkamera verfügbar." }
        guard installAudioInput() else { return "Mikrofon nicht verfügbar - Aufnahme bleibt gesperrt." }
        return nil
    }

    private func installVideoOutput() -> Bool {
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        video.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(video) else { return false }
        session.addOutput(video)
        videoOutput = video
        return true
    }

    private func installAudioOutput() -> Bool {
        let audio = AVCaptureAudioDataOutput()
        audio.setSampleBufferDelegate(self, queue: audioQueue)
        guard session.canAddOutput(audio) else { return false }
        session.addOutput(audio)
        return true
    }

    private func installMovieOutput() -> Bool {
        let movie = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movie) else { return false }
        session.addOutput(movie)
        movieOutput = movie
        return true
    }

    private func installCaptureOutputs() -> String? {
        guard installVideoOutput() else { return "Videoausgabe konnte nicht eingerichtet werden." }
        guard installAudioOutput() else { return "Audioausgabe konnte nicht eingerichtet werden." }
        guard installMovieOutput() else { return "Filmaufnahme konnte nicht eingerichtet werden." }
        return nil
    }

    private func finishFailedConfiguration(_ generation: Int, message: String) {
        session.commitConfiguration()
        emitRuntime(.fallback(generation, message))
    }

    private func startConfiguredSession(
        generation: Int,
        teachingSituation: TeachingSituationID,
        presetDescription: String
    ) {
        guard isActive, activeGeneration == generation else { return }
        cacheCurrentAudioRouteOnSessionQueue()
        session.startRunning()
        let audioRoute = CaptureCapacity.normalizedAudioRoute(
            portTypeRawValues: AVAudioSession.sharedInstance().currentRoute.inputs.map { $0.portType.rawValue }
        )
        emitRuntime(.configuration(
            generation,
            videoConfiguration: "\(presetDescription) · tatsächliche Codecs nach Finalisierung",
            audioRoute: audioRoute
        ))
        prepareVision(for: teachingSituation, generation: generation)
        emitRuntime(.sessionStarted(generation))
    }
}
