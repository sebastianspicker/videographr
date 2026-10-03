import SessionCore
import SwiftUI

/// All original destinations remain available without consuming the video's width.
struct FieldInstrumentTabBar: View {
    enum Tab: String, CaseIterable, Hashable {
        case setup, live, reflect, learn, info

        var title: String {
            switch self {
            case .setup: return "Sitzung"
            case .live: return "Aufnahme"
            case .reflect: return "Notizen"
            case .learn: return "Referenz"
            case .info: return "Info"
            }
        }

        var accessibilityID: String {
            switch self {
            case .setup: return "tab.Setup"
            case .live: return "tab.Live"
            case .reflect: return "tab.Reflektieren"
            case .learn: return "tab.Lernen"
            case .info: return "tab.Info"
            }
        }

        var systemImage: String {
            switch self {
            case .setup: return "list.clipboard"
            case .live: return "record.circle"
            case .reflect: return "text.book.closed"
            case .learn: return "book"
            case .info: return "info.circle"
            }
        }
    }

    @Binding var selection: Tab
    var role: NativeTheme.SurfaceRole
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                Menu {
                    destinationButtons
                } label: {
                    Label("Bereich: \(selection.title)", systemImage: selection.systemImage)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button { selection = tab } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.systemImage).font(.body)
                                Text(tab.title).font(.caption2)
                            }
                            .foregroundStyle(selection == tab ? NativeTheme.accent : NativeTheme.nightInkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(alignment: .top) {
                                if selection == tab {
                                    Rectangle().fill(NativeTheme.accent).frame(width: 28, height: 2)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.title)
                        .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier(tab.accessibilityID)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(NativeTheme.nightCanvas)
        .overlay(alignment: .top) {
            Rectangle().fill(NativeTheme.nightHairline).frame(height: 1)
        }
        .accessibilityIdentifier("chrome.tabBar")
    }

    private var destinationButtons: some View {
        ForEach(Tab.allCases, id: \.self) { tab in
            Button { selection = tab } label: {
                Label(tab.title, systemImage: tab.systemImage)
            }
            .accessibilityIdentifier(tab.accessibilityID)
        }
    }
}

/// Session identity is constant while the task changes. The menu retains the
/// reference catalogue and app information without a permanent navigation rail.
struct ScientificSessionHeader: View {
    let session: CaptureSession
    @Binding var selection: FieldInstrumentTabBar.Tab
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("videographr").font(.headline)
                        .accessibilityLabel("Videographr. Sitzung: \(session.title)")
                    if sizeClass == .regular { sectionMenu }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 20) {
                    brand
                    if sizeClass == .regular {
                        Spacer(minLength: 12)
                        sessionIdentity
                    }
                    Spacer(minLength: 12)
                    sectionMenu
                }
            }
        }
        .padding(.horizontal, sizeClass == .regular ? 28 : 18)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background(NativeTheme.nightSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(NativeTheme.nightHairline).frame(height: 1)
        }
        .accessibilityIdentifier("chrome.sessionHeader")
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("videographr").font(.title3.weight(.medium))
            if sizeClass != .regular {
                Text("Sitzung lokal").font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
            }
        }
    }

    private var sessionIdentity: some View {
        VStack(spacing: 3) {
            Text(session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Neue Sitzung" : session.title)
                .font(.headline).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            Text([session.context.subject, session.context.gradeLevel.isEmpty ? "" : "Klasse \(session.context.gradeLevel)"]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var sectionMenu: some View {
        Menu {
            ForEach(FieldInstrumentTabBar.Tab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .accessibilityIdentifier(tab.accessibilityID)
            }
        } label: {
            VStack(alignment: .trailing, spacing: 4) {
                Label(selection.title, systemImage: "chevron.down")
                if sizeClass == .regular {
                    Label("Sitzung lokal", systemImage: "externaldrive")
                        .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .tint(NativeTheme.nightInk)
        .accessibilityLabel("Bereich wechseln, \(selection.title)")
        .accessibilityIdentifier("chrome.sectionMenu")
    }
}
