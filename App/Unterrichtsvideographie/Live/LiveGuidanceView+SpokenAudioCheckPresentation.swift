extension SpokenAudioCheckModel {
    var blocksCapture: Bool {
        switch phase {
        case .preparing, .recording, .ready, .playing: true
        case .idle, .completed, .failed: false
        }
    }

    var canPlay: Bool { phase == .ready }

    var canCancel: Bool {
        switch phase {
        case .preparing, .recording, .ready, .playing: true
        case .idle, .completed, .failed: false
        }
    }

    var playbackCompleted: Bool { phase == .completed }

    var statusText: String {
        switch phase {
        case .idle: "Noch keine abgehörte Sprechprobe."
        case .preparing: "Kamera wird für die lokale Sprechprobe pausiert…"
        case .recording: "Sprechprobe läuft: vier Sekunden deutlich sprechen."
        case .ready: "Sprechprobe aufgenommen; jetzt vollständig abhören."
        case .playing: "Sprechprobe wird abgespielt…"
        case .completed: "Sprechprobe vollständig abgehört."
        case let .failed(message): "Sprechprobe fehlgeschlagen: \(message)"
        }
    }

    var statusIcon: String {
        switch phase {
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle"
        case .recording: "waveform.circle"
        case .playing: "speaker.wave.2.circle"
        default: "ear"
        }
    }
}
