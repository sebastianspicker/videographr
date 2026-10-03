import SwiftUI

/// Session-centered navigation with a full-width capture surface on iPad.
struct RootTabView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var selection: FieldInstrumentTabBar.Tab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(selection: FieldInstrumentTabBar.Tab = .setup) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            if selection != .live {
                ScientificSessionHeader(session: appStore.session, selection: $selection)
            }
            tabContent.frame(maxWidth: .infinity, maxHeight: .infinity)
            if horizontalSizeClass != .regular {
                FieldInstrumentTabBar(selection: $selection, role: .night)
            }
        }
        .background(NativeTheme.nightCanvas.ignoresSafeArea())
        .foregroundStyle(NativeTheme.nightInk)
        .preferredColorScheme(.dark)
        .tint(NativeTheme.accent)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appStore.bootstrapState {
        case .loading:
            ProgressView("Lokale Sitzungen werden wiederhergestellt…")
                .accessibilityIdentifier("app.loadingSessions")
        case let .failed(message):
            ContentUnavailableView {
                Label("Sitzungen konnten nicht geöffnet werden", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") { Task { await appStore.bootstrap() } }
                    .accessibilityIdentifier("app.retryLoadingSessions")
            }
        case .ready:
            readyTabContent
        }
    }

    @ViewBuilder
    private var readyTabContent: some View {
        switch selection {
        case .setup:
            SetupView(onContinue: { selection = .live })
        case .live:
            LiveGuidanceView(onExit: { selection = .setup })
        case .reflect:
            ReflectView(onEditSession: { selection = .setup }, isReflectionSelected: { selection == .reflect })
        case .learn:
            LearnRootView()
        case .info:
            AboutView()
        }
    }
}

#Preview {
    let appStore = AppStore()
    RootTabView()
        .environmentObject(appStore)
        .environmentObject(LiveStore(appStore: appStore))
}

#Preview("Live compact accessibility", traits: .fixedLayout(width: 390, height: 844)) {
    let appStore = AppStore()
    RootTabView(selection: .live)
        .environmentObject(appStore)
        .environmentObject(LiveStore(appStore: appStore))
        .environment(\.horizontalSizeClass, .compact)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Live iPad scientific monitor", traits: .fixedLayout(width: 1_024, height: 768)) {
    let appStore = AppStore()
    RootTabView(selection: .live)
        .environmentObject(appStore)
        .environmentObject(LiveStore(appStore: appStore))
        .environment(\.horizontalSizeClass, .regular)
}
