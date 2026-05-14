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

    var label: String {
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
}

struct PreferencesWindow: View {
    @Environment(AppState.self) private var state
    @SceneStorage("prefsSection") private var rawSection: String = PrefsSection.about.rawValue
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var section: PrefsSection {
        PrefsSection(rawValue: rawSection) ?? .about
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CustomSidebar(
                selection: Binding(
                    get: { section },
                    set: { rawSection = $0.rawValue }
                ),
                accent: state.accent.preset.accent
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch section {
                case .about:      AboutPane()
                case .general:    PlaceholderPane(title: "General")
                case .appearance: AppearancePane()
                case .shortcuts:  PlaceholderPane(title: "Shortcuts")
                case .advanced:   PlaceholderPane(title: "Advanced")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("MyRadio Preferences")
        .frame(minWidth: 720, idealWidth: 760, minHeight: 540, idealHeight: 580)
        .tint(state.accent.preset.accent)
        .preferredColorScheme(state.theme.preferredColorScheme)
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
                Image(systemName: item.symbol)
                    .font(.system(size: 15, weight: .regular))
                    .frame(width: 22)
                Text(item.label)
                    .font(.system(size: 13.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
