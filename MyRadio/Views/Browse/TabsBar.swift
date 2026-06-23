import SwiftUI
import AppKit

struct TabsBar: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var metrics = ScrollMetrics()
    @State private var liveOffsetX: CGFloat = 0          // synced mirror of the live offset
    @State private var barFrame: CGRect = .zero          // SwiftUI global (window) coords
    @State private var wheelMonitor: Any?

    private let tabs = TabKind.allCases
    private let edgeInset: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    TabButton(tab: tab).id(tab)
                }
            }
            .padding(.horizontal, edgeInset)
        }
        .scrollPosition($scrollPosition)
        // Track offset/content/container width so the chevrons only appear when
        // the bar actually overflows and there's room to scroll that direction.
        .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
            ScrollMetrics(offsetX: geo.contentOffset.x,
                          contentW: geo.contentSize.width,
                          containerW: geo.containerSize.width)
        } action: { _, new in
            metrics = new
            liveOffsetX = new.offsetX
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barFrame = $0 }
        .overlay(alignment: .leading) {
            if metrics.overflowing && !atStart {
                chevron("chevron.backward") { page(-1) }
            }
        }
        .overlay(alignment: .trailing) {
            if metrics.overflowing && !atEnd {
                chevron("chevron.forward") { page(1) }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.border)
                .frame(height: 0.5)
        }
        .onAppear { installWheelMonitor() }
        .onDisappear {
            if let m = wheelMonitor { NSEvent.removeMonitor(m); wheelMonitor = nil }
        }
    }

    // Hidden once the first/last tab is fully visible. Tolerance == the bar's
    // leading inset, so a few px of residual offset left after a manual scroll
    // don't keep a chevron stuck, while a genuinely clipped edge tab still shows it.
    private var atStart: Bool { metrics.offsetX <= edgeInset + 0.5 }
    private var atEnd: Bool { metrics.offsetX >= metrics.maxOffsetX - edgeInset - 0.5 }

    /// Scrolls roughly a page in `dir` (-1 = toward start, +1 = toward end).
    private func page(_ dir: Int) {
        let amount = max(metrics.containerW * 0.7, 120)
        let target = min(max(0, metrics.offsetX + CGFloat(dir) * amount), metrics.maxOffsetX)
        liveOffsetX = target
        withAnimation(.easeOut(duration: 0.2)) {
            scrollPosition.scrollTo(x: target)
        }
    }

    /// Mouse wheel (vertical) → horizontal scroll while the cursor is over the
    /// bar. Trackpads already scroll horizontally, so we only translate coarse
    /// wheel events (no precise deltas) and leave precise/trackpad events alone.
    private func installWheelMonitor() {
        guard wheelMonitor == nil else { return }
        wheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard !event.hasPreciseScrollingDeltas,     // legacy mouse wheel only
                  metrics.overflowing,
                  let window = event.window,
                  let contentH = window.contentView?.bounds.height else { return event }
            // locationInWindow is bottom-left origin; SwiftUI global is top-left.
            let p = CGPoint(x: event.locationInWindow.x, y: contentH - event.locationInWindow.y)
            guard barFrame.contains(p) else { return event }
            let delta = event.scrollingDeltaY
            guard delta != 0 else { return event }
            // ponytail: wheel deltas come in "line" units; ×8 ≈ one notch ≈ a tab.
            // Tune this factor if scrolling feels too fast/slow.
            let target = min(max(0, liveOffsetX - delta * 8), metrics.maxOffsetX)
            liveOffsetX = target
            scrollPosition.scrollTo(x: target)
            return nil   // consume so the list underneath doesn't also scroll
        }
    }

    private func chevron(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(colors.fg2)
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Opaque backing OUTSIDE the button label: the .plain press effect dims
        // the label (incl. any background inside it), which would let the tab
        // underneath bleed through. Keeping it here stays solid while pressed.
        .background(colors.bgWindow)
        .pointingHandCursor()
    }
}

/// Snapshot of the tab bar's scroll geometry, used to drive chevron visibility.
private struct ScrollMetrics: Equatable {
    var offsetX: CGFloat = 0
    var contentW: CGFloat = 1
    var containerW: CGFloat = 0
    var overflowing: Bool { contentW > containerW + 1 }
    var maxOffsetX: CGFloat { max(0, contentW - containerW) }
}

private struct TabButton: View {
    let tab: TabKind
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    private var isActive: Bool { state.activeTab == tab }

    private var count: String? {
        switch tab {
        case .favorites:
            let c = state.favorites.count
            return c > 0 ? c.formatted() : nil
        case .history:
            let c = state.history.count
            return c > 0 ? c.formatted() : nil
        default:
            return nil
        }
    }

    var body: some View {
        Button {
            state.activeTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 11))
                Text(tab.label)
                    .font(.system(size: 12.5, weight: .medium))

                if let count {
                    Text(count)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive ? colors.accent.soft : colors.bgPill)
                        )
                        .foregroundStyle(isActive ? colors.accent.strong : colors.fg3)
                }
            }
            .foregroundStyle(isActive ? colors.fg : (hovered ? colors.fg : colors.fg2))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                if isActive {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.accent.strong)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                        .offset(y: 0.25)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
