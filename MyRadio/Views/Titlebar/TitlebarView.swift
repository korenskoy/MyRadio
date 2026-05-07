import SwiftUI
import RadioBrowserKit

struct TitlebarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            // Titlebar gradient tint
            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 0) {
                // Traffic lights placeholder area (real buttons controlled by NSWindow)
                Spacer().frame(width: 74)

                Spacer()

                // Center: icon + title
                HStack(spacing: 6) {
                    TitleIconView()
                    Text("MyRadio")
                        .font(Typography.titlebar)
                        .foregroundStyle(colors.fg2)
                    if let name = state.currentStation?.name {
                        Text("—")
                            .font(Typography.titlebar)
                            .foregroundStyle(colors.fg3)
                        Text(name)
                            .font(Typography.titlebar)
                            .foregroundStyle(colors.fg2)
                    }
                }

                Spacer()

                // Right controls
                HStack(spacing: 8) {
                    ThemeCycleButton()
                    DebugToggleButton()
                }
                .padding(.trailing, 14)
            }
        }
        .frame(height: AppLayout.titlebarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.border)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Title icon (green square with inner circle)

private struct TitleIconView: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(colors.accent.accent)
                .frame(width: 18, height: 18)
            Circle()
                .strokeBorder(colors.accent.accent, lineWidth: 2)
                .background(Circle().fill(colors.bgWindow))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Theme cycle button (AUTO / LIGHT / DARK)

private struct ThemeCycleButton: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        Button {
            state.theme = state.theme.next
        } label: {
            Text(state.theme.shortLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.fg2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.rSm)
                        .fill(colors.bgPill)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Debug toggle button (bug icon)

private struct DebugToggleButton: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        Button {
            state.logsVisible.toggle()
        } label: {
            Image(systemName: "ladybug")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(state.logsVisible ? colors.accent.strong : colors.fg3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private extension AppTheme {
    var next: AppTheme {
        switch self {
        case .auto:  return .light
        case .light: return .dark
        case .dark:  return .auto
        }
    }

    var shortLabel: String {
        switch self {
        case .auto:  return "AUTO"
        case .light: return "LIGHT"
        case .dark:  return "DARK"
        }
    }
}
