import AVKit
import SessionCore
import SwiftUI

extension ReflectView {
    // MARK: - Studio columns

    var playerColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            sessionContextSummary
            mediaEvidenceStudio
        }
        .padding(16)
    }

    var lafColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lesson Analysis Framework")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInk)
            Text("Strukturhilfen für Ihre eigene Analyse, keine automatische Bewertung.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(ReflectionPromptID.allCases.enumerated()), id: \.element.id) { index, prompt in
                    Button {
                        focusedPrompt = prompt
                    } label: {
                        lafCard(prompt, index: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeTheme.daySurface)
    }

    var notesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Beobachtung am Zeitpunkt")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if hasPlayableSelectedMedia {
                    Button("+ Annotation hinzufügen") {
                        addAnnotation(for: focusedPrompt, wholeAsset: false)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeTheme.accent)
                }
            }

            FieldPanel {
                HStack(spacing: 8) {
                    Text("LAF · \(focusedPrompt.titleDE)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NativeTheme.accent)
                    Text(timecode(playbackMilliseconds))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(NativeTheme.dayInkTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NativeTheme.accentWash, in: Capsule())
                }

                Text(focusedPrompt.promptDE)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 8)

                TextField("Ihre Analyse…", text: binding(for: focusedPrompt), axis: .vertical)
                    .lineLimit(5...12)
                    .font(.body)
                    .padding(.top, 8)
                    .accessibilityIdentifier("reflect.\(focusedPrompt.rawValue)")

                promptEvidenceControls(for: focusedPrompt)
                    .padding(.top, 10)
                evidenceSummary(for: focusedPrompt)
                    .padding(.top, 6)
            }

            // Keep every reflection prompt reachable.
            ForEach(ReflectionPromptID.allCases.filter { $0 != focusedPrompt }) { prompt in
                FieldPanel {
                    Text(prompt.titleDE)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NativeTheme.dayInkSecondary)
                    TextField("Ihre Analyse…", text: binding(for: prompt), axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("reflect.\(prompt.rawValue)")
                    promptEvidenceControls(for: prompt)
                    evidenceSummary(for: prompt)
                }
            }
        }
    }

    var exportColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVIDENZ & EXPORT")
                .font(.caption2.weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(NativeTheme.dayInkTertiary)

            FieldPanel {
                if appSession.session.mediaAssets.isEmpty {
                    Text("Keine Medien verknüpft")
                        .font(.caption)
                        .foregroundStyle(NativeTheme.dayInkTertiary)
                } else {
                    ForEach(appSession.session.mediaAssets) { asset in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.17, green: 0.15, blue: 0.12),
                                            Color(red: 0.08, green: 0.09, blue: 0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assetLabel(asset))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(timecode(asset.durationMilliseconds ?? 0))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(NativeTheme.dayInkTertiary)
                            }
                            Spacer()
                            FieldStatusBadge(title: "OK", tone: .positive)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            export
            progress
        }
    }

    private func lafCard(_ prompt: ReflectionPromptID, index: Int) -> some View {
        let filled = !appSession.session.reflection[prompt].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let linked = !annotations(for: prompt).isEmpty
        let progress = (filled ? 0.5 : 0) + (linked ? 0.5 : 0)
        let active = focusedPrompt == prompt

        return VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "%02d", index))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(NativeTheme.dayInkTertiary)
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
            .padding(.top, 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            active ? NativeTheme.daySurface : NativeTheme.dayCanvas,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    active ? NativeTheme.accent.opacity(0.35) : NativeTheme.dayHairline,
                    lineWidth: 1
                )
        }
    }

    private var sessionContextSummary: some View {
        HStack(spacing: 16) {
            labeledMeta("Titel", appSession.session.title)
            labeledMeta("Zweck", appSession.session.purpose.titleDE)
            labeledMeta("Fach", appSession.session.context.subject.isEmpty ? "Nicht angegeben" : appSession.session.context.subject)
        }
        .font(.caption)
    }

    private func labeledMeta(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .foregroundStyle(NativeTheme.dayInkTertiary)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(NativeTheme.dayInk)
                .lineLimit(1)
        }
    }

    // MARK: - Form-era section aliases (studio implementations)

    @ViewBuilder
    var reflectSessionContext: some View {
        EmptyView()
    }

    @ViewBuilder
    var reflectMediaEvidence: some View {
        EmptyView()
    }

    var mediaEvidenceStudio: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appSession.session.authorizes(.localReflection) {
                Button { isImportingMedia = true } label: {
                    Label("Lokales Video importieren", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityIdentifier("reflect.importMedia")
            } else {
                Label("Videoimport erfordert aktiven lokalen Freigabedatensatz für Reflexion.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }

            if appSession.session.mediaAssets.isEmpty {
                ContentUnavailableView(
                    "Keine Aufnahme verknüpft",
                    systemImage: "video.slash",
                    description: Text("Verknüpfen Sie zu jeder LAF-Frage mindestens einen Medienbeleg.")
                )
                .frame(minHeight: 180)
            } else {
                Picker("Medium", selection: $selectedAssetID) {
                    ForEach(appSession.session.mediaAssets) { asset in
                        Text(assetLabel(asset)).tag(Optional(asset.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("reflect.mediaPicker")

                if let selectedAsset {
                    if hasPlayableSelectedMedia, let player {
                        VideoPlayer(player: player)
                            .frame(minHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityLabel("Videowiedergabe für \(assetLabel(selectedAsset))")
                        playbackControls
                    } else {
                        Label("Die verknüpfte Videodatei fehlt oder kann nicht geöffnet werden.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(NativeTheme.warning)
                            .accessibilityLabel("Videodatei fehlt oder ist beschädigt")
                    }
                }
            }
        }
    }

    @ViewBuilder
    var reflectPlaybackControls: some View {
        let duration = max(1, selectedAsset?.durationMilliseconds ?? 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timecode(playbackMilliseconds))
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text(timecode(duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
            Slider(
                value: Binding(
                    get: { Double(min(playbackMilliseconds, duration)) },
                    set: { newValue in seek(to: Int64(newValue.rounded())) }
                ),
                in: 0...Double(duration)
            )
            .tint(NativeTheme.accent)
            .accessibilityLabel("Wiedergabeposition")
            .accessibilityValue(timecode(playbackMilliseconds))

            HStack {
                Button("Zum Anfang") { seek(to: 0) }
                Spacer()
                Button(rangeStartMilliseconds == nil ? "Bereich beginnen" : "Bereich verwerfen") {
                    if rangeStartMilliseconds == nil {
                        rangeStartMilliseconds = playbackMilliseconds
                    } else {
                        rangeStartMilliseconds = nil
                    }
                }
            }
            .buttonStyle(.bordered)
            .font(.caption)
            if let rangeStartMilliseconds {
                Text("Bereich: \(timecode(rangeStartMilliseconds)) bis aktuelle Position")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
        }
    }

    @ViewBuilder
    var reflectExperimentalHypotheses: some View {
        if appSession.session.hasUsableExperimentalProtocol,
           let snapshot = appSession.session.latestCodingSnapshot
        {
            FieldPanel {
                Label("Experimentelle Hypothese · nicht validiert", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(NativeTheme.warning)
                    .accessibilityLabel("Experimentelle, nicht validierte Hypothese")
                Text(snapshot.summaryDE)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkSecondary)
                    .padding(.top, 6)
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
    var reflectReflectionPrompts: some View {
        EmptyView()
    }

    @ViewBuilder
    func reflectPromptEvidenceControls(for prompt: ReflectionPromptID) -> some View {
        if selectedAsset == nil {
            Text("Für diesen Schritt ist noch kein Medium verfügbar.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        } else if hasPlayableSelectedMedia {
            HStack {
                Button("Aktuelle Position verknüpfen") { addAnnotation(for: prompt, wholeAsset: false) }
                    .buttonStyle(.bordered)
                Button("Ganzes Video verknüpfen") { addAnnotation(for: prompt, wholeAsset: true) }
                    .buttonStyle(.bordered)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    func reflectEvidenceSummary(for prompt: ReflectionPromptID) -> some View {
        let annotations = annotations(for: prompt)
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
                        appSession.session.evidenceAnnotations.removeAll { $0.id == annotation.id }
                        appSession.markDirty()
                    }
                    .font(.caption)
                    .accessibilityLabel("Medienbeleg entfernen")
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    var reflectProgress: some View {
        FieldPanel {
            let filled = appSession.session.reflection.filledCount
            let linked = linkedPromptCount
            ProgressView(value: Double(filled), total: Double(ReflectionPromptID.allCases.count)) {
                Text("\(filled) / 4 Antworten")
                    .font(.caption.weight(.medium))
            }
            .tint(NativeTheme.accent)
            Text("\(linked) / 4 Fragen mit Medienbeleg")
                .font(.caption)
                .foregroundStyle(reflectionIsComplete ? NativeTheme.positiveDay : NativeTheme.dayInkTertiary)
            Label(
                reflectionIsComplete ? "Reflexion vollständig" : "Vollständig nach vier Antworten und je einem Medienbeleg",
                systemImage: reflectionIsComplete ? "checkmark.circle.fill" : "circle.dashed"
            )
            .font(.caption)
            .foregroundStyle(reflectionIsComplete ? NativeTheme.positiveDay : NativeTheme.dayInkTertiary)
            Button("Entwurf speichern") {
                appSession.session.reflection.updatedAt = Date()
                appSession.markDirty()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("reflect.save")
            .padding(.top, 8)
        }
    }
}
