import SwiftUI
import AppKit

// MARK: - Color hex init

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Theme tokens (ported from styles.css)

enum AppTheme: String, CaseIterable {
    case auto, light, dark
}

enum AccentName: String, CaseIterable {
    case system, blue, purple, pink, red, orange, yellow, green, graphite

    var displayName: String {
        self == .system ? "System" : rawValue.capitalized
    }
}

struct AccentPreset {
    let accent:      Color
    let strong:      Color
    let soft:        Color
    let softDark:    Color
    let fg:          Color
}

extension AccentName {
    /// macOS Accent Color picker values (NSColor.system*).
    var preset: AccentPreset {
        switch self {
        case .system:   return Self.systemPreset()
        case .blue:     return .fromHex(0x007AFF)
        case .purple:   return .fromHex(0xAF52DE)
        case .pink:     return .fromHex(0xFF2D55)
        case .red:      return .fromHex(0xFF3B30)
        case .orange:   return .fromHex(0xFF9500)
        case .yellow:   return .fromHex(0xFFCC00)
        case .green:    return .fromHex(0x34C759)
        case .graphite: return .fromHex(0x8E8E93)
        }
    }

    static func systemPreset() -> AccentPreset {
        guard let ns = NSColor.controlAccentColor.usingColorSpace(.sRGB) else {
            return .fromHex(0x007AFF)  // macOS Blue fallback
        }
        return .fromRGB(ns.redComponent, ns.greenComponent, ns.blueComponent)
    }
}

extension AccentPreset {
    /// Build a 5-component preset from a base RGB triple.
    /// strong = darken 0.18, soft = pastel light, softDark = deep tint,
    /// fg = b/w by luminance.
    /// Threshold 0.7 matches Apple's behavior for system accent buttons:
    /// yellow keeps black text, everything else (purple/red/orange/graphite/etc) gets white.
    static func fromRGB(_ r: Double, _ g: Double, _ b: Double) -> AccentPreset {
        let accent   = Color(.sRGB, red: r, green: g, blue: b)
        let strong   = Color(.sRGB, red: max(0, r - 0.18), green: max(0, g - 0.18), blue: max(0, b - 0.18))
        let soft     = Color(.sRGB, red: min(1, r * 0.12 + 0.88), green: min(1, g * 0.12 + 0.88), blue: min(1, b * 0.12 + 0.88))
        let softDark = Color(.sRGB, red: r * 0.25, green: g * 0.25, blue: b * 0.25)
        let lum      = 0.299 * r + 0.587 * g + 0.114 * b
        let fgV: Double = lum > 0.70 ? 0.08 : 0.95
        let fg = Color(.sRGB, red: fgV, green: fgV, blue: fgV)
        return AccentPreset(accent: accent, strong: strong, soft: soft, softDark: softDark, fg: fg)
    }

    static func fromHex(_ hex: UInt32) -> AccentPreset {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        return fromRGB(r, g, b)
    }
}

// MARK: - Semantic colors (accessed via environment)

struct AppColors {
    let accent: AccentPreset

    // Backgrounds
    let bgWindow:    Color
    let bgPanel:     Color
    let bgPanel2:    Color
    let bgElevated:  Color
    let bgHover:     Color
    let bgActive:    Color
    let bgInput:     Color
    let bgPill:      Color
    let bgDebug:     Color
    let bgDebugRow:  Color

    // Foregrounds
    let fg:          Color
    let fg2:         Color
    let fg3:         Color
    let fg4:         Color
    let fgDebug:     Color
    let fgDebug2:    Color

    // Borders
    let border:      Color
    let borderStrong: Color
    let borderDebug: Color

    // Status
    let statusOk:    Color
    let statusWarn:  Color
    let statusErr:   Color
    let statusInfo:  Color

    static func make(theme: AppTheme, accent: AccentName, systemDark: Bool) -> AppColors {
        let isDark = theme == .dark || (theme == .auto && systemDark)
        return isDark ? makeDark(accent: accent) : makeLight(accent: accent)
    }

    static func makeLight(accent: AccentName) -> AppColors {
        AppColors(
            accent:       accent.preset,
            bgWindow:     Color(hex: 0xF4F3EF),
            bgPanel:      Color(hex: 0xFFFFFF),
            bgPanel2:     Color(hex: 0xFAF9F5),
            bgElevated:   Color(hex: 0xFFFFFF),
            bgHover:      Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.045),
            bgActive:     Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.075),
            bgInput:      Color(hex: 0xFFFFFF),
            bgPill:       Color(hex: 0xEFEEE9),
            bgDebug:      Color(hex: 0x1A1A1C),
            bgDebugRow:   Color(hex: 0x232325),
            fg:           Color(hex: 0x161614),
            fg2:          Color(hex: 0x5A584F),
            fg3:          Color(hex: 0x97948A),
            fg4:          Color(hex: 0xB8B5AB),
            fgDebug:      Color(hex: 0xD8D8DA),
            fgDebug2:     Color(hex: 0x8A8A90),
            border:       Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.08),
            borderStrong: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.14),
            borderDebug:  Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.08),
            statusOk:     Color(hex: 0x4DB86A),
            statusWarn:   Color(hex: 0xCDAA3A),
            statusErr:    Color(hex: 0xC0392B),
            statusInfo:   Color(hex: 0x4A8EC2)
        )
    }

    static func makeDark(accent: AccentName) -> AppColors {
        AppColors(
            accent:       accent.preset,
            bgWindow:     Color(hex: 0x1C1B19),
            bgPanel:      Color(hex: 0x232220),
            bgPanel2:     Color(hex: 0x1F1E1C),
            bgElevated:   Color(hex: 0x2C2B28),
            bgHover:      Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.05),
            bgActive:     Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.09),
            bgInput:      Color(hex: 0x2C2B28),
            bgPill:       Color(hex: 0x2C2B28),
            bgDebug:      Color(hex: 0x0F0F10),
            bgDebugRow:   Color(hex: 0x161617),
            fg:           Color(hex: 0xF1EFE8),
            fg2:          Color(hex: 0xB3AFA0),
            fg3:          Color(hex: 0x7C7868),
            fg4:          Color(hex: 0x4F4D45),
            fgDebug:      Color(hex: 0xD8D8DA),
            fgDebug2:     Color(hex: 0x8A8A90),
            border:       Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.08),
            borderStrong: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.14),
            borderDebug:  Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.08),
            statusOk:     Color(hex: 0x4DB86A),
            statusWarn:   Color(hex: 0xCDAA3A),
            statusErr:    Color(hex: 0xC0392B),
            statusInfo:   Color(hex: 0x4A8EC2)
        )
    }
}

// MARK: - Environment key

private struct AppColorsKey: EnvironmentKey {
    static let defaultValue = AppColors.makeLight(accent: .system)
}

extension EnvironmentValues {
    var appColors: AppColors {
        get { self[AppColorsKey.self] }
        set { self[AppColorsKey.self] = newValue }
    }
}
