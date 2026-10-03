import SwiftUI

/// The five destinations, numbered like the sections of a protocol.
enum Destination: String, CaseIterable, Hashable {
    case setup, live, reflect, learn, info

    var title: String {
        switch self {
        case .setup: "Sitzung"
        case .live: "Aufnahme"
        case .reflect: "Notizen"
        case .learn: "Referenz"
        case .info: "Info"
        }
    }

    var number: String {
        String(format: "%02d", (Self.allCases.firstIndex(of: self) ?? 0) + 1)
    }

    var accessibilityID: String {
        switch self {
        case .setup: "tab.Setup"
        case .live: "tab.Live"
        case .reflect: "tab.Reflektieren"
        case .learn: "tab.Lernen"
        case .info: "tab.Info"
        }
    }

    var systemImage: String {
        switch self {
        case .setup: "list.clipboard"
        case .live: "record.circle"
        case .reflect: "text.book.closed"
        case .learn: "book"
        case .info: "info.circle"
        }
    }
}

/// Lowercase serif wordmark; the product has no other logo.
struct Wordmark: View {
    var body: some View {
        Text("videographr")
            .font(Typeface.wordmark)
            .lineLimit(1)
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityLabel("Videographr")
            .accessibilityAddTraits(.isHeader)
    }
}

/// The promise that applies to every screen: nothing leaves the device.
struct LocalityMark: View {
    @Environment(\.surfaceMaterial) private var material

    var body: some View {
        Label("Nur lokal", systemImage: "internaldrive")
            .font(Typeface.labelSmall)
            .tracking(0.3)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(material == .room ? Room.tertiary : Ink.tertiary)
            .accessibilityLabel("Sitzungsdaten bleiben lokal auf diesem Gerät")
    }
}

/// Top of every document screen. On iPad it carries the destinations; on
/// phones the destinations live in the bottom bar.
struct Masthead: View {
    @Binding var selection: Destination
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if sizeClass == .regular && typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack { Wordmark(); Spacer(minLength: Space.m) }
                    destinationMenu
                }
            } else if sizeClass == .regular {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Space.xl) {
                        Wordmark()
                        Spacer(minLength: Space.l)
                        destinationTabs
                        Spacer(minLength: Space.l)
                        LocalityMark()
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack { Wordmark(); Spacer(minLength: Space.m); LocalityMark() }
                        destinationTabs
                    }
                }
            } else if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Wordmark()
                    LocalityMark()
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Wordmark()
                    Spacer(minLength: Space.m)
                    LocalityMark()
                }
            }
        }
        .padding(.horizontal, sizeClass == .regular ? Space.gutterRegular : Space.gutterCompact)
        .padding(.top, Space.m)
        .padding(.bottom, sizeClass == .regular && !typeSize.isAccessibilitySize ? 0 : Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.paper)
        .overlay(alignment: .bottom) { Rule() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chrome.sessionHeader")
    }

    private var destinationTabs: some View {
        HStack(alignment: .bottom, spacing: Space.xl) {
            ForEach(Destination.allCases, id: \.self) { destination in
                Button { selection = destination } label: {
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(destination.number)
                                .font(Typeface.valueSmall)
                                .foregroundStyle(selection == destination ? Ink.human : Ink.tertiary)
                            Text(destination.title)
                                .font(Typeface.callout.weight(.semibold))
                                .foregroundStyle(selection == destination ? Ink.human : Ink.secondary)
                        }
                        Rectangle()
                            .fill(selection == destination ? Ink.human : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.top, Space.s)
                    .fixedSize()
                    .frame(minHeight: Space.target, alignment: .bottom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.title)
                .accessibilityAddTraits(selection == destination ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(destination.accessibilityID)
            }
        }
    }

    private var destinationMenu: some View {
        Menu {
            ForEach(Destination.allCases, id: \.self) { destination in
                Button { selection = destination } label: {
                    Label("\(destination.number) \(destination.title)", systemImage: destination.systemImage)
                }
                .accessibilityIdentifier(destination.accessibilityID)
            }
        } label: {
            Label("Bereich: \(selection.title)", systemImage: "chevron.down")
                .font(Typeface.body.weight(.semibold))
                .frame(minHeight: Space.target)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Bereich wechseln, \(selection.title)")
        .accessibilityIdentifier("chrome.sectionMenu")
    }
}

/// Bottom destinations on phones: numbered words, no icon soup.
struct DestinationBar: View {
    @Binding var selection: Destination
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.surfaceMaterial) private var material

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                Menu {
                    ForEach(Destination.allCases, id: \.self) { destination in
                        Button { selection = destination } label: {
                            Label("\(destination.number) \(destination.title)", systemImage: destination.systemImage)
                        }
                        .accessibilityIdentifier(destination.accessibilityID)
                    }
                } label: {
                    Label("Bereich: \(selection.title)", systemImage: "chevron.up")
                        .font(Typeface.body.weight(.semibold))
                        .foregroundStyle(material == .room ? Room.primary : Ink.primary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Destination.allCases, id: \.self) { destination in
                        item(destination)
                    }
                }
            }
        }
        .padding(.horizontal, Space.xs)
        .background((material == .room ? Room.surface : Ink.sheet).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rule() }
        .tint(material == .room ? Room.human : Ink.human)
        .accessibilityIdentifier("chrome.tabBar")
    }

    private func item(_ destination: Destination) -> some View {
        let selected = selection == destination
        return Button { selection = destination } label: {
            VStack(spacing: 3) {
                Text(destination.number)
                    .font(Typeface.valueSmall)
                Text(destination.title)
                    .font(Typeface.captionSmall.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selected ? human : secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(alignment: .top) {
                Rectangle().fill(selected ? human : Color.clear).frame(width: 28, height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(destination.accessibilityID)
    }

    private var human: Color { material == .room ? Room.human : Ink.human }
    private var secondary: Color { material == .room ? Room.secondary : Ink.secondary }
}
