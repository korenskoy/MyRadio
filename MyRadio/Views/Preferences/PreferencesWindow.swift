//
//  PreferencesWindow.swift
//  MyRadio
//
//  Root container for the Settings scene. Mirrors the Ventura-style
//  sidebar layout from docs/design/myradio/project/preferences.jsx.
//

import SwiftUI

enum PrefsSection: String, CaseIterable, Identifiable {
    case about, general, appearance, shortcuts, advanced
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .about:      return "About"
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .shortcuts:  return "Shortcuts"
        case .advanced:   return "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .about:      return "info.circle.fill"
        case .general:    return "globe"
        case .appearance: return "paintpalette.fill"
        case .shortcuts:  return "keyboard"
        case .advanced:   return "slider.horizontal.3"
        }
    }

    /// Vertical gradient pair for the icon tile.
    /// Exact OKLCH→sRGB conversion of the stops in styles.css (.prefs-side-icon.*).
    func iconGradient(systemAccent: Color) -> LinearGradient {
        let pair: (top: Color, bottom: Color)
        switch self {
        case .about:      pair = (systemAccent.opacity(0.85), systemAccent)
        case .general:    pair = (Color(hex: 0x60C2FF), Color(hex: 0x0089D5))
        case .appearance: pair = (Color(hex: 0xD798FF), Color(hex: 0xA454D7))
        case .shortcuts:  pair = (Color(hex: 0xFF9550), Color(hex: 0xE26500))
        case .advanced:   pair = (Color(hex: 0x87A1BD), Color(hex: 0x52657A))
        }
        return LinearGradient(colors: [pair.top, pair.bottom],
                              startPoint: .top, endPoint: .bottom)
    }
}

struct PreferencesWindow: View {
    @Environment(AppState.self) private var state
    // @AppStorage observes UserDefaults.didChangeNotification globally — Settings
    // scene gets a cross-scene tick even when it isn't the focused window.
    // AppState.theme.didSet writes the mirror.
    @AppStorage("appTheme")  private var themeRaw:  String = AppTheme.auto.rawValue
    @AppStorage("appAccent") private var accentRaw: String = AccentName.system.rawValue

    private var theme:  AppTheme   { AppTheme(rawValue: themeRaw)   ?? state.theme  }
    private var accent: AccentName { AccentName(rawValue: accentRaw) ?? state.accent }

    /// isDark is resolved synchronously — does NOT depend on @Environment(\.colorScheme),
    /// which lags one render behind .preferredColorScheme(nil).
    private var isDark: Bool {
        switch theme {
        case .light: return false
        case .dark:  return true
        case .auto:
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    }

    var body: some View {
        PreferencesContent(isDark: isDark, accent: accent)
            .id(theme)                                   // structural rebuild on theme change
            .colorScheme(isDark ? .dark : .light)        // force SwiftUI children (.primary, SF) into our phase
            .frame(minWidth: 720, idealWidth: 760, minHeight: 540, idealHeight: 580)
            .tint(accent.preset.accent)
            .preferredColorScheme(theme.preferredColorScheme)  // window chrome (title bar, materials)
    }
}

private struct PreferencesContent: View {
    @Environment(AppState.self) private var state
    @SceneStorage("prefsSection") private var rawSection: String = PrefsSection.about.rawValue

    let isDark: Bool
    let accent: AccentName

    private var section: PrefsSection {
        PrefsSection(rawValue: rawSection) ?? .about
    }

    private var colors: AppColors {
        _ = state.systemColorEpoch
        // Build palette from injected isDark — guaranteed in lockstep with the
        // forced .colorScheme above.
        return AppColors.make(theme: isDark ? .dark : .light, accent: accent, systemDark: isDark)
    }

    var body: some View {
        HStack(spacing: 0) {
            CustomSidebar(
                selection: Binding(
                    get: { section },
                    set: { rawSection = $0.rawValue }
                ),
                accent: accent.preset.accent
            )
            .frame(width: 200)
            .background(
                LinearGradient(colors: [colors.bgPanel, colors.bgPanel2],
                               startPoint: .top, endPoint: .bottom)
            )

            Rectangle()
                .fill(colors.border)
                .frame(width: 0.5)

            Group {
                switch section {
                case .about:      AboutPane()
                case .general:    GeneralPane()
                case .appearance: AppearancePane()
                case .shortcuts:  ShortcutsPane()
                case .advanced:   AdvancedPane()
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colors.bgWindow)
        }
        .environment(\.appColors, colors)
    }
}

extension AppTheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        case .auto:  return nil
        }
    }
}

// MARK: - Custom sidebar (so selection respects our accent, not NSColor.controlAccentColor)

private struct CustomSidebar: View {
    @Binding var selection: PrefsSection
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PrefsSection.allCases) { item in
                SidebarRow(
                    item: item,
                    isSelected: selection == item,
                    accent: accent
                ) {
                    selection = item
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarRow: View {
    let item: PrefsSection
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                iconTile
                Text(item.label)
                    .font(.system(size: 13.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(item.iconGradient(systemAccent: accent))
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
                .blendMode(.plusLighter)
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0, y: 1)
    }
}
