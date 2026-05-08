import SwiftUI
import RadioBrowserKit

struct RankedTab: View {
    let sortBy: SortKind
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    enum SortKind { case votes, clicks }

    private var data: [Station] {
        switch sortBy {
        case .votes: state.topVotedStations
        case .clicks: state.popularStations
        }
    }

    private var label: String {
        switch sortBy {
        case .votes: "votes"
        case .clicks: "clicks"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow {
                Text("via radio-browser.info · live")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
                Spacer()
                Text("\(data.count) stations · by \(label)")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
                BrowseButton(label: "", icon: "arrow.clockwise", style: .ghost) {
                    Task {
                        switch sortBy {
                        case .votes:  await state.reloadTopVoted()
                        case .clicks: await state.reloadPopular()
                        }
                    }
                }
            }

            if data.isEmpty {
                ContentUnavailableView("Loading…", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                StationListSection(stations: data, showRank: true)
            }
        }
    }
}
