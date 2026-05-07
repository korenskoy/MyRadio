import SwiftUI

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
    case green, orange, blue, purple

    var displayName: String { rawValue.capitalized }
}

struct AccentPreset {
    let accent:      Color
    let strong:      Color
    let soft:        Color
    let softDark:    Color
    let fg:          Color
}

extension AccentName {
    // OKLCH → sRGB conversions, computed once
    var preset: AccentPreset {
        switch self {
        case .green:
            return AccentPreset(
                accent:   Color(hex: 0x5CC97A),
                strong:   Color(hex: 0x3DAF62),
                soft:     Color(hex: 0xEDF9F1),
                softDark: Color(hex: 0x1A3D27),
                fg:       Color(hex: 0x0C2014)
            )
        case .orange:
            return AccentPreset(
                accent:   Color(hex: 0xD4935A),
                strong:   Color(hex: 0xB8722F),
                soft:     Color(hex: 0xFAF0E8),
                softDark: Color(hex: 0x3D2210),
                fg:       Color(hex: 0x1D0C04)
            )
        case .blue:
            return AccentPreset(
                accent:   Color(hex: 0x5C9BCC),
                strong:   Color(hex: 0x3A7AAF),
                soft:     Color(hex: 0xE8F2FA),
                softDark: Color(hex: 0x112233),
                fg:       Color(hex: 0x04101D)
            )
        case .purple:
            return AccentPreset(
                accent:   Color(hex: 0xB374C8),
                strong:   Color(hex: 0x9350AF),
                soft:     Color(hex: 0xF5EAF9),
                softDark: Color(hex: 0x2D1438),
                fg:       Color(hex: 0x180C1D)
            )
        }
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
    static let defaultValue = AppColors.makeLight(accent: .green)
}

extension EnvironmentValues {
    var appColors: AppColors {
        get { self[AppColorsKey.self] }
        set { self[AppColorsKey.self] = newValue }
    }
}
