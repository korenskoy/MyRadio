import SwiftUI

struct FavoritesTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "\(state.favoriteStations.count) stations") {
                BrowseButton(label: "Add station", icon: "plus", style: .primary)
                BrowseButton(label: "Import", icon: "square.and.arrow.up")
                BrowseButton(label: "Export M3U", icon: "square.and.arrow.down")
                Spacer()
                BrowseButton(label: "", icon: "arrow.up.arrow.down", style: .ghost)
            }

            StationListSection(stations: state.favoriteStations)
        }
    }
}
