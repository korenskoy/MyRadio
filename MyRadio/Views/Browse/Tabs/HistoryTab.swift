import SwiftUI
import RadioBrowserKit

struct HistoryTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "Last 30 days · stored locally") {
                BrowseButton(label: "All time", icon: "line.3.horizontal.decrease")
                Spacer()
                BrowseButton(label: "Clear history", icon: "trash", style: .ghost)
            }

            ForEach(state.historyGroups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(group.dayLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(colors.fg3)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Spacer()

                        Text("\(group.items.count) sessions")
                            .font(Typography.meta)
                            .foregroundStyle(colors.fg3)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                    ForEach(group.items) { entry in
                        if let station = state.station(for: entry.stationUUID) {
                            StationRow(
                                station: station,
                                index: 0,
                                isPlaying: state.currentStation?.stationuuid == station.stationuuid,
                                showDuration: entry.durationFormatted,
                                timeLabel: entry.timeFormatted
                            )
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
