import SwiftUI

struct BrowsePanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            SearchBar()
            TabsBar()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    tabContent
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
        }
        .background(colors.bgWindow)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.activeTab {
        case .discover:
            DiscoverTab()
        case .favorites:
            FavoritesTab()
        case .search:
            SearchTab()
        case .topVoted:
            RankedTab(sortBy: .votes)
        case .popular:
            RankedTab(sortBy: .clicks)
        case .tags:
            TagsTab()
        case .countries:
            CountriesTab()
        case .map:
            MapTab()
        case .history:
            HistoryTab()
        }
    }
}
