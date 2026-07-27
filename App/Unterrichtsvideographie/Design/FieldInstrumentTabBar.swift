import SwiftUI

/// Custom tab chrome so day atelier and night instrument can recolor with selection.
/// System UITabBar cannot flip light/dark independently of child preferredColorScheme.
struct FieldInstrumentTabBar: View {
    enum Tab: String, CaseIterable, Hashable {
        case setup
        case live
        case reflect
        case learn
        case info

        var title: String {
            switch self {
            case .setup: return "Setup"
            case .live: return "Live"
            case .reflect: return "Reflektieren"
            case .learn: return "Lernen"
            case .info: return "Info"
            }
        }

        /// Short label for compact widths.
        var compactTitle: String {
            switch self {
            case .setup: return "Setup"
            case .live: return "Live"
            case .reflect: return "Reflekt."
            case .learn: return "Lernen"
            case .info: return "Info"
            }
        }

        var systemImage: String {
            switch self {
            case .setup: return "list.clipboard"
            case .live: return "record.circle"
            case .reflect: return "text.book.closed"
            case .learn: return "book.fill"
            case .info: return "info.circle"
            }
        }
    }

    @Binding var selection: Tab
    var role: NativeTheme.SurfaceRole

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(barBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chrome.tabBar")
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? selectedTint : inactiveTint)
                Text(tab.compactTitle)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? selectedTint : inactiveTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedFill)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tab.\(tab.title)")
    }

    private var barBackground: Color {
        role == .day ? NativeTheme.dayCanvas : NativeTheme.nightCanvas
    }

    private var hairline: Color {
        role == .day ? NativeTheme.dayHairline : NativeTheme.nightHairline
    }

    private var selectedTint: Color {
        role == .day ? NativeTheme.accent : NativeTheme.recordAccent
    }

    private var inactiveTint: Color {
        role == .day ? NativeTheme.dayInkTertiary : NativeTheme.nightInkTertiary
    }

    private var selectedFill: Color {
        role == .day
            ? NativeTheme.accent.opacity(0.08)
            : NativeTheme.nightElevated
    }
}
