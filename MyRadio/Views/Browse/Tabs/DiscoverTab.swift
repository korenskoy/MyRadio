import SwiftUI
import RadioBrowserKit

struct DiscoverTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        let top = Array(state.stations.prefix(4))
        let popular = Array(state.stations.dropFirst(4).prefix(4))

        VStack(alignment: .leading, spacing: 0) {
            StationListSection(
                title: "Trending in Jazz",
                subtitle: "Curated · updated 2m ago",
                stations: top
            )

            StationListSection(
                title: "Because you played NTS Radio",
                subtitle: "Recommendation",
                stations: popular
            )
        }
    }
}
