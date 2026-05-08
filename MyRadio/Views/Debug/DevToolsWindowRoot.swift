import SwiftUI
import AppKit

struct DevToolsWindowRoot: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors {
        state.appColors(systemDark: colorScheme == .dark)
    }

    var body: some View {
        DebugPanel()
            .environment(\.appColors, colors)
            .frame(minWidth: 700, minHeight: 300)
            .background(
                WindowConfigurator { window in
                    window.title = "DevTools — MyRadio"
                    window.minSize = NSSize(width: 700, height: 300)
                    state.devToolsNSWindow = window
                }
            )
            .onAppear  { state.logsVisible = true }
            .onDisappear {
                state.logsVisible = false
                state.devToolsNSWindow = nil
            }
    }
}

// One-shot NSWindow accessor via a hidden NSView
private struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
