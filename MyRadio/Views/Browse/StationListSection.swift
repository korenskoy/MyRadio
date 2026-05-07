import SwiftUI
import RadioBrowserKit

struct StationListSection: View {
    var title: String? = nil
    var subtitle: String? = nil
    let stations: [Station]
    var showRank: Bool = false

    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                SectionHeader(title: title, subtitle: subtitle)
            }

            ForEach(Array(stations.enumerated()), id: \.element.stationuuid) { idx, station in
                StationRow(
                    station: station,
                    index: idx,
                    isPlaying: state.currentStation?.stationuuid == station.stationuuid,
                    showRank: showRank,
                    rankNumber: idx + 1
                )

                if idx < stations.count - 1 {
                    Divider()
                        .padding(.leading, AppLayout.rowNumWidth + AppLayout.rowGap + AppLayout.rowPaddingH)
                }
            }
        }
        .padding(.bottom, 18)
    }
}
