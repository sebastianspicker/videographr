import SwiftUI

/// Primary shell: Setup → Live → Reflect → Learn → Info with custom Field Instrument tab chrome.
///
/// Day atelier for prep/reflection tabs; night instrument when Live is selected.
/// System UITabBar is hidden so chrome can recolor with the active surface.
struct RootTabView: View {
    @State private var selection: FieldInstrumentTabBar.Tab

    init() {
        #if DEBUG
        let initial: FieldInstrumentTabBar.Tab =
            ProcessInfo.processInfo.environment["VIDEOGRAPHR_E2E_START_TAB"] == "live"
            ? .live
            : .setup
        #else
        let initial: FieldInstrumentTabBar.Tab = .setup
        #endif
        _selection = State(initialValue: initial)
    }

    private var isNight: Bool { selection == .live }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tabContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FieldInstrumentTabBar(
                selection: $selection,
                role: isNight ? .night : .day
            )
        }
        .background((isNight ? NativeTheme.nightCanvas : NativeTheme.dayCanvas).ignoresSafeArea())
        .preferredColorScheme(isNight ? .dark : .light)
        .tint(isNight ? NativeTheme.recordAccent : NativeTheme.accent)
        .animation(.easeInOut(duration: 0.2), value: isNight)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .setup:
            SetupView()
        case .live:
            LiveGuidanceView(onExit: { selection = .setup })
        case .reflect:
            ReflectView()
        case .learn:
            LearnRootView()
        case .info:
            AboutView()
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppSessionModel())
}
