import AVFoundation
import Foundation

@main
struct PlaybackSmoke {
    @MainActor
    static func main() async throws {
        let model = ReflectionPlaybackModel()
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        model.configure(url: url)
        for _ in 0..<500 {
            if model.player?.currentItem?.status == .readyToPlay { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(model.player?.currentItem?.status == .readyToPlay)
        let original = model.pauseForGaussianExploration()!
        precondition(model.matchesPausedFrame(url: url, time: original))
        model.seek(to: 400, durationMilliseconds: 1_000)
        precondition(model.isSeeking && model.pauseForGaussianExploration() == nil)
        let firstRevision = model.seekRevision
        model.seek(to: 700, durationMilliseconds: 1_000)
        precondition(model.seekRevision == firstRevision + 1 && model.isSeeking)
        for _ in 0..<500 {
            if !model.isSeeking { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(!model.isSeeking)
        let frozen = model.pauseForGaussianExploration()!
        precondition(model.matchesPausedFrame(url: url, time: frozen))
        model.player?.play()
        precondition(!model.matchesPausedFrame(url: url, time: frozen))
        model.player?.pause()
        model.seek(to: 100, durationMilliseconds: 1_000)
        model.stop()
        try await Task.sleep(for: .milliseconds(100))
        precondition(model.player == nil && !model.isSeeking && model.mediaURL == nil)
        print("PASS: actual playback model refuses pending seeks, ignores stale completion after stop, and checks paused identity")
    }
}
