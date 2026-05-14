//
//  AppearancePane.swift
//  MyRadio
//
//  Theme picker (Light / Dark / Auto) + accent picker.
//  Mirrors AppearancePane in docs/design/myradio/project/preferences.jsx.
//

import SwiftUI
import AppKit

struct AppearancePane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Appearance")
                    .font(.system(size: 22, weight: .bold))

                groupHeader("Theme")
                themeGroup(selection: $state.theme)

                groupHeader("Accent color")
                accentGroup(selection: $state.accent)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Theme cards

    private func themeGroup(selection: Binding<AppTheme>) -> some View {
        groupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Window appearance")
                    .font(.system(size: 13))
                HStack(spacing: 12) {
                    ForEach([AppTheme.light, .dark, .auto], id: \.self) { theme in
                        ThemeCard(theme: theme, isSelected: selection.wrappedValue == theme) {
                            selection.wrappedValue = theme
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: Accent picker

    private func accentGroup(selection: Binding<AccentName>) -> some View {
        groupBox {
            HStack(spacing: 10) {
                AccentSwatch(name: .system, isSelected: selection.wrappedValue == .system) {
                    selection.wrappedValue = .system
                }
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 4)
                ForEach(AccentName.allCases.filter { $0 != .system }, id: \.self) { name in
                    AccentSwatch(name: name, isSelected: selection.wrappedValue == name) {
                        selection.wrappedValue = name
                    }
                }
                Spacer()
            }
            .padding(14)
        }
    }

    // MARK: Helpers

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
}

// MARK: - Accent swatch

private struct AccentSwatch: View {
    let name: AccentName
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if name == .system {
                    Circle()
                        .fill(AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                            center: .center
                        ))
                } else {
                    Circle().fill(name.preset.accent)
                }
                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }
            }
            .frame(width: 26, height: 26)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                    .padding(-3)
            )
        }
        .buttonStyle(.plain)
        .help(name.displayName)
    }
}

// MARK: - Theme card

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var label: LocalizedStringKey {
        switch theme {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .auto:  return "Auto (System)"
        }
    }

    @ViewBuilder
    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        switch theme {
        case .light:
            shape.fill(Color(white: 0.96))
                .frame(width: 90, height: 56)
                .overlay(shape.stroke(Color.primary.opacity(0.10), lineWidth: 1))
                .overlay(previewChrome(fg: Color(white: 0.5), bg: Color(white: 0.85)))
        case .dark:
            shape.fill(Color(white: 0.16))
                .frame(width: 90, height: 56)
                .overlay(shape.stroke(Color.primary.opacity(0.20), lineWidth: 1))
                .overlay(previewChrome(fg: Color(white: 0.7), bg: Color(white: 0.30)))
        case .auto:
            ZStack {
                HStack(spacing: 0) {
                    Color(white: 0.96)
                    Color(white: 0.16)
                }
                .frame(width: 90, height: 56)
                .clipShape(shape)
                .overlay(shape.stroke(Color.primary.opacity(0.15), lineWidth: 1))
            }
        }
    }

    private func previewChrome(fg: Color, bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Circle().fill(fg.opacity(0.6)).frame(width: 5, height: 5)
                Circle().fill(fg.opacity(0.6)).frame(width: 5, height: 5)
                Circle().fill(fg.opacity(0.6)).frame(width: 5, height: 5)
                Spacer()
            }
            RoundedRectangle(cornerRadius: 2).fill(bg).frame(height: 6)
            RoundedRectangle(cornerRadius: 2).fill(bg).frame(width: 50, height: 6)
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}
