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
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApp.windows.first else { return }
        mainWindow = window
        configureMainWindow(window)
        window.delegate = self
        // Give the window one layout pass before we reposition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.alignTrafficLights(in: window)
        }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender === mainWindow else { return frameSize }
        return NSSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
    }

    // Re-apply on key focus in case macOS reset positions.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === mainWindow else { return }
        alignTrafficLights(in: window)
    }

    private func configureMainWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        let size = NSSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        window.minSize = size
        window.maxSize = size
        window.setContentSize(size)
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        // SwiftUI can restore .resizable — strip it every time the window updates.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            window?.styleMask.remove(.resizable)
        }
    }

    // Centers traffic lights at the vertical midpoint of our 38-pt titlebar.
    // Uses contentView coordinates (fills full window via fullSizeContentView)
    // so the calculation is independent of the system titlebar's internal height.
    private func alignTrafficLights(in window: NSWindow) {
        guard let cv = window.contentView else { return }
        let centerFromTop = AppLayout.titlebarHeight / 2          // 19 pt from window top
        let cvH = cv.bounds.height
        let targetYinCV: CGFloat = cv.isFlipped ? centerFromTop : cvH - centerFromTop

        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let btn = window.standardWindowButton(type),
                  let sv  = btn.superview else { continue }
            let targetInSV = sv.convert(NSPoint(x: 0, y: targetYinCV), from: cv)
            let newY = targetInSV.y - btn.frame.height / 2
            guard abs(btn.frame.origin.y - newY) > 0.5 else { continue }
            btn.setFrameOrigin(NSPoint(x: btn.frame.origin.x, y: newY))
        }
    }
}
