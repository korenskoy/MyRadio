//
//  ShortcutsPane.swift
//  MyRadio
//
//  Read-only listing of keyboard shortcuts. Mirrors the SHORTCUTS table in
//  docs/design/myradio/project/preferences.jsx. Rebinding UI is intentionally
//  not wired up — backend doesn't exist yet.
//

import SwiftUI

struct ShortcutsPane: View {
    private struct ShortcutItem: Identifiable {
        let id: String
        let name: LocalizedStringKey
        let keys: [String]
    }

    /// Live bindings — match AppShortcuts in MyRadioApp.swift exactly.
    private let items: [ShortcutItem] = [
        .init(id: "playpause", name: "Play / Pause",         keys: ["⌘", "P"]),
        .init(id: "mini",      name: "Toggle mini player",   keys: ["⌃", "⌘", "M"]),
        .init(id: "search",    name: "Find stations…",       keys: ["⌘", "F"]),
        .init(id: "sleep",     name: "Sleep timer…",         keys: ["⌘", "."]),
        .init(id: "addst",     name: "Add custom station…",  keys: ["⌘", "N"]),
        .init(id: "devtools",  name: "Toggle DevTools",      keys: ["⌥", "⌘", "I"]),
        .init(id: "prefs",     name: "Open Preferences…",    keys: ["⌘", ","]),
        .init(id: "quit",      name: "Quit MyRadio",         keys: ["⌘", "Q"]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Shortcuts")
                    .font(.system(size: 22, weight: .bold))

                groupHeader("Application")
                shortcutsGroup(items)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shortcutsGroup(_ items: [ShortcutItem]) -> some View {
        groupBox {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.system(size: 13))
                        Spacer(minLength: 8)
                        HStack(spacing: 4) {
                            ForEach(Array(item.keys.enumerated()), id: \.offset) { _, key in
                                kbd(key)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if index < items.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func kbd(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }

    private func groupHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(.uppercase)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func groupBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}
