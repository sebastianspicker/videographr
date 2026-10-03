import ExperimentalResearch
import SessionCore
import SwiftUI

extension SetupView {
    var sessionDetails: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            LedgerField("Titel") {
                TextField("Sitzungstitel", text: sessionBinding(\.title))
                    .accessibilityIdentifier("setup.title")
                    .submitLabel(.next)
                    .focused($focusedField, equals: .title)
                    .writingLine()
            }
            LedgerPair {
                LedgerField("Zweck") {
                    LedgerMenuPicker(
                        title: "Zweck der Sitzung",
                        selection: sessionBinding(\.purpose),
                        options: CapturePurpose.allCases.map { ($0, $0.titleDE) }
                    )
                }
            } trailing: {
                capturePlan
            }
        }
    }

    var context: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            LedgerPair {
                contextTextRow("Fach", text: contextBinding(\.subject), id: "setup.subject", focus: .subject)
            } trailing: {
                contextTextRow("Klassenstufe", text: contextBinding(\.gradeLevel), focus: .grade)
            }
            contextTextRow("Stundenziel", text: contextBinding(\.lessonGoal), id: "setup.lessonGoal", multiline: true, focus: .goal)
        }
    }

    var additionalContext: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            contextTextRow("Standort", text: contextBinding(\.schoolOrSite), focus: .site)
            contextTextRow("Notizen zum Kontext", text: contextBinding(\.notes), multiline: true, focus: .contextNotes)
        }
    }

    var capturePlan: some View {
        LedgerField("Geplante Dauer", hint: "Planungswert für Speicherprüfung, kein automatischer Stopp.") {
            Stepper(value: sessionBinding(\.plannedDurationMinutes), in: 1...240, step: 5) {
                Text("\(appStore.session.plannedDurationMinutes) Min.")
                    .font(Typeface.value)
                    .foregroundStyle(Ink.human)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("setup.plannedDuration")
            .accessibilityHint("Planungswert für Speicher- und Ressourcenprüfungen, kein automatischer Aufnahmestopp.")
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) { Rule(strong: true) }
        }
    }

    var analysisFocus: some View {
        LedgerField("Analysefokus") {
            LedgerMenuPicker(
                title: "Analysefokus",
                selection: sessionBinding(\.analysisIntent),
                options: AnalysisIntent.allCases.map { ($0, $0.titleDE) }
            )
        }
    }

    var teachingSituation: some View {
        LedgerField(
            "Unterrichtssituation",
            hint: "Ihre Planungsvorlage. Sie wird nicht automatisch erkannt und entscheidet nicht über den Aufnahmestart."
        ) {
            LedgerMenuPicker(
                title: "Unterrichtssituation",
                selection: sessionBinding(\.teachingSituation),
                options: TeachingSituationID.allCases.map { situation in
                    let preset = TeachingSituationCatalogue.preset(for: situation)
                    return (situation, "\(TeachingSituationCatalogue.family(for: situation)): \(preset.titleDE)")
                }
            )
            Text(TeachingSituationCatalogue.preset(for: appStore.session.teachingSituation).captureGuidanceDE)
                .font(Typeface.quote)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
        }
    }

    var retention: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Aufbewahrung")
                .font(Typeface.heading)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Space.s)
            Toggle("Aufbewahrungsdatum festhalten", isOn: Binding(
                get: { appStore.session.retentionPolicy.retainUntil != nil },
                set: { enabled in
                    appStore.edit { $0.retentionPolicy.retainUntil = enabled ? Date() : nil }
                }
            ))
            .toggleStyle(InkCheckboxStyle())
            if let retainedDate = appStore.session.retentionPolicy.retainUntil {
                DatePicker("Aufbewahren bis", selection: Binding(
                    get: { appStore.session.retentionPolicy.retainUntil ?? retainedDate },
                    set: { value in appStore.edit { $0.retentionPolicy.retainUntil = value } }
                ), displayedComponents: .date)
                .font(Typeface.body)
            }
            LedgerField("Vorgehen nach Ablauf") {
                TextField("z. B. Löschung durch die Projektleitung", text: Binding(
                    get: { appStore.session.retentionPolicy.actionAfterExpiry },
                    set: { value in appStore.edit { $0.retentionPolicy.actionAfterExpiry = value } }
                ), axis: .vertical)
                .writingLine()
            }
        }
    }

    private func contextTextRow(
        _ label: String, text: Binding<String>, id: String? = nil, multiline: Bool = false,
        focus: PreparationField
    ) -> some View {
        LedgerField(label) {
            Group {
                if multiline {
                    TextField(label, text: text, axis: .vertical).lineLimit(2...4)
                } else {
                    TextField(label, text: text)
                }
            }
            .writingLine()
            .focused($focusedField, equals: focus)
            .submitLabel(multiline ? .done : .next)
            .modifier(OptionalIdentifier(id))
        }
    }
}
