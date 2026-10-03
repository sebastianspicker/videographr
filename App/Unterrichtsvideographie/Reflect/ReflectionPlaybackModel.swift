import AVFoundation
import Observation
import SessionCore
import SwiftUI

struct ReflectionMediaRequest: Equatable {
    let sessionID: UUID
    let assets: [SessionMediaAsset]
}

/// Derived once per content render, independently of playback clock updates.
struct ReflectionAnnotationIndex {
    private let groups: [String: [EvidenceAnnotation]]

    init(_ annotations: [EvidenceAnnotation]) {
        groups = Dictionary(grouping: annotations, by: \.promptIdentifier)
            .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
    }

    func annotations(for prompt: ReflectionPromptID) -> [EvidenceAnnotation] {
        groups[prompt.rawValue] ?? []
    }

    var linkedPromptCount: Int {
        ReflectionPromptID.allCases.reduce(0) { $0 + (groups[$1.rawValue]?.isEmpty == false ? 1 : 0) }
    }
}

/// Only the clock and playback controls observe position; notes and evidence do not.
@MainActor
@Observable
final class ReflectionPlaybackModel {
    private(set) var player: AVPlayer?
    private(set) var positionMilliseconds: Int64 = 0
    private(set) var mediaURL: URL?
    private(set) var isSeeking = false
    private(set) var seekRevision = 0
    @ObservationIgnored private var observation: PlaybackTimeObservation?
    @ObservationIgnored private var generation = 0

    func configure(url: URL?) {
        guard mediaURL != url || (url != nil && player == nil) else { return }
        stop()
        guard let url else { return }
        mediaURL = url
        let nextPlayer = AVPlayer(url: url)
        player = nextPlayer
        let currentGeneration = generation
        observation = PlaybackTimeObservation(player: nextPlayer) { [weak self] time in
            // AVPlayer invokes this observer on the serial main queue.
            MainActor.assumeIsolated {
                guard let self, self.generation == currentGeneration else { return }
                self.updatePosition(seconds: time.seconds)
            }
        }
    }

    func seek(to milliseconds: Int64, durationMilliseconds: Int64?) {
        guard let player else { return }
        let bounded = min(max(0, milliseconds), max(0, durationMilliseconds ?? milliseconds))
        positionMilliseconds = bounded
        seekRevision &+= 1
        let revision = seekRevision
        let playerGeneration = generation
        isSeeking = true
        player.seek(to: CMTime(seconds: Double(bounded) / 1_000, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == playerGeneration, self.seekRevision == revision else { return }
                self.isSeeking = false
                if let time = self.player?.currentTime() { self.updatePosition(seconds: time.seconds) }
            }
        }
    }

    /// Freeze the player's exact clock, rather than the quarter-second display observation.
    func pauseForGaussianExploration() -> CMTime? {
        guard let player, !isSeeking else { return nil }
        player.pause()
        let time = player.currentTime()
        guard player.currentItem?.status == .readyToPlay, time.isNumeric,
              time.seconds.isFinite, time.seconds >= 0 else { return nil }
        updatePosition(seconds: time.seconds)
        return time
    }

    func matchesPausedFrame(url: URL, time: CMTime) -> Bool {
        guard !isSeeking, mediaURL == url, let player, player.rate == 0 else { return false }
        return CMTimeCompare(player.currentTime(), time) == 0
    }

    func stop() {
        generation &+= 1
        seekRevision &+= 1
        isSeeking = false
        observation = nil
        player?.pause()
        player = nil
        mediaURL = nil
        positionMilliseconds = 0
    }

    private func updatePosition(seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        let milliseconds = (seconds * 1_000).rounded()
        guard milliseconds < Double(Int64.max) else { return }
        let position = Int64(milliseconds)
        if position != positionMilliseconds { positionMilliseconds = position }
    }
}

/// Immutable owner pairs every registration with removal, including model teardown.
/// AVPlayer permits observer removal from any queue; callbacks are main-queue confined.
private final class PlaybackTimeObservation: @unchecked Sendable {
    private let player: AVPlayer
    private let token: Any

    init(player: AVPlayer, update: @escaping @Sendable (CMTime) -> Void) {
        self.player = player
        token = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 4), queue: .main, using: update
        )
    }

    deinit { player.removeTimeObserver(token) }
}

func reflectionTimecode(_ milliseconds: Int64) -> String {
    let seconds = max(0, milliseconds / 1_000)
    return String(format: "%02lld:%02lld", seconds / 60, seconds % 60)
}

enum ReflectionAnnotationTimecode {
    enum ParseError: Error, Equatable {
        case invalidFormat
        case outOfRange
    }

    static func parse(_ input: String) -> Result<Int64, ParseError> {
        let components = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2,
              let minutes = Int64(components[0]),
              let seconds = Int64(components[1]),
              minutes >= 0,
              (0...59).contains(seconds)
        else { return .failure(.invalidFormat) }

        let minuteSeconds = minutes.multipliedReportingOverflow(by: 60)
        guard !minuteSeconds.overflow else { return .failure(.outOfRange) }
        let totalSeconds = minuteSeconds.partialValue.addingReportingOverflow(seconds)
        guard !totalSeconds.overflow else { return .failure(.outOfRange) }
        let milliseconds = totalSeconds.partialValue.multipliedReportingOverflow(by: 1_000)
        guard !milliseconds.overflow else { return .failure(.outOfRange) }
        return .success(milliseconds.partialValue)
    }
}

struct ReflectionTimecode: View {
    let playback: ReflectionPlaybackModel

    var body: some View {
        Text(reflectionTimecode(playback.positionMilliseconds))
    }
}

struct ReflectionPlaybackControls: View {
    let playback: ReflectionPlaybackModel
    let durationMilliseconds: Int64?
    @Binding var rangeStartMilliseconds: Int64?

    var body: some View {
        let duration = max(1, durationMilliseconds ?? 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ReflectionTimecode(playback: playback)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text(reflectionTimecode(duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
            Slider(
                value: Binding(
                    get: { Double(min(playback.positionMilliseconds, duration)) },
                    set: { playback.seek(to: Int64($0.rounded()), durationMilliseconds: durationMilliseconds) }
                ),
                in: 0...Double(duration)
            )
            .tint(NativeTheme.accent)
            .accessibilityLabel("Wiedergabeposition")
            .accessibilityValue(reflectionTimecode(playback.positionMilliseconds))

            HStack {
                Button("Zum Anfang") { playback.seek(to: 0, durationMilliseconds: durationMilliseconds) }
                Spacer()
                Button(rangeStartMilliseconds == nil ? "Bereich beginnen" : "Bereich verwerfen") {
                    rangeStartMilliseconds = rangeStartMilliseconds == nil ? playback.positionMilliseconds : nil
                }
            }
            .buttonStyle(ScientificButtonStyle())
            if let rangeStartMilliseconds {
                Text("Bereich: \(reflectionTimecode(rangeStartMilliseconds)) bis aktuelle Position")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
        }
    }
}
