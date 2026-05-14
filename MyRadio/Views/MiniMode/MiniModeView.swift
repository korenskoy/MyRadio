import SwiftUI
import RadioBrowserKit

struct MiniModeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedColors: AppColors {
        state.appColors(systemDark: colorScheme == .dark)
    }

    var body: some View {
        HStack(spacing: 12) {
            MiniCoverView()

            VStack(alignment: .leading, spacing: 2) {
                Text(state.currentStation?.name ?? "No Station")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(resolvedColors.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(state.nowPlayingTitle ?? "Not playing")
                    .font(.system(size: 11))
                    .foregroundStyle(resolvedColors.fg2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MiniPlayButton()

            Button {
                state.toggleMiniMode()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(resolvedColors.fg3)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: AppLayout.miniWidth, height: AppLayout.miniHeight)
        .background(resolvedColors.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.rMd))
        .environment(\.appColors, resolvedColors)
    }

}

// MARK: - Mini Cover

private struct MiniCoverView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            if let station = state.currentStation {
                StationArtwork(
                    station: station,
                    size: AppLayout.miniCoverSize,
                    cornerRadius: AppLayout.rSm,
                    glyphSize: 22
                )
            } else {
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .fill(LinearGradient(
                        colors: [Color.gray, Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: AppLayout.miniCoverSize, height: AppLayout.miniCoverSize)
            }

            if let trackArt = state.currentTrackArtwork {
                Image(nsImage: trackArt)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: AppLayout.miniCoverSize, height: AppLayout.miniCoverSize)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .frame(width: AppLayout.miniCoverSize, height: AppLayout.miniCoverSize)
    }
}

// MARK: - Mini Play Button

private struct MiniPlayButton: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            state.togglePlayPause()
        } label: {
            let bgColor = scheme == .dark ? Color(hex: 0xF1EFE8) : colors.fg
            let fgColor = scheme == .dark ? Color(hex: 0x161614) : colors.bgPanel
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 13))
                .foregroundStyle(fgColor)
                .frame(width: 32, height: 32)
                .background(bgColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NSPanel-based mini window manager

final class MiniWindowManager {
    static let shared = MiniWindowManager()
    private var panel: NSPanel?

    func show(state: AppState) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: AppLayout.miniWidth, height: AppLayout.miniHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let hostingView = NSHostingView(rootView:
            MiniModeView()
                .environment(state)
        )
        panel.contentView = hostingView

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
