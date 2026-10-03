import SessionCore
import SwiftUI

/// Persistent top chrome: operating mode, consent freeze, locality, schema/build.
struct ProvenanceBar: View {
    enum Role {
        case day
        case night
    }

    let role: Role
    let segments: [String]
    var trailing: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedContent
            } else {
                inlineContent
            }
        }
        .padding(.horizontal, role == .day ? 20 : 16)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .frame(minHeight: 40)
        .background(barBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chrome.provenance")
    }

    private var inlineContent: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    separator
                }
                Text(segment)
                    .font(index == 0 ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(index == 0 ? primaryInk : secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(secondaryInk)
                .lineLimit(1)
            }
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(segments.first ?? "Videographr")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryInk)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(secondaryInk)
                        .lineLimit(1)
                }
            }
            if segments.count > 1 {
                Text(segments.dropFirst().joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(hairline)
            .frame(width: 1, height: 11)
            .padding(.horizontal, 12)
    }

    private var primaryInk: Color {
        role == .day ? NativeTheme.dayInkSecondary : NativeTheme.nightInkSecondary
    }

    private var secondaryInk: Color {
        role == .day ? NativeTheme.dayInkTertiary : NativeTheme.nightInkTertiary
    }

    private var hairline: Color {
        role == .day ? NativeTheme.dayHairline : NativeTheme.nightHairline
    }

    private var barBackground: Color {
        role == .day ? NativeTheme.dayCanvas.opacity(0.92) : NativeTheme.nightCanvas.opacity(0.92)
    }
}
