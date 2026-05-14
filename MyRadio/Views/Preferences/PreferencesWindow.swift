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
    @SceneStorage("prefsSection") private var rawSection: String = PrefsSection.about.rawValue
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var section: PrefsSection {
        PrefsSection(rawValue: rawSection) ?? .about
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(PrefsSection.allCases, selection: Binding(
                get: { section },
                set: { rawSection = ($0 ?? .about).rawValue }
            )) { item in
                Label(item.label, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch section {
                case .about:      AboutPane()
                case .general:    PlaceholderPane(title: "General")
                case .appearance: PlaceholderPane(title: "Appearance")
                case .shortcuts:  PlaceholderPane(title: "Shortcuts")
                case .advanced:   PlaceholderPane(title: "Advanced")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("MyRadio Preferences")
        .frame(minWidth: 720, idealWidth: 760, minHeight: 540, idealHeight: 580)
    }
}
