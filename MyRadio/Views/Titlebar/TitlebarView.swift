import SwiftUI
import RadioBrowserKit

struct TitlebarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            // Drag zone — only the titlebar moves the window
            TitlebarDragArea()

            // Titlebar gradient tint
            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                // Traffic lights placeholder area (real buttons controlled by NSWindow)
                Spacer().frame(width: 74)

                Spacer()

                // Center: title
                HStack(spacing: 6) {
                    Text(verbatim: "MyRadio")
                        .font(Typography.titlebar)
                        .foregroundStyle(colors.fg2)
                    if let name = state.currentStation?.name {
                        Text(verbatim: "—")
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
                    DebugToggleButton()
                    SettingsButton()
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

// MARK: - Debug toggle button (bug icon)

private struct DebugToggleButton: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            if state.logsVisible, let w = state.devToolsNSWindow {
                w.close()
            } else {
                openWindow(id: "devtools")
            }
        } label: {
            Image(systemName: "ladybug")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(state.logsVisible ? colors.accent.strong : colors.fg3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings button (gear icon)

private struct SettingsButton: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(colors.fg3)
        }
        .buttonStyle(.plain)
        .help(Text("Preferences (⌘,)"))
    }
}

// MARK: - Drag area (makes only the titlebar move the window)

import AppKit

private struct TitlebarDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}

