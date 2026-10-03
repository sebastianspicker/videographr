import SessionCore
import SwiftUI

extension SetupView {
    var filteredSessions: [CaptureSession] {
        let query = sessionSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appStore.allSessions }
        return appStore.allSessions.filter { session in
            [session.title, session.purpose.titleDE, session.context.subject, session.context.gradeLevel]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var sessionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Button {
                        appStore.newSession()
                        showingSessions = false
                    } label: {
                        Label("Neue Sitzung anlegen", systemImage: "plus")
                    }
                    .buttonStyle(InkButtonStyle(kind: .primary))
                    .accessibilityIdentifier("setup.newSession")

                    if appStore.allSessions.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Noch keine gespeicherten Sitzungen")
                                .font(Typeface.section)
                            Text("Legen Sie eine Sitzung an. Sie bleibt auf diesem Gerät; ein Video können Sie auch später zur Reflexion importieren.")
                                .font(Typeface.proseSmall)
                                .foregroundStyle(Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, Space.l)
                    } else {
                        savedSessions
                    }
                }
                .padding(.horizontal, Space.gutterCompact)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: Space.measure, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Sitzungen auf diesem Gerät")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showingSessions = false }
                }
            }
            .paperSurface()
            .confirmationDialog(
                "Sitzung und lokale Aufnahme löschen?",
                isPresented: Binding(
                    get: { sessionPendingDeletion != nil },
                    set: { if !$0 { sessionPendingDeletion = nil } }
                ),
                presenting: sessionPendingDeletion
            ) { selected in
                Button("Unwiderruflich löschen", role: .destructive) {
                    appStore.deleteSessionAndMedia(selected.id)
                    sessionPendingDeletion = nil
                }
            } message: { selected in
                Text("„\(selected.title)“ und zugehörige lokale Medien werden gelöscht. Importquellen und bereits weitergegebene Kopien bleiben bestehen.")
            }
        }
    }

    @ViewBuilder
    var savedSessions: some View {
        let sessions = filteredSessions
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
                TextField("Titel, Fach, Klasse oder Zweck", text: $sessionSearchQuery)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Sitzungen suchen")
                    .accessibilityIdentifier("setup.sessions.search")
            }
            .writingLine()

            FormLabel("\(sessions.count) von \(appStore.allSessions.count) Sitzungen")
                .padding(.top, Space.s)

            if sessions.isEmpty {
                Text("Keine Sitzung passt zu „\(sessionSearchQuery)“.")
                    .font(Typeface.proseSmall)
                    .foregroundStyle(Ink.secondary)
                    .padding(.vertical, Space.l)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Rule(strong: true)
                    ForEach(sessions) { session in
                        sessionRow(session)
                        Rule()
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: CaptureSession) -> some View {
        let isOpen = session.id == appStore.session.id
        return HStack(alignment: .top, spacing: Space.m) {
            Button {
                appStore.select(session.id)
            } label: {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(session.title.isEmpty ? "Ohne Titel" : session.title)
                            .font(Typeface.heading)
                            .foregroundStyle(Ink.primary)
                            .multilineTextAlignment(.leading)
                        if isOpen {
                            FormLabel("geöffnet", small: true)
                        }
                    }
                    Text("\(session.purpose.titleDE) · \(session.context.subject.isEmpty ? "ohne Fach" : session.context.subject) · \(session.plannedDurationMinutes) Min.")
                        .font(Typeface.valueSmall)
                        .foregroundStyle(Ink.instrument)
                        .multilineTextAlignment(.leading)
                    if session.setupComplete {
                        StatusMark("Startbedingungen vollständig", kind: .secured)
                    } else {
                        StatusMark("Vorbereitung unvollständig", kind: .open)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.m)
                .padding(.leading, Space.m)
                .overlay(alignment: .leading) {
                    Rectangle().fill(isOpen ? Ink.human : Color.clear).frame(width: 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? .isSelected : [])
            .accessibilityIdentifier("setup.session.\(session.id.uuidString)")
            .contextMenu {
                Button("Sitzung und Medien löschen", role: .destructive) {
                    sessionPendingDeletion = session
                }
            }

            Menu {
                Button("Sitzung und Medien löschen", systemImage: "trash", role: .destructive) {
                    sessionPendingDeletion = session
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Ink.secondary)
                    .frame(width: Space.target, height: Space.target)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Aktionen für \(session.title.isEmpty ? "Ohne Titel" : session.title)")
            .padding(.top, Space.s)
        }
    }
}
