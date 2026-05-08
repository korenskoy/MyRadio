import SwiftUI
import AppKit

@main
struct MyRadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(state)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .commands {}

        WindowGroup(id: "devtools") {
            DevToolsWindowRoot()
                .environment(state)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 480)
    }
}

// MARK: - Window configuration via AppDelegate pattern

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApp.windows.first else { return }
        configureMainWindow(window)
    }

    private func configureMainWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        window.maxSize = NSSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}
