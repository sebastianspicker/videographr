import AVFoundation
import AVKit
import Foundation
import SessionCore
import SwiftUI

extension ReflectView {
    func refreshMediaAvailability() async {
        let sessionID = appStore.session.id
        let assets = appStore.session.mediaAssets
        isCheckingMedia = true
        mediaAvailability = [:]
        var resolved: [UUID: URL] = [:]
        for asset in assets {
            if let url = await appStore.resolvedMediaURL(for: asset, sessionID: sessionID) {
                resolved[asset.id] = url
            }
            guard !Task.isCancelled else { return }
        }
        guard !Task.isCancelled, appStore.session.id == sessionID else { return }
        mediaAvailability = resolved
        isCheckingMedia = false
        if !assets.contains(where: { $0.id == selectedAssetID }) {
            selectedAssetID = assets.first?.id
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
        reflectionTimecode(milliseconds)
    }

    func addAnnotation(for prompt: ReflectionPromptID, wholeAsset: Bool) {
        guard let asset = selectedAsset else { return }
        let end = wholeAsset ? Int64(0) : playback.positionMilliseconds
        let start = wholeAsset ? Int64(0) : (rangeStartMilliseconds ?? end)
        var values = EvidenceAnnotation.Values()
        values.promptIdentifier = prompt.rawValue
        values.mediaAssetID = asset.id
        values.startMilliseconds = min(start, end)
        values.endMilliseconds = max(start, end)
        values.authorPseudonym = appStore.session.consentGrants.first?.participantGroupPseudonym ?? "local-reflection"
        let annotation = EvidenceAnnotation(values)
        appStore.edit { $0.evidenceAnnotations.append(annotation) }
        rangeStartMilliseconds = nil
    }

    func populateAnnotationEditorFromPlayback() {
        guard annotationStartTimecode.isEmpty, annotationEndTimecode.isEmpty else { return }
        usePlaybackPositionForAnnotationInterval()
    }

    func usePlaybackPositionForAnnotationInterval() {
        let start = rangeStartMilliseconds ?? playback.positionMilliseconds
        let end = playback.positionMilliseconds
        annotationStartTimecode = timecode(min(start, end))
        annotationEndTimecode = timecode(max(start, end))
        annotationEditorMessage = nil
    }

    func useWholeVideoForAnnotationInterval() {
        guard let duration = selectedAsset?.durationMilliseconds else {
            annotationEditorMessage = "Die Videodauer wird noch geprüft. Bitte warten Sie, bevor Sie einen Zeitbereich sichern."
            return
        }
        annotationStartTimecode = timecode(0)
        annotationEndTimecode = timecode(duration)
        annotationEditorMessage = nil
    }

    func saveHumanAnnotation() {
        guard let asset = selectedAsset else {
            annotationEditorMessage = "Für diese Notiz ist kein lokales Video verfügbar."
            return
        }
        let sessionID = appStore.session.id
        let assetID = asset.id
        guard appStore.session.authorizes(.localReflection) else {
            annotationEditorMessage = "Für diese Notiz fehlt eine aktuelle Freigabe für lokale Reflexion."
            return
        }
        guard let duration = asset.durationMilliseconds else {
            annotationEditorMessage = "Die Videodauer wird noch geprüft. Bitte warten Sie, bevor Sie einen Zeitbereich sichern."
            return
        }
        let author = annotationAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !author.isEmpty else {
            annotationEditorMessage = "Bitte ein Autor-Pseudonym eingeben."
            annotationFocus = .author
            return
        }
        let note = appStore.session.reflection[focusedPrompt].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else {
            annotationEditorMessage = "Bitte eine menschlich verfasste Beobachtungsnotiz eingeben."
            annotationFocus = .note
            return
        }
        let startResult = ReflectionAnnotationTimecode.parse(annotationStartTimecode)
        let endResult = ReflectionAnnotationTimecode.parse(annotationEndTimecode)
        guard case let .success(start) = startResult,
              case let .success(end) = endResult
        else {
            if case .failure = startResult {
                annotationFocus = .start
            } else {
                annotationFocus = .end
            }
            annotationEditorMessage = [startResult, endResult].contains { result in
                if case .failure(.outOfRange) = result { return true }
                return false
            }
                ? "Zeitbereich ist zu groß."
                : "Zeitangaben bitte als MM:SS eingeben."
            return
        }
        guard start <= end else {
            annotationEditorMessage = "Der Beginn des Zeitbereichs darf nicht nach dem Ende liegen."
            annotationFocus = .end
            return
        }
        if end > duration {
            annotationEditorMessage = "Der Zeitbereich liegt außerhalb der bekannten Videodauer."
            annotationFocus = .end
            return
        }

        var values = EvidenceAnnotation.Values()
        values.promptIdentifier = focusedPrompt.rawValue
        values.mediaAssetID = asset.id
        values.startMilliseconds = start
        values.endMilliseconds = end
        values.note = note
        values.authorPseudonym = author
        appStore.edit { $0.evidenceAnnotations.append(EvidenceAnnotation(values)) }
        rangeStartMilliseconds = nil
        annotationEditorMessage = nil
        annotationFocus = nil
        isSavingAnnotation = true

        Task { @MainActor in
            let persisted = await appStore.flushPendingChanges()
            isSavingAnnotation = false
            guard appStore.session.id == sessionID, selectedAsset?.id == assetID else { return }
            if persisted, appStore.saveState == .saved {
                annotationEditorMessage = "Notiz lokal gesichert."
            } else {
                annotationEditorMessage = appStore.lastStoreError ?? "Notiz konnte nicht lokal gesichert werden."
            }
        }
    }

    func clearAnnotationEditorMessage() {
        annotationEditorMessage = nil
    }

    func reflectionIsComplete(index: ReflectionAnnotationIndex) -> Bool {
        appStore.session.reflection.isComplete
            && index.linkedPromptCount == ReflectionPromptID.allCases.count
    }

    /// Two-way binding into session-backed reflection text without copying the session.
    func binding(for prompt: ReflectionPromptID) -> Binding<String> {
        Binding(
            get: { appStore.session.reflection[prompt] },
            set: { newValue in
                appStore.edit { $0.reflection[prompt] = newValue }
                clearAnnotationEditorMessage()
            }
        )
    }
}
