import GuidanceEngine
import SessionCore
import SwiftUI

extension SetupView {
    @ViewBuilder
    var storageStatus: some View {
        FieldPanel {
            HStack(spacing: 10) {
                Image(systemName: saveStateSymbol)
                    .foregroundStyle(saveStateColor)
                Text(appSession.saveState.titleDE)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(saveStateColor)
                    .accessibilityIdentifier("setup.saveState")
                Spacer()
            }
            if let error = appSession.lastStoreError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.danger)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(title: "Sitzung")
            HStack(spacing: 12) {
                FieldPanel {
                    FieldLabeledInput(label: "Sitzungstitel") {
                        TextField("Titel", text: sessionBinding(\.title))
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("setup.title")
                    }
                }
                FieldPanel {
                    FieldLabeledInput(label: "Zweck der Sitzung") {
                        Picker("Zweck", selection: sessionBinding(\.purpose)) {
                            ForEach(CapturePurpose.allCases) { purpose in
                                Text(purpose.titleDE).tag(purpose)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
            FieldPanel {
                FieldLabeledInput(label: "Analysefokus") {
                    Picker("Analysefokus", selection: sessionBinding(\.analysisIntent)) {
                        ForEach(AnalysisIntent.allCases) { intent in
                            Text(intent.titleDE).tag(intent)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    @ViewBuilder
    var capturePlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(title: "Aufnahmeplanung")
            FieldPanel {
                Stepper(
                    "Geplante Dauer: \(appSession.session.plannedDurationMinutes) Minuten",
                    value: sessionBinding(\.plannedDurationMinutes),
                    in: 1...240,
                    step: 5
                )
                .accessibilityIdentifier("setup.plannedDuration")
                Text("Die geplante Dauer wird vor der Aufnahme für Speicher- und Ressourcenprüfungen verwendet. Die tatsächliche Dauer wird separat im Take-Manifest dokumentiert.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    var teachingSituation: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(title: "Unterrichtssituation")
            FieldPanel {
                Picker("Situation", selection: sessionBinding(\.teachingSituation)) {
                    ForEach(TeachingSituationID.allCases) { situation in
                        let preset = TeachingSituationCatalogue.preset(for: situation)
                        Text("\(TeachingSituationCatalogue.family(for: situation)): \(preset.titleDE)")
                            .tag(situation)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                let preset = appSession.session.teachingSituationPreset
                Text("Vom Operator gewählte Planungsvorlage. Sie ist keine automatisch erkannte Unterrichtsform und beeinflusst die Aufnahmefreigabe nicht.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 8)
                Text(preset.captureGuidanceDE)
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    var context: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(
                title: "Sitzungskontext",
                subtitle: "minimal erforderlich für Start"
            )
            FieldPanel(padding: 0) {
                VStack(spacing: 0) {
                    contextTextRow(key: "Fach", text: contextBinding(\.subject), id: "setup.subject")
                    Divider().overlay(NativeTheme.dayHairline)
                    contextTextRow(key: "Lernziel", text: contextBinding(\.lessonGoal), id: "setup.lessonGoal", axis: true)
                    Divider().overlay(NativeTheme.dayHairline)
                    contextTextRow(key: "Klassenstufe", text: contextBinding(\.gradeLevel))
                    Divider().overlay(NativeTheme.dayHairline)
                    contextTextRow(key: "Standort", text: contextBinding(\.schoolOrSite))
                    Divider().overlay(NativeTheme.dayHairline)
                    contextTextRow(key: "Notizen", text: contextBinding(\.notes), axis: true)
                }
            }
        }
    }

    private func contextTextRow(
        key: String,
        text: Binding<String>,
        id: String? = nil,
        axis: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .frame(width: 100, alignment: .leading)
                .padding(.top, 2)
            Group {
                if axis {
                    TextField(key, text: text, axis: .vertical)
                        .lineLimit(2...4)
                } else {
                    TextField(key, text: text)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(NativeTheme.dayInk)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .modifier(OptionalAccessibilityIdentifier(id))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
