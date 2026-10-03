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

    @ViewBuilder
    var savedSessions: some View {
        let sessions = filteredSessions
        if !appStore.allSessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FieldSectionHeader(title: "Gespeicherte Sitzungen")
                FieldPanel {
                    TextField("Sitzungen suchen", text: $sessionSearchQuery)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("setup.sessions.search")

                    if sessions.isEmpty {
                        ContentUnavailableView.search(text: sessionSearchQuery)
                            .frame(minHeight: 120)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sessions) { session in
                                Button {
                                    appStore.select(session.id)
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
                                if session.id != sessions.last?.id {
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
}
