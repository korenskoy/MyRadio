import SwiftUI
import RadioBrowserKit

struct DiscoverTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        let top = Array(state.discoverTopVoted.prefix(8))
        let popular = Array(state.discoverPopular.prefix(8))

        VStack(alignment: .leading, spacing: 0) {
            if top.isEmpty && popular.isEmpty {
                ContentUnavailableView("Loading stations…", systemImage: "antenna.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                StationListSection(
                    title: "Top Voted",
                    subtitle: "radio-browser.info · live",
                    stations: top
                )

                StationListSection(
                    title: "Most Popular",
                    subtitle: "By click count",
                    stations: popular
                )
            }
        }
    }
}
