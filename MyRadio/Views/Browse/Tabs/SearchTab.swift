import SwiftUI
import RadioBrowserKit

struct SearchTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: state.searchQuery.isEmpty
                       ? "Type to search radio-browser.info"
                       : "\(state.searchResults.count) results for \"\(state.searchQuery)\"") {
                BrowseButton(label: "Filter", icon: "line.3.horizontal.decrease")
                TagPill(text: "codec: any")
                TagPill(text: "bitrate: ≥128")
            }

            if state.searchResults.isEmpty && !state.searchQuery.isEmpty && !state.isLoadingTab {
                ContentUnavailableView.search(text: state.searchQuery)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                StationListSection(stations: state.searchResults)
            }
        }
        .onChange(of: state.searchQuery) { _, _ in
            Task { await state.performSearch() }
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
