import SwiftUI
import RadioBrowserKit

struct SearchTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    private var filtered: [Station] {
        let q = state.searchQuery.lowercased()
        guard !q.isEmpty else { return state.stations }
        return state.stations.filter { station in
            station.name.lowercased().contains(q) ||
            station.tagList.contains(where: { $0.lowercased().contains(q) }) ||
            (station.countrycode?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: state.searchQuery.isEmpty
                       ? "\(state.stations.count) stations"
                       : "\(filtered.count) results for \"\(state.searchQuery)\"") {
                BrowseButton(label: "Filter", icon: "line.3.horizontal.decrease")
                TagPill(text: "codec: any")
                TagPill(text: "bitrate: ≥128")
            }

            StationListSection(stations: filtered)
        }
    }
}

private struct TagPill: View {
    let text: String
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Text("✕")
                .font(.system(size: 9))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(colors.fg2)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(colors.bgPill)
        .clipShape(Capsule())
    }
}
