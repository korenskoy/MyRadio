import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors {
        state.appColors(systemDark: colorScheme == .dark)
    }

    var body: some View {
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
            .frame(height: AppLayout.contentHeight)
        }
        .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .background(colors.bgWindow)
        .environment(\.appColors, colors)
        .sheet(isPresented: Bindable(state).showAddStation) {
            AddStationModal()
                .environment(state)
                .environment(\.appColors, colors)
        }
    }
}
