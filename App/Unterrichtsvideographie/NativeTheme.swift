import SwiftUI

/// One scientific-video palette shared by preparation, capture and reflection.
/// Legacy role names remain source-compatible with the feature components.
enum NativeTheme {
    enum SurfaceRole { case day, night }

    static let nightCanvas = Color(red: 0.141, green: 0.161, blue: 0.184)
    static let nightSurface = Color(red: 0.161, green: 0.184, blue: 0.212)
    static let nightElevated = Color(red: 0.125, green: 0.145, blue: 0.169)
    static let nightInk = Color(red: 0.945, green: 0.953, blue: 0.965)
    static let nightInkSecondary = Color(red: 0.769, green: 0.804, blue: 0.851)
    static let nightInkTertiary = Color(red: 0.710, green: 0.749, blue: 0.800)
    static let nightHairline = Color(red: 0.294, green: 0.329, blue: 0.376)
    static let dayCanvas = nightCanvas
    static let daySurface = nightSurface
    static let dayInk = nightInk
    static let dayInkSecondary = nightInkSecondary
    static let dayInkTertiary = nightInkTertiary
    static let dayHairline = nightHairline
    static let dayHairlineStrong = Color(red: 0.459, green: 0.502, blue: 0.561)

    /// Blue denotes ordinary actions and measured signals; red denotes capture.
    static let accent = Color(red: 0.510, green: 0.769, blue: 0.965)
    static let recordAccent = Color(red: 0.914, green: 0.227, blue: 0.263)
    static let recordSurface = Color(red: 0.780, green: 0.170, blue: 0.200)
    static let warningNight = Color(red: 0.949, green: 0.761, blue: 0.400)
    static let dangerNight = Color(red: 1.0, green: 0.576, blue: 0.561)
    static let positiveNight = Color(red: 0.624, green: 0.843, blue: 0.718)
    static let positiveDay = positiveNight
    static let warning = warningNight
    static let danger = dangerNight
    static let positiveWash = positiveNight.opacity(0.08)
    static let canvas = nightCanvas
    static let surface = nightSurface
    static let positive = positiveNight
    static let cornerRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 4

    static func card<Content: View>(
        role: SurfaceRole = .night,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content().padding(16).background(nightSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .strokeBorder(nightHairline, lineWidth: 1)
            }
    }

    static func hairline(role: SurfaceRole) -> Color { nightHairline }
    static func secondaryInk(role: SurfaceRole) -> Color { nightInkSecondary }
}

extension View {
    func fieldInstrumentDaySurface() -> some View { scientificSurface() }
    func fieldInstrumentNightSurface() -> some View { scientificSurface() }

    private func scientificSurface() -> some View {
        self.tint(NativeTheme.accent)
            .foregroundStyle(NativeTheme.nightInk)
            .preferredColorScheme(.dark)
            .scrollContentBackground(.hidden)
            .background(NativeTheme.nightCanvas)
            .toolbarBackground(NativeTheme.nightCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func scientificInput() -> some View {
        self.padding(.horizontal, 12).padding(.vertical, 11)
            .frame(minHeight: 44, alignment: .leading)
            .background(NativeTheme.nightElevated)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(NativeTheme.dayHairlineStrong, lineWidth: 1)
            }
    }
}

struct ScientificButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .frame(minHeight: 44)
            .foregroundStyle(prominent && isEnabled ? NativeTheme.nightCanvas : NativeTheme.nightInk)
            .background(prominent && isEnabled ? NativeTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isEnabled ? NativeTheme.nightInkSecondary : NativeTheme.dayHairlineStrong, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.55)
    }
}
