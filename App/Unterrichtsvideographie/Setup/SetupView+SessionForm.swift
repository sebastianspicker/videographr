import ExperimentalResearch
import SessionCore
import SwiftUI

extension SetupView {
    var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScientificFormRow(label: "Titel") {
                TextField("Sitzungstitel", text: sessionBinding(\.title))
                    .accessibilityIdentifier("setup.title")
                    .submitLabel(.next)
                    .focused($focusedField, equals: .title)
                    .scientificInput()
            }
            ScientificFormRow(label: "Zweck") {
                Picker("Zweck der Sitzung", selection: sessionBinding(\.purpose)) {
                    ForEach(CapturePurpose.allCases) { purpose in
                        Text(purpose.titleDE).tag(purpose)
                    }
                }
                .labelsHidden().pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scientificInput()
            }
        }
    }

    var context: some View {
        VStack(alignment: .leading, spacing: 14) {
            contextTextRow("Fach", text: contextBinding(\.subject), id: "setup.subject", focus: .subject)
            contextTextRow("Klassenstufe", text: contextBinding(\.gradeLevel), focus: .grade)
            contextTextRow("Stundenziel", text: contextBinding(\.lessonGoal), id: "setup.lessonGoal", multiline: true, focus: .goal)
        }
    }

    var additionalContext: some View {
        VStack(alignment: .leading, spacing: 14) {
            contextTextRow("Standort", text: contextBinding(\.schoolOrSite), focus: .site)
            contextTextRow("Notizen", text: contextBinding(\.notes), multiline: true, focus: .contextNotes)
        }
    }

    var capturePlan: some View {
        ScientificFormRow(label: "Geplante Dauer") {
            Stepper(value: sessionBinding(\.plannedDurationMinutes), in: 1...240, step: 5) {
                Text("\(appStore.session.plannedDurationMinutes) Min.").monospacedDigit()
            }
            .accessibilityIdentifier("setup.plannedDuration")
            .accessibilityHint("Planungswert für Speicher- und Ressourcenprüfungen, kein automatischer Aufnahmestopp.")
            .scientificInput()
        }
    }

    var analysisFocus: some View {
        ScientificFormRow(label: "Analysefokus") {
            Picker("Analysefokus", selection: sessionBinding(\.analysisIntent)) {
                ForEach(AnalysisIntent.allCases) { intent in
                    Text(intent.titleDE).tag(intent)
                }
            }
            .labelsHidden().pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scientificInput()
        }
    }

    var teachingSituation: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScientificFormRow(label: "Situation") {
                Picker("Unterrichtssituation", selection: sessionBinding(\.teachingSituation)) {
                    ForEach(TeachingSituationID.allCases) { situation in
                        let preset = TeachingSituationCatalogue.preset(for: situation)
                        Text("\(TeachingSituationCatalogue.family(for: situation)): \(preset.titleDE)")
                            .tag(situation)
                    }
                }
                .labelsHidden().pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scientificInput()
            }
            Text("Vom Operator gewählte Planungsvorlage. Sie ist keine automatisch erkannte Unterrichtsform und beeinflusst die Aufnahmefreigabe nicht.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
            Text(TeachingSituationCatalogue.preset(for: appStore.session.teachingSituation).captureGuidanceDE)
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    var retention: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aufbewahrung").font(.headline)
            Toggle("Aufbewahrungsdatum festhalten", isOn: Binding(
                get: { appStore.session.retentionPolicy.retainUntil != nil },
                set: { enabled in
                    appStore.edit { $0.retentionPolicy.retainUntil = enabled ? Date() : nil }
                }
            ))
            if let retainedDate = appStore.session.retentionPolicy.retainUntil {
                DatePicker("Aufbewahren bis", selection: Binding(
                    get: { appStore.session.retentionPolicy.retainUntil ?? retainedDate },
                    set: { value in appStore.edit { $0.retentionPolicy.retainUntil = value } }
                ), displayedComponents: .date)
            }
            TextField("Vorgehen nach Ablauf", text: Binding(
                get: { appStore.session.retentionPolicy.actionAfterExpiry },
                set: { value in appStore.edit { $0.retentionPolicy.actionAfterExpiry = value } }
            ), axis: .vertical)
            .scientificInput()
            Text("Diese Angaben dokumentieren die Aufbewahrung. Die App löscht keine Daten automatisch.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    private func contextTextRow(
        _ label: String, text: Binding<String>, id: String? = nil, multiline: Bool = false,
        focus: PreparationField
    ) -> some View {
        ScientificFormRow(label: label) {
            Group {
                if multiline {
                    TextField(label, text: text, axis: .vertical).lineLimit(2...4)
                } else {
                    TextField(label, text: text)
                }
            }
            .scientificInput()
            .focused($focusedField, equals: focus)
            .submitLabel(multiline ? .done : .next)
            .modifier(OptionalAccessibilityIdentifier(id))
        }
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id { content.accessibilityIdentifier(id) } else { content }
    }
}
