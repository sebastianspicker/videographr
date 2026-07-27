import SessionCore
import SwiftUI

/// Persistent top chrome: operating mode, consent freeze, locality, schema/build.
struct ProvenanceBar: View {
    enum Role {
        case day
        case night

        var themeRole: NativeTheme.SurfaceRole {
            switch self {
            case .day: return .day
            case .night: return .night
            }
        }
    }

    let role: Role
    let segments: [String]
    var trailing: String? = nil

    var body: some View {
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
        .padding(.horizontal, role == .day ? 20 : 16)
        .frame(height: 40)
        .background(barBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chrome.provenance")
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

extension ProvenanceBar {
    /// Standard session-aware segments for day surfaces.
    static func daySession(_ session: CaptureSession, activeGrantCount: Int) -> ProvenanceBar {
        let mode = session.operatingMode == .evidenceSafe ? "Evidence-safe" : "Experimental"
        let grants = activeGrantCount == 1
            ? "1 Freigabe aktiv"
            : "\(activeGrantCount) Freigaben aktiv"
        return ProvenanceBar(
            role: .day,
            segments: [mode, grants, "Nur lokal · kein Cloud"],
            trailing: "schema v\(session.schemaVersion) · \(BuildIdentity.current.displayVersion)"
        )
    }

    /// Live instrument bar (pre-roll / recording).
    static func nightLive(
        session: CaptureSession,
        isRecording: Bool,
        formatLabel: String = "1920×1080"
    ) -> ProvenanceBar {
        let mode = session.operatingMode == .evidenceSafe ? "Evidence-safe" : "Experimental"
        let phase = isRecording ? "recording" : "pre-roll"
        return ProvenanceBar(
            role: .night,
            segments: [
                mode,
                isRecording ? "Freigaben eingefroren" : "Freigaben geprüft",
                "\(formatLabel) · kontinuierliche Take"
            ],
            trailing: phase
        )
    }
}

/// Compact Evidence-safe status used in side rails / footers.
struct EvidenceSafeModeBadge: View {
    let role: ProvenanceBar.Role

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(led)
                .frame(width: 5, height: 5)
                .shadow(color: led.opacity(0.35), radius: 3)
            Text("EVIDENCE\nSAFE")
                .font(.system(size: 8, weight: .medium))
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .foregroundStyle(secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(role == .day ? NativeTheme.daySurface : NativeTheme.nightSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(role == .day ? NativeTheme.dayHairline : NativeTheme.nightHairline)
        }
        .accessibilityLabel("Evidence-safe Modus aktiv")
        .accessibilityIdentifier("chrome.evidenceSafeBadge")
    }

    private var led: Color {
        role == .day ? NativeTheme.positiveDay : NativeTheme.positiveNight
    }

    private var secondary: Color {
        role == .day ? NativeTheme.dayInkTertiary : NativeTheme.nightInkTertiary
    }
}
