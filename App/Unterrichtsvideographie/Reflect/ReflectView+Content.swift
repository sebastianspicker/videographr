import AVKit
import ExperimentalResearch
import Foundation
import SessionCore
import SwiftUI

extension ReflectView {
    // MARK: - Studio columns

    var playerColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            mediaEvidenceStudio
        }
        .padding(14)
        .background(NativeTheme.daySurface, in: RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(NativeTheme.dayHairline)
        }
    }

    func lafColumn(index: ReflectionAnnotationIndex) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reflexionsfokus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInk)
            Text("Vier Fragen strukturieren die eigene Analyse. Sie erzeugen keine automatische Bewertung.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(ReflectionPromptID.allCases.enumerated()), id: \.element.id) { number, prompt in
                    Button {
                        focusedPrompt = prompt
                    } label: {
                        lafCard(prompt, number: number + 1, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeTheme.daySurface, in: RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(NativeTheme.dayHairline)
        }
    }

    func notesColumn(index: ReflectionAnnotationIndex) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Eigene Beobachtung")
                    .font(.headline)
                Spacer()
                Text("Menschlich verfasst")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }

            Picker("Reflexionsfokus", selection: $focusedPrompt) {
                ForEach(ReflectionPromptID.allCases) { prompt in
                    Text(prompt.titleDE).tag(prompt)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("reflect.promptPicker")

            DisclosureGroup("Reflexionsfrage") {
                Text(focusedPrompt.promptDE)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 3)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(NativeTheme.dayInkSecondary)

            TextField("Autor-Pseudonym", text: $annotationAuthor)
                .textInputAutocapitalization(.characters)
                .submitLabel(.next)
                .onSubmit { annotationFocus = .note }
                .scientificInput()
                .focused($annotationFocus, equals: .author)
                .accessibilityIdentifier("reflect.annotationAuthor")

            TextField("Beobachtungsnotiz", text: binding(for: focusedPrompt), axis: .vertical)
                .lineLimit(3...5)
                .font(.body)
                .submitLabel(.done)
                .onSubmit { annotationFocus = nil }
                .scientificInput()
                .focused($annotationFocus, equals: .note)
                .accessibilityIdentifier("reflect.\(focusedPrompt.rawValue)")

            if let annotationEditorMessage {
                Label(annotationEditorMessage, systemImage: annotationMessageSymbol)
                    .font(.caption)
                    .foregroundStyle(annotationMessageColor)
                    .accessibilityIdentifier("reflect.annotationSaveState")
            }

            if case .failed(let failure) = appStore.saveState {
                Label("Lokale Speicherung fehlgeschlagen: \(failure)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.danger)
            } else {
                Label("Sitzung: \(appStore.saveState.titleDE)", systemImage: saveStateSymbol)
                    .font(.caption)
                    .foregroundStyle(saveStateColor)
                    .accessibilityIdentifier("reflect.persistenceState")
            }

            noteActions

            let annotations = index.annotations(for: focusedPrompt)
            if annotations.isEmpty {
                Label("Noch kein Medienbeleg", systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            } else {
                DisclosureGroup("Medienbelege (\(annotations.count))") {
                    reflectEvidenceSummary(for: focusedPrompt, index: index)
                        .padding(.top, 4)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(NativeTheme.dayInkSecondary)
            }

            DisclosureGroup("Schnelle Verknüpfung") {
                reflectPromptEvidenceControls(for: focusedPrompt)
                    .padding(.top, 4)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(NativeTheme.dayInkSecondary)
        }
        .padding(14)
        .background(NativeTheme.daySurface, in: RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(NativeTheme.dayHairline)
        }
    }

    private var annotationIntervalFields: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Ausgewählter Zeitbereich")
                .font(.caption.weight(.medium))
                .foregroundStyle(NativeTheme.dayInkSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    annotationTimeField("Von", text: $annotationStartTimecode, focus: .start, identifier: "reflect.annotationStart")
                    annotationTimeField("Bis", text: $annotationEndTimecode, focus: .end, identifier: "reflect.annotationEnd")
                }
                VStack(alignment: .leading, spacing: 8) {
                    annotationTimeField("Von", text: $annotationStartTimecode, focus: .start, identifier: "reflect.annotationStart")
                    annotationTimeField("Bis", text: $annotationEndTimecode, focus: .end, identifier: "reflect.annotationEnd")
                }
            }
            Text("MM:SS · Die Notiz wird mit diesem Bereich verknüpft.")
                .font(.caption2)
                .foregroundStyle(NativeTheme.dayInkTertiary)
            if ReflectionAnnotationTimecode.parse(annotationStartTimecode) == .success(0),
               ReflectionAnnotationTimecode.parse(annotationEndTimecode) == .success(0) {
                Text("00:00 bis 00:00 bezeichnet das gesamte Video.")
                    .font(.caption2).foregroundStyle(NativeTheme.dayInkSecondary)
            }
        }
    }

    private var noteActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                saveAnnotationButton
                metadataReviewLink
            }
            VStack(alignment: .leading, spacing: 8) {
                saveAnnotationButton
                metadataReviewLink
            }
        }
    }

    private var metadataReviewLink: some View {
        NavigationLink {
            metadataReview
        } label: {
            Label("Metadaten prüfen", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(ScientificButtonStyle())
        .accessibilityIdentifier("reflect.metadataReview")
    }

    private var annotationIntervalActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                currentPositionButton
                wholeVideoButton
            }
            VStack(alignment: .leading, spacing: 8) {
                currentPositionButton
                wholeVideoButton
            }
        }
    }

    private var saveAnnotationButton: some View {
        Button(isSavingAnnotation ? "Notiz wird gesichert…" : "Notiz sichern") {
            saveHumanAnnotation()
        }
        .buttonStyle(ScientificButtonStyle(prominent: true))
        .disabled(isSavingAnnotation || !hasPlayableSelectedMedia)
        .accessibilityIdentifier("reflect.annotationSave")
    }

    private var currentPositionButton: some View {
        Button("Aktuelle Position") {
            usePlaybackPositionForAnnotationInterval()
        }
        .buttonStyle(ScientificButtonStyle())
        .accessibilityLabel("Aktuelle Wiedergabeposition für den Zeitbereich übernehmen")
    }

    private var wholeVideoButton: some View {
        Button("Ganzes Video") {
            useWholeVideoForAnnotationInterval()
        }
        .buttonStyle(ScientificButtonStyle())
        .accessibilityLabel("Gesamtes Video für den Zeitbereich übernehmen")
    }

    private func annotationTimeField(
        _ label: String,
        text: Binding<String>,
        focus: ReflectionAnnotationField,
        identifier: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
            TextField("00:00", text: text)
                .font(.system(.body, design: .monospaced))
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .submitLabel(focus == .start ? .next : .done)
                .onSubmit { annotationFocus = focus == .start ? .end : nil }
                .focused($annotationFocus, equals: focus)
                .accessibilityLabel("\(label), Minuten und Sekunden")
                .accessibilityIdentifier(identifier)
        }
        .scientificInput()
    }

    private var annotationMessageSymbol: String {
        annotationEditorMessage?.hasPrefix("Notiz lokal gesichert") == true
            ? "checkmark.circle.fill"
            : "exclamationmark.triangle.fill"
    }

    private var annotationMessageColor: Color {
        annotationEditorMessage?.hasPrefix("Notiz lokal gesichert") == true
            ? NativeTheme.positiveDay
            : NativeTheme.danger
    }

    private var saveStateSymbol: String {
        switch appStore.saveState {
        case .saved: return "checkmark.circle"
        case .unsaved: return "pencil.line"
        case .saving: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var saveStateColor: Color {
        switch appStore.saveState {
        case .saved: return NativeTheme.positiveDay
        case .unsaved, .saving: return NativeTheme.dayInkTertiary
        case .failed: return NativeTheme.danger
        }
    }

    private func lafCard(_ prompt: ReflectionPromptID, number: Int, index: ReflectionAnnotationIndex) -> some View {
        let filled = !appStore.session.reflection[prompt].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let linked = !index.annotations(for: prompt).isEmpty
        let progress = (filled ? 0.5 : 0) + (linked ? 0.5 : 0)
        let active = focusedPrompt == prompt

        return HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", number))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(active ? NativeTheme.accent : NativeTheme.dayInkTertiary)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(prompt.titleDE)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeTheme.dayInk)
                    .lineLimit(1)
                Text(prompt.visionFacetDE)
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .lineLimit(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NativeTheme.dayHairline)
                        Capsule()
                            .fill(NativeTheme.accent)
                            .frame(width: max(2, geo.size.width * progress))
                    }
                }
                .frame(height: 2)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(active ? NativeTheme.accent.opacity(0.45) : NativeTheme.dayHairline)
                .frame(height: 1)
        }
    }

    var mediaEvidenceStudio: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appStore.session.mediaAssets.isEmpty {
                mediaImportControl
                ContentUnavailableView(
                    "Keine Aufnahme verknüpft",
                    systemImage: "video.slash",
                    description: Text("Verknüpfen Sie zu jeder LAF-Frage mindestens einen Medienbeleg.")
                )
                .frame(minHeight: 180)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        mediaPicker
                        mediaImportControl
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        mediaPicker
                        mediaImportControl
                    }
                }

                if let selectedAsset {
                    if hasPlayableSelectedMedia, let player = playback.player {
                        videoPlayer(player, asset: selectedAsset)
                        ReflectionPlaybackControls(
                            playback: playback,
                            durationMilliseconds: selectedAsset.durationMilliseconds,
                            rangeStartMilliseconds: $rangeStartMilliseconds
                        )
                        gaussianExplorationControl
                        annotationIntervalFields
                        annotationIntervalActions
                    } else if isCheckingMedia {
                        ProgressView("Videodatei wird geprüft…")
                    } else {
                        Label("Die verknüpfte Videodatei fehlt oder kann nicht geöffnet werden.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(NativeTheme.warning)
                            .accessibilityLabel("Videodatei fehlt oder ist beschädigt")
                    }
                }
            }
        }
    }

    private var mediaPicker: some View {
        Picker("Medium", selection: $selectedAssetID) {
            ForEach(appStore.session.mediaAssets) { asset in
                Text(assetLabel(asset)).tag(Optional(asset.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("reflect.mediaPicker")
    }

    @ViewBuilder
    private var gaussianExplorationControl: some View {
        if appStore.session.operatingMode == .experimentalResearch {
            if GaussianExplorationPolicy.permits(appStore.session) {
                Button {
                    gaussianLaunchMessage = nil
                    playback.player?.pause()
                    gaussianLaunchID = UUID()
                } label: {
                    Label(gaussianLaunchID == nil ? "Standbild-Perspektive erkunden · Experiment" : "Freigaben werden gesichert…", systemImage: "viewfinder")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(ScientificButtonStyle())
                .disabled(gaussianLaunchID != nil || playback.isSeeking)
                .accessibilityIdentifier("reflect.gaussian.open")
                if let gaussianLaunchMessage {
                    Text(gaussianLaunchMessage).font(.caption).foregroundStyle(NativeTheme.warning)
                }
            } else {
                Text("Perspektivexperimente benötigen ein aktuelles Forschungsprotokoll sowie Freigaben für Forschung und lokale Reflexion.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
        }
    }

    @MainActor
    func beginGaussianExploration(token: UUID) async {
        guard let asset = selectedAsset, let url = selectedMediaURL else {
            gaussianLaunchID = nil
            return
        }
        let selection = GaussianLaunchPreparation.Selection(session: appStore.session, assetID: asset.id, mediaURL: url)
        let player = playback.player
        let initialTime = player?.currentTime()
        let seekRevision = playback.seekRevision
        defer { if gaussianLaunchID == token { gaussianLaunchID = nil } }
        do {
            let request = try await GaussianLaunchPreparation.prepare(
                selection: selection,
                persist: { await appStore.flushPendingChanges() },
                currentSelection: {
                    guard gaussianLaunchID == token, scenePhase == .active, isReflectionSelected(),
                          playback.player === player, playback.seekRevision == seekRevision,
                          let initialTime, playback.matchesPausedFrame(url: url, time: initialTime),
                          let currentAsset = selectedAsset, let currentURL = selectedMediaURL else { return nil }
                    return .init(session: appStore.session, assetID: currentAsset.id, mediaURL: currentURL)
                },
                freeze: { playback.pauseForGaussianExploration() }
            )
            guard !Task.isCancelled, gaussianLaunchID == token else { return }
            gaussianRequest = request
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, gaussianLaunchID == token else { return }
            gaussianLaunchMessage = (error as? GaussianFrameError)?.errorDescription
                ?? "Die Perspektivansicht konnte nicht vorbereitet werden."
        }
    }

    @ViewBuilder
    private var mediaImportControl: some View {
        if appStore.session.authorizes(.localReflection) {
            Button { isImportingMedia = true } label: {
                Label(isProcessingMediaImport ? "Video wird importiert…" : "Video importieren",
                      systemImage: isProcessingMediaImport ? "hourglass" : "square.and.arrow.down")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .disabled(isProcessingMediaImport)
            .accessibilityIdentifier("reflect.importMedia")
        } else {
            Label("Videoimport erfordert eine aktive Freigabe für lokale Reflexion.", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        }
    }

    private func videoPlayer(_ player: AVPlayer, asset: SessionMediaAsset) -> some View {
        GeometryReader { proxy in
            VideoPlayer(player: player)
                .frame(width: proxy.size.width, height: proxy.size.width * 9 / 16)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: NativeTheme.cornerRadius, style: .continuous))
        .accessibilityLabel("Videowiedergabe für \(assetLabel(asset))")
    }

    @ViewBuilder
    var experimentalHypotheses: some View {
        if appStore.session.operatingMode == .experimentalResearch,
           appStore.session.hasUsableExperimentalProtocol,
           let snapshot = appStore.session.latestCodingSnapshot
        {
            FieldPanel {
                Label("Experimentelle Hypothese · nicht validiert", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(NativeTheme.warning)
                    .accessibilityLabel("Experimentelle, nicht validierte Hypothese")
                Text(snapshot.summaryDE)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkSecondary)
                    .padding(.top, 6)
                if let report = appStore.session.researchCaptureReport(
                    generatorProvenance: BuildProvenanceFactory.export
                ) {
                    Text(report.summaryDE)
                        .font(.caption2)
                        .foregroundStyle(NativeTheme.dayInkTertiary)
                        .padding(.top, 4)
                }
                if let scaffold = appStore.session.reflectionScaffoldNotes()[focusedPrompt.rawValue] {
                    Text(scaffold)
                        .font(.caption2)
                        .foregroundStyle(NativeTheme.dayInkTertiary)
                        .padding(.top, 4)
                }
                Text("Keine pädagogische Bewertung, keine Konfidenzangabe und kein Ersatz für menschliche Kodierung.")
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(NativeTheme.warning.opacity(0.3), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    func reflectPromptEvidenceControls(for prompt: ReflectionPromptID) -> some View {
        if selectedAsset == nil {
            Text("Für diesen Schritt ist noch kein Medium verfügbar.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        } else if hasPlayableSelectedMedia {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Aktuelle Position verknüpfen") { addAnnotation(for: prompt, wholeAsset: false) }
                        .buttonStyle(ScientificButtonStyle())
                    Button("Ganzes Video verknüpfen") { addAnnotation(for: prompt, wholeAsset: true) }
                        .buttonStyle(ScientificButtonStyle())
                }
                VStack(alignment: .leading) {
                    Button("Aktuelle Position verknüpfen") { addAnnotation(for: prompt, wholeAsset: false) }
                        .buttonStyle(ScientificButtonStyle())
                    Button("Ganzes Video verknüpfen") { addAnnotation(for: prompt, wholeAsset: true) }
                        .buttonStyle(ScientificButtonStyle())
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    func reflectEvidenceSummary(for prompt: ReflectionPromptID, index: ReflectionAnnotationIndex) -> some View {
        let annotations = index.annotations(for: prompt)
        if annotations.isEmpty {
            Label("Noch kein Medienbeleg", systemImage: "link.badge.plus")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        } else {
            ForEach(annotations, id: \.id) { annotation in
                HStack {
                    Label(annotationLabel(annotation), systemImage: "link")
                    Spacer()
                    Button("Entfernen", role: .destructive) {
                        appStore.removeAnnotation(id: annotation.id)
                    }
                    .font(.caption)
                    .accessibilityLabel("Medienbeleg entfernen")
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    func reflectProgress(index: ReflectionAnnotationIndex) -> some View {
        FieldPanel {
            let filled = appStore.session.reflection.filledCount
            let linked = index.linkedPromptCount
            ProgressView(value: Double(filled), total: Double(ReflectionPromptID.allCases.count)) {
                Text("\(filled) / 4 Antworten")
                    .font(.caption.weight(.medium))
            }
            .tint(NativeTheme.accent)
            Text("\(linked) / 4 Fragen mit Medienbeleg")
                .font(.caption)
                .foregroundStyle(reflectionIsComplete(index: index) ? NativeTheme.positiveDay : NativeTheme.dayInkTertiary)
            Label(
                reflectionIsComplete(index: index) ? "Reflexion vollständig" : "Vollständig nach vier Antworten und je einem Medienbeleg",
                systemImage: reflectionIsComplete(index: index) ? "checkmark.circle.fill" : "circle.dashed"
            )
            .font(.caption)
            .foregroundStyle(reflectionIsComplete(index: index) ? NativeTheme.positiveDay : NativeTheme.dayInkTertiary)
            Button("Entwurf speichern") {
                appStore.save()
            }
            .buttonStyle(ScientificButtonStyle(prominent: true))
            .accessibilityIdentifier("reflect.save")
            .padding(.top, 8)
        }
    }
}
