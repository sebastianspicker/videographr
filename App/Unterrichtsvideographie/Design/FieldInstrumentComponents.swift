import SwiftUI

// MARK: - Panel

/// Hairline day/night panel used instead of Form sections.
struct FieldPanel<Content: View>: View {
    var role: NativeTheme.SurfaceRole = .day
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                role == .day ? NativeTheme.daySurface : NativeTheme.nightElevated,
                in: RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(NativeTheme.hairline(role: role), lineWidth: 1)
            }
    }
}

// MARK: - Section chrome

struct FieldSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInkSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct FieldEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(NativeTheme.accent)
    }
}

// MARK: - Editable field

struct FieldLabeledInput<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(NativeTheme.dayInkTertiary)
            content()
                .font(.body.weight(.medium))
                .foregroundStyle(NativeTheme.dayInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Quiet table row used for context key/value pairs.
struct FieldContextRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .frame(width: 110, alignment: .leading)
            Text(value.isEmpty ? "Nicht angegeben" : value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NativeTheme.dayInk)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInkTertiary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Chips / badges

struct FieldScopeChip: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? NativeTheme.positiveDay : NativeTheme.dayInkTertiary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? NativeTheme.positiveWash : NativeTheme.dayCanvas)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isOn ? NativeTheme.positiveDay.opacity(0.25) : NativeTheme.dayHairline,
                        lineWidth: 1
                    )
            }
    }
}

struct FieldStatusBadge: View {
    let title: String
    var tone: Tone = .positive

    enum Tone {
        case positive, warning, neutral
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var foreground: Color {
        switch tone {
        case .positive: return NativeTheme.positiveDay
        case .warning: return NativeTheme.warning
        case .neutral: return NativeTheme.dayInkTertiary
        }
    }

    private var background: Color {
        switch tone {
        case .positive: return NativeTheme.positiveWash
        case .warning: return NativeTheme.warning.opacity(0.14)
        case .neutral: return NativeTheme.dayCanvas
        }
    }
}

// MARK: - Readiness checklist

struct FieldReadinessItem: View {
    let title: String
    let detail: String
    let isMet: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(isMet ? NativeTheme.positiveDay : NativeTheme.dayHairlineStrong, lineWidth: 1.5)
                    .background(Circle().fill(isMet ? NativeTheme.positiveWash : Color.clear))
                if isMet {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NativeTheme.positiveDay)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeTheme.dayInk)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

struct FieldReadyBanner: View {
    let isReady: Bool
    let readyText: String
    let blockedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: isReady ? "lock.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                Text(isReady ? "Bereit für die Aufnahme" : "Noch nicht bereit")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isReady ? NativeTheme.positiveDay : NativeTheme.warning)

            Text(isReady ? readyText : blockedText)
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isReady ? NativeTheme.positiveWash : NativeTheme.warning.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isReady ? NativeTheme.positiveDay.opacity(0.22) : NativeTheme.warning.opacity(0.28),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Primary / ghost buttons

struct FieldPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            NativeTheme.accent.opacity(isEnabled ? 1 : 0.4),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .disabled(!isEnabled)
    }
}

struct FieldGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .foregroundStyle(NativeTheme.dayInkSecondary)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(NativeTheme.dayHairlineStrong, lineWidth: 1)
        }
    }
}
