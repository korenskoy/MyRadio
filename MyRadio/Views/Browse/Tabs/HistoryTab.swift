import SwiftUI
import RadioBrowserKit

struct HistoryTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var showAllTime = false
    @State private var showClearConfirm = false

    /// History entries newer than 30 days unless "All time" is selected.
    private var visibleGroups: [HistoryGroup] {
        guard !showAllTime else { return state.historyGroups }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        return state.historyGroups.compactMap { group in
            let items = group.items.filter { $0.playedAt >= cutoff }
            return items.isEmpty ? nil : HistoryGroup(day: group.day, items: items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: showAllTime
                       ? "All time · stored locally"
                       : "Last 30 days · stored locally") {
                BrowseButton(label: showAllTime ? "All time" : "Last 30 days",
                             icon: "line.3.horizontal.decrease") {
                    showAllTime.toggle()
                }
                Spacer()
                BrowseButton(label: "Clear history", icon: "trash", style: .ghost) {
                    showClearConfirm = true
                }
                .disabled(state.history.isEmpty)
            }

            ForEach(visibleGroups) { group in
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
        .confirmationDialog(
            "Clear listening history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear history", role: .destructive) { state.clearHistory() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
