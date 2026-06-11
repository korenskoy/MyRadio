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
                EmptyView()
            }

            if state.searchResults.isEmpty && !state.searchQuery.isEmpty && !state.isLoadingTab {
                ContentUnavailableView.search(text: state.searchQuery)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                StationListSection(stations: state.searchResults)
            }
        }
        // .task(id:) debounces (one request per typing pause) and cancels the
        // previous search when the query changes, so out-of-order responses can't
        // overwrite newer results.
        .task(id: state.searchQuery) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await state.performSearch()
        }
    }
}
