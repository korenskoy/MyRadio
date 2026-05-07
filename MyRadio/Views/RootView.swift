import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors {
        state.appColors(systemDark: colorScheme == .dark)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Titlebar
                TitlebarView()

                // Main split
                HStack(spacing: 0) {
                    PlayerPanel()
                        .frame(width: AppLayout.playerWidth)

                    Divider()
                        .overlay(colors.border)

                    BrowsePanel()
                        .frame(maxWidth: .infinity)
                }
                .frame(height: AppLayout.contentHeight - (state.logsVisible ? AppLayout.debugHeight : 0))

                // Debug panel
                if state.logsVisible {
                    DebugPanel()
                        .frame(height: AppLayout.debugHeight)
                }
            }
        }
        .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .background(colors.bgWindow)
        .environment(\.appColors, colors)
    }
}
