import AVFoundation
import AVKit
import Foundation
import SessionCore
import SwiftUI

extension ReflectView {
    func configurePlayer() {
        player?.pause()
        guard hasPlayableSelectedMedia, let selectedMediaURL else {
            player = nil
            return
        }
        player = AVPlayer(url: selectedMediaURL)
    }

    func selectInitialAssetIfNeeded() {
        guard selectedAssetID == nil else { return }
        selectedAssetID = appSession.session.mediaAssets.first?.id
    }

    func seek(to milliseconds: Int64) {
        let bounded = min(max(0, milliseconds), selectedAsset?.durationMilliseconds ?? milliseconds)
        playbackMilliseconds = bounded
        player?.seek(to: CMTime(seconds: Double(bounded) / 1_000, preferredTimescale: 600))
    }

    @MainActor
    func monitorPlaybackPosition() async {
        while !Task.isCancelled {
            if let player {
                let seconds = player.currentTime().seconds
                if seconds.isFinite, seconds >= 0 {
                    playbackMilliseconds = Int64((seconds * 1_000).rounded())
                }
            }
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
        }
    }

    func assetLabel(_ asset: SessionMediaAsset) -> String {
        asset.originalFileName ?? asset.relativePath
    }

    func annotationLabel(_ annotation: EvidenceAnnotation) -> String {
        if annotation.startMilliseconds == 0, annotation.endMilliseconds == 0 {
            return "Ganzes Video"
        }
        if annotation.startMilliseconds == annotation.endMilliseconds {
            return timecode(annotation.startMilliseconds)
        }
        return "\(timecode(annotation.startMilliseconds)) – \(timecode(annotation.endMilliseconds))"
    }

    func timecode(_ milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        return String(format: "%02lld:%02lld", totalSeconds / 60, totalSeconds % 60)
    }

    func addAnnotation(for prompt: ReflectionPromptID, wholeAsset: Bool) {
        guard let asset = selectedAsset else { return }
        let end = wholeAsset ? Int64(0) : playbackMilliseconds
        let start = wholeAsset ? Int64(0) : (rangeStartMilliseconds ?? end)
        var values = EvidenceAnnotation.Values()
        values.promptIdentifier = prompt.rawValue
        values.mediaAssetID = asset.id
        values.startMilliseconds = min(start, end)
        values.endMilliseconds = max(start, end)
        values.authorPseudonym = appSession.session.consentGrants.first?.participantGroupPseudonym ?? "local-reflection"
        let annotation = EvidenceAnnotation(values)
        appSession.session.evidenceAnnotations.append(annotation)
        rangeStartMilliseconds = nil
        appSession.markDirty()
    }

    func annotations(for prompt: ReflectionPromptID) -> [EvidenceAnnotation] {
        appSession.session.evidenceAnnotations
            .filter { $0.promptIdentifier == prompt.rawValue }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var linkedPromptCount: Int {
        ReflectionPromptID.allCases.filter { !annotations(for: $0).isEmpty }.count
    }

    var reflectionIsComplete: Bool {
        appSession.session.reflection.isComplete
            && linkedPromptCount == ReflectionPromptID.allCases.count
    }

    /// Two-way binding into session-backed reflection text without copying the session.
    func binding(for prompt: ReflectionPromptID) -> Binding<String> {
        Binding(
            get: { appSession.session.reflection[prompt] },
            set: { newValue in
                appSession.session.reflection[prompt] = newValue
                appSession.markDirty()
            }
        )
    }
}
