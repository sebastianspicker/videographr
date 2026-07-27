import SwiftUI

/// Field Instrument visual language with day-studio and night-instrument surfaces.
///
/// Accent is reserved for primary actions and the record control; status colors never
/// decorate inactive chrome.
enum NativeTheme {
    // MARK: - Surface role

    enum SurfaceRole {
        /// Setup, Reflect, Learn, and Info use the warm paper surface.
        case day
        /// Live capture uses near-black instrument chrome.
        case night
    }

    // MARK: - Day studio (prep / reflect)

    static let dayCanvas = Color(red: 0.969, green: 0.965, blue: 0.953) // #F7F6F3
    static let daySurface = Color.white
    static let dayInk = Color(red: 0.102, green: 0.110, blue: 0.122) // #1A1C1F
    static let dayInkSecondary = Color(red: 0.243, green: 0.259, blue: 0.282) // #3E4248
    static let dayInkTertiary = Color(red: 0.431, green: 0.451, blue: 0.486) // #6E737C
    static let dayHairline = Color(red: 0.894, green: 0.886, blue: 0.863) // #E4E2DC
    static let dayHairlineStrong = Color(red: 0.835, green: 0.827, blue: 0.800) // #D5D3CC

    // MARK: - Night instrument (live)

    static let nightCanvas = Color(red: 0.027, green: 0.031, blue: 0.039) // #07080A
    static let nightSurface = Color(red: 0.067, green: 0.078, blue: 0.102) // #11141A
    static let nightElevated = Color(red: 0.090, green: 0.106, blue: 0.137) // #171B23
    static let nightInk = Color(red: 0.925, green: 0.933, blue: 0.949) // #ECEEF2
    static let nightInkSecondary = Color(red: 0.659, green: 0.690, blue: 0.741) // #A8B0BD
    static let nightInkTertiary = Color(red: 0.431, green: 0.467, blue: 0.529) // #6E7787
    static let nightHairline = Color(red: 0.145, green: 0.165, blue: 0.208) // #252A35

    // MARK: - Accent & status (shared roles, role-tinted)

    /// Deep terracotta for primary actions on day surfaces.
    static let accent = Color(red: 0.722, green: 0.263, blue: 0.122) // #B8431F
    /// Slightly brighter record signal on night instrument.
    static let recordAccent = Color(red: 0.878, green: 0.337, blue: 0.157) // #E05628
    static let accentWash = Color(red: 0.980, green: 0.941, blue: 0.922) // #FAF0EB

    static let warning = Color(red: 0.910, green: 0.635, blue: 0.227) // #E8A23A
    static let danger = Color(red: 0.910, green: 0.353, blue: 0.298) // #E85A4C
    static let positiveDay = Color(red: 0.114, green: 0.420, blue: 0.310) // #1D6B4F
    static let positiveNight = Color(red: 0.243, green: 0.812, blue: 0.580) // #3ECF94
    static let positiveWash = Color(red: 0.933, green: 0.965, blue: 0.949) // #EEF6F2

    // MARK: - Backward-compatible aliases (night-oriented legacy call sites)

    static let canvas = nightCanvas
    static let surface = nightSurface
    static let elevatedSurface = nightElevated
    static let positive = positiveNight

    static let cornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 10

    // MARK: - Cards

    static func card<Content: View>(
        role: SurfaceRole = .night,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let bg = role == .day ? daySurface : nightElevated
        let stroke = role == .day ? dayHairline : nightHairline
        return content()
            .padding(16)
            .background(bg, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
    }

    static func hairline(role: SurfaceRole) -> Color {
        role == .day ? dayHairline : nightHairline
    }

    static func secondaryInk(role: SurfaceRole) -> Color {
        role == .day ? dayInkTertiary : nightInkTertiary
    }
}

// MARK: - View modifiers

extension View {
    /// Day atelier surface (Setup, Reflect, Learn, Info).
    func fieldInstrumentDaySurface() -> some View {
        self
            .tint(NativeTheme.accent)
            .preferredColorScheme(.light)
            .scrollContentBackground(.hidden)
            .background(NativeTheme.dayCanvas)
            .toolbarBackground(NativeTheme.dayCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }

    /// Night instrument surface (Live).
    func fieldInstrumentNightSurface() -> some View {
        self
            .tint(NativeTheme.recordAccent)
            .preferredColorScheme(.dark)
            .scrollContentBackground(.hidden)
            .background(NativeTheme.nightCanvas)
            .toolbarBackground(NativeTheme.nightCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Legacy alias that maps to the night instrument surface.
    func nativeAppSurface() -> some View {
        fieldInstrumentNightSurface()
    }
}
