import SwiftUI
import RadioBrowserKit

struct RankedTab: View {
    let sortBy: SortKind
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    enum SortKind { case votes, clicks }

    private var sorted: [Station] {
        switch sortBy {
        case .votes:
            return state.stations.sorted { ($0.votes ?? 0) > ($1.votes ?? 0) }
        case .clicks:
            return state.stations.sorted { ($0.clickcount ?? 0) > ($1.clickcount ?? 0) }
        }
    }

    private var label: String {
        switch sortBy {
        case .votes: return "votes"
        case .clicks: return "clicks"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "Top 200 by \(label)") {
                Text("via radio-browser.info · cache 4m")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
                Spacer()
                BrowseButton(label: "", icon: "arrow.clockwise", style: .ghost)
            }

            StationListSection(stations: sorted, showRank: true)
        }
    }
}
