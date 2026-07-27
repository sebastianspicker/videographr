import SwiftUI
import GuidanceEngine
import SessionCore

struct PlacementDimensionsView: View {
    let dimensions: [PlacementDimension]

    var body: some View {
        if !dimensions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(dimensions) { dimension in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: dimension.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(dimension.ok ? NativeTheme.positiveNight : NativeTheme.warning)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(dimension.labelDE)
                                .font(.caption.weight(.semibold))
                            Text(dimension.detailDE)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

struct PrioritizedTipRow: View {
    let item: PrioritizedTip
    var isRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                presentationBadge
                severityBadge
                Text(categoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if let note = item.phaseNoteDE {
                Text(note)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(item.presentation == .postTakeNote ? Color.secondary : NativeTheme.warning)
            }
            Text(item.tip.message)
                .font(.body)
                .opacity(item.presentation == .postTakeNote ? 0.85 : 1)
            Text(item.tip.actionHint)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.presentation == .postTakeNote ? Color.secondary : Color.accentColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var presentationBadge: some View {
        Text(item.presentation == .postTakeNote ? "Nach Aufnahme" : (isRecording ? "Während Aufnahme" : "Vor Aufnahme"))
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (item.presentation == .postTakeNote ? Color.gray : Color.blue).opacity(0.15),
                in: Capsule()
            )
    }

    private var severityBadge: some View {
        Text(severityLabel)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(severityColor.opacity(0.18), in: Capsule())
            .foregroundStyle(severityColor)
    }

    private var severityLabel: String {
        switch item.tip.severity {
        case .ok: "OK"
        case .info: "Info"
        case .warning: "Hinweis"
        case .critical: "Kritisch"
        }
    }

    private var severityColor: Color {
        switch item.tip.severity {
        case .ok: NativeTheme.positiveNight
        case .info: NativeTheme.nightInkSecondary
        case .warning: NativeTheme.warning
        case .critical: NativeTheme.danger
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
        case .teachingScene: "Unterrichtsszene"
        case .general: "Allgemein"
        }
    }
}
