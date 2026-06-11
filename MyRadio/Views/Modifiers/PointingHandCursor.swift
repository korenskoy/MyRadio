import SwiftUI
import AppKit

/// Pushes the pointing-hand cursor while hovering (and `active`), and reliably
/// pops it again — including when `active` flips to false mid-hover or the view
/// disappears while still hovered. A bare `onHover { push() } else { pop() }`
/// leaks a pushed cursor in both those cases, leaving the hand stuck.
private struct PointingHandCursor: ViewModifier {
    var active: Bool = true
    @State private var hovering = false
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering = $0; sync() }
            .onChange(of: active) { _, _ in sync() }
            .onDisappear {
                if pushed { NSCursor.pop(); pushed = false }
            }
    }

    private func sync() {
        let shouldPush = hovering && active
        if shouldPush, !pushed {
            NSCursor.pointingHand.push()
            pushed = true
        } else if !shouldPush, pushed {
            NSCursor.pop()
            pushed = false
        }
    }
}

extension View {
    func pointingHandCursor(active: Bool = true) -> some View {
        modifier(PointingHandCursor(active: active))
    }
}
