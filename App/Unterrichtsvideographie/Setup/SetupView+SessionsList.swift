import SessionCore
import SwiftUI

extension SetupView {
    var filteredSessions: [CaptureSession] {
        let query = sessionSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appSession.allSessions }
        return appSession.allSessions.filter { session in
            [session.title, session.purpose.titleDE, session.context.subject, session.context.gradeLevel]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    @ViewBuilder
    var setupStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(title: "Status & Aktionen")
            FieldPanel {
                HStack {
                    Text("Lokale Startbedingungen")
                        .font(.subheadline)
                        .foregroundStyle(NativeTheme.dayInkSecondary)
                    Spacer()
                    Text(appSession.session.setupComplete ? "Ja" : "Nein")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            appSession.session.setupComplete ? NativeTheme.positiveDay : NativeTheme.warning
                        )
                        .accessibilityIdentifier("setup.complete")
                }
                Text(
                    appSession.session.setupComplete
                        ? "Titel, Mindestkontext sowie die zweckgebundenen Freigaben für Aufzeichnung und lokale Reflexion liegen vor."
                        : "Für eine neue Aufnahme werden Titel, Fach, Lernziel sowie Freigaben für Aufzeichnung und lokale Reflexion benötigt."
                )
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 6)

                HStack(spacing: 10) {
                    FieldGhostButton(title: "Neue Sitzung") { appSession.newSession() }
                        .accessibilityIdentifier("setup.newSession")
                    Button("Speichern") { appSession.save() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("setup.save")
                }
                .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    var savedSessions: some View {
        if !appSession.allSessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FieldSectionHeader(title: "Gespeicherte Sitzungen")
                FieldPanel {
                    TextField("Sitzungen suchen", text: $sessionSearchQuery)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("setup.sessions.search")

                    if filteredSessions.isEmpty {
                        ContentUnavailableView.search(text: sessionSearchQuery)
                            .frame(minHeight: 120)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredSessions) { session in
                                Button {
                                    appSession.select(session.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(NativeTheme.dayInk)
                                        Text("\(session.purpose.titleDE) · \(session.context.subject.isEmpty ? "Ohne Fach" : session.context.subject) · \(session.plannedDurationMinutes) Min.")
                                            .font(.caption)
                                            .foregroundStyle(NativeTheme.dayInkTertiary)
                                        Text(session.setupComplete ? "Startbedingungen vollständig" : "Setup unvollständig")
                                            .font(.caption2)
                                            .foregroundStyle(
                                                session.setupComplete ? NativeTheme.positiveDay : NativeTheme.warning
                                            )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("setup.session.\(session.id.uuidString)")
                                .contextMenu {
                                    Button("Sitzung und Medien löschen", role: .destructive) {
                                        sessionPendingDeletion = session
                                    }
                                }
                                if session.id != filteredSessions.last?.id {
                                    Divider().overlay(NativeTheme.dayHairline)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    /// Wide-layout readiness rail.
    var readinessRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("STARTBEDINGUNGEN")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.bottom, 12)

                FieldReadinessItem(
                    title: "Kontext vollständig",
                    detail: "Titel, Fach, Lernziel, Dauer und Situation sind definiert.",
                    isMet: appSession.session.context.isMinimallyComplete
                        && !appSession.session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                Divider().overlay(NativeTheme.dayHairline)
                FieldReadinessItem(
                    title: "Freigaben geprüft",
                    detail: "Erhebung und lokale Reflexion sind zeitlich gültig.",
                    isMet: appSession.session.authorizes(.collection)
                        && appSession.session.authorizes(.localReflection)
                )
                Divider().overlay(NativeTheme.dayHairline)
                FieldReadinessItem(
                    title: "Speicher verfügbar",
                    detail: "Lokaler Speicher für die geplante Dauer wird vor dem Take erneut geprüft.",
                    isMet: true
                )
                Divider().overlay(NativeTheme.dayHairline)
                FieldReadinessItem(
                    title: "Aufbewahrung gesetzt",
                    detail: "Retention-Policy der Sitzung ist hinterlegt.",
                    isMet: true
                )

                FieldReadyBanner(
                    isReady: appSession.session.setupComplete,
                    readyText: "Alle Startbedingungen erfüllt. Live zeigt nur direkte technische Signale, keine pädagogische Bewertung.",
                    blockedText: "Vervollständigen Sie Titel, Kontext und Freigaben, bevor Sie aufnehmen."
                )
                .padding(.top, 18)

                HStack(spacing: 8) {
                    Image(systemName: "shield")
                        .font(.caption)
                    Text("Lokal gespeichert · Geräteeigentümer-Schutz aktiv")
                        .font(.caption)
                }
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 16)
            }
            .padding(20)
        }
        .background(NativeTheme.daySurface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NativeTheme.dayHairline)
                .frame(width: 1)
        }
    }
}
