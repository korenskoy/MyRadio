import SwiftUI
import AppKit
import UserNotifications

@main
struct MyRadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(state)
                .environmentObject(state.updateChecker)
                .ignoresSafeArea()
                .onAppear { appDelegate.state = state }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .commands {
            AppShortcuts(state: state)
        }

        WindowGroup(id: "devtools") {
            DevToolsWindowRoot()
                .environment(state)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 480)

        Settings {
            PreferencesWindow()
                .environment(state)
                .environmentObject(state.updateChecker)
        }
    }
}

// MARK: - Application commands (menu bar + keyboard shortcuts)

private struct AppShortcuts: Commands {
    let state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Playback") {
            Button("Play / Pause") { state.togglePlayPause() }
                .keyboardShortcut("p", modifiers: .command)
            Button(state.isMiniMode
                   ? String(localized: "Exit Mini Player")
                   : String(localized: "Enter Mini Player")) {
                state.toggleMiniMode()
            }
            .keyboardShortcut("m", modifiers: [.control, .command])
            Divider()
            Button("Sleep Timer…") { state.showSleepTimer = true }
                .keyboardShortcut(".", modifiers: .command)
            Button("Add Custom Station…") { state.showAddStation = true }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(after: .textEditing) {
            Button("Find Stations…") {
                state.activeTab = .search
                state.searchFocusRequest = UUID()
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button(state.logsVisible
                   ? String(localized: "Hide DevTools")
                   : String(localized: "Show DevTools")) {
                if state.logsVisible, let w = state.devToolsNSWindow {
                    w.close()
                } else {
                    openWindow(id: "devtools")
                }
            }
            .keyboardShortcut("i", modifiers: [.option, .command])
        }
    }
}

// MARK: - Window configuration via AppDelegate pattern

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?
    /// Set from the WindowGroup's onAppear so we can consult `confirmQuit`
    /// and the current playback state when the app is about to terminate.
    weak var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        guard let window = NSApp.windows.first else { return }
        mainWindow = window
        configureMainWindow(window)
        window.delegate = self
        // Give the window one layout pass before we reposition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.alignTrafficLights(in: window)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let state, state.confirmQuit, state.isPlaying else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = String(localized: "Quit MyRadio?")
        alert.informativeText = String(localized: "Audio is currently playing. Quitting will stop the stream.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Quit"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
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

// MARK: - Notification presentation while app is foregrounded

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
