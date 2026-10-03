import SwiftUI

// MARK: - Panel

/// An editorial day/night section. It keeps related controls together without
/// turning every block of content into a floating card.
struct FieldPanel<Content: View>: View {
    var role: NativeTheme.SurfaceRole = .day
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NativeTheme.hairline(role: role))
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NativeTheme.hairline(role: role))
                    .frame(height: 1)
            }
    }
}

// MARK: - Section chrome

struct FieldSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                heading
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 3) {
                heading
            }
        }
    }

    @ViewBuilder
    private var heading: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NativeTheme.dayInkSecondary)
        if let subtitle {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
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

/// Shared view header for the day atelier. The accessory moves below the title
/// at large Dynamic Type sizes instead of compressing the main label.
struct FieldViewHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    var summary: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    init(
        eyebrow: String,
        title: String,
        summary: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.summary = summary
        self.accessory = accessory
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 16) {
                titleBlock
                Spacer(minLength: 12)
                accessory()
            }
            VStack(alignment: .leading, spacing: 12) {
                titleBlock
                accessory()
            }
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(NativeTheme.dayHairline).frame(height: 1)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldEyebrow(text: eyebrow)
            Text(title)
                .font(.title2.weight(.semibold))
                .tracking(-0.3)
                .foregroundStyle(NativeTheme.dayInk)
            if let summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Chips / badges

struct FieldScopeChip: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Label(title, systemImage: isOn ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
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
        Label(title.uppercased(), systemImage: symbol)
            .font(.caption.weight(.medium))
            .tracking(0.6)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var symbol: String {
        switch tone {
        case .positive: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .neutral: return "info.circle"
        }
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

// MARK: - Ghost buttons

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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(NativeTheme.dayHairlineStrong, lineWidth: 1)
        }
    }
}

/// Aligned fields on iPad, stacked labels on phones and at accessibility sizes.
struct ScientificFormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: 16) {
                    Text(label)
                        .foregroundStyle(NativeTheme.nightInkSecondary)
                        .frame(width: 120, alignment: .leading)
                    content().frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text(label).foregroundStyle(NativeTheme.nightInkSecondary)
                    content().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.body)
    }
}

struct ScientificCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? NativeTheme.accent : NativeTheme.nightInkSecondary)
                configuration.label.foregroundStyle(NativeTheme.nightInk)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
