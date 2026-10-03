import SwiftUI
import GuidanceEngine
import SessionCore

struct PrioritizedTipRow: View {
    let item: PrioritizedTip
    var isRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    phaseLabel
                    severityMark
                    categoryText
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    phaseLabel
                    severityMark
                    categoryText
                }
            }
            if let note = item.phaseNoteDE {
                Text(note)
                    .font(Typeface.captionSmall.weight(.semibold))
                    .foregroundStyle(isPostTake ? Room.secondary : Room.attention)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.tip.message)
                .font(Typeface.body)
                .foregroundStyle(isPostTake ? Room.secondary : Room.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.tip.actionHint)
                .font(Typeface.callout.weight(.semibold))
                .foregroundStyle(isPostTake ? Room.secondary : Room.human)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }

    private var isPostTake: Bool { item.presentation == .postTakeNote }

    private var phaseLabel: some View {
        FormLabel(isPostTake ? "Nach Aufnahme" : (isRecording ? "Während Aufnahme" : "Vor Aufnahme"), small: true)
    }

    private var severityMark: some View {
        StatusMark(severityLabel, kind: severityKind)
    }

    private var categoryText: some View {
        Text(categoryLabel)
            .font(Typeface.labelSmall)
            .foregroundStyle(Room.tertiary)
    }

    private var severityLabel: String {
        switch item.tip.severity {
        case .ok: "OK"
        case .info: "Info"
        case .warning: "Hinweis"
        case .critical: "Kritisch"
        }
    }

    private var severityKind: StatusMark.Kind {
        switch item.tip.severity {
        case .ok: .secured
        case .info: .neutral
        case .warning: .attention
        case .critical: .fault
        }
    }

    private var categoryLabel: String {
        switch item.tip.category {
        case .orientation: "Lage / Gyro"
        case .composition: "Bildausschnitt"
        case .blackboard: "Tafel"
        case .ceiling: "Decke"
        case .backlight: "Gegenlicht"
        case .interaction: "Lehr-Lern-Zone"
        case .motion: "Stabilität"
        case .people: "Personen (CV)"
        case .general: "Allgemein"
        }
    }
}
